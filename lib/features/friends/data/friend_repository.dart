import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../user/data/user_repository.dart';

class PublicProfile {
  const PublicProfile({
    required this.uid,
    required this.nickname,
    required this.friendCode,
  });

  final String uid;
  final String nickname;
  final String friendCode;

  factory PublicProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return PublicProfile(
      uid: doc.id,
      nickname: data['nickname'] as String? ?? '',
      friendCode: data['friendCode'] as String? ?? '',
    );
  }
}

class FriendRequest {
  const FriendRequest({required this.fromUid, required this.toUid});

  final String fromUid;
  final String toUid;

  factory FriendRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return FriendRequest(
      fromUid: data['from'] as String? ?? '',
      toUid: data['to'] as String? ?? '',
    );
  }
}

enum SendRequestResult { sent, becameFriends }

String friendPairId(String a, String b) =>
    a.compareTo(b) < 0 ? '${a}_$b' : '${b}_$a';

class FriendCode {
  FriendCode._();

  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const length = 6;
  static final _random = Random.secure();

  static String generate() => List.generate(
        length,
        (_) => _alphabet[_random.nextInt(_alphabet.length)],
      ).join();

  static bool isValid(String code) =>
      RegExp('^[$_alphabet]{$length}\$').hasMatch(code);
}

class FriendRepository {
  FriendRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _profiles =>
      _db.collection('publicProfiles');
  CollectionReference<Map<String, dynamic>> get _codes =>
      _db.collection('friendCodes');
  CollectionReference<Map<String, dynamic>> get _requests =>
      _db.collection('friendRequests');
  CollectionReference<Map<String, dynamic>> get _friendships =>
      _db.collection('friendships');

  Future<void> ensurePublicProfile(String uid, String nickname) {
    return _db.runTransaction((tx) async {
      final profile = await tx.get(_profiles.doc(uid));
      if (profile.exists) return;

      for (var attempt = 0; attempt < 5; attempt++) {
        final code = FriendCode.generate();
        final codeDoc = await tx.get(_codes.doc(code));
        if (codeDoc.exists) continue;

        tx.set(_codes.doc(code), {'uid': uid});
        tx.set(_profiles.doc(uid), {
          'nickname': nickname,
          'friendCode': code,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return;
      }
      throw StateError('สร้างรหัสเพื่อนไม่สำเร็จ');
    });
  }

  Stream<PublicProfile?> watchProfile(String uid) => _profiles
      .doc(uid)
      .snapshots()
      .map((snap) => snap.exists ? PublicProfile.fromDoc(snap) : null);

  Future<PublicProfile?> findByCode(String code) async {
    final codeDoc = await _codes.doc(code).get();
    final uid = codeDoc.data()?['uid'] as String?;
    if (uid == null) return null;
    final profile = await _profiles.doc(uid).get();
    return profile.exists ? PublicProfile.fromDoc(profile) : null;
  }

  Stream<List<String>> watchFriendIds(String myUid) => _friendships
      .where('memberIds', arrayContains: myUid)
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) => List<String>.from(doc.data()['memberIds'] as List))
          .map((ids) => ids.firstWhere((id) => id != myUid, orElse: () => ''))
          .where((id) => id.isNotEmpty)
          .toList());

  Stream<List<FriendRequest>> watchIncoming(String myUid) => _requests
      .where('to', isEqualTo: myUid)
      .snapshots()
      .map((snap) => snap.docs.map(FriendRequest.fromDoc).toList());

  Stream<List<FriendRequest>> watchOutgoing(String myUid) => _requests
      .where('from', isEqualTo: myUid)
      .snapshots()
      .map((snap) => snap.docs.map(FriendRequest.fromDoc).toList());

  Future<SendRequestResult> sendRequest(String myUid, String toUid) async {
    final reverse = await _requests.doc('${toUid}_$myUid').get();
    if (reverse.exists) {
      await accept(myUid, toUid);
      return SendRequestResult.becameFriends;
    }
    await _requests.doc('${myUid}_$toUid').set({
      'from': myUid,
      'to': toUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return SendRequestResult.sent;
  }

  Future<void> accept(String myUid, String fromUid) {
    final ids = [myUid, fromUid]..sort();
    final batch = _db.batch()
      ..set(_friendships.doc(friendPairId(myUid, fromUid)), {
        'memberIds': ids,
        'createdAt': FieldValue.serverTimestamp(),
      })
      ..delete(_requests.doc('${fromUid}_$myUid'));
    return batch.commit();
  }

  Future<void> reject(String myUid, String fromUid) =>
      _requests.doc('${fromUid}_$myUid').delete();

  Future<void> cancel(String myUid, String toUid) =>
      _requests.doc('${myUid}_$toUid').delete();

  Future<void> removeFriend(String myUid, String friendUid) =>
      _friendships.doc(friendPairId(myUid, friendUid)).delete();
}


final friendRepositoryProvider = Provider<FriendRepository>(
  (ref) => FriendRepository(FirebaseFirestore.instance),
);

final myUidProvider = Provider<String?>(
  (ref) => ref.watch(authUserProvider).value?.uid,
);

final publicProfileProvider =
    StreamProvider.autoDispose.family<PublicProfile?, String>(
  (ref, uid) => ref.watch(friendRepositoryProvider).watchProfile(uid),
);

final myPublicProfileProvider = StreamProvider.autoDispose<PublicProfile?>((ref) {
  final uid = ref.watch(myUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(friendRepositoryProvider).watchProfile(uid);
});

final friendIdsProvider = StreamProvider.autoDispose<List<String>>((ref) {
  final uid = ref.watch(myUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(friendRepositoryProvider).watchFriendIds(uid);
});

final incomingRequestsProvider =
    StreamProvider.autoDispose<List<FriendRequest>>((ref) {
  final uid = ref.watch(myUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(friendRepositoryProvider).watchIncoming(uid);
});

final outgoingRequestsProvider =
    StreamProvider.autoDispose<List<FriendRequest>>((ref) {
  final uid = ref.watch(myUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(friendRepositoryProvider).watchOutgoing(uid);
});