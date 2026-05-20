// ─────────────────────────────────────────────────────────────────────────────
// Layer 7 — Severity Scoring Engine
// Computes a weighted clinical severity score from answers + vitals.
// Maps score → risk level → score band.
// The score band is advisory — it feeds Layer 8 (Adaptive Risk Engine).
// It never downgrades a RED locked by Layer 6.
// ─────────────────────────────────────────────────────────────────────────────

import 'rule_engine.dart';

class SeverityResult {
  final int baseScore;          // raw score from answer score_rules
  final int vitalPenalty;       // additional score from abnormal vitals
  final int totalScore;         // baseScore + vitalPenalty
  final String scoreBand;       // GREEN | YELLOW | RED — from thresholds
  final String riskLevel;       // LOW | MODERATE | HIGH | CRITICAL
  final List<ScoreContribution> contributions; // audit trail

  const SeverityResult({
    required this.baseScore,
    required this.vitalPenalty,
    required this.totalScore,
    required this.scoreBand,
    required this.riskLevel,
    required this.contributions,
  });

  Map<String, dynamic> toMap() => {
    'base_score': baseScore,
    'vital_penalty': vitalPenalty,
    'total_score': totalScore,
    'score_band': scoreBand,
    'risk_level': riskLevel,
    'contributions': contributions.map((c) => c.toMap()).toList(),
  };
}

class ScoreContribution {
  final String source;   // question_id or vital key
  final String type;     // 'answer' | 'vital'
  final int score;
  final String reason;

  const ScoreContribution({
    required this.source,
    required this.type,
    required this.score,
    required this.reason,
  });

  Map<String, dynamic> toMap() => {
    'source': source,
    'type': type,
    'score': score,
    'reason': reason,
  };
}

// ── Vital penalty rules (cross-module) ───────────────────────────────────────
// These add score weight for abnormal vitals regardless of module.
class _VitalPenalty {
  final String vital;
  final String operator;
  final num threshold;
  final int penalty;
  final String reason;

  const _VitalPenalty({
    required this.vital,
    required this.operator,
    required this.threshold,
    required this.penalty,
    required this.reason,
  });
}

class SeverityScoringEngine {
  static const _vitalPenalties = <_VitalPenalty>[
    // SpO2
    _VitalPenalty(vital: 'spo2', operator: 'LT', threshold: 90,  penalty: 4, reason: 'SpO2 < 90% — critical hypoxia'),
    _VitalPenalty(vital: 'spo2', operator: 'LT', threshold: 95,  penalty: 2, reason: 'SpO2 < 95% — mild hypoxia'),

    // Respiratory rate (newborn threshold)
    _VitalPenalty(vital: 'respiratory_rate', operator: 'GT', threshold: 60, penalty: 3, reason: 'RR > 60/min — tachypnoea (newborn)'),
    _VitalPenalty(vital: 'respiratory_rate', operator: 'GT', threshold: 50, penalty: 2, reason: 'RR > 50/min — tachypnoea (infant/child)'),

    // Temperature
    _VitalPenalty(vital: 'temperature_c', operator: 'GT', threshold: 38.5, penalty: 3, reason: 'Temp > 38.5°C — high fever'),
    _VitalPenalty(vital: 'temperature_c', operator: 'GT', threshold: 37.5, penalty: 1, reason: 'Temp > 37.5°C — low-grade fever'),

    // Blood pressure
    _VitalPenalty(vital: 'systolic_bp',  operator: 'GTE', threshold: 160, penalty: 4, reason: 'Systolic BP ≥ 160 — severe hypertension'),
    _VitalPenalty(vital: 'systolic_bp',  operator: 'GTE', threshold: 140, penalty: 2, reason: 'Systolic BP ≥ 140 — hypertension'),
    _VitalPenalty(vital: 'diastolic_bp', operator: 'GTE', threshold: 110, penalty: 3, reason: 'Diastolic BP ≥ 110 — severe hypertension'),
    _VitalPenalty(vital: 'diastolic_bp', operator: 'GTE', threshold: 90,  penalty: 2, reason: 'Diastolic BP ≥ 90 — hypertension'),

    // Haemoglobin
    _VitalPenalty(vital: 'haemoglobin', operator: 'LT', threshold: 7,  penalty: 4, reason: 'Hb < 7 g/dL — severe anaemia'),
    _VitalPenalty(vital: 'haemoglobin', operator: 'LT', threshold: 10, penalty: 2, reason: 'Hb < 10 g/dL — moderate anaemia'),

    // MUAC
    _VitalPenalty(vital: 'muac_cm', operator: 'LT', threshold: 11.5, penalty: 4, reason: 'MUAC < 11.5 cm — SAM'),
    _VitalPenalty(vital: 'muac_cm', operator: 'LT', threshold: 12.5, penalty: 2, reason: 'MUAC < 12.5 cm — MAM'),
  ];

