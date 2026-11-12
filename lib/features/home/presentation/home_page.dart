// lib/features/home/presentation/home_page.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/settings_controller.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    final settings = ref.watch(settingsProvider);
    final settingsController = ref.read(settingsProvider.notifier);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('หน้าหลัก')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('เข้าสู่ระบบแล้ว', style: textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('เบอร์: ${user?.phoneNumber ?? '-'}', style: textTheme.bodyLarge),
            Text('UID: ${user?.uid ?? '-'}', style: textTheme.bodyMedium),
            const SizedBox(height: 32),
            Text('ขนาดตัวอักษร', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<double>(
              segments: const [
                ButtonSegment(value: 1.0, label: Text('ปกติ')),
                ButtonSegment(value: 1.15, label: Text('ใหญ่')),
                ButtonSegment(value: 1.3, label: Text('ใหญ่มาก')),
              ],
              selected: {settings.textScale},
              onSelectionChanged: (selected) =>
                  settingsController.setTextScale(selected.first),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('โหมดกลางคืน', style: textTheme.bodyLarge),
              value: settings.themeMode == ThemeMode.dark,
              onChanged: (isDark) => settingsController
                  .setThemeMode(isDark ? ThemeMode.dark : ThemeMode.light),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => FirebaseAuth.instance.signOut(),
              child: const Text('ออกจากระบบ'),
            ),
          ],
        ),
      ),
    );
  }
}