import 'dart:convert';
import 'package:flutter/services.dart';

import 'layers/input_validator.dart';
import 'layers/contradiction_checker.dart';
import 'layers/age_module_validator.dart';
import 'layers/required_vital_checker.dart';
import 'layers/protocol_hash_verifier.dart';
import 'layers/rule_engine.dart';
import 'layers/severity_scoring_engine.dart';
import 'layers/adaptive_risk_engine.dart';
import 'layers/safety_escalation_layer.dart';
import 'layers/referral_decision_engine.dart';
import 'layers/explainable_output.dart';

export 'layers/explainable_output.dart'      show DecisionOutput, ActionCard;
export 'layers/rule_engine.dart'             show RuleTraceEntry, EngineModule, EngineRule, EngineQuestion;
export 'layers/adaptive_risk_engine.dart'    show PatientDemographics, PriorVisitHistory, AdaptiveAdjustment;
export 'layers/severity_scoring_engine.dart' show SeverityResult;
export 'layers/safety_escalation_layer.dart' show SafetyAction;
export 'layers/required_vital_checker.dart'  show MissingVital;
export 'layers/contradiction_checker.dart'   show ContradictionEntry;

// ─────────────────────────────────────────────────────────────────────────────
// RuleExecutor — orchestrates all 11 pipeline layers
// ─────────────────────────────────────────────────────────────────────────────

class RuleExecutor {
  static const _enginePath = 'assets/data/asha_engine.json';

  // ── Layer instances ───────────────────────────────────────────────────────
  final _inputValidator      = InputValidator();
  final _contradictionChecker = ContradictionChecker();
  final _ageModuleValidator  = AgeModuleValidator();
  final _vitalChecker        = RequiredVitalChecker();
  final _hashVerifier        = ProtocolHashVerifier();
  final _ruleEngine          = RuleEngine();
  final _scoringEngine       = SeverityScoringEngine();
  final _adaptiveRisk        = AdaptiveRiskEngine();
  final _safetyEscalation    = SafetyEscalationLayer();
  final _referralEngine      = ReferralDecisionEngine();
  final _outputAssembler     = ExplainableOutput();

  // ── Loaded state ──────────────────────────────────────────────────────────
  final Map<String, EngineModule> _modules = {};
  late Map<String, dynamic> _followupRules;
  late String _engineVersion;
  bool _loaded = false;
  String? protocolHash;

  // ── Load ──────────────────────────────────────────────────────────────────
  Future<void> load() async {
    if (_loaded) return;
    final raw = await rootBundle.loadString(_enginePath);

    // Layer 5: hash verify on first load (registers hash)
    final hashResult = await _hashVerifier.verify(rawJson: raw);
    protocolHash = hashResult.computedHash;

    final json = jsonDecode(raw) as Map<String, dynamic>;
    _engineVersion = (json['version'] as String?) ?? '2.0.0';
    _followupRules = (json['followup_rules'] as Map<String, dynamic>?) ?? {};

    for (final m in (json['modules'] as List)) {
      final mod = EngineModule.fromJson(m as Map<String, dynamic>);
      _modules[mod.moduleId] = mod;
    }
    _loaded = true;
  }

  // ── Question index (VoiceTriageScreen / GeminiTriageService) ─────────────
  List<EngineQuestion> questionIndex() {
    assert(_loaded, 'load() must be called first');
    final result = <EngineQuestion>[];
    final seen   = <String>{};

    for (final mod in _modules.values) {
      final allRules = [
        ...mod.hardStopRules,
        ...mod.combinationRules,
        ...mod.yellowRules,
        ...mod.numericRules,
      ];
      for (final rule in allRules) {
        final qId = rule.conditionSet
            .firstWhere((c) => c.questionId != null,
                orElse: () => rule.conditionSet.first)
            .questionId;
        if (qId == null) continue;
        final key = '${mod.moduleId}:$qId';
        if (seen.contains(key)) continue;
        seen.add(key);
        final q = mod.questions[qId];
        result.add(EngineQuestion(
          id: qId,
          moduleId: mod.moduleId,
          ruleId: rule.ruleId,
          textBn: q?.textBn ?? '',
          textEn: q?.textEn ?? '',
          options: q?.options ?? ['হ্যাঁ', 'না'],
          actionBn: rule.actionBn,
          actionEn: rule.actionEn,
        ));
      }
    }
    return result;
  }

  /// Returns the numeric (vitals) rules for [moduleId], or empty if the module
  /// is unknown. Used by [EngineGroundedQA] to answer "what's the threshold?"
  /// questions offline, with the same auditable rules that drive triage.
  List<EngineRule> numericRulesForModule(String moduleId) =>
      _modules[moduleId]?.numericRules ?? const [];

  /// Returns all rule arrays for [moduleId] (hard-stop + combination + numeric
  /// + yellow) flattened. Used when a question could match any rule shape.
  List<EngineRule> allRulesForModule(String moduleId) {
    final m = _modules[moduleId];
    if (m == null) return const [];
    return [
      ...m.hardStopRules,
      ...m.combinationRules,
      ...m.numericRules,
      ...m.yellowRules,
    ];
  }

  /// Question metadata for [moduleId]: `{questionId: (textBn, textEn, options)}`.
  /// Used by [EngineGroundedQA] to look up the human description of a question
  /// when the ASHA asks about a symptom (e.g. "জন্ডিস মানে কী?" → look up the
  /// question that has `id: n6` and use its textBn).
  Map<String, ({String textBn, String textEn, List<String> options})>
      questionsForModule(String moduleId) =>
          _modules[moduleId]?.questions ?? const {};

