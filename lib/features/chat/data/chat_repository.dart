import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../friends/data/friend_repository.dart';

enum ChatType { community, private, group }

ChatType chatTypeOf(String chatId) {
  if (chatId.startsWith('community_')) return ChatType.community;
  if (chatId.startsWith('p_')) return ChatType.private;
  return ChatType.group;
}

class CommunityRoom {
  const CommunityRoom(this.id, this.name, this.image);

  final String id;
  final String name;
  final String image;
}

const communityRooms = [
  CommunityRoom('community_cooking', 'ทำอาหาร', 'assets/images/chat/room_cooking.png'),
  CommunityRoom('community_dharma', 'ธรรมะ', 'assets/images/chat/room_dharma.png'),
  CommunityRoom('community_pets', 'สัตว์เลี้ยง', 'assets/images/chat/room_pets.png'),
];

CommunityRoom? communityRoomById(String id) {
  for (final room in communityRooms) {
    if (room.id == id) return room;
  }
  return null;
}

DateTime? _toDate(Object? value) => value is Timestamp ? value.toDate() : null;

class ChatRoom {
  const ChatRoom({
    required this.id,
    required this.type,
    required this.name,
    required this.ownerId,
    required this.memberIds,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.lastSenderId,
    required this.createdAt,
    required this.lastReadAt,
  });

  final String id;
  final ChatType type;
  final String name;
  final String? ownerId;
  final List<String> memberIds;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String? lastSenderId;
  final DateTime? createdAt;
  final Map<String, DateTime> lastReadAt;

  factory ChatRoom.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final reads = <String, DateTime>{};
    final rawReads = data['lastReadAt'];
    if (rawReads is Map) {
      rawReads.forEach((key, value) {
        final at = _toDate(value);
        if (key is String && at != null) reads[key] = at;
      });
    }
    return ChatRoom(
      id: doc.id,
      type: chatTypeOf(doc.id),
      name: data['name'] as String? ?? '',
      ownerId: data['ownerId'] as String?,
      memberIds: List<String>.from(data['memberIds'] as List? ?? const []),
      lastMessage: data['lastMessage'] as String?,
      lastMessageAt: _toDate(data['lastMessageAt']),
      lastSenderId: data['lastSenderId'] as String?,
      createdAt: _toDate(data['createdAt']),
      lastReadAt: reads,
    );
  }

  String otherMemberId(String myUid) =>
      memberIds.firstWhere((id) => id != myUid, orElse: () => '');

  bool isUnreadFor(String myUid) {
    final last = lastMessageAt;
    if (last == null || lastSenderId == myUid) return false;
    final read = lastReadAt[myUid];
    return read == null || read.isBefore(last);
  }

  int readersOf(DateTime sentAt, String senderId) {
    var count = 0;
    lastReadAt.forEach((uid, at) {
      if (uid == senderId || at.isBefore(sentAt)) return;
      if (type != ChatType.community && !memberIds.contains(uid)) return;
      count++;
    });
    return count;
  }

  DateTime get sortTime => lastMessageAt ?? createdAt ?? DateTime(2000);
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
    required this.pending,
  });

  final String id;
  final String senderId;
  final String text;
  final DateTime? createdAt;
  final bool pending;

  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] as String? ?? '',
      text: data['text'] as String? ?? '',
      createdAt: _toDate(data['createdAt']),
      pending: doc.metadata.hasPendingWrites,
    );
  }
}

class ChatRepository {
  ChatRepository(this._db);

  final FirebaseFirestore _db;

  static const maxMessageLength = 1000;
  static const maxGroupMembers = 50;

  CollectionReference<Map<String, dynamic>> get _chats => _db.collection('chats');

  DocumentReference<Map<String, dynamic>> _chat(String chatId) => _chats.doc(chatId);

  Stream<ChatRoom?> watchChat(String chatId) => _chat(chatId)
      .snapshots()
      .map((snap) => snap.exists ? ChatRoom.fromDoc(snap) : null);

  Stream<List<ChatMessage>> watchMessages(String chatId) => _chat(chatId)
      .collection('messages')
      .orderBy('createdAt', descending: true)
      .limit(200)
      .snapshots(includeMetadataChanges: true)
      .map((snap) => snap.docs.map(ChatMessage.fromDoc).toList());

  Stream<List<ChatRoom>> watchMyChats(String myUid) => _chats
      .where('memberIds', arrayContains: myUid)
      .snapshots()
      .map((snap) {
        final rooms = snap.docs.map(ChatRoom.fromDoc).toList()
          ..sort((a, b) => b.sortTime.compareTo(a.sortTime));
        return rooms;
      });

  Future<String> ensurePrivateChat(String myUid, String friendUid) async {
    final chatId = 'p_${friendPairId(myUid, friendUid)}';
    final ref = _chat(chatId);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'type': 'private',
        'memberIds': [myUid, friendUid]..sort(),
        'createdAt': FieldValue.serverTimestamp(),
        'lastReadAt': <String, dynamic>{},
      });
    }
    return chatId;
  }

  Future<String> createGroup({
    required String ownerUid,
    required List<String> memberUids,
    required String name,
  }) async {
    final ref = _chats.doc();
    await ref.set({
      'type': 'group',
      'name': name,
      'ownerId': ownerUid,
      'memberIds': {ownerUid, ...memberUids}.toList(),
      'createdAt': FieldValue.serverTimestamp(),
      'lastReadAt': <String, dynamic>{},
    });
    return ref.id;
  }

  Future<void> sendMessage(String chatId, String myUid, String text) {
    final batch = _db.batch();
    batch.set(_chat(chatId).collection('messages').doc(), {
      'senderId': myUid,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (chatTypeOf(chatId) != ChatType.community) {
      batch.update(_chat(chatId), {
        'lastMessage': text.length > 100 ? '${text.substring(0, 100)}…' : text,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastSenderId': myUid,
        'lastReadAt.$myUid': FieldValue.serverTimestamp(),
      });
    }
    return batch.commit();
  }

  Future<void> markRead(String chatId, String myUid) {
    if (chatTypeOf(chatId) == ChatType.community) {
      return _chat(chatId).set({
        'type': 'community',
        'lastReadAt': {myUid: FieldValue.serverTimestamp()},
      }, SetOptions(merge: true));
    }
    return _chat(chatId).update({'lastReadAt.$myUid': FieldValue.serverTimestamp()});
  }


  Future<void> renameGroup(String chatId, String name) =>
      _chat(chatId).update({'name': name});

  Future<void> addMembers(String chatId, List<String> uids) =>
      _chat(chatId).update({'memberIds': FieldValue.arrayUnion(uids)});

  Future<void> removeMember(String chatId, String uid) =>
      _chat(chatId).update({'memberIds': FieldValue.arrayRemove([uid])});

  Future<void> leaveGroup(String chatId, String myUid) =>
      _chat(chatId).update({'memberIds': FieldValue.arrayRemove([myUid])});

  Future<void> deleteGroup(String chatId) => _chat(chatId).delete();
}

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(FirebaseFirestore.instance),
);

final chatProvider = StreamProvider.autoDispose.family<ChatRoom?, String>(
  (ref, chatId) => ref.watch(chatRepositoryProvider).watchChat(chatId),
);

final messagesProvider =
    StreamProvider.autoDispose.family<List<ChatMessage>, String>(
  (ref, chatId) => ref.watch(chatRepositoryProvider).watchMessages(chatId),
);

final myChatsProvider = StreamProvider.autoDispose<List<ChatRoom>>((ref) {
  final uid = ref.watch(myUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(chatRepositoryProvider).watchMyChats(uid);
});