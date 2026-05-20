// ─────────────────────────────────────────────────────────────────────────────
// Layer 4 — Required Vital Check
// Checks that vitals needed by numeric rules are present.
// Missing critical vitals → warn (never block — ASHA may not have equipment).
// Missing vitals that would change a GREEN to RED → escalate band conservatively.
// ─────────────────────────────────────────────────────────────────────────────

class VitalCheckResult {
  final List<MissingVital> missing;
  final bool hasBlockingGaps; // true if a RED-tier vital is absent

  const VitalCheckResult({
    required this.missing,
    required this.hasBlockingGaps,
  });

  factory VitalCheckResult.clean() => const VitalCheckResult(
        missing: [],
        hasBlockingGaps: false,
      );

  bool get hasMissing => missing.isNotEmpty;
}

class MissingVital {
  final String vitalKey;
  final String moduleId;
  final String ruleId;       // which numeric rule needs it
  final String bandIfMissing; // what band that rule would fire
  final String message;

  const MissingVital({
    required this.vitalKey,
    required this.moduleId,
    required this.ruleId,
    required this.bandIfMissing,
    required this.message,
  });

  Map<String, dynamic> toMap() => {
    'vital_key': vitalKey,
    'module_id': moduleId,
    'rule_id': ruleId,
    'band_if_missing': bandIfMissing,
    'message': message,
  };
}

// ── Vital requirement definition ──────────────────────────────────────────────
class _VitalRequirement {
  final String vitalKey;
  final String ruleId;
  final String bandIfMissing;
  final String message;

  const _VitalRequirement({
    required this.vitalKey,
    required this.ruleId,
    required this.bandIfMissing,
    required this.message,
  });
}

class RequiredVitalChecker {
  // ── Per-module vital requirements ─────────────────────────────────────────
  static const _requirements = <String, List<_VitalRequirement>>{

    'newborn': [
      _VitalRequirement(
        vitalKey: 'spo2',
        ruleId: 'NB-VITAL-001',
        bandIfMissing: 'RED',
        message: 'VITAL_001: SpO2 not recorded for newborn. '
            'NB-VITAL-001 (SpO2 < 90% → RED) cannot be evaluated. '
            'Measure SpO2 if pulse oximeter available.',
      ),
      _VitalRequirement(
        vitalKey: 'respiratory_rate',
        ruleId: 'NB-VITAL-002',
        bandIfMissing: 'RED',
        message: 'VITAL_002: Respiratory rate not recorded for newborn. '
            'NB-VITAL-002 (RR > 60 → RED) cannot be evaluated. '
            'Count breaths for 60 seconds.',
      ),
      _VitalRequirement(
        vitalKey: 'temperature_c',
        ruleId: 'NB-VITAL-003',
        bandIfMissing: 'RED',
        message: 'VITAL_003: Temperature not recorded for newborn. '
            'NB-VITAL-003 (Temp > 37.5°C → RED) cannot be evaluated. '
            'Use axillary thermometer.',
      ),
      _VitalRequirement(
        vitalKey: 'weight_kg',
        ruleId: 'NB-VITAL-004',
        bandIfMissing: 'YELLOW',
        message: 'VITAL_004: Weight not recorded for newborn. '
            'NB-VITAL-004 (Weight < 1.5 kg → YELLOW) cannot be evaluated. '
            'Weigh baby if scale available.',
      ),
    ],

    'child': [
      _VitalRequirement(
        vitalKey: 'spo2',
        ruleId: 'CH-VITAL-001',
        bandIfMissing: 'RED',
        message: 'VITAL_005: SpO2 not recorded for child. '
            'CH-VITAL-001 (SpO2 < 90% → RED) cannot be evaluated.',
      ),
      _VitalRequirement(
        vitalKey: 'muac_cm',
        ruleId: 'CH-VITAL-002',
        bandIfMissing: 'RED',
        message: 'VITAL_006: MUAC not recorded for child. '
            'CH-VITAL-002 (MUAC < 11.5 cm → RED/SAM) cannot be evaluated. '
            'Measure mid-upper arm circumference.',
      ),
    ],

    'pregnancy': [
      _VitalRequirement(
        vitalKey: 'systolic_bp',
        ruleId: 'ANC-VITAL-001',
        bandIfMissing: 'RED',
        message: 'VITAL_007: Systolic BP not recorded for pregnant patient. '
            'ANC-VITAL-001 (Systolic ≥ 140 → RED) cannot be evaluated. '
            'Measure BP if sphygmomanometer available.',
      ),
      _VitalRequirement(
        vitalKey: 'diastolic_bp',
        ruleId: 'ANC-VITAL-002',
        bandIfMissing: 'RED',
        message: 'VITAL_008: Diastolic BP not recorded for pregnant patient. '
            'ANC-VITAL-002 (Diastolic ≥ 90 → RED) cannot be evaluated.',
      ),
      _VitalRequirement(
        vitalKey: 'haemoglobin',
        ruleId: 'ANC-VITAL-003',
        bandIfMissing: 'RED',
        message: 'VITAL_009: Haemoglobin not recorded for pregnant patient. '
            'ANC-VITAL-003 (Hb < 7 → RED) cannot be evaluated. '
            'Check MCP card for last Hb reading.',
      ),
    ],

    'delivery_pnc': [
      _VitalRequirement(
        vitalKey: 'temperature_c',
        ruleId: 'PNC-VITAL-001',
        bandIfMissing: 'RED',
        message: 'VITAL_010: Temperature not recorded for postpartum patient. '
            'PNC-VITAL-001 (Temp > 38°C → RED) cannot be evaluated.',
      ),
      _VitalRequirement(
        vitalKey: 'haemoglobin',
        ruleId: 'PNC-VITAL-002',
        bandIfMissing: 'RED',
        message: 'VITAL_011: Haemoglobin not recorded for postpartum patient. '
            'PNC-VITAL-002 (Hb < 7 → RED) cannot be evaluated.',
      ),
    ],

    'immunisation': [], // no numeric rules
    'emergency':    [], // no numeric rules
  };

  /// Checks which required vitals are absent for the given module.
  ///
  /// Never blocks the pipeline — ASHA may not have equipment.
  /// Sets [hasBlockingGaps] = true if any RED-tier vital is missing,
  /// so the Adaptive Risk Engine can conservatively escalate.
  VitalCheckResult check({
    required String moduleId,
    required Map<String, dynamic> vitals,
  }) {
    final reqs = _requirements[moduleId] ?? [];
    final missing = <MissingVital>[];

    for (final req in reqs) {
      final v = vitals[req.vitalKey];
      if (v == null) {
        missing.add(MissingVital(
          vitalKey: req.vitalKey,
          moduleId: moduleId,
          ruleId: req.ruleId,
          bandIfMissing: req.bandIfMissing,
          message: req.message,
        ));
      }
    }

    if (missing.isEmpty) return VitalCheckResult.clean();

    final hasBlockingGaps = missing.any((m) => m.bandIfMissing == 'RED');
    return VitalCheckResult(
      missing: missing,
      hasBlockingGaps: hasBlockingGaps,
    );
  }
}
