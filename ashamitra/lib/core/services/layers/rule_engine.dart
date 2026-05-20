// ─────────────────────────────────────────────────────────────────────────────
// Layer 6 — Rule Engine
// Deterministic 4-stage clinical rule evaluator.
// Reads from the already-parsed module data passed in by RuleExecutor.
// Stages: hard_stop → combination_rules → numeric_rules → yellow_rules
// ─────────────────────────────────────────────────────────────────────────────

// ── Public question descriptor (used by VoiceTriageScreen / GeminiTriageService) ───
class EngineQuestion {
  final String id;
  final String moduleId;
  final String ruleId;
  final String textBn;
  final String textEn;
  final List<String> options;
  final String actionBn;
  final String actionEn;

  const EngineQuestion({
    required this.id,
    required this.moduleId,
    required this.ruleId,
    required this.textBn,
    required this.textEn,
    required this.options,
    required this.actionBn,
    required this.actionEn,
  });
}

// ── Internal condition model ──────────────────────────────────────────────────
class EngineCondition {
  final String? questionId;
  final String? vital;
  final String operator;
  final dynamic value;

  const EngineCondition({
    this.questionId,
    this.vital,
    required this.operator,
    required this.value,
  });

  factory EngineCondition.fromJson(Map<String, dynamic> j) => EngineCondition(
        questionId: j['question_id'] as String?,
        vital: j['vital'] as String?,
        operator: j['operator'] as String,
        value: j['value'],
      );

  bool evaluateAnswer(Map<String, dynamic> answers) {
    if (questionId == null) return false;
    final answer = answers[questionId];
    if (answer == null) return false;
    if (operator == 'EQUALS') return _equals(answer, value);
    if (operator == 'IN') {
      final list = (value as List).map((e) => e.toString()).toList();
      return list.contains(answer.toString());
    }
    return false;
  }

  bool evaluateVital(Map<String, dynamic> vitals) {
    if (vital == null) return false;
    final v = vitals[vital];
    if (v == null) return false;
    final num vNum = v as num;
    switch (operator) {
      case 'LESS_THAN':               return vNum < (value as num);
      case 'GREATER_THAN':            return vNum > (value as num);
      case 'GREATER_THAN_OR_EQUAL':   return vNum >= (value as num);
      case 'LESS_THAN_OR_EQUAL':      return vNum <= (value as num);
      case 'EQUALS':                  return vNum == (value as num);
      case 'BETWEEN':
        final range = value as List;
        return vNum >= (range[0] as num) && vNum <= (range[1] as num);
      default: return false;
    }
  }

  bool _equals(dynamic a, dynamic b) {
    // Normalise both sides to bool when either side is bool,
    // so 'true'/true and 'false'/false always compare correctly
    // regardless of which side is the string and which is the bool.
    final aBool = a is bool ? a : (a == 'true' ? true : a == 'false' ? false : null);
    final bBool = b is bool ? b : (b == 'true' ? true : b == 'false' ? false : null);
    if (aBool != null && bBool != null) return aBool == bBool;
    return a.toString() == b.toString();
  }
}

// ── Internal rule model ───────────────────────────────────────────────────────
class EngineRule {
  final String ruleId;
  final int priority;
  final String band;
  final String actionBn;
  final String actionEn;
  final String referral;
  final List<String> suspectedConditions;
  final List<String> dangerSigns;
  final bool signOffPending;
  final List<EngineCondition> conditionSet;

  const EngineRule({
    required this.ruleId,
    required this.priority,
    required this.band,
    required this.actionBn,
    required this.actionEn,
    required this.referral,
    required this.suspectedConditions,
    required this.dangerSigns,
    required this.signOffPending,
    required this.conditionSet,
  });

  factory EngineRule.fromJson(Map<String, dynamic> j) => EngineRule(
        ruleId: j['ruleId'] as String,
        priority: (j['priority'] as num?)?.toInt() ?? 99,
        band: j['band'] as String,
        actionBn: (j['action_bn'] as String?) ?? '',
        actionEn: (j['action_en'] as String?) ?? '',
        referral: (j['referral'] as String?) ?? '',
        suspectedConditions: _strList(j['suspected_conditions']),
        dangerSigns: _strList(j['danger_signs']),
        signOffPending: (j['clinical_sign_off_pending'] as bool?) ?? false,
        conditionSet: (j['condition_set'] as List)
            .map((c) => EngineCondition.fromJson(c as Map<String, dynamic>))
            .toList(),
      );

