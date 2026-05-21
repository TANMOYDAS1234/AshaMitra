// ─────────────────────────────────────────────────────────────────────────────
// OfflineBrain — Symptom-driven dynamic question selection + combination detection
//
// 1. Scores remaining questions by clinical urgency (hard-stop > combo > yellow)
// 2. Detects multi-keyword combinations in free text (e.g. headache + swelling
//    = pre-eclampsia combo → immediate RED escalation)
// 3. Returns immediate action if last answer confirmed a danger sign
// ─────────────────────────────────────────────────────────────────────────────

import 'rule_executor.dart';

class OfflineNextQuestion {
  final EngineQuestion? question;
  final String? immediateActionBn;
  final bool shouldFinish;
  // Non-null when a combination was detected — triggers immediate RED
  final String? combinationAlertBn;

  const OfflineNextQuestion({
    this.question,
    this.immediateActionBn,
    this.shouldFinish = false,
    this.combinationAlertBn,
  });
}

// ── Combination rule: fires when ALL required IDs are confirmed YES ────────────
class _CombinationRule {
  final List<String> requiredIds; // ALL must be true
  final String alertBn;           // spoken immediately
  final String label;             // for logging

  const _CombinationRule({
    required this.requiredIds,
    required this.alertBn,
    required this.label,
  });
}

class OfflineBrain {
  // ── Rule priority weights ─────────────────────────────────────────────────
  static const _hardStopWeight    = 100;
  static const _combinationWeight = 60;
  static const _yellowWeight      = 30;
  static const _riskScoreWeight   = 10;

  // ── Combination rules — multi-keyword detection ───────────────────────────
  // Each rule fires when ALL its requiredIds are confirmed YES.
  // Ordered by clinical severity (most dangerous first).
  static const _combinationRules = [
    // Pre-eclampsia: headache + swelling
    _CombinationRule(
      requiredIds: ['p1', 'p2'],
      alertBn: 'সতর্কতা! মাথা ব্যথা ও ফোলা একসাথে — প্রি-এক্লাম্পসিয়ার লক্ষণ। এখনই বাম কাতে শোয়ান ও ১০৮ কল করুন।',
      label: 'pre-eclampsia',
    ),
    // Eclampsia: headache + blurred vision
    _CombinationRule(
      requiredIds: ['p1', 'p6'],
      alertBn: 'সতর্কতা! মাথা ব্যথা ও চোখে ঝাপসা — এক্লাম্পসিয়ার ঝুঁকি। এখনই FRU-তে রেফার করুন।',
      label: 'eclampsia',
    ),
    // Severe pre-eclampsia: headache + swelling + blurred vision
    _CombinationRule(
      requiredIds: ['p1', 'p2', 'p6'],
      alertBn: 'সতর্কতা! গুরুতর প্রি-এক্লাম্পসিয়া — মাথা ব্যথা, ফোলা ও ঝাপসা দৃষ্টি। এখনই ১০৮ কল করুন।',
      label: 'severe-pre-eclampsia',
    ),
    // PPH + sepsis: bleeding + fever postpartum
    _CombinationRule(
      requiredIds: ['pp1', 'pp2'],
      alertBn: 'সতর্কতা! রক্তপাত ও জ্বর একসাথে — PPH ও সেপসিসের ঝুঁকি। এখনই ১০৮ কল করুন।',
      label: 'pph-sepsis',
    ),
    // PSBI: not feeding + fever newborn
    _CombinationRule(
      requiredIds: ['n1', 'n2'],
      alertBn: 'সতর্কতা! দুধ খাচ্ছে না ও জ্বর — PSBI নিশ্চিত। এখনই SNCU-তে রেফার করুন।',
      label: 'psbi',
    ),
    // Severe PSBI: not feeding + breathing difficulty
    _CombinationRule(
      requiredIds: ['n1', 'n3'],
      alertBn: 'সতর্কতা! দুধ খাচ্ছে না ও শ্বাসকষ্ট — গুরুতর PSBI। এখনই SNCU-তে রেফার করুন।',
      label: 'severe-psbi',
    ),
    // Severe dehydration: diarrhoea + sunken eyes
    _CombinationRule(
      requiredIds: ['c3', 'c5'],
      alertBn: 'সতর্কতা! ডায়রিয়া ও পানিশূন্যতা — এখনই ORS শুরু করুন ও FRU-তে রেফার করুন।',
      label: 'severe-dehydration',
    ),
    // Pneumonia: cough + fever child
    _CombinationRule(
      requiredIds: ['c1', 'c2'],
      alertBn: 'সতর্কতা! জ্বর ও কাশি একসাথে — নিউমোনিয়ার সন্দেহ। আজই PHC-তে নিয়ে যান।',
      label: 'pneumonia',
    ),
  ];

