import 'package:get/get.dart';

class Validators {
  static String? phone(String? v) {
    if (v == null || v.trim().isEmpty) return 'phone_required'.tr;
    final digits = v.trim().replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) return 'phone_invalid'.tr;
    return null;
  }

  static String? required(String? v) =>
      (v == null || v.isEmpty) ? 'field_required'.tr : null;
}
