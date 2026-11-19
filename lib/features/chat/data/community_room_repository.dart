import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'chat_repository.dart';

const roomIcons = <String, IconData>{
  'cooking': Icons.soup_kitchen_outlined,
  'dharma': Icons.self_improvement_rounded,
  'pets': Icons.pets_rounded,
  'garden': Icons.local_florist_outlined,
  'music': Icons.music_note_outlined,
  'travel': Icons.landscape_outlined,
  'health': Icons.favorite_border_rounded,
  'chat': Icons.forum_outlined,
};

IconData roomIconOf(String key) => roomIcons[key] ?? Icons.forum_outlined;

const _defaultRooms = [
  (id: 'community_cooking', name: 'ทำอาหาร', icon: 'cooking', image: 'assets/images/chat/room_cooking.png'),
  (id: 'community_dharma', name: 'ธรรมะ', icon: 'dharma', image: 'assets/images/chat/room_dharma.png'),
  (id: 'community_pets', name: 'สัตว์เลี้ยง', icon: 'pets', image: 'assets/images/chat/room_pets.png'),
];

class CommunityRoom {
  const CommunityRoom({
    required this.id,
    required this.name,
    required this.icon,
    required this.open,
    required this.order,
    this.imageUrl,
  });

  final String id;
  final String name;
  final String icon;
  final bool open;
  final int order;

  /// Cover uploaded by an admin. Shown before [image].
  final String? imageUrl;

  /// Built-in cover of the 3 original rooms.
  String? get image {
    for (final room in _defaultRooms) {
      if (room.id == id) return room.image;
    }
    return null;
  }

  factory CommunityRoom.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return CommunityRoom(
      id: doc.id,
      name: data['name'] as String? ?? '',
      icon: data['icon'] as String? ?? 'chat',
      open: data['open'] as bool? ?? false,
      order: (data['order'] as num?)?.toInt() ?? 0,
      imageUrl: data['imageUrl'] as String?,
    );
  }
}

class CommunityRoomRepository {
  CommunityRoomRepository(this._db, this._storage);

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  static const maxNameLength = 30;

  CollectionReference<Map<String, dynamic>> get _rooms => _db.collection('communityRooms');

  Stream<List<CommunityRoom>> watchRooms() => _rooms.snapshots().map((snap) {
        final rooms = snap.docs.map(CommunityRoom.fromDoc).toList()
          ..sort((a, b) => a.order.compareTo(b.order));
        return rooms;
      });

  Stream<CommunityRoom?> watchRoom(String id) =>
      _rooms.doc(id).snapshots().map((s) => s.exists ? CommunityRoom.fromDoc(s) : null);

  Future<void> ensureDefaultRooms() async {
    for (var i = 0; i < _defaultRooms.length; i++) {
      final room = _defaultRooms[i];
      final ref = _rooms.doc(room.id);
      final snap = await ref.get();
      if (snap.exists) continue;
      await ref.set({
        'name': room.name,
        'icon': room.icon,
        'open': true,
        'order': i,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<String> addRoom(String name, String icon) async {
    final snap = await _rooms.get();
    var order = 0;
    for (final doc in snap.docs) {
      final o = (doc.data()['order'] as num?)?.toInt() ?? 0;
      if (o >= order) order = o + 1;
    }
    final id = 'community_${_rooms.doc().id}';
    await _rooms.doc(id).set({
      'name': name,
      'icon': icon,
      'open': true,
      'order': order,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return id;
  }

  Future<void> setCover(String id, PickedImage image, {String? oldUrl}) async {
    final ref = _storage.ref('rooms/$id/${DateTime.now().millisecondsSinceEpoch}.${image.extension}');
    await ref.putData(image.bytes, SettableMetadata(contentType: image.contentType));
    final url = await ref.getDownloadURL();
    await _rooms.doc(id).update({'imageUrl': url});
    await _deleteFile(oldUrl);
  }

  Future<void> removeCover(String id, String? oldUrl) async {
    await _rooms.doc(id).update({'imageUrl': FieldValue.delete()});
    await _deleteFile(oldUrl);
  }

  Future<void> _deleteFile(String? url) async {
    if (url == null) return;
    try {
      await _storage.refFromURL(url).delete();
    } catch (_) {}
  }

  Future<void> updateRoom(String id, {required String name, required String icon}) =>
      _rooms.doc(id).update({'name': name, 'icon': icon});

  Future<void> setOpen(String id, bool open) => _rooms.doc(id).update({'open': open});
}

final communityRoomRepositoryProvider = Provider<CommunityRoomRepository>(
  (ref) => CommunityRoomRepository(FirebaseFirestore.instance, FirebaseStorage.instance),
);

final communityRoomsProvider = StreamProvider.autoDispose<List<CommunityRoom>>(
  (ref) => ref.watch(communityRoomRepositoryProvider).watchRooms(),
);

final openCommunityRoomsProvider = Provider.autoDispose<AsyncValue<List<CommunityRoom>>>(
  (ref) => ref
      .watch(communityRoomsProvider)
      .whenData((rooms) => rooms.where((r) => r.open).toList()),
);

final communityRoomProvider = StreamProvider.autoDispose.family<CommunityRoom?, String>(
  (ref, id) => ref.watch(communityRoomRepositoryProvider).watchRoom(id),
);
