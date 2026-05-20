// ─────────────────────────────────────────────────────────────────────────────
// Layer 11 — Explainable Output
// Assembles the final DecisionOutput from all layer results.
// Builds the Bengali action card with structured reasoning.
// Produces the complete audit trace for MDSR.
// ─────────────────────────────────────────────────────────────────────────────

import 'rule_engine.dart';
import 'severity_scoring_engine.dart';
import 'adaptive_risk_engine.dart';
import 'safety_escalation_layer.dart';
import 'referral_decision_engine.dart';
import 'input_validator.dart';
import 'contradiction_checker.dart';
import 'age_module_validator.dart';
import 'required_vital_checker.dart';
import 'protocol_hash_verifier.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Final output contract — matches decision_output.json
// ─────────────────────────────────────────────────────────────────────────────

class DecisionOutput {
  // ── Identity ──────────────────────────────────────────────────────────────
  final String caseId;
  final String engineVersion;
  final String evaluatedAt;

  // ── Engine result ─────────────────────────────────────────────────────────
  final String finalBand;
  final bool redLock;
  final List<String> triggeredRules;
  final int riskScore;
  final String riskLevel;

  // ── Clinical summary ──────────────────────────────────────────────────────
  final List<String> suspectedConditions;
  final List<String> dangerSigns;

  // ── Action card (Bengali + English) ──────────────────────────────────────
  final ActionCard actionCard;

  // ── Referral ──────────────────────────────────────────────────────────────
  final String facilityType;
  final String urgency;
  final int maxDelayMinutes;

  // ── Transport ─────────────────────────────────────────────────────────────
  final bool ambulanceCalled;
  final String transportAction;
  final double? distanceToFruKm;
  final int estimatedTravelMinutes;

  // ── Follow-up ─────────────────────────────────────────────────────────────
  final bool followupRequired;
  final int recheckAfterHours;
  final String followupTrigger;

  // ── Safety ────────────────────────────────────────────────────────────────
  final bool signOffPending;
  final List<String> safetyFlags;
  final List<SafetyAction> safetyActions;

  // ── Adaptive adjustments ──────────────────────────────────────────────────
  final List<AdaptiveAdjustment> adaptiveAdjustments;

  // ── Severity ──────────────────────────────────────────────────────────────
  final SeverityResult severity;

  // ── Validation ────────────────────────────────────────────────────────────
  final List<String> validationWarnings;
  final List<ContradictionEntry> contradictions;
  final List<MissingVital> missingVitals;

  // ── Audit ─────────────────────────────────────────────────────────────────
  final String? protocolHash;
  final List<RuleTraceEntry> trace;

  // ── Pipeline error (if any layer blocked) ────────────────────────────────
  final bool pipelineBlocked;
  final List<String> pipelineErrors;

  // ── Backward-compat getters for existing screens ─────────────────────────
  String get band           => finalBand;
  String get actionBn       => actionCard.summaryBn;
  String get actionEn       => actionCard.summaryEn;
  String get referral       => facilityType;
  bool   get hardStop       => redLock;
  bool   get invariantLocked => redLock;
  String get ruleId         => triggeredRules.isNotEmpty ? triggeredRules.first : '';
  List<String> get recommendedActions => actionCard.steps;

  const DecisionOutput({
    required this.caseId,
    required this.engineVersion,
    required this.evaluatedAt,
    required this.finalBand,
    required this.redLock,
    required this.triggeredRules,
    required this.riskScore,
    required this.riskLevel,
    required this.suspectedConditions,
    required this.dangerSigns,
    required this.actionCard,
    required this.facilityType,
    required this.urgency,
    required this.maxDelayMinutes,
    required this.ambulanceCalled,
    required this.transportAction,
    required this.distanceToFruKm,
    required this.estimatedTravelMinutes,
    required this.followupRequired,
    required this.recheckAfterHours,
    required this.followupTrigger,
    required this.signOffPending,
    required this.safetyFlags,
    required this.safetyActions,
    required this.adaptiveAdjustments,
    required this.severity,
    required this.validationWarnings,
    required this.contradictions,
    required this.missingVitals,
    required this.protocolHash,
    required this.trace,
    required this.pipelineBlocked,
    required this.pipelineErrors,
  });

