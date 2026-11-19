import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/notifications/push_service.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../friends/data/friend_repository.dart';
import '../../friends/presentation/friend_widgets.dart';
import '../../user/data/user_repository.dart';
import '../data/chat_repository.dart';
import '../data/community_room_repository.dart';
import 'chat_media.dart';
import 'chat_widgets.dart';
import 'image_picking.dart';

class ChatRoomPage extends ConsumerStatefulWidget {
  const ChatRoomPage({super.key, required this.chatId});

  final String chatId;

  @override
  ConsumerState<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends ConsumerState<ChatRoomPage> {
  final _textController = TextEditingController();
  bool _sending = false;
  bool _uploading = false;
  String _uploadLabel = '';
  bool _recording = false;
  DateTime? _markedUpTo;
  List<ChatMessage>? _latestMessages;
  late final AppLifecycleListener _lifecycle;

  ChatType get _type => chatTypeOf(widget.chatId);

  String get _deniedMessage => switch (_type) {
        ChatType.private => 'ส่งไม่ได้ เพราะไม่ได้เป็นเพื่อนกันแล้ว',
        ChatType.group => 'ส่งไม่ได้ คุณอาจไม่ได้อยู่ในกลุ่มนี้แล้ว',
        ChatType.community => 'ส่งไม่ได้ ห้องนี้ถูกปิดแล้ว',
        ChatType.support => 'ส่งไม่ได้ การสนทนานี้จบแล้ว',
      };

  Future<void> _confirmEndSupport(String myUid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('จบการสนทนา'),
        content: const Text(
          'แก้ไขปัญหาหรือตอบคำถามเสร็จแล้วใช่ไหม\nสมาชิกจะพิมพ์ต่อในรอบนี้ไม่ได้',
          style: TextStyle(fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('จบการสนทนา'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(chatRepositoryProvider).endSupport(widget.chatId, myUid);
    } on FirebaseException catch (e) {
      if (mounted) showAppSnack(context, 'จบการสนทนาไม่สำเร็จ (${e.code})', isError: true);
    }
  }

  Future<void> _restartSupport(ChatRoom chat, String myUid) async {
    try {
      await ref.read(chatRepositoryProvider).startSupport(chat.supportMemberUid, myUid);
    } on FirebaseException catch (e) {
      if (mounted) showAppSnack(context, 'เริ่มแชทใหม่ไม่สำเร็จ (${e.code})', isError: true);
    }
  }

  @override
  void initState() {
    super.initState();
    PushService.openChatId = widget.chatId;
    _lifecycle = AppLifecycleListener(onResume: () {
      final latest = _latestMessages;
      if (latest != null) _markRead(latest);
    });
    _textController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    if (PushService.openChatId == widget.chatId) PushService.openChatId = null;
    _lifecycle.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _markRead(List<ChatMessage> messages) {
    _latestMessages = messages;
    final appState = WidgetsBinding.instance.lifecycleState;
    if (appState != null && appState != AppLifecycleState.resumed) return;
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
          ? _deniedMessage
          : 'ส่งข้อความไม่สำเร็จ (${e.code})';
      showAppSnack(context, message, isError: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    final myUid = ref.read(myUidProvider);
    if (myUid == null || _uploading) return;
    PickedImage? image;
    try {
      image = await pickChatImage(source);
    } catch (_) {
      if (mounted) showAppSnack(context, 'เปิดรูปภาพไม่สำเร็จ', isError: true);
      return;
    }
    if (image == null || !mounted) return;

    final picked = image;
    await _upload(
      'กำลังส่งรูปภาพ...',
      'ส่งรูปภาพไม่สำเร็จ',
      () => ref.read(chatRepositoryProvider).sendImage(widget.chatId, myUid, picked),
    );
  }

  Future<void> _pickAndSendVideo(ImageSource source) async {
    final myUid = ref.read(myUidProvider);
    if (myUid == null || _uploading) return;
    PickedVideo? video;
    try {
      video = await pickChatVideo(source);
    } on VideoPickException catch (e) {
      if (mounted) showAppSnack(context, e.message, isError: true);
      return;
    } catch (_) {
      if (mounted) showAppSnack(context, 'เปิดวิดีโอไม่สำเร็จ', isError: true);
      return;
    }
    if (video == null || !mounted) return;
    final picked = video;
    await _upload(
      'กำลังส่งวิดีโอ...',
      'ส่งวิดีโอไม่สำเร็จ',
      () => ref.read(chatRepositoryProvider).sendVideo(
            widget.chatId,
            myUid,
            filePath: picked.path,
            width: picked.width,
            height: picked.height,
            durationMs: picked.durationMs,
          ),
    );
  }

  Future<void> _sendVoice(String path, int durationMs) async {
    setState(() => _recording = false);
    final myUid = ref.read(myUidProvider);
    if (myUid == null) return;
    await _upload(
      'กำลังส่งข้อความเสียง...',
      'ส่งข้อความเสียงไม่สำเร็จ',
      () => ref.read(chatRepositoryProvider).sendAudio(widget.chatId, myUid, path, durationMs),
    );
  }

  Future<void> _upload(
    String label,
    String failMessage,
    Future<void> Function() action,
  ) async {
    setState(() {
      _uploading = true;
      _uploadLabel = label;
    });
    try {
      await action();
    } on FirebaseException catch (e) {
      if (!mounted) return;
      final message = e.code == 'permission-denied' || e.code == 'unauthorized'
          ? _deniedMessage
          : '$failMessage (${e.code})';
      showAppSnack(context, message, isError: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _openAttachMenu() async {
    final action = await askAttachAction(context);
    switch (action) {
      case AttachAction.galleryPhoto:
        await _pickAndSendImage(ImageSource.gallery);
      case AttachAction.cameraPhoto:
        await _pickAndSendImage(ImageSource.camera);
      case AttachAction.galleryVideo:
        await _pickAndSendVideo(ImageSource.gallery);
      case AttachAction.cameraVideo:
        await _pickAndSendVideo(ImageSource.camera);
      case null:
        break;
    }
  }

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

    final isAdmin = ref.watch(currentUserProfileProvider).value?.isAdmin ?? false;
    final supportClosed = _type == ChatType.support && chat != null && chat.isClosed;

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
              isAdmin: isAdmin,
              onLeave: myUid == null ? null : () => _confirmLeave(myUid),
              onEndSupport: myUid == null ? null : () => _confirmEndSupport(myUid),
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
                            if (message.isSystem) {
                              return _SystemNote(message: message);
                            }
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
                              onSenderTap: _type == ChatType.support
                                  ? (isAdmin && message.senderId == chat?.supportMemberUid
                                      ? () => context.push(
                                            AppRoutes.adminUserDetailPath(message.senderId))
                                      : null)
                                  : () => context.push(
                                        AppRoutes.userProfilePath(message.senderId),
                                      ),
                            );
                          },
                        );
                      },
                    ),
            ),
            if (supportClosed && myUid != null)
              _SupportClosedBar(
                isAdmin: isAdmin,
                onRestart: () => _restartSupport(chat, myUid),
              )
            else if (!removedFromGroup)
              _recording
                  ? VoiceRecorderBar(
                      onSend: _sendVoice,
                      onCancel: () => setState(() => _recording = false),
                      onError: (message) {
                        setState(() => _recording = false);
                        showAppSnack(context, message, isError: true);
                      },
                    )
                  : _buildInputBar(scheme),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(ColorScheme scheme) {
    final hasText = _textController.text.trim().isNotEmpty;
    final inputBar = Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: Row(
        children: [
          IconButton(
            tooltip: 'แนบไฟล์',
            iconSize: 30,
            color: const Color(0xFF2E86DE),
            onPressed: _uploading ? null : _openAttachMenu,
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
                  tooltip: 'อัดเสียง',
                  iconSize: 30,
                  color: const Color(0xFF2E86DE),
                  onPressed: _uploading
                      ? null
                      : () {
                          FocusScope.of(context).unfocus();
                          setState(() => _recording = true);
                        },
                  icon: const Icon(Icons.mic_none_rounded),
                ),
        ],
      ),
    );
    if (!_uploading) return inputBar;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const LinearProgressIndicator(),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(_uploadLabel,
              style: TextStyle(fontSize: 16, color: scheme.onSurfaceVariant)),
        ),
        inputBar,
      ],
    );
  }
}

