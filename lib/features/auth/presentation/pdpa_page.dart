// lib/features/auth/presentation/pdpa_page.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_router.dart';

import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_widgets.dart';
import '../../user/data/user_repository.dart';
import '../../user/data/phone_repository.dart';

class PdpaPage extends ConsumerStatefulWidget {
  const PdpaPage({super.key, required this.draft, required this.phoneNumber});

  final RegisterDraft draft;
  final String phoneNumber;

  @override
  ConsumerState<PdpaPage> createState() => _PdpaPageState();
}

class _PdpaPageState extends ConsumerState<PdpaPage> {
  bool _accepted = false;
  bool _isSaving = false;

  Future<void> _accept() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userRepo = ref.read(userRepositoryProvider);
    final phoneRepo = ref.read(phoneRepositoryProvider);

    setState(() => _isSaving = true);
    try {
      await userRepo.createProfile(
        user: user,
        firstName: widget.draft.firstName,
        lastName: widget.draft.lastName,
        nickname: widget.draft.nickname,
      );

      final phoneToSave = widget.phoneNumber;

      if (phoneToSave.isNotEmpty) {
        await phoneRepo.createPhoneRecord(
          phoneNumber: phoneToSave,
          uid: user.uid,
        );
      }

      if (!mounted) return;
      context.go(AppRoutes.home);
    } on FirebaseException catch (e) {
      if (!mounted) return;
      showAppSnack(
        context,
        'บันทึกข้อมูลไม่สำเร็จ (${e.code}) กรุณาลองใหม่',
        isError: true,
      );
    } catch (e) {
      if (!mounted) return;
      showAppSnack(context, 'เกิดข้อผิดพลาด: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _decline() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ไม่ยินยอมใช่ไหม'),
        content: const Text(
          'หากไม่ยินยอม จะไม่สามารถใช้งาน Oldfort ได้ '
          'ระบบจะออกจากระบบให้ และคุณกลับมาสมัครใหม่ได้ทุกเมื่อ',
          style: TextStyle(fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('กลับไปอ่าน'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ออกจากระบบ'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BackTextButton(
                onTap: () async {
                  await FirebaseAuth.instance.signOut();
                  if (!mounted) return;
                  this.context.go(AppRoutes.login);
                },
              ),
              const SizedBox(height: 8),
              const PageTitle('ความยินยอม\nข้อมูลส่วนบุคคล'),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        for (final section in _pdpaSections) ...[
                          Text(
                            section.title,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: scheme.tertiary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          for (final line in section.lines)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '•  $line',
                                style: const TextStyle(
                                  fontSize: 18,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: _accepted,
                onChanged: _isSaving
                    ? null
                    : (value) => setState(() => _accepted = value ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'ข้าพเจ้าได้อ่านและยินยอมให้ Oldfort เก็บและใช้ข้อมูลส่วนบุคคล '
                  'รวมถึงข้อมูลสุขภาพ ตามที่ระบุข้างต้น',
                  style: TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _accepted && !_isSaving ? _accept : null,
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Text('ยินยอมและเริ่มใช้งาน'),
              ),
              TextButton(
                onPressed: _isSaving ? null : _decline,
                child: const Text('ไม่ยินยอม'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PdpaSection {
  const _PdpaSection(this.title, this.lines);

  final String title;
  final List<String> lines;
}

const _pdpaSections = [
  _PdpaSection('ข้อมูลที่เราเก็บ', [
    'ชื่อ นามสกุล ชื่อเล่น และหมายเลขโทรศัพท์',
    'ข้อมูลสุขภาพที่คุณบันทึก เช่น การแจ้งเตือนกินยา การออกกำลังกาย การดื่มน้ำ และค่า BMI',
    'ผลเกมทดสอบความจำ ผลทดสอบการได้ยิน และผลแบบสอบถามสุขภาพ',
    'ข้อความแชทกับเพื่อนและกับทีมช่วยเหลือ',
  ]),
  _PdpaSection('เก็บไปเพื่ออะไร', [
    'ใช้เพื่อให้บริการฟีเจอร์ต่าง ๆ ในแอป Oldfort เท่านั้น',
    'ไม่ขายหรือส่งต่อข้อมูลให้ผู้อื่น และไม่ใช้เพื่อโฆษณา',
  ]),
  _PdpaSection('ใครเห็นข้อมูลของคุณ', [
    'คุณเห็นข้อมูลทั้งหมดของตัวเอง',
    'เพื่อนในแอปเห็นเฉพาะชื่อเล่น และข้อความที่ส่งถึงกัน',
    'ผู้ดูแลระบบไม่สามารถดูข้อมูลสุขภาพของคุณได้',
  ]),
  _PdpaSection('เก็บข้อมูลไว้ที่ไหน', [
    'ข้อมูลเก็บบบนบริการ Google Firebase และส่งผ่านการเชื่อมต่อที่เข้ารหัส',
  ]),
  _PdpaSection('สิทธิของคุณ', [
    'ขอดู แก้ไข หรือขอลบข้อมูลของคุณได้',
    'ถอนความยินยอมได้ทุกเมื่อ ผ่านเมนู "ติดต่อขอความช่วยเหลือ" ในหน้าการตั้งค่า',
    'ข้อมูลสุขภาพเป็นข้อมูลอ่อนไหวตาม พ.ร.บ.คุ้มครองข้อมูลส่วนบุคคล พ.ศ. 2562 '
        'จึงต้องได้รับความยินยอมจากคุณโดยชัดแจ้งก่อน',
  ]),
];
