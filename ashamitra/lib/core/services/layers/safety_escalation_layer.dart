// ─────────────────────────────────────────────────────────────────────────────
// Layer 9 — Safety Escalation
// Final safety sweep before output is emitted.
// Runs AFTER adaptive risk — catches anything the earlier layers missed.
//
// Responsibilities:
//   A. Sign-off pending flag — warn on output, never block
//   B. Module/age hard mismatch that slipped through — force correct module
//   C. Emergency cross-sweep — re-runs emergency hard-stop rules on final answers
//   D. Band floor enforcement — if any RED-tier rule fired, band cannot be GREEN
//   E. Referral sanity — RED band must always have a non-empty referral
// ─────────────────────────────────────────────────────────────────────────────

import 'rule_engine.dart';

class SafetyEscalationResult {
  final String finalBand;         // band after all safety checks
  final bool signOffPending;      // true if any fired rule has pending sign-off
  final List<String> safetyFlags; // human-readable flags for audit + UI
  final List<SafetyAction> actions; // structured actions for output layer

  const SafetyEscalationResult({
    required this.finalBand,
    required this.signOffPending,
    required this.safetyFlags,
    required this.actions,
  });
}

class SafetyAction {
  final String code;
  final String description;
  final String severity; // 'INFO' | 'WARNING' | 'CRITICAL'

  const SafetyAction({
    required this.code,
    required this.description,
    required this.severity,
  });

  Map<String, dynamic> toMap() => {
    'code': code,
    'description': description,
    'severity': severity,
  };
}

class SafetyEscalationLayer {
  /// Runs the final safety sweep.
  ///
  /// [adjustedBand]     — band from Layer 8 (Adaptive Risk)
  /// [ruleEngineResult] — full result from Layer 6
  /// [emergencyModule]  — the emergency EngineModule for cross-sweep
  /// [answers]          — original answers map
  /// [referral]         — referral string from winning rule
  SafetyEscalationResult run({
    required String adjustedBand,
    required RuleEngineResult ruleEngineResult,
    required EngineModule? emergencyModule,
    required Map<String, dynamic> answers,
    required String referral,
    required String moduleId,
  }) {
    String band = adjustedBand;
    final flags   = <String>[];
    final actions = <SafetyAction>[];
    bool signOffPending = ruleEngineResult.signOffPending;

    // ── A. Sign-off pending ───────────────────────────────────────────────────
    if (signOffPending) {
      flags.add('SAFETY_A_001: One or more fired rules have clinical sign-off '
          'pending (e.g. PPH proxy threshold). Output is advisory only. '
          'Confirm with ANM/MO before acting.');
      actions.add(const SafetyAction(
        code: 'SAFETY_A_001',
        description: 'Clinical sign-off pending on a fired rule. '
            'Confirm action with ANM or Medical Officer.',
        severity: 'WARNING',
      ));
    }

    // ── B. Emergency cross-sweep ──────────────────────────────────────────────
    // Re-run emergency hard-stop rules on the final answers.
    // This catches cases where the module router selected a non-emergency
    // module but the answers contain emergency-level danger signs.
    if (emergencyModule != null && moduleId != 'emergency') {
      for (final rule in emergencyModule.hardStopRules) {
        final fired = rule.evaluateAnswers(answers);
        if (fired) {
          if (band != 'RED') {
            flags.add('SAFETY_B_001: Emergency hard-stop rule ${rule.ruleId} '
                'fired during cross-sweep. Band escalated to RED.');
            actions.add(SafetyAction(
              code: 'SAFETY_B_001',
              description: 'Emergency danger sign detected: '
                  '${rule.dangerSigns.join(", ")}. '
                  'Refer FRU/DH immediately.',
              severity: 'CRITICAL',
            ));
            band = 'RED';
          }
        }
      }
    }

    // ── C. Band floor enforcement ─────────────────────────────────────────────
    // If any RED-tier rule fired in Layer 6, band cannot be GREEN or YELLOW.
    final hasRedRule = ruleEngineResult.triggeredRules.isNotEmpty &&
        ruleEngineResult.redLock;
    if (hasRedRule && band != 'RED') {
      flags.add('SAFETY_C_001: RED-tier rule fired in rule engine but band '
          'was not RED after adaptive risk. Enforcing RED floor.');
      actions.add(const SafetyAction(
        code: 'SAFETY_C_001',
        description: 'RED band enforced — hard-stop rule fired.',
        severity: 'CRITICAL',
      ));
      band = 'RED';
    }

    // ── D. Referral sanity ────────────────────────────────────────────────────
    if (band == 'RED' && referral.isEmpty) {
      flags.add('SAFETY_D_001: RED band with empty referral destination. '
          'Defaulting to "FRU / SNCU / DH immediately".');
      actions.add(const SafetyAction(
        code: 'SAFETY_D_001',
        description: 'Referral destination missing for RED band. '
            'Default: FRU / SNCU / DH immediately.',
        severity: 'WARNING',
      ));
    }

    // ── E. GREEN with danger signs — sanity check ─────────────────────────────
    if (band == 'GREEN' && ruleEngineResult.dangerSigns.isNotEmpty) {
      flags.add('SAFETY_E_001: GREEN band but danger signs present: '
          '${ruleEngineResult.dangerSigns.join(", ")}. '
          'Escalating to YELLOW for safety.');
      actions.add(SafetyAction(
        code: 'SAFETY_E_001',
        description: 'Danger signs present despite GREEN band: '
            '${ruleEngineResult.dangerSigns.join(", ")}. '
            'Refer PHC within 24 h.',
        severity: 'WARNING',
      ));
      band = 'YELLOW';
    }

    return SafetyEscalationResult(
      finalBand: band,
      signOffPending: signOffPending,
      safetyFlags: flags,
      actions: actions,
    );
  }
}