  /// Blocked output — returned when any layer issues a hard block.
  factory DecisionOutput.blocked({
    required String caseId,
    required String engineVersion,
    required List<String> errors,
  }) =>
      DecisionOutput(
        caseId: caseId,
        engineVersion: engineVersion,
        evaluatedAt: DateTime.now().toIso8601String(),
        finalBand: 'UNKNOWN',
        redLock: false,
        triggeredRules: const [],
        riskScore: 0,
        riskLevel: 'UNKNOWN',
        suspectedConditions: const [],
        dangerSigns: const [],
        actionCard: ActionCard.blocked(errors),
        facilityType: '',
        urgency: '',
        maxDelayMinutes: 0,
        ambulanceCalled: false,
        transportAction: '',
        distanceToFruKm: null,
        estimatedTravelMinutes: 0,
        followupRequired: false,
        recheckAfterHours: 0,
        followupTrigger: '',
        signOffPending: false,
        safetyFlags: const [],
        safetyActions: const [],
        adaptiveAdjustments: const [],
        severity: SeverityResult(
          baseScore: 0,
          vitalPenalty: 0,
          totalScore: 0,
          scoreBand: 'UNKNOWN',
          riskLevel: 'UNKNOWN',
          contributions: const [],
        ),
        validationWarnings: const [],
        contradictions: const [],
        missingVitals: const [],
        protocolHash: null,
        trace: const [],
        pipelineBlocked: true,
        pipelineErrors: errors,
      );

