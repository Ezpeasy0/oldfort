import 'dart:convert';

import 'package:crypto/crypto.dart';

class PhoneUtils {
  // แปลงเบอร์เป็น E.164 (เช่น 0812345678 -> +66812345678)
  static String toE164(String phone) {
    String cleaned = phone.trim().replaceAll(RegExp(r'\D'), '');
    if (cleaned.startsWith('0')) {
      cleaned = '66${cleaned.substring(1)}';
    }
    if (!cleaned.startsWith('+')) {
      cleaned = '+$cleaned';
    }
    return cleaned;
  }

  static String hashPhoneNumber(String formattedPhone) {
    final bytes = utf8.encode(formattedPhone);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  static bool isValidThaiMobile(String phone) {
    String cleaned = phone.trim().replaceAll(RegExp(r'\D'), '');
    return RegExp(r'^0[689]\d{8}$').hasMatch(cleaned);
  }

  static String toLocal(String phone) {
    String cleaned = phone.trim().replaceAll(RegExp(r'\D'), '');
    if (cleaned.startsWith('66') && cleaned.length == 11) {
      cleaned = '0${cleaned.substring(2)}';
    } else if (cleaned.startsWith('0') && cleaned.length == 10) {
      return cleaned;
    }
    return cleaned;
  }
}
