import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../user/data/user_repository.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  void _comingSoon(BuildContext context) =>
      showAppSnack(context, 'เมนูนี้กำลังพัฒนา เร็ว ๆ นี้');

  Future<void> _callSos(BuildContext context) async {
    final uri = Uri(scheme: 'tel', path: '1669');
    var opened = false;
    try {
      opened = await launchUrl(uri);
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      showAppSnack(context, 'เปิดหน้าโทรออกไม่ได้ กรุณากดโทร 1669 เอง',
          isError: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider).value;

    const menus = <_MenuItem>[
      _MenuItem('การแจ้งเตือน\nสุขภาพ', Icons.notifications_none_rounded),
      _MenuItem('แชท พูดคุย', Icons.chat_bubble_outline_rounded),
      _MenuItem('เพื่อน', Icons.people_outline_rounded),
      _MenuItem('เกมทดสอบ\nสุขภาพ', Icons.sports_esports_outlined),
      _MenuItem('บทความสุขภาพ', Icons.description_outlined),
      _MenuItem('แบบสอบถาม\nสุขภาพทั่วไป', Icons.question_mark_rounded),
    ];

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            _Header(name: profile?.fullName ?? ''),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                children: [
                  for (var i = 0; i < menus.length; i += 2)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _MenuTile(
                              item: menus[i],
                              onTap: () => _comingSoon(context),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: _MenuTile(
                              item: menus[i + 1],
                              onTap: () => _comingSoon(context),
                            ),
                          ),
                        ],
                      ),
                    ),

                  Row(
                    children: [
                      const Spacer(),
                      Expanded(
                        flex: 2,
                        child: _MenuTile(
                          item: const _MenuItem('การตั้งค่า', Icons.settings_outlined),
                          onTap: () => context.push(AppRoutes.settings),
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // ปุ่ม SOS โทร 1669 (ใหญ่กว่าปุ่มอื่นเล็กน้อย)
                  Row(
                    children: [
                      const Spacer(),
                      Expanded(
                        flex: 3,
                        child: _MenuTile(
                          item: const _MenuItem('โทร. 1669', Icons.phone_in_talk_rounded),
                          color: AppColors.sos,
                          labelColor: AppColors.sos,
                          onTap: () => _callSos(context),
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem {
  const _MenuItem(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _Header extends StatelessWidget {
  const _Header({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        32,
        MediaQuery.paddingOf(context).top + 28,
        24,
        32,
      ),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.elliptical(120, 40),
          bottomRight: Radius.elliptical(300, 90),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.person_outline_rounded, size: 52, color: scheme.tertiary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 24, color: scheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.item,
    required this.onTap,
    this.color = AppColors.brown,
    this.labelColor,
  });

  final _MenuItem item;
  final VoidCallback onTap;
  final Color color;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(item.icon, size: 72, color: Colors.white),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            item.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: labelColor != null ? FontWeight.bold : FontWeight.normal,
              color: labelColor ?? Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}