import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';

// ── Result returned by evaluateAnswers() ─────────────────────────────────────
class EngineResult {
  final String band;        // 'RED' | 'YELLOW' | 'GREEN'
  final String ruleId;      // rule that determined the band
  final String actionBn;    // Bengali action string
  final String actionEn;    // English action string
  final String referral;    // referral destination
  final bool hardStop;      // true if a hard-stop rule fired
  final bool invariantLocked; // true if EM-005 locked the band
  final bool signOffPending;  // true if PNC-001 or similar pending sign-off
  final List<RuleTrace> trace; // ordered evaluation trace

  const EngineResult({
    required this.band,
    required this.ruleId,
    required this.actionBn,
    required this.actionEn,
    required this.referral,
    required this.hardStop,
    required this.invariantLocked,
    required this.signOffPending,
    required this.trace,
  });
}

// ── Public question descriptor used by SymptomMapper ────────────────────────
class EngineQuestion {
  final String id;        // question_id used in condition_set (e.g. p1, n2)
  final String moduleId;
  final String ruleId;
  final String textBn;    // Bengali question text from JSON questions array
  final String textEn;    // English question text from JSON questions array
  final String actionBn;
  final String actionEn;

  const EngineQuestion({
    required this.id,
    required this.moduleId,
    required this.ruleId,
    required this.textBn,
    required this.textEn,
    required this.actionBn,
    required this.actionEn,
  });
}

// ── Single rule evaluation record for audit trace ────────────────────────────
class RuleTrace {
  final String ruleId;
  final bool fired;
  final String band;
  final String reason;

  const RuleTrace({
    required this.ruleId,
    required this.fired,
    required this.band,
    required this.reason,
  });

  Map<String, dynamic> toMap() => {
    'ruleId': ruleId,
    'fired': fired,
    'band': band,
    'reason': reason,
  };
}

// ── Internal models parsed from clinical_decision_engine.json ─────────────────
class _Condition {
  final String questionId;
  final String operator; // 'EQUALS' | 'IN'
  final dynamic value;   // String or List<String>

  const _Condition({
    required this.questionId,
    required this.operator,
    required this.value,
  });

  factory _Condition.fromJson(Map<String, dynamic> j) => _Condition(
        questionId: j['question_id'] as String,
        operator: j['operator'] as String,
        value: j['value'],
      );

  bool evaluate(Map<String, String> answers) {
    final answer = answers[questionId];
    if (answer == null) return false;
    if (operator == 'EQUALS') {
      // Normalise both sides: bool true/false ↔ string 'true'/'false'
      final a = answer == 'true' ? true : answer == 'false' ? false : answer;
      final v = value == 'true' ? true : value == 'false' ? false : value;
      return a == v;
    }
    if (operator == 'IN') {
      final list = (value as List).map((e) => e.toString()).toList();
      return list.contains(answer);
    }
    return false;
  }
}

class _EscalationRule {
  final List<_Condition> conditionSet;
  final String band;

  const _EscalationRule({required this.conditionSet, required this.band});

  factory _EscalationRule.fromJson(Map<String, dynamic> j) => _EscalationRule(
        conditionSet: (j['condition_set'] as List)
            .map((c) => _Condition.fromJson(c as Map<String, dynamic>))
            .toList(),
        band: j['band'] as String,
      );

  bool evaluate(Map<String, String> answers) =>
      conditionSet.every((c) => c.evaluate(answers));
}

class _DecisionRule {
  final String ruleId;
  final int priority;
  final bool hardStop;
  final bool invariant;
  final bool signOffPending;
  final List<_Condition> conditionSet;
  final String band;
  final String actionBn;
  final String actionEn;
  final String referral;
  final _EscalationRule? escalationRule;

  const _DecisionRule({
    required this.ruleId,
    required this.priority,
    required this.hardStop,
    required this.invariant,
    required this.signOffPending,
    required this.conditionSet,
    required this.band,
    required this.actionBn,
    required this.actionEn,
    required this.referral,
    this.escalationRule,
  });

