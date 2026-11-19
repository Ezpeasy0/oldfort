import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AdminUser {
  const AdminUser({
    required this.uid,
    required this.phone,
    required this.firstName,
    required this.lastName,
    required this.nickname,
    required this.role,
    required this.suspended,
    required this.createdAt,
  });

  final String uid;
  final String phone;
  final String firstName;
  final String lastName;
  final String nickname;
  final String role;
  final bool suspended;
  final DateTime? createdAt;

  String get fullName => '$firstName $lastName';
  bool get isAdmin => role == 'admin';

  /// +66812345678 -> 081-234-5678
  String get displayPhone {
    if (!phone.startsWith('+66') || phone.length != 12) return phone;
    final local = '0${phone.substring(3)}';
    return '${local.substring(0, 3)}-${local.substring(3, 6)}-${local.substring(6)}';
  }

  factory AdminUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final created = data['createdAt'];
    return AdminUser(
      uid: doc.id,
      phone: data['phone'] as String? ?? '',
      firstName: data['firstName'] as String? ?? '',
      lastName: data['lastName'] as String? ?? '',
      nickname: data['nickname'] as String? ?? '',
      role: data['role'] as String? ?? 'member',
      suspended: data['suspended'] as bool? ?? false,
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }
}

class AdminRepository {
  AdminRepository(this._db, this._functions);

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  // Called by URL like checkPhone: the emulator cannot reach cloudfunctions.net.
  static const _setUserSuspendedUrl = 'https://setusersuspended-seuelxgtgq-as.a.run.app';

  Stream<List<AdminUser>> watchUsers() =>
      _db.collection('users').snapshots().map((snap) {
        final users = snap.docs.map(AdminUser.fromDoc).toList()
          ..sort((a, b) => a.fullName.compareTo(b.fullName));
        return users;
      });

  Stream<AdminUser?> watchUser(String uid) => _db
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((snap) => snap.exists ? AdminUser.fromDoc(snap) : null);

  Future<void> setSuspended(String uid, bool suspended) async {
    await _functions
        .httpsCallableFromUrl(_setUserSuspendedUrl)
        .call<Object?>({'uid': uid, 'suspended': suspended});
  }
}

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepository(
    FirebaseFirestore.instance,
    FirebaseFunctions.instance,
  ),
);

final adminUsersProvider = StreamProvider.autoDispose<List<AdminUser>>(
  (ref) => ref.watch(adminRepositoryProvider).watchUsers(),
);

final adminUserProvider = StreamProvider.autoDispose.family<AdminUser?, String>(
  (ref, uid) => ref.watch(adminRepositoryProvider).watchUser(uid),
);
