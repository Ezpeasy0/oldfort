import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  const AppUser({
    required this.uid,
    required this.phone,
    required this.firstName,
    required this.lastName,
    required this.nickname,
    required this.role,
  });

  final String uid;
  final String phone; // +66xxxxxxxxx
  final String firstName;
  final String lastName;
  final String nickname;
  final String role; // member or admin

  String get fullName => '$firstName $lastName';
  bool get isAdmin => role == 'admin';

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return AppUser(
      uid: doc.id,
      phone: data['phone'] as String? ?? '',
      firstName: data['firstName'] as String? ?? '',
      lastName: data['lastName'] as String? ?? '',
      nickname: data['nickname'] as String? ?? '',
      role: data['role'] as String? ?? 'member',
    );
  }
}