import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/friends/data/friend_repository.dart';

enum SessionStatus { loading, signedOut, needsProfile, ready, error }

class SessionController extends ChangeNotifier {
  SessionController(this._auth, this._db) {
    _authSub = _auth.authStateChanges().listen(_onAuthChanged);
  }

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;

  SessionStatus _status = SessionStatus.loading;
  SessionStatus get status => _status;

  String? errorMessage;

  String? _phoneSyncTried;
  String? _publicProfileChecked;

  void _onAuthChanged(User? user) {
    _profileSub?.cancel();
    _profileSub = null;

    if (user == null) {
      _setStatus(SessionStatus.signedOut);
      return;
    }

    _setStatus(SessionStatus.loading);
    _profileSub = _db
        .collection('users')
        .doc(user.uid)
        .snapshots(includeMetadataChanges: true)
        .listen(
      (snap) {
        if (snap.exists) {
          _syncPhoneIfNeeded(user.uid, snap.data());
          _ensurePublicProfile(user.uid, snap);
          _setStatus(SessionStatus.ready);
        } else if (!snap.metadata.isFromCache) {

          _setStatus(SessionStatus.needsProfile);
        }

      },
      onError: (Object e) {
        if (_auth.currentUser == null) return;
        errorMessage = e.toString();
        _setStatus(SessionStatus.error);
      },
    );
  }

  void _syncPhoneIfNeeded(String uid, Map<String, dynamic>? data) {
    final authPhone = _auth.currentUser?.phoneNumber;
    if (authPhone == null || data == null) return;
    if (data['phone'] == authPhone) return;
    if (_phoneSyncTried == authPhone) return;
    _phoneSyncTried = authPhone;
    _db.collection('users').doc(uid).update({
      'phone': authPhone,
      'updatedAt': FieldValue.serverTimestamp(),
    }).catchError((Object e) {
      debugPrint('sync phone failed: $e');
    });
  }

  void _ensurePublicProfile(
      String uid, DocumentSnapshot<Map<String, dynamic>> snap) {
    if (_publicProfileChecked == uid) return;
    if (snap.metadata.hasPendingWrites) return;
    _publicProfileChecked = uid;
    final nickname = snap.data()?['nickname'] as String? ?? '';
    FriendRepository(_db).ensurePublicProfile(uid, nickname).catchError((Object e) {
      debugPrint('ensure public profile failed: $e');
      _publicProfileChecked = null;
    });
  }

  void _setStatus(SessionStatus value) {
    if (_status == value) return;
    _status = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _profileSub?.cancel();
    super.dispose();
  }
}

final sessionProvider = Provider<SessionController>((ref) {
  final controller =
      SessionController(FirebaseAuth.instance, FirebaseFirestore.instance);
  ref.onDispose(controller.dispose);
  return controller;
});