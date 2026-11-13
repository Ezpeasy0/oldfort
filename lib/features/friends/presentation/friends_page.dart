import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/widgets/app_widgets.dart';
import '../data/friend_repository.dart';
import 'friend_widgets.dart';

class FriendsPage extends ConsumerStatefulWidget {
  const FriendsPage({super.key});

  @override
  ConsumerState<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends ConsumerState<FriendsPage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final incoming = ref.watch(incomingRequestsProvider).value ?? const [];
    ref.watch(friendIdsProvider);
    ref.watch(outgoingRequestsProvider);

    final requestLabel =
        incoming.isEmpty ? 'คำขอเพิ่มเพื่อน' : 'คำขอเพิ่มเพื่อน (${incoming.length})';

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          children: [
            const BackTextButton(),
            const PageTitle('เพื่อน'),
            const SizedBox(height: 20),
            SegmentedTabs(
              labels: ['รายชื่อเพื่อน', 'เพิ่มเพื่อน', requestLabel],
              selectedIndex: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
            const SizedBox(height: 16),
            switch (_tab) {
              0 => const _FriendListTab(),
              1 => const _AddFriendTab(),
              _ => const _RequestsTab(),
            },
          ],
        ),
      ),
    );
  }
}

class _FriendListTab extends ConsumerWidget {
  const _FriendListTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendIds = ref.watch(friendIdsProvider);

    return friendIds.when(
      loading: () => const _CenterMessage.loading(),
      error: (e, _) => _CenterMessage('โหลดรายชื่อเพื่อนไม่สำเร็จ\n$e'),
      data: (ids) {
        if (ids.isEmpty) {
          return const _CenterMessage(
            'ยังไม่มีเพื่อน\nไปที่แท็บ "เพิ่มเพื่อน" แล้วกรอกรหัสเพื่อนได้เลย',
          );
        }
        return Column(
          children: [
            for (final uid in ids)
              PersonTile(
                uid: uid,
                onTap: () => context.push(AppRoutes.userProfilePath(uid)),
              ),
          ],
        );
      },
    );
  }
}


class _AddFriendTab extends ConsumerStatefulWidget {
  const _AddFriendTab();

  @override
  ConsumerState<_AddFriendTab> createState() => _AddFriendTabState();
}

class _AddFriendTabState extends ConsumerState<_AddFriendTab> {
  final _codeController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final code = _codeController.text.trim().toUpperCase();
    if (!FriendCode.isValid(code)) {
      showAppSnack(context, 'รหัสเพื่อนมี 6 ตัว เป็นตัวอักษร A-Z และตัวเลข 2-9',
          isError: true);
      return;
    }
    final myUid = ref.read(myUidProvider);
    if (myUid == null) return;
    if (ref.read(myPublicProfileProvider).value?.friendCode == code) {
      showAppSnack(context, 'นี่คือรหัสเพื่อนของคุณเอง', isError: true);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      final repo = ref.read(friendRepositoryProvider);
      final target = await repo.findByCode(code);
      if (!mounted) return;
      if (target == null) {
        showAppSnack(context, 'ไม่พบรหัสเพื่อนนี้ กรุณาตรวจสอบอีกครั้ง', isError: true);
        return;
      }

      final friendIds = ref.read(friendIdsProvider).value ?? const [];
      if (friendIds.contains(target.uid)) {
        showAppSnack(context, 'คุณกับ ${target.nickname} เป็นเพื่อนกันอยู่แล้ว');
        return;
      }
      final outgoing = ref.read(outgoingRequestsProvider).value ?? const [];
      if (outgoing.any((r) => r.toUid == target.uid)) {
        showAppSnack(context, 'ส่งคำขอไปแล้ว รอ ${target.nickname} ตอบรับ');
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('เพิ่มเพื่อน'),
          content: Text(
            'ส่งคำขอเป็นเพื่อนถึง "${target.nickname}" ใช่ไหม',
            style: const TextStyle(fontSize: 18),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('ยกเลิก'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('ส่งคำขอ'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      final result = await repo.sendRequest(myUid, target.uid);
      if (!mounted) return;
      _codeController.clear();
      showAppSnack(
        context,
        result == SendRequestResult.becameFriends
            ? 'เป็นเพื่อนกับ ${target.nickname} แล้ว'
            : 'ส่งคำขอถึง ${target.nickname} แล้ว',
      );
    } on FirebaseException catch (e) {
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
    final myCode = ref.watch(myPublicProfileProvider).value?.friendCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('รหัสเพื่อนของฉัน',
                        style: TextStyle(fontSize: 16, color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Text(
                      myCode ?? 'กำลังสร้าง...',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                        color: scheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'คัดลอกรหัส',
                iconSize: 28,
                onPressed: myCode == null
                    ? null
                    : () {
                        Clipboard.setData(ClipboardData(text: myCode));
                        showAppSnack(context, 'คัดลอกรหัสเพื่อนแล้ว');
                      },
                icon: const Icon(Icons.copy_rounded),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        LabeledField(
          label: 'รหัสเพื่อน (Friend Code)',
          controller: _codeController,
          hintText: 'เช่น K7M2QP',
          textInputAction: TextInputAction.done,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
            LengthLimitingTextInputFormatter(FriendCode.length),
            TextInputFormatter.withFunction(
              (oldValue, newValue) =>
                  newValue.copyWith(text: newValue.text.toUpperCase()),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _busy ? null : _add,
          child: _busy
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Text('เพิ่ม'),
        ),
      ],
    );
  }
}


class _RequestsTab extends ConsumerWidget {
  const _RequestsTab();

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
    String doneMessage,
  ) async {
    try {
      await action();
      if (context.mounted) showAppSnack(context, doneMessage);
    } on FirebaseException catch (e) {
      if (context.mounted) {
        showAppSnack(context, 'ทำรายการไม่สำเร็จ (${e.code})', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(incomingRequestsProvider);
    final myUid = ref.watch(myUidProvider);
    final repo = ref.read(friendRepositoryProvider);

    return requests.when(
      loading: () => const _CenterMessage.loading(),
      error: (e, _) => _CenterMessage('โหลดคำขอไม่สำเร็จ\n$e'),
      data: (list) {
        if (list.isEmpty || myUid == null) {
          return const _CenterMessage('ยังไม่มีคำขอเพิ่มเพื่อน');
        }
        return Column(
          children: [
            for (final request in list)
              PersonTile(
                uid: request.fromUid,
                onTap: () =>
                    context.push(AppRoutes.userProfilePath(request.fromUid)),
                below: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    SmallButton(
                      label: 'รับคำขอ',
                      onPressed: () => _run(
                        context,
                        () => repo.accept(myUid, request.fromUid),
                        'เป็นเพื่อนกันแล้ว',
                      ),
                    ),
                    SmallButton(
                      label: 'ปฏิเสธ',
                      primary: false,
                      onPressed: () => _run(
                        context,
                        () => repo.reject(myUid, request.fromUid),
                        'ปฏิเสธคำขอแล้ว',
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CenterMessage extends StatelessWidget {
  const _CenterMessage(this.message) : loading = false;
  const _CenterMessage.loading()
      : message = '',
        loading = true;

  final String message;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: loading
            ? const CircularProgressIndicator()
            : Text(
                message,
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