class _RoomHeader extends ConsumerWidget {
  const _RoomHeader({
    required this.chatId,
    required this.chat,
    required this.myUid,
    required this.isAdmin,
    required this.onLeave,
    required this.onEndSupport,
  });

  final String chatId;
  final ChatRoom? chat;
  final String? myUid;
  final bool isAdmin;
  final VoidCallback? onLeave;
  final VoidCallback? onEndSupport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final type = chatTypeOf(chatId);

    var title = '...';
    var icon = Icons.forum_rounded;
    String? avatarUrl;
    VoidCallback? onTitleTap;
    Widget? action;

    switch (type) {
      case ChatType.community:
        final room = ref.watch(communityRoomProvider(chatId)).value;
        title = room?.name ?? 'แชทชุมชน';
        icon = room == null ? Icons.forum_rounded : roomIconOf(room.icon);
      case ChatType.support:
        icon = Icons.support_agent_rounded;
        if (isAdmin) {
          final memberUid = chatTypeOf(chatId) == ChatType.support ? chatId.substring(8) : '';
          final member = ref.watch(publicProfileProvider(memberUid)).value;
          title = member?.nickname ?? '...';
          avatarUrl = member?.photoUrl;
          onTitleTap = () => context.push(AppRoutes.adminUserDetailPath(memberUid));
          if (chat != null && !chat!.isClosed) {
            action = OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: scheme.error,
                side: BorderSide(color: scheme.error),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onPressed: onEndSupport,
              icon: const Icon(Icons.check_rounded),
              label: const Text('จบการสนทนา', style: TextStyle(fontSize: 16)),
            );
          }
        } else {
          final adminUid = chat?.lastAdminId;
          final adminProfile =
              adminUid == null ? null : ref.watch(publicProfileProvider(adminUid)).value;
          title = adminProfile?.nickname ?? 'ฝ่ายสนับสนุน';
          avatarUrl = adminProfile?.photoUrl;
        }
      case ChatType.private:
        final otherUid = (chat != null && myUid != null) ? chat!.otherMemberId(myUid!) : '';
        final other = otherUid.isEmpty ? null : ref.watch(publicProfileProvider(otherUid)).value;
        title = other?.nickname ?? '...';
        avatarUrl = other?.photoUrl;
        icon = Icons.person_rounded;
        if (otherUid.isNotEmpty) {
          onTitleTap = () => context.push(AppRoutes.userProfilePath(otherUid));
        }
      case ChatType.group:
        title = chat?.name ?? '...';
        avatarUrl = chat?.photoUrl;
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
                        ProfileAvatar(
                          size: 40,
                          icon: icon,
                          imageUrl: avatarUrl,
                        ),
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

class _SystemNote extends ConsumerWidget {
  const _SystemNote({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final String text;
    if (message.text == 'closed') {
      final name = ref.watch(publicProfileProvider(message.senderId)).value?.nickname ?? 'ผู้ดูแล';
      text = '$name จบการสนทนาแล้ว';
    } else {
      text = 'เริ่มการสนทนา';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$text · ${formatChatTime(message.createdAt ?? DateTime.now())}',
            style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

class _SupportClosedBar extends StatelessWidget {
  const _SupportClosedBar({required this.isAdmin, required this.onRestart});

  final bool isAdmin;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            'การสนทนานี้จบแล้ว',
            style: TextStyle(fontSize: 18, color: scheme.onSurfaceVariant),
          ),
          TextButton(
            onPressed: onRestart,
            child: Text(
              isAdmin ? 'เปิดการสนทนาอีกครั้ง' : 'เริ่มแชทใหม่',
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }
}
