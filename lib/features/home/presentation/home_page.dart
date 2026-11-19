import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/notifications/push_service.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../chat/data/chat_repository.dart';
import '../../friends/data/friend_repository.dart';
import '../../friends/presentation/friend_widgets.dart';
import '../../user/data/user_repository.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  void _openMenu(BuildContext context, _MenuItem item) {
    final route = item.route;
    if (route == null) {
      showAppSnack(context, 'เมนูนี้กำลังพัฒนา เร็ว ๆ นี้');
    } else {
      context.push(route);
    }
  }

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
    final photoUrl = ref.watch(myPublicProfileProvider).value?.photoUrl;

    if (profile != null && profile.isAdmin) {
      return PushStarter(
        child: _AdminHome(name: profile.fullName, photoUrl: photoUrl),
      );
    }

    const menus = <_MenuItem>[
      _MenuItem('การแจ้งเตือน\nสุขภาพ', Icons.notifications_none_rounded),
      _MenuItem('แชท พูดคุย', Icons.chat_bubble_outline_rounded, AppRoutes.chat),
      _MenuItem('เพื่อน', Icons.people_outline_rounded, AppRoutes.friends),
      _MenuItem('เกมทดสอบ\nสุขภาพ', Icons.sports_esports_outlined),
      _MenuItem('บทความสุขภาพ', Icons.description_outlined),
      _MenuItem('แบบสอบถาม\nสุขภาพทั่วไป', Icons.question_mark_rounded),
    ];

    return PushStarter(
      child: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              _Header(name: profile?.fullName ?? '', photoUrl: photoUrl),
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
                                onTap: () => _openMenu(context, menus[i]),
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: _MenuTile(
                                item: menus[i + 1],
                                onTap: () => _openMenu(context, menus[i + 1]),
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
      ),
    );
  }
}

class _MenuItem {
  const _MenuItem(this.label, this.icon, [this.route]);

  final String label;
  final IconData icon;
  final String? route;
}

class _AdminHome extends ConsumerWidget {
  const _AdminHome({required this.name, this.photoUrl});

  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final waiting = ref.watch(supportChatsProvider).value?.where((c) => c.waitingForAdmin).length ?? 0;

    final menus = <(_MenuItem, int)>[
      (const _MenuItem('แชทช่วยเหลือ', Icons.support_agent_rounded, AppRoutes.adminSupport), waiting),
      (const _MenuItem('จัดการผู้ใช้', Icons.manage_accounts_outlined, AppRoutes.adminUsers), 0),
      (const _MenuItem('ห้องแชทชุมชน', Icons.forum_outlined, AppRoutes.adminRooms), 0),
      (const _MenuItem('การตั้งค่า', Icons.settings_outlined, AppRoutes.settings), 0),
    ];

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            _Header(name: name, photoUrl: photoUrl, isAdmin: true),
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
                          for (final j in [i, i + 1]) ...[
                            if (j == i + 1) const SizedBox(width: 20),
                            Expanded(
                              child: _MenuTile(
                                item: menus[j].$1,
                                badge: menus[j].$2,
                                onTap: () => context.push(menus[j].$1.route!),
                              ),
                            ),
                          ],
                        ],
                      ),
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

class _Header extends StatelessWidget {
  const _Header({required this.name, this.photoUrl, this.isAdmin = false});

  final String name;
  final String? photoUrl;
  final bool isAdmin;

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
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push(AppRoutes.profile),
        child: Row(
          children: [
            photoUrl == null
                ? Icon(Icons.person_outline_rounded, size: 52, color: scheme.tertiary)
                : ProfileAvatar(size: 56, imageUrl: photoUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 24, color: scheme.onSurface),
                  ),
                  if (isAdmin)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'ผู้ดูแลระบบ',
                        style: TextStyle(fontSize: 15, color: Colors.white),
                      ),
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

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.item,
    required this.onTap,
    this.color = AppColors.brown,
    this.labelColor,
    this.badge = 0,
  });

  final _MenuItem item;
  final VoidCallback onTap;
  final Color color;
  final Color? labelColor;
  final int badge;

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
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(child: Icon(item.icon, size: 72, color: Colors.white)),
                  if (badge > 0)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 34),
                        height: 34,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.sos,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$badge',
                          style: const TextStyle(fontSize: 19, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
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