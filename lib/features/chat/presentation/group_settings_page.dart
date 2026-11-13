import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../friends/data/friend_repository.dart';
import '../../friends/presentation/friend_widgets.dart';
import '../data/chat_repository.dart';
import 'private_chats_page.dart';

class GroupSettingsPage extends ConsumerStatefulWidget {
  const GroupSettingsPage({super.key, required this.chatId});

  final String chatId;

  @override
  ConsumerState<GroupSettingsPage> createState() => _GroupSettingsPageState();
}

class _GroupSettingsPageState extends ConsumerState<GroupSettingsPage> {
  final _nameController = TextEditingController();
  bool _nameLoaded = false;
  bool _busy = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  ChatRepository get _repo => ref.read(chatRepositoryProvider);

  Future<void> _run(Future<void> Function() action, String doneMessage) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) showAppSnack(context, doneMessage);
    } on FirebaseException catch (e) {
      if (mounted) {
        showAppSnack(context, 'ทำรายการไม่สำเร็จ (${e.code})', isError: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String message, String okLabel) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message, style: const TextStyle(fontSize: 18)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(okLabel),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || name.length > 50) {
      showAppSnack(context, 'ชื่อกลุ่มต้องมี 1-50 ตัวอักษร', isError: true);
      return;
    }
    FocusScope.of(context).unfocus();
    await _run(() => _repo.renameGroup(widget.chatId, name), 'บันทึกชื่อกลุ่มแล้ว');
  }

  Future<void> _removeMember(String uid) async {
    final nickname = ref.read(publicProfileProvider(uid)).value?.nickname ?? 'สมาชิกคนนี้';
    if (!await _confirm('เชิญออกจากกลุ่ม', 'ต้องการเชิญ "$nickname" ออกจากกลุ่มใช่ไหม', 'เชิญออก')) {
      return;
    }
    await _run(() => _repo.removeMember(widget.chatId, uid), 'เชิญ $nickname ออกแล้ว');
  }

  Future<void> _invite(ChatRoom chat) async {
    final friendIds = ref.read(friendIdsProvider).value ?? const [];
    final candidates = friendIds.where((id) => !chat.memberIds.contains(id)).toList();
    if (candidates.isEmpty) {
      showAppSnack(context, 'เพื่อนทุกคนอยู่ในกลุ่มแล้ว');
      return;
    }
    final room = ChatRepository.maxGroupMembers - chat.memberIds.length;
    final picked = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _InviteSheet(candidates: candidates, maxPick: room),
    );
    if (picked == null || picked.isEmpty) return;
    await _run(
      () => _repo.addMembers(widget.chatId, picked),
      'เชิญเข้ากลุ่มแล้ว ${picked.length} คน',
    );
  }

  Future<void> _deleteGroup() async {
    if (!await _confirm(
      'ลบกลุ่ม',
      'ลบกลุ่มนี้สำหรับสมาชิกทุกคน และลบแล้วกู้คืนไม่ได้ ต้องการลบใช่ไหม',
      'ลบกลุ่ม',
    )) {
      return;
    }
    setState(() => _busy = true);
    try {
      await _repo.deleteGroup(widget.chatId);
      if (!mounted) return;
      showAppSnack(context, 'ลบกลุ่มแล้ว');
      final router = GoRouter.of(context);
      router.pop();
      router.pop();
    } on FirebaseException catch (e) {
      if (mounted) {
        showAppSnack(context, 'ลบกลุ่มไม่สำเร็จ (${e.code})', isError: true);
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final myUid = ref.watch(myUidProvider);
    final chatAsync = ref.watch(chatProvider(widget.chatId));
    ref.watch(friendIdsProvider); 
    final chat = chatAsync.value;

    if (chat != null && !_nameLoaded) {
      _nameController.text = chat.name;
      _nameLoaded = true;
    }

    Widget body;
    if (chatAsync.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (chat == null || chat.ownerId != myUid) {
      body = Center(
        child: Text('แก้ไขได้เฉพาะผู้สร้างกลุ่ม',
            style: TextStyle(fontSize: 18, color: scheme.onSurfaceVariant)),
      );
    } else {
      body = ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        children: [
          const BackTextButton(),
          const PageTitle('แก้ไขกลุ่ม'),
          const SizedBox(height: 16),
          const Center(child: ProfileAvatar(size: 120, icon: Icons.groups_rounded)),
          const SizedBox(height: 8),
          Center(
            child: Text('รูปกลุ่มจะเปลี่ยนได้ในเวอร์ชันถัดไป',
                style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant)),
          ),
          const SizedBox(height: 24),
          LabeledField(
            label: 'ชื่อกลุ่ม',
            controller: _nameController,
            maxLength: 50,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _busy ? null : _saveName,
            child: const Text('บันทึกชื่อกลุ่ม'),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: Text('สมาชิก (${chat.memberIds.length})',
                    style: TextStyle(fontSize: 20, color: scheme.tertiary)),
              ),
              SmallButton(
                label: 'เชิญเพื่อน',
                onPressed: _busy ? null : () => _invite(chat),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final uid in chat.memberIds)
            PersonTile(
              uid: uid,
              below: uid == chat.ownerId
                  ? Text('ผู้สร้างกลุ่ม',
                      style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant))
                  : SmallButton(
                      label: 'เชิญออก',
                      primary: false,
                      onPressed: _busy ? null : () => _removeMember(uid),
                    ),
            ),
          const SizedBox(height: 32),
          Center(
            child: SizedBox(
              width: 200,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.sos,
                  foregroundColor: Colors.white,
                ),
                onPressed: _busy ? null : _deleteGroup,
                child: const Text('ลบกลุ่ม'),
              ),
            ),
          ),
        ],
      );
    }

    return Scaffold(body: SafeArea(child: body));
  }
}

class _InviteSheet extends StatefulWidget {
  const _InviteSheet({required this.candidates, required this.maxPick});

  final List<String> candidates;
  final int maxPick;

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  final _picked = <String>{};

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('เชิญเพื่อนเข้ากลุ่ม',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, color: scheme.tertiary)),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final uid in widget.candidates)
                      SelectableFriendTile(
                        uid: uid,
                        selected: _picked.contains(uid),
                        onChanged: (value) => setState(() {
                          if (!value) {
                            _picked.remove(uid);
                          } else if (_picked.length < widget.maxPick) {
                            _picked.add(uid);
                          }
                        }),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _picked.isEmpty
                    ? null
                    : () => Navigator.of(context).pop(_picked.toList()),
                child: Text(_picked.isEmpty ? 'เชิญ' : 'เชิญ (${_picked.length})'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
