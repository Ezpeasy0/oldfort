import 'package:flutter_test/flutter_test.dart';
import 'package:oldfort/core/utils/phone_utils.dart';

void main() {
  group('PhoneUtils', () {
    test('รับเบอร์มือถือไทย 10 หลัก', () {
      expect(PhoneUtils.isValidThaiMobile('0812345678'), isTrue);
      expect(PhoneUtils.isValidThaiMobile('081-234-5678'), isTrue);
      expect(PhoneUtils.isValidThaiMobile('0612345678'), isTrue);
    });

    test('ปฏิเสธเบอร์ผิดรูปแบบ', () {
      expect(PhoneUtils.isValidThaiMobile('021234567'), isFalse);
      expect(PhoneUtils.isValidThaiMobile('081234567'), isFalse);
      expect(PhoneUtils.isValidThaiMobile(''), isFalse);
    });

    test('แปลงเป็น +66', () {
      expect(PhoneUtils.toE164('0812345678'), '+66812345678');
    });
  });
}