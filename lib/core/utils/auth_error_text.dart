import 'package:firebase_auth/firebase_auth.dart';

String authErrorText(FirebaseAuthException e) {
  switch (e.code) {
    case 'invalid-phone-number':
      return 'หมายเลขโทรศัพท์ไม่ถูกต้อง';
    case 'invalid-verification-code':
      return 'รหัส OTP ไม่ถูกต้อง กรุณาตรวจสอบแล้วลองใหม่';
    case 'session-expired':
    case 'code-expired':
      return 'รหัส OTP หมดอายุแล้ว กรุณากดขอรหัสใหม่';
    case 'too-many-requests':
      return 'ขอรหัสบ่อยเกินไป กรุณารอสักครู่แล้วลองใหม่';
    case 'network-request-failed':
      return 'ไม่มีการเชื่อมต่ออินเทอร์เน็ต';
    case 'quota-exceeded':
      return 'ระบบส่ง SMS ไม่ได้ชั่วคราว กรุณาลองใหม่ภายหลัง';
    case 'credential-already-in-use':
    case 'account-exists-with-different-credential':
      return 'เบอร์นี้ถูกใช้กับบัญชีอื่นแล้ว';
    case 'requires-recent-login':
      return 'เพื่อความปลอดภัย กรุณาออกจากระบบแล้วเข้าใหม่ก่อนเปลี่ยนเบอร์';
    default:
      return 'เกิดข้อผิดพลาด (${e.code}) กรุณาลองใหม่อีกครั้ง';
  }
}