import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/widgets/app_widgets.dart';

class RegisterInfoPage extends StatefulWidget {
  const RegisterInfoPage({super.key});

  @override
  State<RegisterInfoPage> createState() => _RegisterInfoPageState();
}

class _RegisterInfoPageState extends State<RegisterInfoPage> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _nicknameController = TextEditingController();

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  void _next() {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final nickname = _nicknameController.text.trim();

    if (firstName.isEmpty || lastName.isEmpty || nickname.isEmpty) {
      showAppSnack(context, 'กรุณากรอกข้อมูลให้ครบถ้วน', isError: true);
      return;
    }
    FocusScope.of(context).unfocus();

    context.push(
      AppRoutes.pdpa,
      extra: RegisterDraft(
        firstName: firstName,
        lastName: lastName,
        nickname: nickname,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              BackTextButton(onTap: () => FirebaseAuth.instance.signOut()),
              const SizedBox(height: 30),
              const PageTitle('กรอกชื่อ นามสกุล\nและชื่อเล่น'),
              const SizedBox(height: 36),
              LabeledField(
                label: 'ชื่อ',
                controller: _firstNameController,
                hintText: 'เช่น สมชาย',
                maxLength: 50,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 20),
              LabeledField(
                label: 'นามสกุล',
                controller: _lastNameController,
                hintText: 'เช่น ใจดี',
                maxLength: 50,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 20),
              LabeledField(
                label: 'ชื่อเล่น',
                controller: _nicknameController,
                hintText: 'เช่น ชาย',
                maxLength: 30,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _next,
                child: const Text('ยืนยันข้อมูล'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}