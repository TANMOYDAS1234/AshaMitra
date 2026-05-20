// ─────────────────────────────────────────────────────────────────────────────
// Layer 2 — Contradiction Check
// Detects logically impossible answer combinations before rules run.
// ─────────────────────────────────────────────────────────────────────────────

class ContradictionResult {
  final bool hasContradictions;
  final List<ContradictionEntry> contradictions;

  const ContradictionResult({
    required this.hasContradictions,
    required this.contradictions,
  });

  factory ContradictionResult.clean() => const ContradictionResult(
        hasContradictions: false,
        contradictions: [],
      );
}

class ContradictionEntry {
  final String code;       // e.g. CONTRA_001
  final String questionA;
  final String questionB;
  final String reason;
  final bool blocking;     // true → pipeline halts; false → warning only

  const ContradictionEntry({
    required this.code,
    required this.questionA,
    required this.questionB,
    required this.reason,
    required this.blocking,
  });

  Map<String, dynamic> toMap() => {
    'code': code,
    'question_a': questionA,
    'question_b': questionB,
    'reason': reason,
    'blocking': blocking,
  };
}

// ── Contradiction rule definition ─────────────────────────────────────────────
class _ContraRule {
  final String code;
  final String qA;
  final dynamic valA;
  final String qB;
  final dynamic valB;
  final String reason;
  final bool blocking;

  const _ContraRule({
    required this.code,
    required this.qA,
    required this.valA,
    required this.qB,
    required this.valB,
    required this.reason,
    required this.blocking,
  });
}

class ContradictionChecker {
  // ── Per-module contradiction rules ────────────────────────────────────────
  static const _rules = <String, List<_ContraRule>>{

    'newborn': [
      // Cannot be lethargic (n5=true) AND feeding well (n1=false) simultaneously
      // if skin is also normal — lethargy always implies feeding problem
      _ContraRule(
        code: 'CONTRA_NB_001',
        qA: 'n5', valA: true,
        qB: 'n1', valB: false,
        reason: 'Lethargy (n5=true) with normal feeding (n1=false) is clinically '
            'inconsistent in a newborn — lethargic neonates cannot feed normally.',
        blocking: false, // warn only — ASHA may have observed partial feeding
      ),
      // Cyanosis (n6=true) with normal breathing (n3=false) is impossible
      _ContraRule(
        code: 'CONTRA_NB_002',
        qA: 'n6', valA: true,
        qB: 'n3', valB: false,
        reason: 'Cyanosis (n6=true) with no breathing difficulty (n3=false) is '
            'physiologically impossible — cyanosis always implies respiratory compromise.',
        blocking: true,
      ),
    ],

    'child': [
      // Severe dehydration (c5=true) with no diarrhoea/vomiting (c3=false)
      // is possible but unusual — warn
      _ContraRule(
        code: 'CONTRA_CH_001',
        qA: 'c5', valA: true,
        qB: 'c3', valB: false,
        reason: 'Severe dehydration signs (c5=true) with no diarrhoea/vomiting '
            '(c3=false) is unusual — confirm dehydration cause.',
        blocking: false,
      ),
    ],

    'pregnancy': [
      // Blurred vision (p6=true) with no headache/BP (p1=false) — eclampsia
      // prodrome without BP symptoms is inconsistent
      _ContraRule(
        code: 'CONTRA_ANC_001',
        qA: 'p6', valA: true,
        qB: 'p1', valB: false,
        reason: 'Blurred vision (p6=true) without headache/high BP (p1=false) — '
            'eclampsia prodrome without BP symptoms is clinically inconsistent. '
            'Re-check BP.',
        blocking: false,
      ),
      // Bleeding (p3=true) with no abdominal pain AND no fetal movement change
      // is possible (placenta praevia) — warn only
      _ContraRule(
        code: 'CONTRA_ANC_002',
        qA: 'p3', valA: true,
        qB: 'p4', valB: false,
        reason: 'Vaginal bleeding (p3=true) with normal fetal movement (p4=false) — '
            'possible placenta praevia. Confirm fetal status.',
        blocking: false,
      ),
    ],

    'delivery_pnc': [
      // Fever (pp2=true) with no bleeding/discharge (pp1=false) AND
      // no abdominal pain (pp4=false) — isolated fever, low sepsis risk
      // Not a contradiction but worth flagging
      _ContraRule(
        code: 'CONTRA_PNC_001',
        qA: 'pp2', valA: true,
        qB: 'pp1', valB: false,
        reason: 'Fever (pp2=true) with no bleeding/discharge (pp1=false) — '
            'isolated fever. Monitor for sepsis progression.',
        blocking: false,
      ),
    ],

    'immunisation': [],
    'emergency': [],
  };

