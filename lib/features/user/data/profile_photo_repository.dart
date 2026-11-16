import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chat/data/chat_repository.dart';

class ProfilePhotoRepository {
  ProfilePhotoRepository(this._db, this._storage);

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('publicProfiles').doc(uid);

  Future<void> setPhoto(String uid, PickedImage image, {String? oldUrl}) async {
    final path = 'users/$uid/${DateTime.now().millisecondsSinceEpoch}.${image.extension}';
    final ref = _storage.ref(path);
    await ref.putData(image.bytes, SettableMetadata(contentType: image.contentType));
    final url = await ref.getDownloadURL();
    await _doc(uid).update({
      'photoUrl': url,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _deleteFile(oldUrl);
  }

  Future<void> removePhoto(String uid, String? oldUrl) async {
    await _doc(uid).update({
      'photoUrl': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _deleteFile(oldUrl);
  }

  Future<void> _deleteFile(String? url) async {
    if (url == null) return;
    try {
      await _storage.refFromURL(url).delete();
    } catch (_) {}
  }
}

final profilePhotoRepositoryProvider = Provider<ProfilePhotoRepository>(
  (ref) => ProfilePhotoRepository(FirebaseFirestore.instance, FirebaseStorage.instance),
);
