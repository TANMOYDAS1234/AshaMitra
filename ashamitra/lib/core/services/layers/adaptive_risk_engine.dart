// ─────────────────────────────────────────────────────────────────────────────
// Layer 8 — Adaptive Risk Engine
// Adjusts the provisional band from Layer 6 using:
//   A. Patient demographics (age, weight, sex)
//   B. Prior visit history from SQLite (previous RED band, HRP flag, missed ANC)
//   C. Missing vital gaps from Layer 4 (conservative escalation)
//   D. Severity score from Layer 7 (score-driven escalation)
//
// Rules:
//   - Can escalate GREEN → YELLOW, GREEN → RED, YELLOW → RED
//   - Can NEVER downgrade RED (red_lock is permanent)
//   - Every adjustment is recorded in AdaptiveAdjustment for audit
// ─────────────────────────────────────────────────────────────────────────────

import 'required_vital_checker.dart';
import 'severity_scoring_engine.dart';

// ── Prior visit history (from SQLite / DecisionTraceService) ─────────────────
class PriorVisitHistory {
  final int totalVisits;
  final int redBandCount;       // number of prior RED outcomes
  final int yellowBandCount;
  final bool hrpFlagged;        // High Risk Pregnancy flag
  final int missedAncCount;     // number of missed ANC visits
  final String? lastBand;       // most recent band
  final DateTime? lastVisitDate;

  const PriorVisitHistory({
    this.totalVisits = 0,
    this.redBandCount = 0,
    this.yellowBandCount = 0,
    this.hrpFlagged = false,
    this.missedAncCount = 0,
    this.lastBand,
    this.lastVisitDate,
  });

  factory PriorVisitHistory.empty() => const PriorVisitHistory();
}

// ── Adaptive adjustment record ────────────────────────────────────────────────
class AdaptiveAdjustment {
  final String code;
  final String reason;
  final String fromBand;
  final String toBand;
  final String source; // 'demographics' | 'history' | 'vital_gap' | 'score'

  const AdaptiveAdjustment({
    required this.code,
    required this.reason,
    required this.fromBand,
    required this.toBand,
    required this.source,
  });

  Map<String, dynamic> toMap() => {
    'code': code,
    'reason': reason,
    'from_band': fromBand,
    'to_band': toBand,
    'source': source,
  };
}

// ── Adaptive risk result ──────────────────────────────────────────────────────
class AdaptiveRiskResult {
  final String adjustedBand;
  final bool escalated;
  final List<AdaptiveAdjustment> adjustments;

  const AdaptiveRiskResult({
    required this.adjustedBand,
    required this.escalated,
    required this.adjustments,
  });

  factory AdaptiveRiskResult.unchanged(String band) => AdaptiveRiskResult(
        adjustedBand: band,
        escalated: false,
        adjustments: const [],
      );
}

// ── Patient demographics ──────────────────────────────────────────────────────
class PatientDemographics {
  final int? ageDays;
  final int? ageMonths;
  final int? ageYears;
  final String? sex;
  final double? weightKg;

  const PatientDemographics({
    this.ageDays,
    this.ageMonths,
    this.ageYears,
    this.sex,
    this.weightKg,
  });

  factory PatientDemographics.empty() => const PatientDemographics();

  int? get totalDays {
    if (ageDays != null) return ageDays;
    if (ageMonths != null) return (ageMonths! * 30.44).round();
    if (ageYears != null) return (ageYears! * 365.25).round();
    return null;
  }
}

// ── Adaptive Risk Engine ──────────────────────────────────────────────────────
class AdaptiveRiskEngine {
  /// Adjusts [provisionalBand] based on demographics, history, vital gaps,
  /// and severity score.
  ///
  /// Never downgrades RED. Returns [AdaptiveRiskResult] with full audit trail.
  AdaptiveRiskResult adjust({
    required String moduleId,
    required String provisionalBand,
    required bool redLock,
    required PatientDemographics demographics,
    required PriorVisitHistory history,
    required VitalCheckResult vitalCheck,
    required SeverityResult severity,
  }) {
    // RED is permanent — no adjustment possible
    if (redLock) return AdaptiveRiskResult.unchanged('RED');

    String band = provisionalBand;
    final adjustments = <AdaptiveAdjustment>[];

    // ── A. Demographics ───────────────────────────────────────────────────────
    band = _applyDemographics(
      band: band,
      moduleId: moduleId,
      demographics: demographics,
      adjustments: adjustments,
    );

    // ── B. Prior visit history ────────────────────────────────────────────────
    band = _applyHistory(
      band: band,
      moduleId: moduleId,
      history: history,
      adjustments: adjustments,
    );

    // ── C. Missing vital gaps (conservative escalation) ───────────────────────
    band = _applyVitalGaps(
      band: band,
      vitalCheck: vitalCheck,
      adjustments: adjustments,
    );

    // ── D. Severity score escalation ──────────────────────────────────────────
    band = _applyScoreEscalation(
      band: band,
      severity: severity,
      adjustments: adjustments,
    );

    return AdaptiveRiskResult(
      adjustedBand: band,
      escalated: band != provisionalBand,
      adjustments: adjustments,
    );
  }

