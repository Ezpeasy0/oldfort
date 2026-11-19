import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../chat/data/chat_repository.dart';
import '../../friends/data/friend_repository.dart';

class SupportStartPage extends ConsumerStatefulWidget {
  const SupportStartPage({super.key});

  @override
  ConsumerState<SupportStartPage> createState() => _SupportStartPageState();
}

class _SupportStartPageState extends ConsumerState<SupportStartPage> {
  bool _starting = false;
  bool _redirected = false;

  void _openRoom(String chatId) {
    if (_redirected) return;
    _redirected = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.pushReplacement(AppRoutes.chatRoomPath(chatId));
    });
  }

  Future<void> _start(String uid) async {
    setState(() => _starting = true);
    try {
      await ref.read(chatRepositoryProvider).startSupport(uid, uid);
      _openRoom(supportChatId(uid));
    } on FirebaseException catch (e) {
      if (mounted) {
        showAppSnack(context, 'เริ่มแชทไม่สำเร็จ (${e.code})', isError: true);
        setState(() => _starting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final uid = ref.watch(myUidProvider);
    final chatAsync = uid == null ? null : ref.watch(chatProvider(supportChatId(uid)));
    final chat = chatAsync?.value;

    if (chat != null && !chat.isClosed && !_starting) _openRoom(chat.id);
    final loading = chatAsync == null || chatAsync.isLoading || (chat != null && !chat.isClosed);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              const BackTextButton(),
              const PageTitle('ติดต่อ\nขอความช่วยเหลือ'),
              Expanded(
                child: Center(
                  child: loading
                      ? const CircularProgressIndicator()
                      : Text(
                          'คุณต้องการเริ่มต้น\nการสนทนา\nกับฝ่ายสนับสนุนหรือไม่',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 24, height: 1.4, color: scheme.onSurface),
                        ),
                ),
              ),
              if (!loading)
                Padding(
                  padding: const EdgeInsets.only(bottom: 60),
                  child: SizedBox(
                    width: 180,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _starting || uid == null ? null : () => _start(uid),
                      child: _starting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                            )
                          : const Text('เริ่มแชท'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