  factory _DecisionRule.fromJson(Map<String, dynamic> j) => _DecisionRule(
        ruleId: j['ruleId'] as String,
        priority: (j['priority'] as num).toInt(),
        hardStop: (j['hard_stop'] as bool?) ?? false,
        invariant: (j['invariant'] as bool?) ?? false,
        signOffPending: (j['clinical_sign_off_pending'] as bool?) ?? false,
        conditionSet: (j['condition_set'] as List)
            .map((c) => _Condition.fromJson(c as Map<String, dynamic>))
            .toList(),
        band: j['band'] as String,
        actionBn: (j['action_bn'] as String?) ?? '',
        actionEn: (j['action_en'] as String?) ?? '',
        referral: (j['referral'] as String?) ?? '',
        escalationRule: j['escalation_rule'] != null
            ? _EscalationRule.fromJson(
                j['escalation_rule'] as Map<String, dynamic>)
            : null,
      );

  /// Returns true if ALL conditions in conditionSet are satisfied.
  bool evaluate(Map<String, String> answers) =>
      conditionSet.every((c) => c.evaluate(answers));
}

class _EngineModule {
  final String moduleId;
  final List<_DecisionRule> rules;
  // question_id → {textBn, textEn} from the JSON questions array
  final Map<String, ({String textBn, String textEn})> questionTexts;

  const _EngineModule({
    required this.moduleId,
    required this.rules,
    required this.questionTexts,
  });

  factory _EngineModule.fromJson(Map<String, dynamic> j) {
    final texts = <String, ({String textBn, String textEn})>{};
    for (final q in (j['questions'] as List? ?? [])) {
      final id = q['id'] as String;
      texts[id] = (
        textBn: (q['text_bn'] as String?) ?? '',
        textEn: (q['text_en'] as String?) ?? '',
      );
    }
    return _EngineModule(
      moduleId: j['module_id'] as String,
      questionTexts: texts,
      rules: ((j['decision_rules'] as List?) ?? [])
          .map((r) => _DecisionRule.fromJson(r as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.priority.compareTo(b.priority)),
    );
  }
}

// ── ClinicalEngineService ─────────────────────────────────────────────────────
class ClinicalEngineService {
  static const _enginePath = 'assets/data/clinical_decision_engine.json';

  final Map<String, _EngineModule> _modules = {};
  bool _loaded = false;
  String? protocolHash; // SHA-256 hex of the loaded engine JSON

  Future<void> load() async {
    if (_loaded) return;
    final raw = await rootBundle.loadString(_enginePath);

    // ── Step 9: Protocol hash ─────────────────────────────────
    final bytes = utf8.encode(raw);
    protocolHash = sha256.convert(bytes).toString();

    final json = jsonDecode(raw) as Map<String, dynamic>;
    for (final m in (json['modules'] as List)) {
      final mod = _EngineModule.fromJson(m as Map<String, dynamic>);
      _modules[mod.moduleId] = mod;
    }
    _loaded = true;
    _validate();
  }

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Returns a flat list of all questions across all modules for SymptomMapper.
  /// Reuses already-parsed data — no second JSON read.
  List<EngineQuestion> questionIndex() {
    assert(_loaded, 'load() must be called first');
    final result = <EngineQuestion>[];
    for (final mod in _modules.values) {
      for (final rule in mod.rules) {
        if (rule.conditionSet.isEmpty) continue;
        final qId = rule.conditionSet.first.questionId;
        final texts = mod.questionTexts[qId];
        result.add(EngineQuestion(
          id: qId,
          moduleId: mod.moduleId,
          ruleId: rule.ruleId,
          textBn: texts?.textBn ?? '',
          textEn: texts?.textEn ?? '',
          actionBn: rule.actionBn,
          actionEn: rule.actionEn,
        ));
      }
    }
    return result;
  }