  // ── A. Demographics ───────────────────────────────────────────────────────

  String _applyDemographics({
    required String band,
    required String moduleId,
    required PatientDemographics demographics,
    required List<AdaptiveAdjustment> adjustments,
  }) {
    final days = demographics.totalDays;

    // Newborn < 7 days: any YELLOW → RED (first week is highest risk)
    if (moduleId == 'newborn' && days != null && days < 7 && band == 'YELLOW') {
      adjustments.add(AdaptiveAdjustment(
        code: 'ADAPT_D_001',
        reason: 'Newborn age < 7 days — first week highest risk. YELLOW escalated to RED.',
        fromBand: 'YELLOW',
        toBand: 'RED',
        source: 'demographics',
      ));
      return 'RED';
    }

    // Newborn weight < 2 kg: escalate GREEN → YELLOW
    if (moduleId == 'newborn' &&
        demographics.weightKg != null &&
        demographics.weightKg! < 2.0 &&
        band == 'GREEN') {
      adjustments.add(AdaptiveAdjustment(
        code: 'ADAPT_D_002',
        reason: 'Birth weight < 2 kg — low birth weight. GREEN escalated to YELLOW.',
        fromBand: 'GREEN',
        toBand: 'YELLOW',
        source: 'demographics',
      ));
      return 'YELLOW';
    }

    // Child < 3 months: any YELLOW → RED (infants < 3 months are high risk)
    if (moduleId == 'child' && days != null && days < 91 && band == 'YELLOW') {
      adjustments.add(AdaptiveAdjustment(
        code: 'ADAPT_D_003',
        reason: 'Infant age < 3 months — high vulnerability. YELLOW escalated to RED.',
        fromBand: 'YELLOW',
        toBand: 'RED',
        source: 'demographics',
      ));
      return 'RED';
    }

    // Pregnancy: age < 18 or > 35 years → escalate GREEN → YELLOW
    if (moduleId == 'pregnancy' && demographics.ageYears != null) {
      final age = demographics.ageYears!;
      if ((age < 18 || age > 35) && band == 'GREEN') {
        adjustments.add(AdaptiveAdjustment(
          code: 'ADAPT_D_004',
          reason: 'Maternal age ${age < 18 ? "< 18" : "> 35"} years — '
              'high-risk pregnancy age group. GREEN escalated to YELLOW.',
          fromBand: 'GREEN',
          toBand: 'YELLOW',
          source: 'demographics',
        ));
        return 'YELLOW';
      }
    }

    return band;
  }

  // ── B. Prior visit history ────────────────────────────────────────────────

