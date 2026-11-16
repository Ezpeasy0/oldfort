import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../router/app_router.dart';

final rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

class PushService {
  PushService(this._messaging, this._db, this._router);

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _db;
  final GoRouter _router;

  static String? openChatId;

  String? _uid;
  String? _token;
  bool _listening = false;
  StreamSubscription<String>? _refreshSub;

  Future<void> start(String uid) async {
    _listen();
    if (_uid == uid) return;
    _uid = uid;
    try {
      await _messaging.requestPermission();
      // ignore: deprecated_member_use
      final token = await _messaging.getToken();
      if (token != null) await _saveToken(uid, token);
      await _refreshSub?.cancel();
      // ignore: deprecated_member_use
      _refreshSub = _messaging.onTokenRefresh.listen((t) => _saveToken(uid, t));
    } catch (e) {
      debugPrint('push start failed: $e');
      _uid = null;
    }
  }

  Future<void> stop() async {
    final uid = _uid;
    final token = _token;
    _uid = null;
    _token = null;
    await _refreshSub?.cancel();
    _refreshSub = null;
    if (uid == null || token == null) return;
    try {
      await _devices(uid).doc(token).delete();
    } catch (e) {
      debugPrint('push stop failed: $e');
    }
  }

  CollectionReference<Map<String, dynamic>> _devices(String uid) =>
      _db.collection('users').doc(uid).collection('devices');

  Future<void> _saveToken(String uid, String token) async {
    _token = token;
    await _devices(uid).doc(token).set({
      'platform': 'android',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  void _listen() {
    if (_listening) return;
    _listening = true;

    FirebaseMessaging.onMessage.listen(_showInApp);
    FirebaseMessaging.onMessageOpenedApp.listen(_openChat);
    _messaging.getInitialMessage().then((message) {
      if (message != null) _openChat(message);
    });
  }

  void _openChat(RemoteMessage message) {
    final chatId = message.data['chatId'];
    if (chatId is! String || chatId.isEmpty) return;
    if (openChatId == chatId) return;
    _router.push(AppRoutes.chatRoomPath(chatId));
  }

  void _showInApp(RemoteMessage message) {
    final chatId = message.data['chatId'];
    if (chatId is! String || chatId.isEmpty || openChatId == chatId) return;
    final notification = message.notification;
    final title = notification?.title ?? 'ข้อความใหม่';
    final body = notification?.body ?? '';

    rootMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF342B1C),
          duration: const Duration(seconds: 5),
          content: Text(
            body.isEmpty ? title : '$title\n$body',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, color: Colors.white),
          ),
          action: SnackBarAction(
            label: 'เปิด',
            textColor: Colors.white,
            onPressed: () => _router.push(AppRoutes.chatRoomPath(chatId)),
          ),
        ),
      );
  }
}

final pushServiceProvider = Provider<PushService>((ref) {
  return PushService(
    FirebaseMessaging.instance,
    FirebaseFirestore.instance,
    ref.read(routerProvider),
  );
});

class PushStarter extends ConsumerStatefulWidget {
  const PushStarter({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PushStarter> createState() => _PushStarterState();
}

class _PushStarterState extends ConsumerState<PushStarter> {
  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) ref.read(pushServiceProvider).start(uid);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
