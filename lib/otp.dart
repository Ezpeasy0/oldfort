// lib/otp.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'info.dart';

class OtpPage extends StatefulWidget {
  final String phoneNumber;
  final String verificationId;

  const OtpPage({
    super.key,
    required this.phoneNumber,
    required this.verificationId,
  });

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());

  // Expiry time
  Timer? _timer;
  int _start = 30;
  bool _isResendActive = false;

  static const Color backgroundColor = Color(0xFFF8F5F0);

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    setState(() {
      _start = 30;
      _isResendActive = false;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_start == 0) {
        setState(() {
          timer.cancel();
          _isResendActive = true;
        });
      } else {
        setState(() {
          _start--;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  // resend OTP
  Future<void> _resendOtp() async {
    String formattedPhone = widget.phoneNumber.startsWith('0')
        ? '+66${widget.phoneNumber.substring(1)}'
        : widget.phoneNumber;

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: formattedPhone,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await FirebaseAuth.instance.signInWithCredential(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: ${e.message}')));
      },
      codeSent: (String verificationId, int? resendingToken) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ส่งรหัส OTP ใหม่เรียบร้อยแล้ว')),
        );
        _startTimer();
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  // Confirm OTP & Navigate to info.dart
  Future<void> _verifyOtpAndProceed() async {
    String smsCode = _controllers.map((c) => c.text).join();

    if (smsCode.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณากรอกรหัส OTP ให้ครบ 6 หลัก'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: smsCode,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const RegisterInfoPage()),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('รหัส OTP ไม่ถูกต้อง: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String timerText = '00 : ${_start.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. back button
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.arrow_back_ios,
                      size: 16,
                      color: Color(0xFF090909),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'ย้อนกลับ',
                      style: TextStyle(
                        fontFamily: 'Itim',
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6B553D),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 80),

              // 2. Descriptions
              Center(
                child: Column(
                  children: [
                    const Text(
                      'กรอกรหัส OTP',
                      style: TextStyle(
                        fontFamily: 'Itim',
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6B553D),
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 30),
                    Text(
                      'ที่ส่งไปยังเบอร์ ${widget.phoneNumber}',
                      style: const TextStyle(
                        fontFamily: 'Itim',
                        fontSize: 18,
                        color: Color(0xFF6C7278),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // 3. OTP Text
              const Padding(
                padding: EdgeInsets.only(left: 4.0, bottom: 8.0),
                child: Text(
                  'OTP',
                  style: TextStyle(
                    fontFamily: 'Itim',
                    fontSize: 16,
                    color: Color(0xFF6C7278),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              // 4. Fill OTP
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 50,
                    height: 60,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        textAlignVertical: TextAlignVertical.center,
                        maxLength: 1,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        decoration: const InputDecoration(
                          counterText: '',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (value) {
                          if (value.isNotEmpty && index < 5) {
                            _focusNodes[index + 1].requestFocus();
                          } else if (value.isEmpty && index > 0) {
                            _focusNodes[index - 1].requestFocus();
                          }
                        },
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),

              // 5. Expire Time
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  timerText,
                  style: const TextStyle(
                    fontFamily: 'Itim',
                    fontSize: 16,
                    color: Color(0xFF6C7278),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 6. Resend OTP
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: _isResendActive ? _resendOtp : null,
                  child: Text(
                    'ขอรหัส OTP ใหม่',
                    style: TextStyle(
                      fontFamily: 'Itim',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _isResendActive
                          ? Color(0xFF6B553D)
                          : Colors.grey.shade400, // สีเทาถ้ายังนับเวลาไม่หมด
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 50),

              // 7. Confirm Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _verifyOtpAndProceed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF342B1C),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'ยืนยันรหัส',
                    style: TextStyle(
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