  /// Evaluates answers against the clinical decision engine for a given module.
  ///
  /// [moduleId]  — one of: newborn | child | pregnancy | delivery_pnc |
  ///               immunisation | emergency
  /// [answers]   — map of question_id → selected answer string
  ///
  /// Returns [EngineResult] with band, action, referral, and full audit trace.
  ///
  /// EM-005 invariant: once RED is returned, it is permanently locked.
  /// Callers must not call this again with the same session after RED fires —
  /// but if they do, RED will still be returned.
  EngineResult evaluateAnswers(
      String moduleId, Map<String, String> answers) {
    assert(_loaded, 'ClinicalEngineService.load() must be called before evaluate');

    final trace = <RuleTrace>[];
    bool redLocked = false;
    bool invariantLocked = false;
    _DecisionRule? firedRule;

    // ── Step 1: Always sweep emergency module first (cross-module hard-stops) ─
    final emergencyMod = _modules['emergency'];
    if (emergencyMod != null && moduleId != 'emergency') {
      for (final rule in emergencyMod.rules) {
        final fired = rule.evaluate(answers);
        trace.add(RuleTrace(
          ruleId: rule.ruleId,
          fired: fired,
          band: fired ? 'RED' : 'NOT_FIRED',
          reason: fired
              ? 'Emergency hard-stop fired'
              : 'Emergency rule not triggered',
        ));
        if (fired && rule.hardStop) {
          redLocked = true;
          invariantLocked = rule.invariant;
          firedRule ??= rule;
        }
      }
    }

    // ── Step 2: Sweep the target module rules in priority order ───────────────
    final mod = _modules[moduleId];
    if (mod != null) {
      for (final rule in mod.rules) {
        // EM-005: if already RED locked, still trace but do not change band
        final fired = rule.evaluate(answers);

        // Check escalation rule (multi-condition AND upgrade)
        String effectiveBand = rule.band;
        if (fired && rule.escalationRule != null) {
          if (rule.escalationRule!.evaluate(answers)) {
            effectiveBand = rule.escalationRule!.band;
          }
        }

        trace.add(RuleTrace(
          ruleId: rule.ruleId,
          fired: fired,
          band: fired ? effectiveBand : 'NOT_FIRED',
          reason: fired
              ? (effectiveBand == 'RED'
                  ? 'Hard-stop or escalation fired'
                  : 'Rule condition met')
              : 'Condition not met — rule did not fire',
        ));

        if (fired && !redLocked) {
          if (rule.hardStop || effectiveBand == 'RED') {
            redLocked = true;
            invariantLocked = rule.invariant;
            firedRule = rule;
          } else if (firedRule == null || firedRule!.band == 'GREEN') {
            // Promote to YELLOW if no RED yet
            firedRule = rule;
          }
        }
      }
    }

    // ── Step 3: Resolve final band ─────────────────────────────────────────────
    if (firedRule == null) {
      // No rule fired — GREEN
      return EngineResult(
        band: 'GREEN',
        ruleId: 'BAND-001',
        actionBn: 'বাড়িতে যত্ন নিন। রুটিন ফলো-আপ করুন।',
        actionEn: 'Home care. Routine follow-up per module schedule. Counsel on warning signs.',
        referral: 'None',
        hardStop: false,
        invariantLocked: false,
        signOffPending: false,
        trace: trace,
      );
    }

      final finalBand = redLocked ? 'RED' : firedRule.band;

    final effectiveActionBn = firedRule.actionBn;
    final effectiveActionEn = firedRule.actionEn;
    final effectiveReferral = firedRule.referral;

    return EngineResult(
      band: finalBand,
      ruleId: firedRule.ruleId,
      actionBn: effectiveActionBn,
      actionEn: effectiveActionEn,
      referral: effectiveReferral,
      hardStop: firedRule.hardStop || redLocked,
      invariantLocked: invariantLocked,
      signOffPending: firedRule.signOffPending,
      trace: trace,
    );
  }

  // ── Validation (debug only) ─────────────────────────────────────────────────
  void _validate() {
    for (final mod in _modules.values) {
      final ruleIds = mod.rules.map((r) => r.ruleId).toSet();

      // Every hard_stop rule must not be in YELLOW classification
      for (final rule in mod.rules) {
        if (rule.hardStop) {
          assert(rule.band == 'RED',
              '[${mod.moduleId}] hard_stop rule ${rule.ruleId} has band ${rule.band} — must be RED');
        }
      }

      // EM-005 invariant must exist in emergency module
      if (mod.moduleId == 'emergency') {
        assert(
          mod.rules.any((r) => r.invariant),
          '[emergency] EM-005 invariant rule missing',
        );
      }

      // All rule IDs are unique within module
      assert(ruleIds.length == mod.rules.length,
          '[${mod.moduleId}] duplicate ruleIds detected');
    }
  }
}