  String _applyHistory({
    required String band,
    required String moduleId,
    required PriorVisitHistory history,
    required List<AdaptiveAdjustment> adjustments,
  }) {
    // Prior RED band in same module → escalate GREEN → YELLOW
    if (history.redBandCount > 0 && band == 'GREEN') {
      adjustments.add(AdaptiveAdjustment(
        code: 'ADAPT_H_001',
        reason: 'Patient had ${history.redBandCount} prior RED outcome(s) in this module. '
            'GREEN escalated to YELLOW for closer monitoring.',
        fromBand: 'GREEN',
        toBand: 'YELLOW',
        source: 'history',
      ));
      return 'YELLOW';
    }

    // HRP flagged → escalate GREEN → YELLOW for pregnancy/delivery_pnc
    if (history.hrpFlagged &&
        (moduleId == 'pregnancy' || moduleId == 'delivery_pnc') &&
        band == 'GREEN') {
      adjustments.add(AdaptiveAdjustment(
        code: 'ADAPT_H_002',
        reason: 'Patient is flagged as High Risk Pregnancy (HRP). '
            'GREEN escalated to YELLOW.',
        fromBand: 'GREEN',
        toBand: 'YELLOW',
        source: 'history',
      ));
      return 'YELLOW';
    }

    // ≥ 2 missed ANC visits → escalate GREEN → YELLOW
    if (moduleId == 'pregnancy' && history.missedAncCount >= 2 && band == 'GREEN') {
      adjustments.add(AdaptiveAdjustment(
        code: 'ADAPT_H_003',
        reason: '${history.missedAncCount} missed ANC visits on record. '
            'GREEN escalated to YELLOW.',
        fromBand: 'GREEN',
        toBand: 'YELLOW',
        source: 'history',
      ));
      return 'YELLOW';
    }

    // Last visit was RED and < 48 hours ago → escalate YELLOW → RED
    if (history.lastBand == 'RED' && history.lastVisitDate != null) {
      final hoursSinceLast =
          DateTime.now().difference(history.lastVisitDate!).inHours;
      if (hoursSinceLast < 48 && band == 'YELLOW') {
        adjustments.add(AdaptiveAdjustment(
          code: 'ADAPT_H_004',
          reason: 'Last visit was RED ${hoursSinceLast}h ago — '
              'patient not yet recovered. YELLOW escalated to RED.',
          fromBand: 'YELLOW',
          toBand: 'RED',
          source: 'history',
        ));
        return 'RED';
      }
    }

    return band;
  }

  // ── C. Missing vital gaps ─────────────────────────────────────────────────

  String _applyVitalGaps({
    required String band,
    required VitalCheckResult vitalCheck,
    required List<AdaptiveAdjustment> adjustments,
  }) {
    // If RED-tier vitals are missing and band is GREEN → escalate to YELLOW
    // (conservative: we cannot confirm safety without the vital)
    if (vitalCheck.hasBlockingGaps && band == 'GREEN') {
      final missingKeys = vitalCheck.missing
          .where((m) => m.bandIfMissing == 'RED')
          .map((m) => m.vitalKey)
          .join(', ');
      adjustments.add(AdaptiveAdjustment(
        code: 'ADAPT_V_001',
        reason: 'RED-tier vitals not recorded: $missingKeys. '
            'Cannot confirm GREEN safety. Escalated to YELLOW.',
        fromBand: 'GREEN',
        toBand: 'YELLOW',
        source: 'vital_gap',
      ));
      return 'YELLOW';
    }

    // If RED-tier vitals are missing and band is YELLOW → escalate to RED
    if (vitalCheck.hasBlockingGaps && band == 'YELLOW') {
      final missingKeys = vitalCheck.missing
          .where((m) => m.bandIfMissing == 'RED')
          .map((m) => m.vitalKey)
          .join(', ');
      adjustments.add(AdaptiveAdjustment(
        code: 'ADAPT_V_002',
        reason: 'RED-tier vitals not recorded: $missingKeys. '
            'Cannot rule out emergency. YELLOW escalated to RED.',
        fromBand: 'YELLOW',
        toBand: 'RED',
        source: 'vital_gap',
      ));
      return 'RED';
    }

    return band;
  }

  // ── D. Severity score escalation ─────────────────────────────────────────

  String _applyScoreEscalation({
    required String band,
    required SeverityResult severity,
    required List<AdaptiveAdjustment> adjustments,
  }) {
    // Score band is RED but provisional band is YELLOW → escalate
    if (severity.scoreBand == 'RED' && band == 'YELLOW') {
      adjustments.add(AdaptiveAdjustment(
        code: 'ADAPT_S_001',
        reason: 'Severity score ${severity.totalScore} (${severity.riskLevel}) '
            'exceeds RED threshold. YELLOW escalated to RED.',
        fromBand: 'YELLOW',
        toBand: 'RED',
        source: 'score',
      ));
      return 'RED';
    }

    // Score band is YELLOW but provisional band is GREEN → escalate
    if (severity.scoreBand == 'YELLOW' && band == 'GREEN') {
      adjustments.add(AdaptiveAdjustment(
        code: 'ADAPT_S_002',
        reason: 'Severity score ${severity.totalScore} (${severity.riskLevel}) '
            'exceeds YELLOW threshold. GREEN escalated to YELLOW.',
        fromBand: 'GREEN',
        toBand: 'YELLOW',
        source: 'score',
      ));
      return 'YELLOW';
    }

    return band;
  }
}
