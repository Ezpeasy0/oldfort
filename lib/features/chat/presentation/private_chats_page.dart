import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../friends/data/friend_repository.dart';
import '../../friends/presentation/friend_widgets.dart';
import '../data/chat_repository.dart';
import 'chat_widgets.dart';

class PrivateChatsPage extends ConsumerWidget {
  const PrivateChatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final myUid = ref.watch(myUidProvider);
    final chats = ref.watch(myChatsProvider);

    return Scaffold(
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'create-group',
            tooltip: 'สร้างแชทกลุ่ม',
            backgroundColor: scheme.surface,
            foregroundColor: scheme.onSurface,
            shape: CircleBorder(side: BorderSide(color: scheme.onSurface)),
            onPressed: () => context.push(AppRoutes.createGroup),
            child: const Icon(Icons.add, size: 32),
          ),
          const SizedBox(height: 6),
          Text('สร้างแชทกลุ่ม',
              style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant)),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 120),
          children: [
            const BackTextButton(),
            const PageTitle('แชทส่วนตัว'),
            const SizedBox(height: 16),
            Text('แชท', style: TextStyle(fontSize: 18, color: scheme.tertiary)),
            const SizedBox(height: 4),
            chats.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('โหลดแชทไม่สำเร็จ\n$e'),
              data: (list) {
                if (list.isEmpty || myUid == null) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Text(
                      'ยังไม่มีแชท\nเปิดโปรไฟล์เพื่อนแล้วกด "ส่งข้อความ"\nหรือกด + เพื่อสร้างแชทกลุ่ม',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, color: scheme.onSurfaceVariant),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final chat in list) _ChatListTile(chat: chat, myUid: myUid),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatListTile extends ConsumerWidget {
  const _ChatListTile({required this.chat, required this.myUid});

  final ChatRoom chat;
  final String myUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isGroup = chat.type == ChatType.group;
    final title = isGroup
        ? chat.name
        : ref.watch(publicProfileProvider(chat.otherMemberId(myUid))).value?.nickname ??
            '...';

    final last = chat.lastMessage;
    final subtitle = last == null
        ? 'ยังไม่มีข้อความ'
        : (chat.lastSenderId == myUid ? 'คุณ: $last' : last);
    final unread = chat.isUnreadFor(myUid);

    return InkWell(
      onTap: () => context.push(AppRoutes.chatRoomPath(chat.id)),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
        ),
        child: Row(
          children: [
            ProfileAvatar(icon: isGroup ? Icons.groups_rounded : Icons.person_rounded),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: scheme.tertiary,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: unread ? FontWeight.bold : FontWeight.normal,
                      color: unread ? scheme.onSurface : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (chat.lastMessageAt != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatChatTime(chat.lastMessageAt),
                      style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 6),
                    if (unread)
                      Container(
                        width: 14,
                        height: 14,
                        decoration: const BoxDecoration(
                          color: AppColors.green,
                          shape: BoxShape.circle,
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

class CreateGroupPage extends ConsumerStatefulWidget {
  const CreateGroupPage({super.key});

  @override
  ConsumerState<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends ConsumerState<CreateGroupPage> {
  final _selected = <String>{};
  bool _busy = false;

  Future<void> _create() async {
    final myUid = ref.read(myUidProvider);
    if (myUid == null || _selected.isEmpty) return;

    final names = [
      for (final uid in _selected)
        ref.read(publicProfileProvider(uid)).value?.nickname ?? '',
    ].where((n) => n.isNotEmpty).join(', ');
    var name = names.isEmpty ? 'แชทกลุ่ม' : names;
    if (name.length > 50) name = '${name.substring(0, 47)}...';

    setState(() => _busy = true);
    try {
      final chatId = await ref.read(chatRepositoryProvider).createGroup(
            ownerUid: myUid,
            memberUids: _selected.toList(),
            name: name,
          );
      if (!mounted) return;
      context.pushReplacement(AppRoutes.chatRoomPath(chatId));
    } on FirebaseException catch (e) {
      if (mounted) {
        showAppSnack(context, 'สร้างกลุ่มไม่สำเร็จ (${e.code})', isError: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final friendIds = ref.watch(friendIdsProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          children: [
            const BackTextButton(),
            const PageTitle('แชทกลุ่ม'),
            const SizedBox(height: 16),
            Text('รายชื่อเพื่อน (เลือกได้หลายคน)',
                style: TextStyle(fontSize: 18, color: scheme.tertiary)),
            const SizedBox(height: 4),
            friendIds.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('โหลดรายชื่อเพื่อนไม่สำเร็จ\n$e'),
              data: (ids) {
                if (ids.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Text(
                      'ยังไม่มีเพื่อน ต้องเพิ่มเพื่อนก่อนจึงจะสร้างกลุ่มได้',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, color: scheme.onSurfaceVariant),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final uid in ids)
                      SelectableFriendTile(
                        uid: uid,
                        selected: _selected.contains(uid),
                        onChanged: (value) => setState(() {
                          if (value) {
                            _selected.add(uid);
                          } else {
                            _selected.remove(uid);
                          }
                        }),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 32),
            Center(
              child: SizedBox(
                width: 200,
                child: ElevatedButton(
                  onPressed: _busy || _selected.isEmpty ? null : _create,
                  child: _busy
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : Text(_selected.isEmpty ? 'สร้าง' : 'สร้าง (${_selected.length})'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SelectableFriendTile extends StatelessWidget {
  const SelectableFriendTile({
    super.key,
    required this.uid,
    required this.selected,
    required this.onChanged,
  });

  final String uid;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      alignment: Alignment.centerRight,
      children: [
        PersonTile(uid: uid, onTap: () => onChanged(!selected)),
        IgnorePointer(
          child: Icon(
            selected ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 30,
            color: selected ? AppColors.green : scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
