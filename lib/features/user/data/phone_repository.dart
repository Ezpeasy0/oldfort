// lib/features/user/data/phone_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/phone_utils.dart';

class PhoneRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference _doc(String phoneNumber) {
    final formatted = PhoneUtils.toE164(phoneNumber);
    final hash = PhoneUtils.hashPhoneNumber(formatted);
    return _db.collection('phones').doc(hash);
  }

  Future<bool> checkPhoneExists(String phoneNumber) async {
    final docSnapshot = await _doc(phoneNumber).get();
    return docSnapshot.exists;
  }

  Future<void> createPhoneRecord({
    required String phoneNumber,
    required String uid,
  }) async {
    await _doc(phoneNumber)
        .set({'uid': uid, 'createdAt': FieldValue.serverTimestamp()});
  }
}

final phoneRepositoryProvider = Provider<PhoneRepository>(
  (ref) => PhoneRepository(),
);
