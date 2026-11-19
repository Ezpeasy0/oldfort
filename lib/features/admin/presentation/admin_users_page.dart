import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../chat/data/chat_repository.dart';
import '../../friends/data/friend_repository.dart';
import '../../friends/presentation/friend_widgets.dart';
import '../data/admin_repository.dart';
import 'admin_widgets.dart';

const _suspendedBg = Color(0xFFFDE7E7);
const _suspendedFg = Color(0xFFB00000);

class AdminUsersPage extends ConsumerStatefulWidget {
  const AdminUsersPage({super.key});

  @override
  ConsumerState<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends ConsumerState<AdminUsersPage> {
  final _search = TextEditingController();
  int _filter = 0; // 0 all, 1 member, 2 admin, 3 suspended

  static const _filters = ['ทั้งหมด', 'สมาชิก', 'ผู้ดูแล', 'ถูกระงับ'];

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(AdminUser u) {
    final ok = switch (_filter) {
      1 => !u.isAdmin,
      2 => u.isAdmin,
      3 => u.suspended,
      _ => true,
    };
    if (!ok) return false;
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return true;
    final digits = q.replaceAll(RegExp(r'[^0-9]'), '');
    return u.fullName.toLowerCase().contains(q) ||
        u.nickname.toLowerCase().contains(q) ||
        (digits.length >= 3 && u.displayPhone.replaceAll('-', '').contains(digits));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final users = ref.watch(adminUsersProvider);

    return AdminGuard(
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            children: [
              const BackTextButton(),
              const PageTitle('จัดการผู้ใช้'),
              const SizedBox(height: 16),
              TextField(
                controller: _search,
                style: TextStyle(fontSize: 18, color: scheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'ค้นหาชื่อ หรือเบอร์โทร',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: scheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide(color: scheme.outlineVariant),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide(color: scheme.outlineVariant),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < _filters.length; i++)
                    ChoiceChip(
                      label: Text(_filters[i], style: const TextStyle(fontSize: 17)),
                      selected: _filter == i,
                      onSelected: (_) => setState(() => _filter = i),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              users.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text('โหลดผู้ใช้ไม่สำเร็จ\n$e'),
                data: (list) {
                  final shown = list.where(_matches).toList();
                  if (shown.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Text(
                        'ไม่พบผู้ใช้',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, color: scheme.onSurfaceVariant),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8, left: 4),
                          child: Text(
                            '${shown.length} คน',
                            style: TextStyle(fontSize: 16, color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ),
                      for (final u in shown) _UserTile(user: u),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user});

  final AdminUser user;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AdminCard(
      onTap: () => context.push(AppRoutes.adminUserDetailPath(user.uid)),
      child: Row(
        children: [
          UserAvatar(uid: user.uid, size: 52),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 20, color: scheme.onSurface),
                ),
                Text(
                  '${user.displayPhone} · ${user.nickname}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (user.suspended)
            const StatusChip('ถูกระงับ', background: _suspendedBg, foreground: _suspendedFg)
          else if (user.isAdmin)
            const StatusChip('ผู้ดูแล', background: AppColors.primary, foreground: Colors.white),
          Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

class AdminUserDetailPage extends ConsumerStatefulWidget {
  const AdminUserDetailPage({super.key, required this.uid});

  final String uid;

  @override
  ConsumerState<AdminUserDetailPage> createState() => _AdminUserDetailPageState();
}

class _AdminUserDetailPageState extends ConsumerState<AdminUserDetailPage> {
  bool _busy = false;

  Future<void> _openSupport(String myUid) async {
    setState(() => _busy = true);
    final chatId = supportChatId(widget.uid);
    try {
      final exists = await FirebaseFirestore.instance.collection('chats').doc(chatId).get();
      if (!exists.exists) {
        await ref.read(chatRepositoryProvider).startSupport(widget.uid, myUid);
      }
      if (mounted) context.push(AppRoutes.chatRoomPath(chatId));
    } on FirebaseException catch (e) {
      if (mounted) showAppSnack(context, 'เปิดแชทไม่สำเร็จ (${e.code})', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleSuspend(AdminUser user) async {
    final suspend = !user.suspended;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(suspend ? 'ระงับบัญชี' : 'ปลดการระงับบัญชี'),
        content: Text(
          suspend
              ? 'ต้องการระงับบัญชีของ "${user.fullName}" ใช่ไหม\nผู้ใช้จะถูกออกจากระบบและเข้าสู่ระบบไม่ได้'
              : 'ต้องการปลดการระงับบัญชีของ "${user.fullName}" ใช่ไหม',
          style: const TextStyle(fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(suspend ? 'ระงับบัญชี' : 'ปลดการระงับ'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(adminRepositoryProvider).setSuspended(user.uid, suspend);
      if (mounted) showAppSnack(context, suspend ? 'ระงับบัญชีแล้ว' : 'ปลดการระงับแล้ว');
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        showAppSnack(context, 'ทำรายการไม่สำเร็จ (${e.code})', isError: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final myUid = ref.watch(myUidProvider);
    final userAsync = ref.watch(adminUserProvider(widget.uid));
    final publicProfile = ref.watch(publicProfileProvider(widget.uid)).value;

    return AdminGuard(
      child: Scaffold(
        body: SafeArea(
          child: userAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('โหลดข้อมูลไม่สำเร็จ\n$e')),
            data: (user) {
              if (user == null) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [BackTextButton(), Spacer(), Text('ไม่พบผู้ใช้นี้'), Spacer()],
                  ),
                );
              }
              final isSelf = user.uid == myUid;
              final created = user.createdAt;
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                children: [
                  const BackTextButton(),
                  Center(child: UserAvatar(uid: user.uid, size: 130)),
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      user.nickname,
                      style: TextStyle(fontSize: 30, color: scheme.tertiary),
                    ),
                  ),
                  if (user.suspended)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Center(
                        child: StatusChip(
                          'บัญชีนี้ถูกระงับ',
                          background: _suspendedBg,
                          foreground: _suspendedFg,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  AdminCard(
                    child: Column(
                      children: [
                        _InfoRow('ชื่อ-นามสกุล', user.fullName),
                        _InfoRow('เบอร์โทรศัพท์', user.displayPhone),
                        _InfoRow('Friend Code', publicProfile?.friendCode ?? '-'),
                        _InfoRow('บทบาท', user.isAdmin ? 'ผู้ดูแลระบบ' : 'สมาชิก'),
                        _InfoRow(
                          'สมัครเมื่อ',
                          created == null
                              ? '-'
                              : '${created.day}/${created.month}/${created.year + 543}',
                          last: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (!user.isAdmin && myUid != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _busy ? null : () => _openSupport(myUid),
                        icon: const Icon(Icons.support_agent_rounded),
                        label: const Text('เปิดแชทช่วยเหลือ'),
                      ),
                    ),
                  if (!user.isAdmin && !isSelf) ...[
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: user.suspended
                          ? OutlinedButton(
                              onPressed: _busy ? null : () => _toggleSuspend(user),
                              child: const Text('ปลดการระงับบัญชี'),
                            )
                          : ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.sos,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: _busy ? null : () => _toggleSuspend(user),
                              child: const Text('ระงับบัญชี'),
                            ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value, {this.last = false});

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: 17, color: scheme.onSurfaceVariant)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 18, color: scheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}
