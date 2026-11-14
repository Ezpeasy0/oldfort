import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_user.dart';

class UserRepository {
  UserRepository(this._db);

  final FirebaseFirestore _db;

  static const pdpaVersion = '1.0';

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('users').doc(uid);

  Stream<AppUser?> watchUser(String uid) =>
      _doc(uid)
          .snapshots()
          .map((snap) => snap.exists ? AppUser.fromDoc(snap) : null);

  Future<void> createProfile({
    required User user,
    required String firstName,
    required String lastName,
    required String nickname,
  }) {
    return _doc(user.uid).set({
      'phone': user.phoneNumber,
      'firstName': firstName,
      'lastName': lastName,
      'nickname': nickname,
      'role': 'member',
      'pdpaVersion': pdpaVersion,
      'pdpaAcceptedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateName(String uid, String field, String value) {
    final batch = _db.batch()
      ..update(_doc(uid), {
        field: value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    if (field == 'nickname') {
      batch.update(_db.collection('publicProfiles').doc(uid), {
        'nickname': value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    return batch.commit();
  }

  Future<void> updatePhone(String uid, String phoneE164) {
    return _doc(
      uid,
    ).update({'phone': phoneE164, 'updatedAt': FieldValue.serverTimestamp()});
  }
}

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepository(FirebaseFirestore.instance),
);

final authUserProvider = StreamProvider<User?>(
  (ref) => FirebaseAuth.instance.userChanges(),
);

final currentUserProfileProvider = StreamProvider<AppUser?>((ref) {
  final user = ref.watch(authUserProvider).value;
  if (user == null) return Stream.value(null);
  return ref.watch(userRepositoryProvider).watchUser(user.uid);
});
