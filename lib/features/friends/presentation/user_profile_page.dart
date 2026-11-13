import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_widgets.dart';
import '../data/friend_repository.dart';
import 'friend_widgets.dart';

class UserProfilePage extends ConsumerStatefulWidget {
  const UserProfilePage({super.key, required this.uid});

  final String uid;

  @override
  ConsumerState<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends ConsumerState<UserProfilePage> {
  bool _busy = false;

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

  Future<void> _confirmRemove(String myUid, String nickname) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบเพื่อน'),
        content: Text(
          'ต้องการลบ "$nickname" ออกจากรายชื่อเพื่อนใช่ไหม',
          style: const TextStyle(fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ลบเพื่อน'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(
      () => ref.read(friendRepositoryProvider).removeFriend(myUid, widget.uid),
      'ลบเพื่อนแล้ว',
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final myUid = ref.watch(myUidProvider);
    final profileAsync = ref.watch(publicProfileProvider(widget.uid));
    final friendIds = ref.watch(friendIdsProvider).value ?? const [];
    final outgoing = ref.watch(outgoingRequestsProvider).value ?? const [];
    final incoming = ref.watch(incomingRequestsProvider).value ?? const [];

    final profile = profileAsync.value;
    final isMe = widget.uid == myUid;
    final isFriend = friendIds.contains(widget.uid);
    final sentRequest = outgoing.any((r) => r.toUid == widget.uid);
    final gotRequest = incoming.any((r) => r.fromUid == widget.uid);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          children: [
            const BackTextButton(),
            const PageTitle('โปรไฟล์'),
            const SizedBox(height: 24),
            if (profileAsync.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (profile == null || myUid == null)
              Center(
                child: Text('ไม่พบผู้ใช้นี้',
                    style: TextStyle(fontSize: 20, color: scheme.onSurfaceVariant)),
              )
            else ...[
              const Center(child: ProfileAvatar(size: 200)),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  profile.nickname,
                  style: TextStyle(fontSize: 24, color: scheme.onSurface),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'รหัสเพื่อน: ${profile.friendCode}',
                  style: TextStyle(fontSize: 18, color: scheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 32),
              if (isMe)
                Center(
                  child: Text('นี่คือโปรไฟล์ของคุณ',
                      style: TextStyle(fontSize: 18, color: scheme.onSurfaceVariant)),
                )
              else
                _buildActions(
                  myUid: myUid,
                  nickname: profile.nickname,
                  isFriend: isFriend,
                  sentRequest: sentRequest,
                  gotRequest: gotRequest,
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActions({
    required String myUid,
    required String nickname,
    required bool isFriend,
    required bool sentRequest,
    required bool gotRequest,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final repo = ref.read(friendRepositoryProvider);

    final List<Widget> buttons;
    String? note;

    if (isFriend) {
      buttons = [
        SmallButton(
          label: 'ส่งข้อความ',
          // แชทส่วนตัวทำใน Step 5B
          onPressed: _busy
              ? null
              : () => showAppSnack(context, 'แชทส่วนตัวกำลังพัฒนา เร็ว ๆ นี้'),
        ),
        SmallButton(
          label: 'ลบเพื่อน',
          primary: false,
          onPressed: _busy ? null : () => _confirmRemove(myUid, nickname),
        ),
      ];
    } else if (gotRequest) {
      buttons = [
        SmallButton(
          label: 'รับคำขอ',
          onPressed: _busy
              ? null
              : () => _run(() => repo.accept(myUid, widget.uid), 'เป็นเพื่อนกันแล้ว'),
        ),
        SmallButton(
          label: 'ปฏิเสธ',
          primary: false,
          onPressed: _busy
              ? null
              : () => _run(() => repo.reject(myUid, widget.uid), 'ปฏิเสธคำขอแล้ว'),
        ),
      ];
      note = '$nickname ส่งคำขอเป็นเพื่อนมาหาคุณ';
    } else if (sentRequest) {
      buttons = [
        SmallButton(
          label: 'ยกเลิกคำขอ',
          primary: false,
          onPressed: _busy
              ? null
              : () => _run(() => repo.cancel(myUid, widget.uid), 'ยกเลิกคำขอแล้ว'),
        ),
        const SmallButton(label: 'ส่งข้อความ', onPressed: null),
      ];
      note = 'ส่งคำขอแล้ว รอ $nickname ตอบรับ';
    } else {
      buttons = [
        SmallButton(
          label: 'เพิ่มเพื่อน',
          onPressed: _busy
              ? null
              : () => _run(() async {
                    await repo.sendRequest(myUid, widget.uid);
                  }, 'ส่งคำขอเป็นเพื่อนแล้ว'),
        ),
        const SmallButton(label: 'ส่งข้อความ', onPressed: null),
      ];
      note = 'ต้องเป็นเพื่อนกันก่อน จึงจะส่งข้อความได้';
    }

    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 24,
          runSpacing: 12,
          children: buttons,
        ),
        if (note != null) ...[
          const SizedBox(height: 16),
          Text(
            note,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: scheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}