  bool evaluateAnswers(Map<String, dynamic> answers) =>
      conditionSet.every((c) => c.evaluateAnswer(answers));

  bool evaluateVitals(Map<String, dynamic> vitals) =>
      conditionSet.every((c) => c.evaluateVital(vitals));
}

// ── Internal module model ─────────────────────────────────────────────────────
class EngineModule {
  final String moduleId;
  final Map<String, ({String textBn, String textEn, List<String> options})> questions;
  final List<EngineRule> hardStopRules;
  final List<EngineRule> combinationRules;
  final List<EngineRule> yellowRules;
  final List<EngineRule> numericRules;
  final List<ScoreRule> scoreRules;
  final Map<String, List<int>> scoreThresholds;

  const EngineModule({
    required this.moduleId,
    required this.questions,
    required this.hardStopRules,
    required this.combinationRules,
    required this.yellowRules,
    required this.numericRules,
    required this.scoreRules,
    required this.scoreThresholds,
  });

  factory EngineModule.fromJson(Map<String, dynamic> j) {
    final qs = <String, ({String textBn, String textEn, List<String> options})>{};
    for (final q in (j['questions'] as List? ?? [])) {
      qs[q['id'] as String] = (
        textBn: (q['text_bn'] as String?) ?? '',
        textEn: (q['text_en'] as String?) ?? '',
        options: _strList(q['options']),
      );
    }

    List<EngineRule> parseRules(String key) =>
        ((j[key] as List?) ?? [])
            .map((r) => EngineRule.fromJson(r as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.priority.compareTo(b.priority));

    final re = j['risk_engine'] as Map<String, dynamic>? ?? {};
    final scoreRules = ((re['score_rules'] as List?) ?? [])
        .map((s) => ScoreRule.fromJson(s as Map<String, dynamic>))
        .toList();

    final rawThresholds = (re['thresholds'] as Map<String, dynamic>?) ?? {};
    final thresholds = <String, List<int>>{};
    rawThresholds.forEach((band, range) {
      if (range is List && range.length == 2) {
        thresholds[band] = [(range[0] as num).toInt(), (range[1] as num).toInt()];
      }
    });

    return EngineModule(
      moduleId: j['module_id'] as String,
      questions: qs,
      hardStopRules: parseRules('hard_stop_rules'),
      combinationRules: parseRules('combination_rules'),
      yellowRules: parseRules('yellow_rules'),
      numericRules: parseRules('numeric_rules'),
      scoreRules: scoreRules,
      scoreThresholds: thresholds,
    );
  }
}

class ScoreRule {
  final String condition;
  final int score;
  const ScoreRule({required this.condition, required this.score});
  factory ScoreRule.fromJson(Map<String, dynamic> j) =>
      ScoreRule(condition: j['condition'] as String, score: (j['score'] as num).toInt());
}

// ── Rule engine output ────────────────────────────────────────────────────────
class RuleEngineResult {
  final bool redLock;
  final String provisionalBand;   // before adaptive risk + safety escalation
  final List<String> triggeredRules;
  final Set<String> suspectedConditions;
  final Set<String> dangerSigns;
  final bool signOffPending;
  final EngineRule? winningRule;
  final int riskScore;
  final List<RuleTraceEntry> trace;

  const RuleEngineResult({
    required this.redLock,
    required this.provisionalBand,
    required this.triggeredRules,
    required this.suspectedConditions,
    required this.dangerSigns,
    required this.signOffPending,
    required this.winningRule,
    required this.riskScore,
    required this.trace,
  });
}

class RuleTraceEntry {
  final String ruleId;
  final String stage;
  final bool fired;
  final String band;
  final String reason;

  const RuleTraceEntry({
    required this.ruleId,
    required this.stage,
    required this.fired,
    required this.band,
    required this.reason,
  });

