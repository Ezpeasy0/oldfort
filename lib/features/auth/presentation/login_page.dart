// lib/login_register.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/utils/auth_error_text.dart';
import '../../../core/utils/phone_utils.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // 0 = Log In, 1 = Register
  int _selectedTab = 0;
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;

  static const Color backgroundColor = Color(0xFFF8F5F0);

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (!PhoneUtils.isValidThaiMobile(phone)) {
      _showError('กรุณากรอกเบอร์มือถือ 10 หลัก เช่น 0812345678');
      return;
    }
    final isRegister = _selectedTab == 1;
    setState(() => _isLoading = true);

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: PhoneUtils.toE164(phone),
      timeout: const Duration(seconds: 30),

      verificationCompleted: (PhoneAuthCredential credential) async {
        await FirebaseAuth.instance.signInWithCredential(credential);
        if (!mounted) return;
        setState(() => _isLoading = false);
        context.go(isRegister ? AppRoutes.registerInfo : AppRoutes.home);
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        _showError(authErrorText(e));
      },
      codeSent: (String verificationId, int? resendToken) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        context.push(
          AppRoutes.otp,
          extra: OtpArgs(
            phoneNumber: phone,
            verificationId: verificationId,
            isRegister: isRegister,
            resendToken: resendToken,
          ),
        );
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        if (mounted) setState(() => _isLoading = false);
      },
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 18)),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),

              // 1. Logo
              Center(
                child: SizedBox(
                  height: 180,
                  child: Image.asset(
                    'assets/images/Logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.home_work_rounded,
                        size: 140,
                        color: Color(0xFF5CA38C),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 2. Application Name
              const Text(
                'OLDFORT',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6B553D),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),

              // 3. Text
              const Text(
                'ลงทะเบียนหรือลงชื่อเข้าใช้\nเพื่อใช้งานตัวช่วยสำหรับผู้สูงอายุ',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Itim',
                  fontSize: 18,
                  height: 1.4,
                  color: Color(0xFF6C7278),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),

              // 4. Tab Switch "Login" & "Register"
              Container(
                height: 48,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F6F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedTab = 0;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: _selectedTab == 0
                                ? Colors.white
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: _selectedTab == 0
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.05,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : [],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'ลงชื่อเข้าใช้',
                            style: TextStyle(
                              fontFamily: 'Itim',
                              fontSize: 16,
                              fontWeight: _selectedTab == 0
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: _selectedTab == 0
                                  ? const Color(0xFF342B1C)
                                  : const Color(0xFF7D7D91),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedTab = 1;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: _selectedTab == 1
                                ? Colors.white
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: _selectedTab == 1
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.05,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : [],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'ลงทะเบียน',
                            style: TextStyle(
                              fontFamily: 'Itim',
                              fontSize: 16,
                              fontWeight: _selectedTab == 1
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: _selectedTab == 1
                                  ? const Color(0xFF342B1C)
                                  : const Color(0xFF7D7D91),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 5. TextField Label
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'หมายเลขโทรศัพท์',
                  style: TextStyle(
                    fontFamily: 'Itim',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B553D),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // 6. TextField Input
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                  decoration: InputDecoration(
                    hintText: '+66 XXXXXXXXX',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 16,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF5CA38C),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Login Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _sendOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF342B1C),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          _selectedTab == 0 ? 'เข้าสู่ระบบ' : 'สมัครสมาชิก',
                          style: const TextStyle(
                            fontFamily: 'Itim',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