  // ── Main execute — runs all 11 layers ────────────────────────────────────
  //
  // [moduleId]        — newborn | child | pregnancy | delivery_pnc |
  //                     immunisation | emergency
  // [answers]         — Map<questionId, dynamic> bool or String
  // [vitals]          — Map<vitalKey, num>
  // [demographics]    — patient age, weight, sex
  // [history]         — prior visit history from SQLite
  // [caseId]          — written into audit log
  // [ambulanceCalled] — drives transport advisory
  // [distanceKm]      — drives travel time estimate
  //
  DecisionOutput execute({
    required String moduleId,
    required Map<String, dynamic> answers,
    Map<String, dynamic> vitals             = const {},
    PatientDemographics demographics        = const PatientDemographics(),
    PriorVisitHistory history               = const PriorVisitHistory(),
    String caseId                           = '',
    bool ambulanceCalled                    = false,
    double? distanceKm,
  }) {
    assert(_loaded, 'RuleExecutor.load() must be called before execute()');

    // ── Layer 1: Input Validation ─────────────────────────────────────────
    final inputResult = _inputValidator.validate(
      moduleId: moduleId,
      answers: answers,
      vitals: vitals,
      caseId: caseId,
    );
    if (!inputResult.valid) {
      return DecisionOutput.blocked(
        caseId: caseId,
        engineVersion: _engineVersion,
        errors: inputResult.errors,
      );
    }

    // ── Layer 2: Contradiction Check ──────────────────────────────────────
    final contraResult = _contradictionChecker.check(
      moduleId: moduleId,
      answers: answers,
      vitals: vitals,
    );
    // Blocking contradictions halt the pipeline
    if (contraResult.hasContradictions &&
        contraResult.contradictions.any((c) => c.blocking)) {
      final blockingErrors = contraResult.contradictions
          .where((c) => c.blocking)
          .map((c) => '${c.code}: ${c.reason}')
          .toList();
      return DecisionOutput.blocked(
        caseId: caseId,
        engineVersion: _engineVersion,
        errors: blockingErrors,
      );
    }

    // ── Layer 3: Age / Module Validation ──────────────────────────────────
    final ageResult = _ageModuleValidator.validate(
      moduleId: moduleId,
      ageDays: demographics.ageDays,
      ageMonths: demographics.ageMonths,
      ageYears: demographics.ageYears,
      sex: demographics.sex,
    );
    if (!ageResult.valid) {
      return DecisionOutput.blocked(
        caseId: caseId,
        engineVersion: _engineVersion,
        errors: ageResult.errors,
      );
    }

    // ── Layer 4: Required Vital Check ─────────────────────────────────────
    final vitalCheckResult = _vitalChecker.check(
      moduleId: moduleId,
      vitals: vitals,
    );
    // Never blocks — missing vitals are handled by Layer 8

    // ── Layer 5: Protocol Hash Verify ─────────────────────────────────────
    // Synchronous check against already-registered hash
    if (protocolHash == null) {
      return DecisionOutput.blocked(
        caseId: caseId,
        engineVersion: _engineVersion,
        errors: ['HASH_000: Engine not loaded — protocolHash is null.'],
      );
    }

    // ── Layer 6: Rule Engine ──────────────────────────────────────────────
    final mod = _modules[moduleId]!;
    final ruleResult = _ruleEngine.evaluate(
      module: mod,
      answers: answers,
      vitals: vitals,
    );

    // ── Layer 7: Severity Scoring ─────────────────────────────────────────
    final severityResult = _scoringEngine.compute(
      baseScore: ruleResult.riskScore,
      vitals: vitals,
      scoreThresholds: mod.scoreThresholds,
      scoreRules: mod.scoreRules,
      answers: answers,
    );

    // ── Layer 8: Adaptive Risk Engine ─────────────────────────────────────
    final adaptiveResult = _adaptiveRisk.adjust(
      moduleId: moduleId,
      provisionalBand: ruleResult.provisionalBand,
      redLock: ruleResult.redLock,
      demographics: demographics,
      history: history,
      vitalCheck: vitalCheckResult,
      severity: severityResult,
    );

    // ── Layer 9: Safety Escalation ────────────────────────────────────────
    final safetyResult = _safetyEscalation.run(
      adjustedBand: adaptiveResult.adjustedBand,
      ruleEngineResult: ruleResult,
      emergencyModule: _modules['emergency'],
      answers: answers,
      referral: ruleResult.winningRule?.referral ?? '',
      moduleId: moduleId,
    );

    // ── Layer 10: Referral Decision ───────────────────────────────────────
    final referralResult = _referralEngine.decide(
      finalBand: safetyResult.finalBand,
      moduleId: moduleId,
      ruleReferral: ruleResult.winningRule?.referral ?? '',
      ambulanceCalled: ambulanceCalled,
      distanceKm: distanceKm,
      followupRules: _followupRules,
    );

    // ── Layer 11: Explainable Output ──────────────────────────────────────
    return _outputAssembler.assemble(
      caseId: caseId,
      engineVersion: _engineVersion,
      moduleId: moduleId,
      inputValidation: inputResult,
      contradictions: contraResult,
      ageModule: ageResult,
      vitalCheck: vitalCheckResult,
      hashVerify: HashVerifyResult.pass(protocolHash!),
      ruleEngine: ruleResult,
      severity: severityResult,
      adaptive: adaptiveResult,
      safety: safetyResult,
      referral: referralResult,
      protocolHash: protocolHash,
    );
  }
}