  Map<String, dynamic> toMap() => {
    'ruleId': ruleId,
    'stage': stage,
    'fired': fired,
    'band': band,
    'reason': reason,
  };
}

// ── Rule Engine ───────────────────────────────────────────────────────────────
class RuleEngine {
  /// Runs the 4-stage deterministic evaluation against a loaded [EngineModule].
  ///
  /// Stage 1 — hard_stop_rules   : any true → RED locked immediately
  /// Stage 2 — combination_rules : AND of multiple answers → RED or YELLOW
  /// Stage 3 — numeric_rules     : vital threshold breaches
  /// Stage 4 — yellow_rules      : single-condition YELLOW rules
  ///                               (skipped if RED already locked)
  RuleEngineResult evaluate({
    required EngineModule module,
    required Map<String, dynamic> answers,
    required Map<String, dynamic> vitals,
  }) {
    final trace            = <RuleTraceEntry>[];
    final triggeredRules   = <String>[];
    final suspectedConds   = <String>{};
    final dangerSignsSet   = <String>{};
    bool redLock           = false;
    bool signOffPending    = false;
    EngineRule? winningRule;

    // ── Stage 1: hard_stop_rules ──────────────────────────────────────────────
    for (final rule in module.hardStopRules) {
      final fired = rule.evaluateAnswers(answers);
      trace.add(RuleTraceEntry(
        ruleId: rule.ruleId,
        stage: 'hard_stop',
        fired: fired,
        band: fired ? 'RED' : 'NOT_FIRED',
        reason: fired ? 'Hard-stop condition met' : 'Condition not met',
      ));
      if (fired) {
        triggeredRules.add(rule.ruleId);
        suspectedConds.addAll(rule.suspectedConditions);
        dangerSignsSet.addAll(rule.dangerSigns);
        if (rule.signOffPending) signOffPending = true;
        redLock = true;
        winningRule ??= rule;
      }
    }

    // ── Stage 2: combination_rules ────────────────────────────────────────────
    for (final rule in module.combinationRules) {
      final fired = rule.evaluateAnswers(answers);
      trace.add(RuleTraceEntry(
        ruleId: rule.ruleId,
        stage: 'combination_rules',
        fired: fired,
        band: fired ? rule.band : 'NOT_FIRED',
        reason: fired ? 'All combination conditions met' : 'Combination not met',
      ));
      if (fired) {
        triggeredRules.add(rule.ruleId);
        suspectedConds.addAll(rule.suspectedConditions);
        dangerSignsSet.addAll(rule.dangerSigns);
        if (rule.band == 'RED') {
          redLock = true;
          winningRule ??= rule;
        } else if (!redLock) {
          winningRule ??= rule;
        }
      }
    }

    // ── Stage 3: numeric_rules ────────────────────────────────────────────────
    if (vitals.isNotEmpty) {
      for (final rule in module.numericRules) {
        final fired = rule.evaluateVitals(vitals);
        trace.add(RuleTraceEntry(
          ruleId: rule.ruleId,
          stage: 'numeric_rules',
          fired: fired,
          band: fired ? rule.band : 'NOT_FIRED',
          reason: fired ? 'Vital threshold breached' : 'Vital within range',
        ));
        if (fired) {
          triggeredRules.add(rule.ruleId);
          dangerSignsSet.addAll(rule.dangerSigns);
          if (rule.band == 'RED') {
            redLock = true;
            winningRule ??= rule;
          } else if (!redLock) {
            winningRule ??= rule;
          }
        }
      }
    }

    // ── Stage 4: yellow_rules (skipped if RED locked) ─────────────────────────
    if (!redLock) {
      for (final rule in module.yellowRules) {
        final fired = rule.evaluateAnswers(answers);
        trace.add(RuleTraceEntry(
          ruleId: rule.ruleId,
          stage: 'yellow_rules',
          fired: fired,
          band: fired ? rule.band : 'NOT_FIRED',
          reason: fired ? 'Yellow risk condition met' : 'Condition not met',
        ));
        if (fired) {
          triggeredRules.add(rule.ruleId);
          suspectedConds.addAll(rule.suspectedConditions);
          dangerSignsSet.addAll(rule.dangerSigns);
          winningRule ??= rule;
        }
      }
    }

    // ── Risk score ────────────────────────────────────────────────────────────
    int riskScore = 0;
    for (final sr in module.scoreRules) {
      final answer = answers[sr.condition];
      if (answer == true || answer == 'true') riskScore += sr.score;
    }

    final provisionalBand = redLock
        ? 'RED'
        : (winningRule?.band == 'YELLOW' ? 'YELLOW' : 'GREEN');

    return RuleEngineResult(
      redLock: redLock,
      provisionalBand: provisionalBand,
      triggeredRules: triggeredRules,
      suspectedConditions: suspectedConds,
      dangerSigns: dangerSignsSet,
      signOffPending: signOffPending,
      winningRule: winningRule,
      riskScore: riskScore,
      trace: trace,
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────
List<String> _strList(dynamic v) {
  if (v == null) return [];
  return (v as List).map((e) => e.toString()).toList();
}
