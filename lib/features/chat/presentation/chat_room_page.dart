import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../friends/data/friend_repository.dart';
import '../../friends/presentation/friend_widgets.dart';
import '../data/chat_repository.dart';
import 'chat_widgets.dart';

class ChatRoomPage extends ConsumerStatefulWidget {
  const ChatRoomPage({super.key, required this.chatId});

  final String chatId;

  @override
  ConsumerState<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends ConsumerState<ChatRoomPage> {
  final _textController = TextEditingController();
  bool _sending = false;
  DateTime? _markedUpTo;

  ChatType get _type => chatTypeOf(widget.chatId);

  @override
  void initState() {
    super.initState();
    _textController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _markRead(List<ChatMessage> messages) {
    final myUid = ref.read(myUidProvider);
    if (myUid == null || messages.isEmpty) return;
    final newest = messages.first.createdAt;
    if (newest == null) return;
    final marked = _markedUpTo;
    if (marked != null && !newest.isAfter(marked)) return;
    _markedUpTo = newest;
    ref.read(chatRepositoryProvider).markRead(widget.chatId, myUid).catchError((Object e) {
      debugPrint('mark read failed: $e');
    });
  }

  Future<void> _send() async {
    final myUid = ref.read(myUidProvider);
    final text = _textController.text.trim();
    if (myUid == null || text.isEmpty || _sending) return;
    if (text.length > ChatRepository.maxMessageLength) {
      showAppSnack(context, 'ข้อความยาวเกิน ${ChatRepository.maxMessageLength} ตัวอักษร',
          isError: true);
      return;
    }

    setState(() => _sending = true);
    _textController.clear();
    try {
      await ref.read(chatRepositoryProvider).sendMessage(widget.chatId, myUid, text);
    } on FirebaseException catch (e) {
      if (!mounted) return;
      _textController.text = text;
      final message = e.code == 'permission-denied'
          ? (_type == ChatType.private
              ? 'ส่งไม่ได้ เพราะไม่ได้เป็นเพื่อนกันแล้ว'
              : 'ส่งไม่ได้ คุณอาจไม่ได้อยู่ในกลุ่มนี้แล้ว')
          : 'ส่งข้อความไม่สำเร็จ (${e.code})';
      showAppSnack(context, message, isError: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _comingSoon() => showAppSnack(context, 'ส่งรูปภาพได้เร็ว ๆ นี้');

  Future<void> _confirmLeave(String myUid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ออกจากกลุ่ม'),
        content: const Text('ต้องการออกจากกลุ่มนี้ใช่ไหม', style: TextStyle(fontSize: 18)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ออกจากกลุ่ม'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(chatRepositoryProvider).leaveGroup(widget.chatId, myUid);
      if (!mounted) return;
      showAppSnack(context, 'ออกจากกลุ่มแล้ว');
      context.pop();
    } on FirebaseException catch (e) {
      if (mounted) {
        showAppSnack(context, 'ออกจากกลุ่มไม่สำเร็จ (${e.code})', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final myUid = ref.watch(myUidProvider);
    final chat = ref.watch(chatProvider(widget.chatId)).value;
    final messagesAsync = ref.watch(messagesProvider(widget.chatId));

    ref.listen<AsyncValue<List<ChatMessage>>>(
      messagesProvider(widget.chatId),
      (previous, next) {
        final list = next.value;
        if (list != null) _markRead(list);
      },
    );

    final removedFromGroup = _type == ChatType.group &&
        myUid != null &&
        ref.watch(chatProvider(widget.chatId)).hasValue &&
        (chat == null || !chat.memberIds.contains(myUid));

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _RoomHeader(
              chatId: widget.chatId,
              chat: chat,
              myUid: myUid,
              onLeave: myUid == null ? null : () => _confirmLeave(myUid),
            ),
            Divider(height: 1, color: scheme.outlineVariant),
            Expanded(
              child: removedFromGroup
                  ? const _CenterNote('คุณไม่ได้อยู่ในกลุ่มนี้แล้ว')
                  : messagesAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => _CenterNote('โหลดข้อความไม่สำเร็จ\n$e'),
                      data: (messages) {
                        if (messages.isEmpty) {
                          return const _CenterNote('ยังไม่มีข้อความ\nเริ่มทักทายได้เลย');
                        }

                        WidgetsBinding.instance
                            .addPostFrameCallback((_) {
                          if (mounted) _markRead(messages);
                        });
                        return ListView.builder(
                          reverse: true,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message = messages[index];
                            final isMine = message.senderId == myUid;
                            final sentAt = message.createdAt;
                            final readers = (isMine && chat != null && sentAt != null)
                                ? chat.readersOf(sentAt, message.senderId)
                                : 0;
                            return MessageBubble(
                              message: message,
                              isMine: isMine,
                              chatType: _type,
                              readers: readers,
                              onSenderTap: () => context.push(
                                AppRoutes.userProfilePath(message.senderId),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
            if (!removedFromGroup) _buildInputBar(scheme),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(ColorScheme scheme) {
    final hasText = _textController.text.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: Row(
        children: [
          IconButton(
            tooltip: 'แนบไฟล์',
            iconSize: 30,
            color: const Color(0xFF2E86DE),
            onPressed: _comingSoon,
            icon: const Icon(Icons.add),
          ),
          Expanded(
            child: TextField(
              controller: _textController,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              style: TextStyle(fontSize: 20, color: scheme.onSurface),
              decoration: InputDecoration(
                hintText: 'พิมพ์ข้อความ',
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: scheme.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: scheme.outlineVariant),
                ),
              ),
            ),
          ),
          hasText
              ? IconButton(
                  tooltip: 'ส่ง',
                  iconSize: 30,
                  color: const Color(0xFF2E86DE),
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.send_rounded),
                )
              : IconButton(
                  tooltip: 'ถ่ายรูป',
                  iconSize: 30,
                  color: const Color(0xFF2E86DE),
                  onPressed: _comingSoon,
                  icon: const Icon(Icons.photo_camera_outlined),
                ),
        ],
      ),
    );
  }
}

class _RoomHeader extends ConsumerWidget {
  const _RoomHeader({
    required this.chatId,
    required this.chat,
    required this.myUid,
    required this.onLeave,
  });

  final String chatId;
  final ChatRoom? chat;
  final String? myUid;
  final VoidCallback? onLeave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final type = chatTypeOf(chatId);

    var title = '...';
    var icon = Icons.forum_rounded;
    VoidCallback? onTitleTap;
    Widget? action;

    switch (type) {
      case ChatType.community:
        title = communityRoomById(chatId)?.name ?? 'แชทชุมชน';
        icon = Icons.forum_rounded;
      case ChatType.private:
        final otherUid = (chat != null && myUid != null) ? chat!.otherMemberId(myUid!) : '';
        title = otherUid.isEmpty
            ? '...'
            : ref.watch(publicProfileProvider(otherUid)).value?.nickname ?? '...';
        icon = Icons.person_rounded;
        if (otherUid.isNotEmpty) {
          onTitleTap = () => context.push(AppRoutes.userProfilePath(otherUid));
        }
      case ChatType.group:
        title = chat?.name ?? '...';
        icon = Icons.groups_rounded;
        final isOwner = chat != null && chat!.ownerId == myUid;
        if (chat != null && myUid != null && chat!.memberIds.contains(myUid)) {
          action = isOwner
              ? IconButton.filledTonal(
                  tooltip: 'แก้ไขกลุ่ม',
                  onPressed: () => context.push(AppRoutes.groupSettingsPath(chatId)),
                  icon: const Icon(Icons.edit),
                )
              : IconButton(
                  tooltip: 'ออกจากกลุ่ม',
                  onPressed: onLeave,
                  icon: Icon(Icons.logout_rounded, color: scheme.error),
                );
        }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BackTextButton(),
          Row(
            children: [
              const SizedBox(width: 24),
              Expanded(
                child: InkWell(
                  onTap: onTitleTap,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        ProfileAvatar(size: 40, icon: icon),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 20, color: scheme.tertiary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              ?action,
            ],
          ),
        ],
      ),
    );
  }
}

class _CenterNote extends StatelessWidget {
  const _CenterNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}