/// Child growth assessment for the HBYC visit.
///
/// Two complementary checks (matches WHO/IMNCI field practice on the MCP card):
///   • Weight-for-age  → underweight / severely underweight (WHO 0–24 mo cut-offs)
///   • Growth faltering → weight vs the previous visit (no gain / weight loss)
///
/// MUAC (in the visit screen) covers acute malnutrition; these cover the
/// weight-for-age growth trajectory that was previously only recorded, not
/// assessed.
class ChildGrowth {
  ChildGrowth._();

  // ── WHO Child Growth Standards, weight-for-age (kg), months 0–24 ──────────
  // Index = age in completed months. `2` = −2SD (underweight cut-off),
  // `3` = −3SD (severely underweight). Source: WHO Child Growth Standards
  // weight-for-age tables (girls / boys). Below −2SD = underweight.
  static const List<double> _g2 = [
    2.4, 3.2, 3.9, 4.5, 5.0, 5.4, 5.7, 6.0, 6.3, 6.5, 6.7, 6.9, 7.0,
    7.2, 7.4, 7.6, 7.7, 7.9, 8.1, 8.2, 8.4, 8.6, 8.7, 8.9, 9.0,
  ];
  static const List<double> _g3 = [
    2.0, 2.7, 3.4, 4.0, 4.4, 4.8, 5.1, 5.3, 5.6, 5.8, 5.9, 6.1, 6.3,
    6.4, 6.6, 6.7, 6.9, 7.0, 7.2, 7.3, 7.5, 7.6, 7.8, 7.9, 8.1,
  ];
  static const List<double> _b2 = [
    2.5, 3.4, 4.3, 5.0, 5.6, 6.0, 6.4, 6.7, 6.9, 7.1, 7.4, 7.6, 7.7,
    7.9, 8.1, 8.3, 8.4, 8.6, 8.8, 8.9, 9.1, 9.2, 9.4, 9.5, 9.7,
  ];
  static const List<double> _b3 = [
    2.1, 2.9, 3.8, 4.4, 4.9, 5.3, 5.7, 5.9, 6.2, 6.4, 6.6, 6.8, 6.9,
    7.1, 7.2, 7.4, 7.5, 7.7, 7.8, 8.0, 8.1, 8.2, 8.4, 8.5, 8.6,
  ];

  /// Whole months between [dob] and now (0 if dob is null/future).
  static int? ageMonths(DateTime? dob, {DateTime? at}) {
    if (dob == null) return null;
    final now = at ?? DateTime.now();
    if (dob.isAfter(now)) return 0;
    var m = (now.year - dob.year) * 12 + (now.month - dob.month);
    if (now.day < dob.day) m -= 1; // not yet reached this month's day
    return m < 0 ? 0 : m;
  }

  /// Weight-for-age band: 'severe' (<−3SD) · 'underweight' (<−2SD) · 'normal'.
  /// Returns '' when out of the 0–24 mo reference range or inputs are missing
  /// (older children rely on MUAC + faltering instead).
  static String wfaStatus(double? weightKg, int? months, String gender) {
    if (weightKg == null || weightKg <= 0 || months == null) return '';
    if (months < 0 || months > 24) return '';
    final male = gender.toLowerCase().startsWith('m');
    final s2 = (male ? _b2 : _g2)[months];
    final s3 = (male ? _b3 : _g3)[months];
    if (weightKg < s3) return 'severe';
    if (weightKg < s2) return 'underweight';
    return 'normal';
  }

  /// Growth faltering vs the previous visit's weight:
  ///   'loss'    → weighs less than last time
  ///   'no_gain' → same weight (a growing child should gain)
  ///   'ok'      → gained
  ///   ''        → no prior weight to compare
  static String faltering(double? currentKg, double? prevKg) {
    if (currentKg == null || currentKg <= 0 || prevKg == null || prevKg <= 0) {
      return '';
    }
    if (currentKg < prevKg - 0.05) return 'loss';
    if (currentKg <= prevKg + 0.05) return 'no_gain';
    return 'ok';
  }
}
