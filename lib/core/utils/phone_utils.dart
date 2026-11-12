class PhoneUtils {
  PhoneUtils._();

  static final RegExp _thaiMobile = RegExp(r'^0[689]\d{8}$');

  static String digitsOnly(String input) => input.replaceAll(RegExp(r'\D'), '');

  static bool isValidThaiMobile(String input) =>
      _thaiMobile.hasMatch(digitsOnly(input));

  static String toE164(String input) => '+66${digitsOnly(input).substring(1)}';

  static String toLocal(String e164) =>
      e164.startsWith('+66') ? '0${e164.substring(3)}' : e164;
}