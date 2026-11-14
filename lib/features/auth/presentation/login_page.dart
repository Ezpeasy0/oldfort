// lib/features/auth/presentation/login_page.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/utils/auth_error_text.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../user/data/phone_repository.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  int _selectedTab = 0; // 0 = ลงชื่อเข้าใช้, 1 = ลงทะเบียน
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
      showAppSnack(
        context,
        'กรุณากรอกเบอร์มือถือ 10 หลัก เช่น 0812345678',
        isError: true,
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final formattedPhone = PhoneUtils.toE164(phone);
      final bool isRegisterMode = _selectedTab == 1;

      final phoneRepo = ref.read(phoneRepositoryProvider);
      final bool isAlreadyRegistered = await phoneRepo.checkPhoneExists(phone);

      if (isRegisterMode && isAlreadyRegistered) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        showAppSnack(
          context,
          'เบอร์นี้มีบัญชีในระบบแล้ว กรุณาไปที่แท็บ "ลงชื่อเข้าใช้"',
          isError: true,
        );
        return;
      }

      if (!isRegisterMode && !isAlreadyRegistered) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        showAppSnack(
          context,
          'ยังไม่มีบัญชีในระบบ กรุณาสมัครสมาชิกก่อน',
          isError: true,
        );
        return;
      }

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        timeout: const Duration(seconds: 30),
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            await FirebaseAuth.instance.signInWithCredential(credential);
            if (mounted) {
              setState(() => _isLoading = false);
              context.go(AppRoutes.home);
            }
          } on FirebaseAuthException catch (e) {
            if (mounted) {
              setState(() => _isLoading = false);
              showAppSnack(context, authErrorText(e), isError: true);
            }
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
              isRegister: isRegisterMode,
            ),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (mounted) setState(() => _isLoading = false);
        },
      );
    } catch (e) {
      debugPrint('LOGIN ERROR: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        showAppSnack(context, 'เกิดข้อผิดพลาด: ${e.toString()}', isError: true);
      }
    }
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
