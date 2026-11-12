import 'package:flutter/material.dart';

class RegisterInfoPage extends StatefulWidget {
  const RegisterInfoPage({super.key});

  @override
  State<RegisterInfoPage> createState() => _RegisterInfoPageState();
}

class _RegisterInfoPageState extends State<RegisterInfoPage> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();

  static const Color backgroundColor = Color(0xFFF8F5F0);

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Back Button
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
              const SizedBox(height: 30),

              // 2. Title
              Center(
                child: const Text(
                  'กรอกชื่อ นามสกุล\nและชื่อเล่น',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Itim',
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6B553D),
                    height: 1.3,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              const SizedBox(height: 36),

              // 3. First Name Field
              const Text(
                'ชื่อ',
                style: TextStyle(
                  fontFamily: 'Itim',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B553D),
                ),
              ),
              const SizedBox(height: 8),
              Container(
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
                  controller: _firstNameController,
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'XXXXX',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 16,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 4. Last Name Field
              const Text(
                'นามสกุล',
                style: TextStyle(
                  fontFamily: 'Itim',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B553D),
                ),
              ),
              const SizedBox(height: 8),
              Container(
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
                  controller: _lastNameController,
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'XXXXX',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 16,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 5. Nickname Field (ชื่อเล่น)
              const Text(
                'ชื่อเล่น',
                style: TextStyle(
                  fontFamily: 'Itim',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B553D),
                ),
              ),
              const SizedBox(height: 8),
              Container(
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
                  controller: _nicknameController,
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'XXXXX',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 16,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // 6. Submit Button (ปุ่มยืนยันข้อมูล)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    final firstName = _firstNameController.text.trim();
                    final lastName = _lastNameController.text.trim();
                    final nickname = _nicknameController.text.trim();

                    if (firstName.isEmpty ||
                        lastName.isEmpty ||
                        nickname.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('กรุณากรอกข้อมูลให้ครบถ้วน'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    // ตัวอย่างการแสดงผลเมื่อกดปุ่มยืนยัน
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'บันทึกข้อมูล: $firstName $lastName ($nickname)',
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF342B1C),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'ยืนยันข้อมูล',
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
