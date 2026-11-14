// lib/features/auth/presentation/otp_page.dart
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/utils/auth_error_text.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/otp_code_field.dart';

class OtpPage extends StatefulWidget {
  const OtpPage({super.key, required this.args});

  final OtpArgs args;

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final _codeController = TextEditingController();

  Timer? _timer;
  int _secondsLeft = 30;

  late String _verificationId;
  int? _resendToken;
  bool _isVerifying = false;
  bool _isResending = false;

  bool get _canResend => _secondsLeft == 0 && !_isResending;

  @override
  void initState() {
    super.initState();
    _verificationId = widget.args.verificationId;
    _resendToken = widget.args.resendToken;
    _startTimer();
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

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _resendOtp() async {
    setState(() => _isResending = true);
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: PhoneUtils.toE164(widget.args.phoneNumber),
      forceResendingToken: _resendToken,
      timeout: const Duration(seconds: 30),
      verificationCompleted: (PhoneAuthCredential credential) =>
          _signIn(credential),
      verificationFailed: (FirebaseAuthException e) {
        if (!mounted) return;
        setState(() => _isResending = false);
        showAppSnack(context, authErrorText(e), isError: true);
      },
      codeSent: (String verificationId, int? resendToken) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _resendToken = resendToken;
          _isResending = false;
          _codeController.clear();
          _startTimer();
        });
        showAppSnack(context, 'ส่งรหัส OTP ใหม่เรียบร้อยแล้ว');
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  Future<void> _verify(String code) async {
    if (_isVerifying) return;
    if (code.length < 6) {
      showAppSnack(context, 'กรุณากรอกรหัส OTP ให้ครบ 6 หลัก', isError: true);
      return;
    }
    final credential = PhoneAuthProvider.credential(
      verificationId: _verificationId,
      smsCode: code,
    );
    await _signIn(credential);
  }

  Future<void> _signIn(PhoneAuthCredential credential) async {
    if (_isVerifying) return;
    setState(() => _isVerifying = true);
    try {
      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      final user = userCredential.user;

      if (user == null) return;
      if (!mounted) return;

      // 💡 แยกเส้นทางตามโหมดที่ส่งมาจากหน้า Login โดยตรง ไม่ต้องเช็กซ้ำซ้อน
      if (widget.args.isRegister) {
        final draft = RegisterDraft(firstName: '', lastName: '', nickname: '');

        context.go(
          AppRoutes.pdpa,
          extra: PdpaRouteArgs(
            draft: draft,
            phoneNumber: widget.args.phoneNumber,
          ),
        );
      } else {
        context.go(AppRoutes.home);
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _codeController.clear();
      showAppSnack(context, authErrorText(e), isError: true);
    } catch (e) {
      if (!mounted) return;
      debugPrint('SIGN IN ERROR: $e');
      showAppSnack(context, 'เกิดข้อผิดพลาด: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final timerText = '00 : ${_secondsLeft.toString().padLeft(2, '0')}';

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BackTextButton(),
              const SizedBox(height: 48),
              const PageTitle('กรอกรหัส OTP'),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'ที่ส่งไปยังเบอร์ ${widget.args.phoneNumber}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'OTP',
                style: TextStyle(fontSize: 18, color: scheme.tertiary),
              ),
              const SizedBox(height: 8),
              OtpCodeField(controller: _codeController, onCompleted: _verify),
              const SizedBox(height: 16),
              if (_secondsLeft > 0)
                Center(
                  child: Text(
                    timerText,
                    style: TextStyle(
                      fontSize: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              TextButton(
                onPressed: _canResend ? _resendOtp : null,
                child: const Text('ขอรหัส OTP ใหม่'),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isVerifying
                    ? null
                    : () => _verify(_codeController.text),
                child: _isVerifying
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Text('ยืนยันรหัส'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