  // ── Vital contradiction rules (cross-module) ──────────────────────────────
  // These check for physiologically impossible vital combinations.
  static const _vitalRules = <_VitalContraRule>[
    // SpO2 > 100 is impossible
    _VitalContraRule(
      code: 'CONTRA_VIT_001',
      vital: 'spo2',
      operator: 'GREATER_THAN',
      value: 100,
      reason: 'SpO2 > 100% is physiologically impossible — check sensor.',
      blocking: true,
    ),
    // Temperature > 45°C is incompatible with life
    _VitalContraRule(
      code: 'CONTRA_VIT_002',
      vital: 'temperature_c',
      operator: 'GREATER_THAN',
      value: 45,
      reason: 'Temperature > 45°C is incompatible with life — check thermometer.',
      blocking: true,
    ),
    // Respiratory rate > 120 in any patient is implausible
    _VitalContraRule(
      code: 'CONTRA_VIT_003',
      vital: 'respiratory_rate',
      operator: 'GREATER_THAN',
      value: 120,
      reason: 'Respiratory rate > 120/min is implausible — recount.',
      blocking: true,
    ),
    // Systolic BP > 300 is implausible
    _VitalContraRule(
      code: 'CONTRA_VIT_004',
      vital: 'systolic_bp',
      operator: 'GREATER_THAN',
      value: 300,
      reason: 'Systolic BP > 300 mmHg is implausible — recheck.',
      blocking: true,
    ),
    // Diastolic > systolic is impossible
    // Handled separately in check() below
  ];

  ContradictionResult check({
    required String moduleId,
    required Map<String, dynamic> answers,
    required Map<String, dynamic> vitals,
  }) {
    final found = <ContradictionEntry>[];

    // ── Answer contradictions ─────────────────────────────────────────────────
    final moduleRules = _rules[moduleId] ?? [];
    for (final rule in moduleRules) {
      final a = answers[rule.qA];
      final b = answers[rule.qB];
      if (a == null || b == null) continue;
      if (_matches(a, rule.valA) && _matches(b, rule.valB)) {
        found.add(ContradictionEntry(
          code: rule.code,
          questionA: rule.qA,
          questionB: rule.qB,
          reason: rule.reason,
          blocking: rule.blocking,
        ));
      }
    }

    // ── Vital range contradictions ────────────────────────────────────────────
    for (final vr in _vitalRules) {
      final v = vitals[vr.vital];
      if (v == null) continue;
      final num vNum = v as num;
      bool triggered = false;
      if (vr.operator == 'GREATER_THAN' && vNum > vr.value) triggered = true;
      if (vr.operator == 'LESS_THAN' && vNum < vr.value) triggered = true;
      if (triggered) {
        found.add(ContradictionEntry(
          code: vr.code,
          questionA: vr.vital,
          questionB: '',
          reason: vr.reason,
          blocking: vr.blocking,
        ));
      }
    }

    // ── Diastolic > Systolic ──────────────────────────────────────────────────
    final sys = vitals['systolic_bp'] as num?;
    final dia = vitals['diastolic_bp'] as num?;
    if (sys != null && dia != null && dia >= sys) {
      found.add(const ContradictionEntry(
        code: 'CONTRA_VIT_005',
        questionA: 'diastolic_bp',
        questionB: 'systolic_bp',
        reason: 'Diastolic BP ≥ Systolic BP is physiologically impossible — recheck.',
        blocking: true,
      ));
    }

    if (found.isEmpty) return ContradictionResult.clean();
    return ContradictionResult(
      hasContradictions: true,
      contradictions: found,
    );
  }

  bool _matches(dynamic actual, dynamic expected) {
    if (actual is bool && expected is bool) return actual == expected;
    if (actual is String && expected is String) return actual == expected;
    if (actual is bool && expected is String) {
      return (actual && expected == 'true') || (!actual && expected == 'false');
    }
    return actual.toString() == expected.toString();
  }
}

class _VitalContraRule {
  final String code;
  final String vital;
  final String operator;
  final num value;
  final String reason;
  final bool blocking;

  const _VitalContraRule({
    required this.code,
    required this.vital,
    required this.operator,
    required this.value,
    required this.reason,
    required this.blocking,
  });
}
