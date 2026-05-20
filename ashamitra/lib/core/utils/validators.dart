class Validators {
  static String? phone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Phone number is required';
    final digits = v.trim().replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) return 'Enter a valid 10-digit phone number';
    return null;
  }

  static String? required(String? v) =>
      (v == null || v.isEmpty) ? 'This field is required' : null;
}
