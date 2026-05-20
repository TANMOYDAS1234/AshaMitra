// ─────────────────────────────────────────────────────────────────────────────
// Layer 3 — Age / Module Validation
// Checks that the patient's age is consistent with the selected module.
// ─────────────────────────────────────────────────────────────────────────────

class AgeModuleResult {
  final bool valid;
  final List<String> errors;    // blocking
  final List<String> warnings;  // non-blocking
  final String? suggestedModule; // if wrong module detected, suggest correct one

  const AgeModuleResult({
    required this.valid,
    required this.errors,
    required this.warnings,
    this.suggestedModule,
  });

  factory AgeModuleResult.pass({List<String> warnings = const []}) =>
      AgeModuleResult(valid: true, errors: const [], warnings: warnings);

  factory AgeModuleResult.fail(
    List<String> errors, {
    List<String> warnings = const [],
    String? suggestedModule,
  }) =>
      AgeModuleResult(
        valid: false,
        errors: errors,
        warnings: warnings,
        suggestedModule: suggestedModule,
      );
}

class AgeModuleValidator {
  /// Age boundaries (inclusive) for each module in days.
  /// null = no upper/lower bound.
  static const _moduleBounds = <String, ({int? minDays, int? maxDays})>{
    'newborn':      (minDays: 0,    maxDays: 28),
    'child':        (minDays: 61,   maxDays: 1825), // 2 months – 5 years
    'pregnancy':    (minDays: null, maxDays: null),  // age not the constraint
    'delivery_pnc': (minDays: null, maxDays: null),  // age not the constraint
    'immunisation': (minDays: 0,    maxDays: 5840),  // 0–16 years
    'emergency':    (minDays: null, maxDays: null),  // any age
  };

  /// Modules that require sex = female
  static const _femaleOnlyModules = {'pregnancy', 'delivery_pnc'};

  /// Validates age against module and flags mismatches.
  ///
  /// [moduleId]   — selected module
  /// [ageDays]    — patient age in days (null if not provided)
  /// [ageMonths]  — patient age in months (null if not provided)
  /// [ageYears]   — patient age in years (null if not provided)
  /// [sex]        — 'male' | 'female' | null
  AgeModuleResult validate({
    required String moduleId,
    int? ageDays,
    int? ageMonths,
    int? ageYears,
    String? sex,
  }) {
    final errors   = <String>[];
    final warnings = <String>[];
    String? suggestedModule;

    // ── Normalise age to days ─────────────────────────────────────────────────
    final int? totalDays = _normaliseToDays(ageDays, ageMonths, ageYears);

    // ── Sex check for female-only modules ────────────────────────────────────
    if (_femaleOnlyModules.contains(moduleId)) {
      if (sex != null && sex.toLowerCase() == 'male') {
        errors.add('AGE_MOD_001: Module "$moduleId" is only applicable to female '
            'patients. Patient sex is recorded as male.');
      }
    }

    // ── Age bounds check ─────────────────────────────────────────────────────
    final bounds = _moduleBounds[moduleId];
    if (bounds != null && totalDays != null) {
      final min = bounds.minDays;
      final max = bounds.maxDays;

      if (min != null && totalDays < min) {
        final msg = 'AGE_MOD_002: Patient age (${_formatAge(totalDays)}) is below '
            'the minimum for module "$moduleId" (min: ${_formatAge(min)}).';
        errors.add(msg);
        suggestedModule = _suggestModule(totalDays, sex);
      }

      if (max != null && totalDays > max) {
        final msg = 'AGE_MOD_003: Patient age (${_formatAge(totalDays)}) exceeds '
            'the maximum for module "$moduleId" (max: ${_formatAge(max)}).';
        errors.add(msg);
        suggestedModule = _suggestModule(totalDays, sex);
      }
    }

    // ── Newborn-specific: age > 28 days routed to newborn ────────────────────
    if (moduleId == 'newborn' && totalDays != null && totalDays > 28) {
      errors.add('AGE_MOD_004: Newborn module applies to 0–28 days only. '
          'Patient is ${_formatAge(totalDays)}. Use "child" module.');
      suggestedModule = 'child';
    }

    // ── Child module: age < 2 months should be newborn ───────────────────────
    if (moduleId == 'child' && totalDays != null && totalDays < 61) {
      errors.add('AGE_MOD_005: Child module applies from 2 months. '
          'Patient is ${_formatAge(totalDays)}. Use "newborn" module.');
      suggestedModule = 'newborn';
    }

    // ── No age provided — warn for age-sensitive modules ─────────────────────
    if (totalDays == null &&
        (moduleId == 'newborn' || moduleId == 'child' || moduleId == 'immunisation')) {
      warnings.add('AGE_MOD_006: No age provided for age-sensitive module '
          '"$moduleId". Age/module mismatch cannot be detected.');
    }

    // ── Immunisation: age > 16 years ─────────────────────────────────────────
    if (moduleId == 'immunisation' && totalDays != null && totalDays > 5840) {
      warnings.add('AGE_MOD_007: Patient age (${_formatAge(totalDays)}) exceeds '
          'UIP schedule range (0–16 years). Immunisation module may not apply.');
    }

    if (errors.isNotEmpty) {
      return AgeModuleResult.fail(
        errors,
        warnings: warnings,
        suggestedModule: suggestedModule,
      );
    }
    return AgeModuleResult.pass(warnings: warnings);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  int? _normaliseToDays(int? ageDays, int? ageMonths, int? ageYears) {
    if (ageDays != null) return ageDays;
    if (ageMonths != null) return (ageMonths * 30.44).round();
    if (ageYears != null) return (ageYears * 365.25).round();
    return null;
  }

  String _formatAge(int days) {
    if (days < 31)  return '$days days';
    if (days < 365) return '${(days / 30.44).round()} months';
    return '${(days / 365.25).toStringAsFixed(1)} years';
  }

  String? _suggestModule(int totalDays, String? sex) {
    if (totalDays <= 28) return 'newborn';
    if (totalDays <= 1825) return 'child';
    if (sex?.toLowerCase() == 'female') return 'pregnancy';
    return null;
  }
}