  // ── Immediate actions per single danger sign ──────────────────────────────
  static const _immediateActions = <String, String>{
    'p1': 'রক্তচাপ বেশি — এখনই বাম কাতে শোয়ান এবং ১০৮ কল করুন।',
    'p3': 'রক্তপাত হচ্ছে — শুইয়ে দিন, পা উঁচু করুন, যোনি পরীক্ষা করবেন না।',
    'p6': 'চোখে ঝাপসা — এক্লাম্পসিয়ার লক্ষণ, এখনই FRU-তে রেফার করুন।',
    'pp1': 'অতিরিক্ত রক্তপাত — জরায়ু মালিশ করুন, ১০৮ কল করুন।',
    'pp2': 'জ্বর আছে — পিউরপেরাল সেপসিসের ঝুঁকি, PHC-তে নিয়ে যান।',
    'n1': 'দুধ খাচ্ছে না — PSBI সন্দেহ, এখনই SNCU-তে রেফার করুন।',
    'n3': 'শ্বাসকষ্ট — শ্বাসের হার গণনা করুন, ≥৬০/মিনিট হলে RED।',
    'n5': 'নিস্তেজ — গুরুতর সিস্টেমিক অসুস্থতা, এখনই SNCU-তে রেফার করুন।',
    'c5': 'পানিশূন্যতা — এখনই ORS শুরু করুন, FRU-তে রেফার করুন।',
    'c1': 'পাঁচ দিনের বেশি জ্বর — ম্যালেরিয়া/ডেঙ্গু বাদ দিতে PHC-তে নিয়ে যান।',
    'e1': 'রক্তপাত থামছে না — এখনই ১০৮ কল করুন।',
    'e2': 'খিঁচুনি — বাম কাতে শোয়ান, শ্বাসনালী রক্ষা করুন, ১০৮ কল করুন।',
    'e3': 'শ্বাস বন্ধ — শ্বাসনালী পরিষ্কার করুন, ১০৮ কল করুন।',
    'e4': 'জ্ঞান নেই — রিকভারি পজিশনে রাখুন, ১০৮ কল করুন।',
  };

  final Map<String, int> _questionUrgency = {};
  bool _initialized = false;

  void init(RuleExecutor executor) {
    if (_initialized) return;
    _initialized = true;

    for (final q in executor.questionIndex()) {
      int score = _riskScoreWeight;
      final ruleId = q.ruleId.toUpperCase();
      if (ruleId.contains('COMB')) {
        score += _combinationWeight;
      } else if (ruleId.contains('VITAL')) {
        score += _yellowWeight;
      } else {
        final m = RegExp(r'-(\d+)$').firstMatch(ruleId);
        final priority = int.tryParse(m?.group(1) ?? '9') ?? 9;
        score += _hardStopWeight - (priority * 5);
      }
      _questionUrgency[q.id] = (_questionUrgency[q.id] ?? 0) + score;
    }
  }

  // ── Check if any combination rule fires given current confirmed YES set ────
  // Returns the alert text of the highest-priority fired combination, or null.
  String? checkCombinations(Set<String> confirmedYes) {
    for (final rule in _combinationRules) {
      if (rule.requiredIds.every((id) => confirmedYes.contains(id))) {
        return rule.alertBn;
      }
    }
    return null;
  }

  // ── Returns IDs that would complete a combination if confirmed ────────────
  // Used to boost urgency of questions that would trigger a combo.
  Set<String> _nearCombinationIds(Set<String> confirmedYes) {
    final result = <String>{};
    for (final rule in _combinationRules) {
      final missing = rule.requiredIds.where((id) => !confirmedYes.contains(id)).toList();
      // One question away from completing the combination
      if (missing.length == 1) result.add(missing.first);
    }
    return result;
  }

  // ── Main method: pick the most urgent next question ───────────────────────
  OfflineNextQuestion getNextQuestion({
    required List<EngineQuestion> remaining,
    required Set<String> confirmedYes,
    String? lastAnsweredId,
    bool lastAnswerWasYes = false,
  }) {
    if (remaining.isEmpty) {
      return const OfflineNextQuestion(shouldFinish: true);
    }

    if (confirmedYes.length >= 3) {
      return const OfflineNextQuestion(shouldFinish: true);
    }

    // Check if a combination just fired
    final comboAlert = lastAnswerWasYes ? checkCombinations(confirmedYes) : null;

    // Immediate action for the last answered question
    String? immediateAction;
    if (lastAnswerWasYes && lastAnsweredId != null) {
      immediateAction = _immediateActions[lastAnsweredId];
    }

    // IDs that would complete a combination — get urgency boost
    final nearCombo = _nearCombinationIds(confirmedYes);

    final scored = <({EngineQuestion q, int score})>[];
    for (final q in remaining) {
      int score = _questionUrgency[q.id] ?? _yellowWeight;

      // Near-combination boost: asking this question could complete a RED combo
      if (nearCombo.contains(q.id)) score += _combinationWeight;

      // Same-cluster bonus
      if (lastAnswerWasYes && lastAnsweredId != null) {
        final lastPrefix = lastAnsweredId.replaceAll(RegExp(r'\d'), '');
        final qPrefix = q.id.replaceAll(RegExp(r'\d'), '');
        if (lastPrefix == qPrefix) score += 20;
      }

      scored.add((q: q, score: score));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));

    return OfflineNextQuestion(
      question: scored.first.q,
      immediateActionBn: immediateAction,
      combinationAlertBn: comboAlert,
      shouldFinish: false,
    );
  }
}
