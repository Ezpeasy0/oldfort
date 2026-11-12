import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ออกจากระบบ'),
        content: const Text('ต้องการออกจากระบบใช่ไหม', style: TextStyle(fontSize: 18)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ออกจากระบบ'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await FirebaseAuth.instance.signOut(); // router to log in
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          children: [
            const BackTextButton(),
            const PageTitle('การตั้งค่า'),
            const SizedBox(height: 24),
            _SettingsCard(
              label: 'ตั้งค่าผู้ใช้',
              onTap: () => context.push(AppRoutes.profile),
              child: Icon(Icons.manage_accounts_outlined, size: 80, color: scheme.onSurface),
            ),
            _SettingsCard(
              label: 'ปรับขนาดตัวอักษรและธีม',
              onTap: () => context.push(AppRoutes.display),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  for (final size in [24.0, 40.0, 56.0])
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'Aa',
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          fontSize: size,
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            _SettingsCard(
              label: 'ติดต่อขอความช่วยเหลือ',
              onTap: () =>
                  showAppSnack(context, 'เมนูนี้กำลังพัฒนา เร็ว ๆ นี้'),
              child: Icon(Icons.support_agent_rounded, size: 80, color: scheme.onSurface),
            ),
            const SizedBox(height: 16),
            Center(
              child: SizedBox(
                width: 220,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.sos,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _confirmSignOut(context),
                  child: const Text('ออกจากระบบ'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.label,
    required this.onTap,
    required this.child,
  });

  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        children: [
          Material(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(20),
            elevation: 2,
            shadowColor: Colors.black26,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onTap,
              child: SizedBox(
                height: 130,
                width: double.infinity,
                child: Center(child: child),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, color: scheme.onSurface),
          ),
        ],
      ),
    );
  }
}