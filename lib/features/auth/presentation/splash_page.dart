import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_controller.dart';

class SplashPage extends ConsumerWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ListenableBuilder(
              listenable: session,
              builder: (context, _) {
                if (session.status == SessionStatus.error) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_off_rounded, size: 72, color: scheme.error),
                      const SizedBox(height: 16),
                      const Text(
                        'โหลดข้อมูลบัญชีไม่สำเร็จ',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 22),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        session.errorMessage ?? '',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => FirebaseAuth.instance.signOut(),
                        child: const Text('ออกจากระบบแล้วลองใหม่'),
                      ),
                    ],
                  );
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/images/Logo.png', height: 140),
                    const SizedBox(height: 24),
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'กำลังโหลด...',
                      style: TextStyle(fontSize: 20, color: scheme.onSurfaceVariant),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}