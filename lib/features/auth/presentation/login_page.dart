// lib/features/auth/presentation/login_page.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/utils/auth_error_text.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../core/widgets/app_widgets.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {

  int _selectedTab = 0;
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (!PhoneUtils.isValidThaiMobile(phone)) {
      showAppSnack(context, 'กรุณากรอกเบอร์มือถือ 10 หลัก เช่น 0812345678',
          isError: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: PhoneUtils.toE164(phone),
      timeout: const Duration(seconds: 30),

      verificationCompleted: (PhoneAuthCredential credential) async {
        try {
          await FirebaseAuth.instance.signInWithCredential(credential);

        } on FirebaseAuthException catch (e) {
          if (mounted) showAppSnack(context, authErrorText(e), isError: true);
        } finally {
          if (mounted) setState(() => _isLoading = false);
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        showAppSnack(context, authErrorText(e), isError: true);
      },
      codeSent: (String verificationId, int? resendToken) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        context.push(
          AppRoutes.otp,
          extra: OtpArgs(
            phoneNumber: phone,
            verificationId: verificationId,
            resendToken: resendToken,
          ),
        );
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        if (mounted) setState(() => _isLoading = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Image.asset(
                'assets/images/Logo.png',
                height: 160,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.home_work_rounded,
                  size: 140,
                  color: scheme.secondary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'OLDFORT',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: scheme.tertiary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'ลงทะเบียนหรือลงชื่อเข้าใช้\nเพื่อใช้งานตัวช่วยสำหรับผู้สูงอายุ',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  height: 1.4,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              SegmentedTabs(
                labels: const ['ลงชื่อเข้าใช้', 'ลงทะเบียน'],
                selectedIndex: _selectedTab,
                onChanged: (i) => setState(() => _selectedTab = i),
              ),
              const SizedBox(height: 24),
              LabeledField(
                label: 'หมายเลขโทรศัพท์',
                controller: _phoneController,
                hintText: '0812345678',
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _sendOtp,
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : Text(_selectedTab == 0 ? 'เข้าสู่ระบบ' : 'สมัครสมาชิก'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}