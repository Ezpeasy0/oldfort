import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/auth_error_text.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/otp_code_field.dart';
import '../../user/data/user_repository.dart';

class ChangePhonePage extends ConsumerStatefulWidget {
  const ChangePhonePage({super.key});

  @override
  ConsumerState<ChangePhonePage> createState() => _ChangePhonePageState();
}

class _ChangePhonePageState extends ConsumerState<ChangePhonePage> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  bool _codeSent = false;
  bool _busy = false;
  String? _verificationId;
  int? _resendToken;
  String _newPhoneE164 = '';

  Timer? _timer;
  int _secondsLeft = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _secondsLeft = 30;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 0) _secondsLeft--;
        if (_secondsLeft == 0) timer.cancel();
      });
    });
  }

  Future<void> _sendCode({bool resend = false}) async {
    final phone = _phoneController.text.trim();
    if (!PhoneUtils.isValidThaiMobile(phone)) {
      showAppSnack(context, 'กรุณากรอกเบอร์มือถือ 10 หลัก เช่น 0812345678',
          isError: true);
      return;
    }
    final newPhone = PhoneUtils.toE164(phone);
    if (newPhone == FirebaseAuth.instance.currentUser?.phoneNumber) {
      showAppSnack(context, 'นี่คือเบอร์ที่ใช้อยู่แล้ว', isError: true);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    _newPhoneE164 = newPhone;

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: newPhone,
      timeout: const Duration(seconds: 30),
      forceResendingToken: resend ? _resendToken : null,
      verificationCompleted: (PhoneAuthCredential credential) =>
          _applyCredential(credential),
      verificationFailed: (FirebaseAuthException e) {
        if (!mounted) return;
        setState(() => _busy = false);
        showAppSnack(context, authErrorText(e), isError: true);
      },
      codeSent: (String verificationId, int? resendToken) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _resendToken = resendToken;
          _codeSent = true;
          _busy = false;
          _codeController.clear();
          _startTimer();
        });
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  Future<void> _confirm(String code) async {
    if (code.length < 6 || _verificationId == null) {
      showAppSnack(context, 'กรุณากรอกรหัส OTP ให้ครบ 6 หลัก', isError: true);
      return;
    }
    await _applyCredential(PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: code,
    ));
  }

  Future<void> _applyCredential(PhoneAuthCredential credential) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _busy = true);
    try {

      await user.updatePhoneNumber(credential);

      await user.getIdToken(true);

      await ref.read(userRepositoryProvider).updatePhone(user.uid, _newPhoneE164);

      if (!mounted) return;
      showAppSnack(context, 'เปลี่ยนเบอร์เรียบร้อยแล้ว');
      context.pop();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _codeController.clear();
      showAppSnack(context, authErrorText(e), isError: true);
    } on FirebaseException catch (e) {
      if (!mounted) return;
      showAppSnack(context, 'บันทึกเบอร์ไม่สำเร็จ (${e.code})', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final currentPhone = PhoneUtils.toLocal(
      FirebaseAuth.instance.currentUser?.phoneNumber ?? '',
    );
    final hintStyle = TextStyle(fontSize: 18, color: scheme.onSurfaceVariant);

    const busyIndicator = SizedBox(
      width: 24,
      height: 24,
      child: CircularProgressIndicator(strokeWidth: 2.5),
    );

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          children: [
            const BackTextButton(),
            const PageTitle('เปลี่ยนเบอร์\nโทรศัพท์'),
            const SizedBox(height: 24),
            if (!_codeSent) ...[
              Text('เบอร์ปัจจุบัน: $currentPhone', style: hintStyle),
              const SizedBox(height: 16),
              LabeledField(
                label: 'เบอร์ใหม่',
                controller: _phoneController,
                hintText: '0812345678',
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
              ),
              const SizedBox(height: 8),
              Text('รหัส OTP จะส่งไปที่เบอร์ใหม่', style: hintStyle),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _busy ? null : () => _sendCode(),
                child: _busy ? busyIndicator : const Text('ส่งรหัส OTP'),
              ),
            ] else ...[
              Text(
                'กรอกรหัสที่ส่งไปยังเบอร์ ${_phoneController.text}',
                textAlign: TextAlign.center,
                style: hintStyle,
              ),
              const SizedBox(height: 16),
              OtpCodeField(controller: _codeController, onCompleted: _confirm),
              const SizedBox(height: 16),
              if (_secondsLeft > 0)
                Center(
                  child: Text(
                    '00 : ${_secondsLeft.toString().padLeft(2, '0')}',
                    style: hintStyle,
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                              _codeSent = false;
                              _timer?.cancel();
                            }),
                    child: const Text('แก้ไขเบอร์'),
                  ),
                  TextButton(
                    onPressed: _secondsLeft == 0 && !_busy
                        ? () => _sendCode(resend: true)
                        : null,
                    child: const Text('ขอรหัส OTP ใหม่'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _busy ? null : () => _confirm(_codeController.text),
                child: _busy ? busyIndicator : const Text('ยืนยันเปลี่ยนเบอร์'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}