  /// Computes severity score from:
  /// 1. Answer-based score_rules from the module (already computed in Layer 6)
  /// 2. Vital penalty rules (cross-module, computed here)
  ///
  /// [baseScore]        — riskScore from Layer 6 RuleEngineResult
  /// [vitals]           — raw vitals map
  /// [scoreThresholds]  — module thresholds from EngineModule
  SeverityResult compute({
    required int baseScore,
    required Map<String, dynamic> vitals,
    required Map<String, List<int>> scoreThresholds,
    required List<ScoreRule> scoreRules,
    required Map<String, dynamic> answers,
  }) {
    final contributions = <ScoreContribution>[];

    // ── Answer contributions (re-derive for audit trail) ──────────────────────
    int recomputedBase = 0;
    for (final sr in scoreRules) {
      final answer = answers[sr.condition];
      if (answer == true || answer == 'true') {
        recomputedBase += sr.score;
        contributions.add(ScoreContribution(
          source: sr.condition,
          type: 'answer',
          score: sr.score,
          reason: 'Answer "${sr.condition}" = true → +${sr.score}',
        ));
      }
    }

    // ── Vital penalties ───────────────────────────────────────────────────────
    // Gap D fix: use a map of vital→highestPenalty so only the single highest
    // penalty per vital is counted. The old Set approach added the vital key
    // before calling _shouldReplace, making the contains-check always true and
    // silently dropping every subsequent (higher) penalty for the same vital.
    int vitalPenalty = 0;
    final highestApplied = <String, int>{}; // vital key → highest penalty so far

    for (final vp in _vitalPenalties) {
      final v = vitals[vp.vital];
      if (v == null) continue;
      final num vNum = v as num;

      bool triggered = false;
      switch (vp.operator) {
        case 'LT':  triggered = vNum < vp.threshold; break;
        case 'GT':  triggered = vNum > vp.threshold; break;
        case 'GTE': triggered = vNum >= vp.threshold; break;
        case 'LTE': triggered = vNum <= vp.threshold; break;
      }
      if (!triggered) continue;

      final prev = highestApplied[vp.vital];
      if (prev == null) {
        highestApplied[vp.vital] = vp.penalty;
        vitalPenalty += vp.penalty;
        contributions.add(ScoreContribution(
          source: vp.vital, type: 'vital', score: vp.penalty, reason: vp.reason,
        ));
      } else if (vp.penalty > prev) {
        // Replace with higher penalty — adjust running total by delta only
        highestApplied[vp.vital] = vp.penalty;
        vitalPenalty += vp.penalty - prev;
        final idx = contributions.lastIndexWhere(
            (c) => c.source == vp.vital && c.type == 'vital');
        if (idx != -1) {
          contributions[idx] = ScoreContribution(
            source: vp.vital, type: 'vital', score: vp.penalty, reason: vp.reason,
          );
        }
      }
      // Lower or equal penalty for same vital — skip
    }

    final totalScore = recomputedBase + vitalPenalty;
    final scoreBand  = _bandFromScore(totalScore, scoreThresholds);
    final riskLevel  = _riskLevel(totalScore, scoreThresholds);

    return SeverityResult(
      baseScore: recomputedBase,
      vitalPenalty: vitalPenalty,
      totalScore: totalScore,
      scoreBand: scoreBand,
      riskLevel: riskLevel,
      contributions: contributions,
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  String _bandFromScore(int score, Map<String, List<int>> thresholds) {
    final red    = thresholds['RED'];
    final yellow = thresholds['YELLOW'];
    if (red != null && red.length == 2 && score >= red[0] && score <= red[1]) return 'RED';
    if (yellow != null && yellow.length == 2 && score >= yellow[0] && score <= yellow[1]) return 'YELLOW';
    return 'GREEN';
  }

  String _riskLevel(int score, Map<String, List<int>> thresholds) {
    final red    = thresholds['RED'];
    final yellow = thresholds['YELLOW'];
    if (red != null && red.length == 2 && score >= red[0]) {
      return score >= red[0] + 4 ? 'CRITICAL' : 'HIGH';
    }
    if (yellow != null && yellow.length == 2 && score >= yellow[0]) return 'MODERATE';
    return 'LOW';
  }

}
