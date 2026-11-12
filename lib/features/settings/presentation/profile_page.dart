import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../user/data/app_user.dart';
import '../../user/data/user_repository.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  Future<void> _editName(
    BuildContext context,
    WidgetRef ref, {
    required AppUser profile,
    required String field,
    required String label,
    required String current,
    required int maxLength,
  }) async {
    final newValue = await showDialog<String>(
      context: context,
      builder: (context) => _EditTextDialog(
        label: label,
        initialValue: current,
        maxLength: maxLength,
      ),
    );
    if (newValue == null || newValue == current) return;

    try {
      await ref.read(userRepositoryProvider).updateName(profile.uid, field, newValue);
      if (context.mounted) showAppSnack(context, 'บันทึก$labelแล้ว');
    } on FirebaseException catch (e) {
      if (context.mounted) {
        showAppSnack(context, 'บันทึกไม่สำเร็จ (${e.code})', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final profile = ref.watch(currentUserProfileProvider).value;

    return Scaffold(
      body: SafeArea(
        child: profile == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                children: [
                  const BackTextButton(),
                  const PageTitle('ตั้งค่าผู้ใช้'),
                  const SizedBox(height: 16),
                  Center(
                    child: Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: scheme.tertiary),
                      ),
                      child: Icon(Icons.person_rounded, size: 90, color: scheme.tertiary),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      profile.nickname,
                      style: TextStyle(fontSize: 22, color: scheme.onSurface),
                    ),
                  ),
                  Center(
                    child: SelectableText(
                      'UID: ${profile.uid}',
                      style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _InfoRow(
                    label: 'ชื่อ',
                    value: profile.firstName,
                    onEdit: () => _editName(context, ref,
                        profile: profile,
                        field: 'firstName',
                        label: 'ชื่อ',
                        current: profile.firstName,
                        maxLength: 50),
                  ),
                  _InfoRow(
                    label: 'นามสกุล',
                    value: profile.lastName,
                    onEdit: () => _editName(context, ref,
                        profile: profile,
                        field: 'lastName',
                        label: 'นามสกุล',
                        current: profile.lastName,
                        maxLength: 50),
                  ),
                  _InfoRow(
                    label: 'ชื่อเล่น',
                    value: profile.nickname,
                    onEdit: () => _editName(context, ref,
                        profile: profile,
                        field: 'nickname',
                        label: 'ชื่อเล่น',
                        current: profile.nickname,
                        maxLength: 30),
                  ),
                  _InfoRow(
                    label: 'หมายเลขโทรศัพท์',
                    value: PhoneUtils.toLocal(profile.phone),
                    onEdit: () => context.push(AppRoutes.changePhone),
                  ),
                ],
              ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, required this.onEdit});

  final String label;
  final String value;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 18, color: scheme.tertiary)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.only(left: 16),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(value, style: TextStyle(fontSize: 20, color: scheme.onSurface)),
                ),
                IconButton(
                  tooltip: 'แก้ไข$label',
                  onPressed: onEdit,
                  icon: Icon(Icons.edit, color: scheme.onSurface),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditTextDialog extends StatefulWidget {
  const _EditTextDialog({
    required this.label,
    required this.initialValue,
    required this.maxLength,
  });

  final String label;
  final String initialValue;
  final int maxLength;

  @override
  State<_EditTextDialog> createState() => _EditTextDialogState();
}

class _EditTextDialogState extends State<_EditTextDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() => _error = 'กรุณากรอก${widget.label}');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('แก้ไข${widget.label}'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: widget.maxLength,
        style: const TextStyle(fontSize: 20),
        decoration: InputDecoration(errorText: _error),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('ยกเลิก'),
        ),
        TextButton(onPressed: _save, child: const Text('บันทึก')),
      ],
    );
  }
}