  Map<String, dynamic> toJson() => {
    'case_id': caseId,
    'engine_version': engineVersion,
    'evaluated_at': evaluatedAt,
    'engine_result': {
      'final_band': finalBand,
      'red_lock': redLock,
      'triggered_rules': triggeredRules,
      'risk_score': riskScore,
      'risk_level': riskLevel,
    },
    'clinical_summary': {
      'suspected_conditions': suspectedConditions,
      'danger_signs': dangerSigns,
    },
    'action_card': actionCard.toMap(),
    'referral': {
      'facility_type': facilityType,
      'urgency': urgency,
      'max_delay_minutes': maxDelayMinutes,
    },
    'transport_advisory': {
      'ambulance_called': ambulanceCalled,
      'action_required': transportAction,
      'distance_to_fru_km': distanceToFruKm,
      'estimated_travel_minutes': estimatedTravelMinutes,
    },
    'followup': {
      'required': followupRequired,
      'recheck_after_hours': recheckAfterHours,
      'trigger': followupTrigger,
    },
    'safety': {
      'sign_off_pending': signOffPending,
      'flags': safetyFlags,
      'actions': safetyActions.map((a) => a.toMap()).toList(),
    },
    'adaptive_adjustments': adaptiveAdjustments.map((a) => a.toMap()).toList(),
    'severity': severity.toMap(),
    'validation': {
      'warnings': validationWarnings,
      'contradictions': contradictions.map((c) => c.toMap()).toList(),
      'missing_vitals': missingVitals.map((v) => v.toMap()).toList(),
    },
    'audit_log': {
      'evaluated_at': evaluatedAt,
      'engine_version': engineVersion,
      'protocol_hash': protocolHash,
      'trace': trace.map((t) => t.toMap()).toList(),
    },
    'pipeline_blocked': pipelineBlocked,
    'pipeline_errors': pipelineErrors,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Action card — structured Bengali + English output
// ─────────────────────────────────────────────────────────────────────────────

class ActionCard {
  final String band;
  final String bandLabelBn;
  final String summaryBn;
  final String summaryEn;
  final List<String> steps;           // ordered action steps (Bengali)
  final List<String> dangerSignsBn;   // danger signs in Bengali
  final List<String> suspectedBn;     // suspected conditions in Bengali
  final String referralBn;
  final String followupBn;
  final bool signOffPending;

  const ActionCard({
    required this.band,
    required this.bandLabelBn,
    required this.summaryBn,
    required this.summaryEn,
    required this.steps,
    required this.dangerSignsBn,
    required this.suspectedBn,
    required this.referralBn,
    required this.followupBn,
    required this.signOffPending,
  });

  factory ActionCard.blocked(List<String> errors) => ActionCard(
        band: 'UNKNOWN',
        bandLabelBn: 'অজানা',
        summaryBn: 'ইনপুট যাচাই ব্যর্থ হয়েছে। ট্রায়াজ সম্পন্ন করা যায়নি।',
        summaryEn: 'Input validation failed. Triage could not be completed.',
        steps: errors,
        dangerSignsBn: const [],
        suspectedBn: const [],
        referralBn: '',
        followupBn: '',
        signOffPending: false,
      );

  Map<String, dynamic> toMap() => {
    'band': band,
    'band_label_bn': bandLabelBn,
    'summary_bn': summaryBn,
    'summary_en': summaryEn,
    'steps': steps,
    'danger_signs_bn': dangerSignsBn,
    'suspected_bn': suspectedBn,
    'referral_bn': referralBn,
    'followup_bn': followupBn,
    'sign_off_pending': signOffPending,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// ExplainableOutput — assembles DecisionOutput from all layer results
// ─────────────────────────────────────────────────────────────────────────────

class ExplainableOutput {
  /// Assembles the final [DecisionOutput] from all layer results.
  DecisionOutput assemble({
    required String caseId,
    required String engineVersion,
    required String moduleId,
    required InputValidationResult inputValidation,
    required ContradictionResult contradictions,
    required AgeModuleResult ageModule,
    required VitalCheckResult vitalCheck,
    required HashVerifyResult hashVerify,
    required RuleEngineResult ruleEngine,
    required SeverityResult severity,
    required AdaptiveRiskResult adaptive,
    required SafetyEscalationResult safety,
    required ReferralResult referral,
    required String? protocolHash,
  }) {
    final finalBand = safety.finalBand;

    // ── Action card ───────────────────────────────────────────────────────────
    final actionCard = _buildActionCard(
      band: finalBand,
      moduleId: moduleId,
      ruleEngine: ruleEngine,
      referral: referral,
      safety: safety,
      adaptive: adaptive,
      vitalCheck: vitalCheck,
    );

    // ── Collect all warnings ──────────────────────────────────────────────────
    final validationWarnings = <String>[
      ...inputValidation.warnings,
      ...ageModule.warnings,
      if (hashVerify.expectedHash == null)
        'First engine load — hash registered for future verification.',
    ];

    // ── Full trace ────────────────────────────────────────────────────────────
    final trace = <RuleTraceEntry>[
      ...ruleEngine.trace,
    ];

    return DecisionOutput(
      caseId: caseId,
      engineVersion: engineVersion,
      evaluatedAt: DateTime.now().toIso8601String(),
      finalBand: finalBand,
      redLock: safety.finalBand == 'RED',
      triggeredRules: ruleEngine.triggeredRules,
      riskScore: severity.totalScore,
      riskLevel: severity.riskLevel,
      suspectedConditions: ruleEngine.suspectedConditions.toList(),
      dangerSigns: ruleEngine.dangerSigns.toList(),
      actionCard: actionCard,
      facilityType: referral.facilityType,
      urgency: referral.urgency,
      maxDelayMinutes: referral.maxDelayMinutes,
      ambulanceCalled: referral.ambulanceCalled,
      transportAction: referral.transportAction,
      distanceToFruKm: referral.distanceToFruKm,
      estimatedTravelMinutes: referral.estimatedTravelMinutes,
      followupRequired: referral.followupRequired,
      recheckAfterHours: referral.recheckAfterHours,
      followupTrigger: referral.followupTrigger,
      signOffPending: safety.signOffPending,
      safetyFlags: safety.safetyFlags,
      safetyActions: safety.actions,
      adaptiveAdjustments: adaptive.adjustments,
      severity: severity,
      validationWarnings: validationWarnings,
      contradictions: contradictions.contradictions,
      missingVitals: vitalCheck.missing,
      protocolHash: protocolHash,
      trace: trace,
      pipelineBlocked: false,
      pipelineErrors: const [],
    );
  }

  // ── Action card builder ───────────────────────────────────────────────────

  ActionCard _buildActionCard({
    required String band,
    required String moduleId,
    required RuleEngineResult ruleEngine,
    required ReferralResult referral,
    required SafetyEscalationResult safety,
    required AdaptiveRiskResult adaptive,
    required VitalCheckResult vitalCheck,
  }) {
    final (bandLabelBn, summaryBn, summaryEn) = _bandStrings(
      band: band,
      moduleId: moduleId,
      winningRule: ruleEngine.winningRule,
    );

    final dangerSignsBn = ruleEngine.dangerSigns
        .map((d) => _translateDangerSign(d))
        .toList();

    final suspectedBn = ruleEngine.suspectedConditions
        .map((s) => _translateCondition(s))
        .toList();

    // Steps = referral actions + adaptive escalation reasons + missing vital prompts
    final steps = <String>[
      ...referral.referralActions,
      if (adaptive.escalated)
        ...adaptive.adjustments.map((a) => '⚠️ ${a.reason}'),
      if (vitalCheck.hasMissing)
        ...vitalCheck.missing.map((v) => '📋 ${v.message}'),
      if (safety.signOffPending)
        '⚠️ এই নিয়মটি চূড়ান্ত অনুমোদনের অপেক্ষায় আছে। ANM/MO-এর সাথে নিশ্চিত করুন।',
    ];

    return ActionCard(
      band: band,
      bandLabelBn: bandLabelBn,
      summaryBn: summaryBn,
      summaryEn: summaryEn,
      steps: steps,
      dangerSignsBn: dangerSignsBn,
      suspectedBn: suspectedBn,
      referralBn: referral.facilityType,
      followupBn: referral.followupRequired
          ? '${referral.recheckAfterHours} ঘণ্টা পর পুনরায় পরীক্ষা করুন।'
          : 'রুটিন ফলো-আপ।',
      signOffPending: safety.signOffPending,
    );
  }

  // ── Band strings ──────────────────────────────────────────────────────────

  (String, String, String) _bandStrings({
    required String band,
    required String moduleId,
    required EngineRule? winningRule,
  }) {
    switch (band) {
      case 'RED':
        final actionBn = winningRule?.actionBn ?? '';
        return (
          '🔴 জরুরি',
          actionBn.isNotEmpty
              ? actionBn
              : 'গুরুতর বিপদচিহ্ন শনাক্ত হয়েছে। এখনই রেফার করুন।',
          winningRule?.actionEn ?? 'Critical danger signs detected. Refer immediately.',
        );
      case 'YELLOW':
        final actionBn = winningRule?.actionBn ?? '';
        return (
          '🟡 সতর্কতা',
          actionBn.isNotEmpty
              ? actionBn
              : 'কিছু বিপদচিহ্ন পাওয়া গেছে। ২৪ ঘণ্টার মধ্যে PHC-তে রেফার করুন।',
          winningRule?.actionEn ?? 'Risk signs present. Refer PHC within 24 h.',
        );
      default:
        return (
          '🟢 স্বাভাবিক',
          'কোনো বিপদচিহ্ন পাওয়া যায়নি। বাড়িতে যত্ন নিন।',
          'No danger signs found. Home care.',
        );
    }
  }

  // ── Translation maps ──────────────────────────────────────────────────────

  static const _dangerSignBn = <String, String>{
    'Poor feeding':              'খাওয়ার সমস্যা',
    'Fever':                     'জ্বর',
    'Breathing difficulty':      'শ্বাসকষ্ট',
    'Umbilical infection':       'নাভিতে সংক্রমণ',
    'Lethargy':                  'নিস্তেজতা',
    'Skin colour change':        'ত্বকের রঙ পরিবর্তন',
    'Low SpO2':                  'অক্সিজেন কম',
    'Fast breathing':            'দ্রুত শ্বাস',
    'Low birth weight':          'কম ওজন',
    'Fever > 5 days':            '৫ দিনের বেশি জ্বর',
    'Sunken eyes':               'চোখ গর্তে',
    'Dry lips':                  'ঠোঁট শুকনো',
    'Low weight for age':        'বয়সের তুলনায় কম ওজন',
    'Severe wasting':            'গুরুতর অপুষ্টি',
    'Moderate wasting':          'মাঝারি অপুষ্টি',
    'High BP':                   'উচ্চ রক্তচাপ',
    'Headache':                  'মাথাব্যথা',
    'Vaginal bleeding':          'যোনিপথে রক্তপাত',
    'Severe abdominal pain':     'তীব্র পেট ব্যথা',
    'Baby not moving':           'শিশুর নড়াচড়া নেই',
    'Blurred vision':            'ঝাপসা দৃষ্টি',
    'Dizziness':                 'মাথা ঘোরা',
    'Leg swelling':              'পা ফোলা',
    'Excessive bleeding':        'অতিরিক্ত রক্তপাত',
    'Foul discharge':            'দুর্গন্ধযুক্ত স্রাব',
    'Fever postpartum':          'প্রসব-পরবর্তী জ্বর',
    'Breast pain':               'স্তনে ব্যথা',
    'Burning urination':         'প্রস্রাবে জ্বালা',
    'Weakness':                  'দুর্বলতা',
    'Severe anaemia':            'গুরুতর রক্তাল্পতা',
    'Moderate anaemia':          'মাঝারি রক্তাল্পতা',
    'Convulsion':                'খিঁচুনি',
    'Unconscious':               'অজ্ঞান',
    'Unresponsive':              'সাড়া নেই',
  };

  static const _conditionBn = <String, String>{
    'Possible neonatal sepsis':              'সম্ভাব্য নবজাতক সেপসিস',
    'Neonatal fever / sepsis':               'নবজাতকের জ্বর / সেপসিস',
    'Respiratory distress':                  'শ্বাসকষ্ট',
    'Omphalitis':                            'নাভির সংক্রমণ',
    'Jaundice / Cyanosis':                   'জন্ডিস / সায়ানোসিস',
    'Severe PSBI':                           'গুরুতর PSBI',
    'Prolonged fever — malaria / typhoid':   'দীর্ঘস্থায়ী জ্বর — ম্যালেরিয়া/টাইফয়েড',
    'Severe dehydration':                    'গুরুতর পানিশূন্যতা',
    'Pneumonia':                             'নিউমোনিয়া',
    'Malnutrition':                          'অপুষ্টি',
    'Pre-eclampsia / Eclampsia':             'প্রি-এক্লাম্পসিয়া / এক্লাম্পসিয়া',
    'Antepartum haemorrhage':                'প্রসব-পূর্ব রক্তপাত',
    'Reduced fetal movement':                'ভ্রূণের নড়াচড়া কমেছে',
    'Imminent eclampsia':                    'আসন্ন এক্লাম্পসিয়া',
    'Postpartum haemorrhage':                'প্রসব-পরবর্তী রক্তপাত',
    'Puerperal sepsis':                      'পিউরপেরাল সেপসিস',
    'Mastitis':                              'ম্যাস্টাইটিস',
    'UTI':                                   'মূত্রনালীর সংক্রমণ',
    'Anaemia':                               'রক্তাল্পতা',
    'Haemorrhage':                           'রক্তক্ষরণ',
    'Eclampsia / Seizure':                   'এক্লাম্পসিয়া / খিঁচুনি',
    'Respiratory failure':                   'শ্বাসযন্ত্রের ব্যর্থতা',
    'Unconsciousness':                       'অচেতনতা',
  };

  String _translateDangerSign(String en) => _dangerSignBn[en] ?? en;
  String _translateCondition(String en)  => _conditionBn[en] ?? en;
}
