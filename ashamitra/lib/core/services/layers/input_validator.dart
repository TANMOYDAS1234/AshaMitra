// ─────────────────────────────────────────────────────────────────────────────
// Layer 1 — Input Validation
// Validates the patient case envelope before any rule runs.
// ─────────────────────────────────────────────────────────────────────────────

class InputValidationResult {
  final bool valid;
  final List<String> errors;   // blocking — pipeline must not proceed
  final List<String> warnings; // non-blocking — logged to trace

  const InputValidationResult({
    required this.valid,
    required this.errors,
    required this.warnings,
  });

  factory InputValidationResult.pass({List<String> warnings = const []}) =>
      InputValidationResult(valid: true, errors: const [], warnings: warnings);

  factory InputValidationResult.fail(List<String> errors,
          {List<String> warnings = const []}) =>
      InputValidationResult(valid: false, errors: errors, warnings: warnings);
}

class InputValidator {
  static const _knownModules = {
    'newborn',
    'child',
    'pregnancy',
    'delivery_pnc',
    'immunisation',
    'emergency',
  };

  /// Validates the full patient case input envelope.
  ///
  /// Blocking errors   → pipeline halts, no band emitted
  /// Non-blocking warnings → logged to trace, pipeline continues
  InputValidationResult validate({
    required String moduleId,
    required Map<String, dynamic> answers,
    required Map<String, dynamic> vitals,
    required String caseId,
  }) {
    final errors   = <String>[];
    final warnings = <String>[];

    // ── Module ID ─────────────────────────────────────────────────────────────
    if (moduleId.isEmpty) {
      errors.add('INPUT_001: moduleId is empty.');
    } else if (!_knownModules.contains(moduleId)) {
      errors.add('INPUT_002: Unknown moduleId "$moduleId". '
          'Must be one of: ${_knownModules.join(', ')}.');
    }

    // ── Case ID ───────────────────────────────────────────────────────────────
    if (caseId.isEmpty) {
      warnings.add('INPUT_003: caseId is empty — audit trace will have no case reference.');
    }

    // ── Answers ───────────────────────────────────────────────────────────────
    if (answers.isEmpty) {
      errors.add('INPUT_004: answers map is empty — no clinical data to evaluate.');
    } else {
      for (final entry in answers.entries) {
        final v = entry.value;
        if (v == null) {
          errors.add('INPUT_005: Answer for "${entry.key}" is null. Must be bool or String.');
        } else if (v is! bool && v is! String) {
          errors.add('INPUT_006: Answer for "${entry.key}" has invalid type '
              '${v.runtimeType}. Must be bool or String.');
        }
      }
    }

    // ── Vitals ────────────────────────────────────────────────────────────────
    for (final entry in vitals.entries) {
      final v = entry.value;
      if (v == null) {
        warnings.add('INPUT_007: Vital "${entry.key}" is null — '
            'numeric rules for this vital will be skipped.');
      } else if (v is! num) {
        errors.add('INPUT_008: Vital "${entry.key}" has invalid type '
            '${v.runtimeType}. Must be int or double.');
      } else if ((v as num) < 0) {
        errors.add('INPUT_009: Vital "${entry.key}" is negative ($v). '
            'Physiologically impossible.');
      }
    }

    if (errors.isNotEmpty) {
      return InputValidationResult.fail(errors, warnings: warnings);
    }
    return InputValidationResult.pass(warnings: warnings);
  }
}
