import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../chat/data/chat_repository.dart';
import '../../chat/presentation/chat_widgets.dart';
import '../../friends/data/friend_repository.dart';
import '../../friends/presentation/friend_widgets.dart';
import 'admin_widgets.dart';

class SupportInboxPage extends ConsumerStatefulWidget {
  const SupportInboxPage({super.key});

  @override
  ConsumerState<SupportInboxPage> createState() => _SupportInboxPageState();
}

class _SupportInboxPageState extends ConsumerState<SupportInboxPage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final myUid = ref.watch(myUidProvider);
    final chats = ref.watch(supportChatsProvider);
    final openCount = chats.value?.where((c) => !c.isClosed).length ?? 0;

    return AdminGuard(
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            children: [
              const BackTextButton(),
              const PageTitle('แชทช่วยเหลือ'),
              const SizedBox(height: 16),
              SegmentedTabs(
                labels: ['กำลังคุย ($openCount)', 'จบแล้ว'],
                selectedIndex: _tab,
                onChanged: (i) => setState(() => _tab = i),
              ),
              const SizedBox(height: 16),
              chats.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text('โหลดแชทไม่สำเร็จ\n$e'),
                data: (list) {
                  final shown = list.where((c) => c.isClosed == (_tab == 1)).toList();
                  if (shown.isEmpty || myUid == null) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Text(
                        _tab == 0 ? 'ไม่มีแชทที่กำลังคุยอยู่' : 'ยังไม่มีแชทที่จบแล้ว',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, color: scheme.onSurfaceVariant),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final chat in shown) _SupportTile(chat: chat, myUid: myUid),
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

class _SupportTile extends ConsumerWidget {
  const _SupportTile({required this.chat, required this.myUid});

  final ChatRoom chat;
  final String myUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final memberUid = chat.supportMemberUid;
    final member = ref.watch(publicProfileProvider(memberUid)).value;
    final unread = chat.isUnreadFor(myUid);

    String status;
    if (chat.isClosed) {
      final closer = chat.closedBy == null
          ? null
          : ref.watch(publicProfileProvider(chat.closedBy!)).value?.nickname;
      status = 'จบโดย ${closer ?? 'ผู้ดูแล'}';
    } else if (chat.waitingForAdmin) {
      status = 'รอตอบ';
    } else {
      final adminName = chat.lastAdminId == null
          ? null
          : ref.watch(publicProfileProvider(chat.lastAdminId!)).value?.nickname;
      status = adminName == null ? 'รอสมาชิก' : '$adminName ตอบล่าสุด · รอสมาชิก';
    }

    return AdminCard(
      onTap: () => context.push(AppRoutes.chatRoomPath(chat.id)),
      child: Row(
        children: [
          UserAvatar(uid: memberUid, size: 52),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        member?.nickname ?? '...',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 20, color: scheme.onSurface),
                      ),
                    ),
                    Text(
                      formatChatTime(chat.lastMessageAt),
                      style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        chat.lastMessage ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          color: scheme.onSurfaceVariant,
                          fontWeight: unread ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (unread)
                      Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Color(0xFF3E7F6B),
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 14,
                    color: chat.waitingForAdmin ? scheme.error : scheme.tertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
