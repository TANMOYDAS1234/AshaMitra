// ─────────────────────────────────────────────────────────────────────────────
// EngineGroundedQA — offline dynamic Q&A
//
// When an ASHA asks a clinical question ("নবজাতকের জ্বর কত হলে বিপদ?"), this
// service:
//   1. Identifies the topic by matching keywords against vital-name aliases
//      (or question-id aliases for symptom questions).
//   2. Looks up the matching rules in the **active clinical module** of the
//      live engine — same `asha_engine.json` that drives triage.
//   3. Synthesises a short Bengali + English answer from the rule's actionBn
//      / actionEn fields.
//
// Why this matters:
//   - The answers are GROUNDED in the same protocol-signed rules that decide
//     triage outcomes. The hash-verify layer applies to both.
//   - Works offline — no LLM, no network, no model on device.
//   - When a clinical reviewer updates a rule (e.g. tightens a threshold),
//     the educational answer auto-updates with it.
//   - The answer is module-aware — asking "fever threshold?" in pregnancy
//     returns mother-relevant rules, not newborn rules.
// ─────────────────────────────────────────────────────────────────────────────

import '../rule_executor.dart';

class EngineGroundedQA {
  /// Maps clinical question keywords to a vital field name. Order matters —
  /// the first matching key wins, so put more-specific entries first.
  static const _vitalKeywords = <String, List<String>>{
    'temperature_c': [
      'জ্বর', 'গা গরম', 'তাপ', 'তাপমাত্রা',
      'fever', 'bukhar', 'jor', 'tap', 'temperature', 'temp',
    ],
    'systolic_bp': [
      'সিস্টোলিক', 'উপরের রক্তচাপ',
      'systolic',
    ],
    'diastolic_bp': [
      'ডায়াস্টোলিক', 'নিচের রক্তচাপ',
      'diastolic',
    ],
    // Generic BP — matches if no systolic/diastolic word found; handled below
    // by checking both systolic_bp and diastolic_bp rules in one go.
    'bp_generic': [
      'বিপি', 'bp', 'রক্তচাপ', 'blood pressure', 'pressure',
    ],
    'respiratory_rate': [
      'শ্বাসের হার', 'শ্বাসের গতি', 'শ্বাসকষ্ট',
      'respiratory rate', 'breathing rate', 'rr ',
    ],
    'spo2': [
      'spo2', 'spo₂', 'অক্সিজেন', 'oxygen', 'saturation', 'স্যাচুরেশন',
    ],
    'haemoglobin': [
      'hb', 'hemoglobin', 'haemoglobin', 'হিমোগ্লোবিন',
      'রক্তাল্পতা', 'anaemia', 'anemia',
    ],
    'muac_cm': [
      'muac', 'মুয়াক', 'মাঝবাহু', 'mid-arm', 'mid arm',
    ],
    'weight_kg': [
      'ওজন', 'weight', 'kg', 'কেজি',
    ],
    'heart_rate': [
      'হৃদস্পন্দন', 'নাড়ি', 'heart rate', 'pulse', 'hr ',
    ],
    'urine_protein_plus': [
      'প্রোটিন', 'protein', 'প্রস্রাব', 'urine',
    ],
    'fundal_height_weeks_diff': [
      'ফান্ডাল', 'ফান্ডাস', 'fundal', 'fundus',
    ],
    'pads_soaked_per_30min': [
      'প্যাড', 'pad', 'রক্তপাত', 'bleeding',
    ],
    'pads_per_day': [
      'দিনে প্যাড', 'pads per day', 'how many pads', 'কতগুলো প্যাড',
    ],
    'weight_for_age_z': [
      'ওজন কম', 'underweight', 'z-score', 'z score',
    ],
    'gestational_age_weeks': [
      'সপ্তাহ', 'weeks pregnant', 'preterm', 'প্রিটার্ম', 'প্রি-টার্ম',
      'gestation', 'gestational age', 'মাস গর্ভ', 'months pregnant',
    ],
    'labour_hours': [
      'প্রসব ব্যথা', 'labour pain', 'labor pain', 'প্রসব সময়',
      'how long labour', 'how many hours labour', 'ব্যথা কত ঘণ্টা',
    ],
    'leaking_hours_no_labour': [
      'পানি ভাঙা', 'water broke', 'water break', 'leaking', 'লিকেজ',
      'prom', 'rupture', 'membrane rupture',
    ],
    'tsh_miu': [
      'tsh', 'থাইরয়েড', 'thyroid', 'hypothyroidism',
      'হাইপোথাইরয়েড', 'levothyroxine', 'লেভোথাইরক্সিন',
    ],
    'ogtt_2hr_mg_dl': [
      'ogtt', 'oral glucose', 'gdm', 'gestational diabetes',
      'গর্ভকালীন ডায়াবেটিস', 'ডায়াবেটিস', 'sugar', '75g',
    ],
    'fhr_bpm': [
      'fhr', 'foetal heart', 'fetal heart', 'ভ্রূণের হৃদস্পন্দন',
      'baby heart rate', 'বাচ্চার হার্ট রেট',
    ],
  };

  /// Maps clinical question keywords to a question id. Used when an ASHA
  /// asks about a yes/no symptom rather than a vital — e.g. "জন্ডিস মানে কী?"
  static const _questionIdKeywords = <String, Map<String, List<String>>>{
    'newborn': {
      'n1': ['দুধ', 'feed', 'breastfeed', 'breastfeeding', 'খাচ্ছে না',
             'colostrum', 'কোলোস্ট্রাম', 'শালদুধ'],
      'n2': ['জ্বর নবজাতক', 'newborn fever', 'কোল্ড স্ট্রেস', 'cold stress',
             'hypothermia', 'হাইপোথার্মিয়া'],
      'n3': ['শ্বাসকষ্ট', 'fast breathing', 'tachypnoea', 'tachypnea',
             'chest indrawing', 'বুকে ইনড্রয়িং', 'বুকে চাপ'],
      'n4': ['নাভি', 'navel', 'umbilical', 'umbilicus', 'omphalitis',
             'ওম্ফালাইটিস', 'নাভিতে পুঁজ'],
      'n5': ['নিস্তেজ', 'lethargic', 'lethargy', 'নড়ছে না', 'limp',
             'unresponsive', 'সাড়া নেই'],
      'n6': ['জন্ডিস', 'jaundice', 'piliya', 'হলুদ ত্বক', 'নীল',
             'cyanosis', 'kernicterus', 'কার্নিকটেরাস'],
    },
    'pregnancy': {
      'p1': ['মাথা ব্যথা', 'headache', 'hypertension', 'pre-eclampsia',
             'প্রি-এক্লাম্পসিয়া', 'প্রি এক্লাম্পসিয়া'],
      'p2': ['ফোলা', 'edema', 'oedema', 'swelling', 'pedal edema'],
      'p3': ['রক্তপাত', 'bleeding', 'aph', 'antepartum', 'placental abruption',
             'placenta previa', 'প্লাসেন্টা'],
      'p4': ['নড়াচড়া', 'fetal movement', 'baby movement', 'kick count',
             'বাচ্চার নড়াচড়া'],
      'p5': ['anc', 'checkup', 'antenatal', 'visit'],
      'p6': ['ঝাপসা', 'blurred', 'eclampsia', 'এক্লাম্পসিয়া', 'fits',
             'খিঁচুনি', 'magnesium', 'mgso4'],
    },
    'child': {
      'c1': ['জ্বর', 'fever', 'বুখার', 'malaria', 'ম্যালেরিয়া',
             'dengue', 'ডেঙ্গু', 'typhoid'],
      'c2': ['কাশি', 'cough', 'pneumonia', 'নিউমোনিয়া', 'ari',
             'breathing', 'respiratory'],
      'c3': ['ডায়রিয়া', 'diarrhoea', 'diarrhea', 'বমি', 'vomiting',
             'dysentery', 'ডিসেন্ট্রি', 'blood in stool'],
      'c4': ['খাচ্ছে না', 'not eating', 'not feeding', 'feeding refusal'],
      'c5': ['পানিশূন্যতা', 'dehydration', 'sunken', 'plan a', 'plan b',
             'plan c', 'ors', 'zinc', 'জিঙ্ক'],
      'c6': ['ওজন কম', 'low weight', 'underweight', 'sam', 'mam',
             'severe acute malnutrition', 'কুপোষণ'],
    },
    'delivery_pnc': {
      'pp1': ['pph', 'রক্তপাত', 'haemorrhage', 'hemorrhage', 'discharge',
              'স্রাব', 'দুর্গন্ধ', 'foul smelling'],
      'pp2': ['জ্বর', 'fever', 'sepsis', 'সেপসিস', 'puerperal'],
      'pp3': ['স্তন', 'breast', 'mastitis', 'ম্যাস্টাইটিস', 'abscess',
              'breast pain'],
      'pp4': ['পেট ব্যথা', 'abdominal pain', 'suture', 'সেলাই'],
      'pp5': ['প্রস্রাব', 'urination', 'urine', 'uti'],
      'pp6': ['দুর্বল', 'weakness', 'dizzy', 'মাথা ঘোরা', 'fainting',
              'anaemia', 'rakto-alpata', 'রক্তাল্পতা'],
    },
    'immunisation': {
      'im1': ['bcg', 'tuberculosis', 'টিবি', 'জন্মে'],
      'im2': ['pentavalent', 'penta', 'পেন্টা', 'opv', 'oral polio',
              '৬ সপ্তাহ', '6 weeks'],
      'im3': ['mr', 'measles', 'rubella', 'হাম', '৯ মাস', '9 months'],
      'im4': ['dpt', 'booster', 'বুস্টার', '১৬ মাস', '16 months'],
      'im5': ['vitamin a', 'ভিটামিন এ', 'vit a'],
    },
  };

  /// Looks up a clinically-grounded answer for [rawInput] in [moduleId].
  /// Returns null if no relevant rule was found — caller should fall back to
  /// the static educational bank.
  static ({String bn, String en})? lookup({
    required String rawInput,
    required String moduleId,
    required RuleExecutor executor,
  }) {
    final lower = rawInput.toLowerCase();

    // ── 1. Try vital-based lookup (numeric rules) ──────────────────────────
    final vital = _matchVital(lower);
    if (vital != null) {
      final answer = _answerForVital(
        vital: vital,
        moduleId: moduleId,
        executor: executor,
      );
      if (answer != null) return answer;
    }

    // ── 2. Try question-id lookup (yes/no symptom questions) ───────────────
    final qid = _matchQuestionId(lower, moduleId);
    if (qid != null) {
      final answer = _answerForQuestion(
        questionId: qid,
        moduleId: moduleId,
        executor: executor,
      );
      if (answer != null) return answer;
    }

    return null;
  }

  // ── Internals ───────────────────────────────────────────────────────────

  static String? _matchVital(String lower) {
    for (final entry in _vitalKeywords.entries) {
      for (final kw in entry.value) {
        if (lower.contains(kw.toLowerCase())) return entry.key;
      }
    }
    return null;
  }

  static String? _matchQuestionId(String lower, String moduleId) {
    final modMap = _questionIdKeywords[moduleId];
    if (modMap == null) return null;
    for (final entry in modMap.entries) {
      for (final kw in entry.value) {
        if (lower.contains(kw.toLowerCase())) return entry.key;
      }
    }
    return null;
  }

  static ({String bn, String en})? _answerForVital({
    required String vital,
    required String moduleId,
    required RuleExecutor executor,
  }) {
    // Generic BP expands to BOTH systolic and diastolic — show both bounds.
    final vitals = vital == 'bp_generic'
        ? ['systolic_bp', 'diastolic_bp']
        : [vital];

    final rules = executor.numericRulesForModule(moduleId).where((r) =>
        r.conditionSet.any((c) => c.vital != null && vitals.contains(c.vital)))
        .toList();
    if (rules.isEmpty) return null;

    // RED first, then YELLOW, then GREEN — pick the top 2 most clinically
    // important so the answer stays short.
    rules.sort((a, b) => _bandPriority(a.band) - _bandPriority(b.band));
    final top = rules.take(2).toList();

    final bn = top.map((r) => r.actionBn).where((s) => s.isNotEmpty).join(' ');
    final en = top.map((r) => r.actionEn).where((s) => s.isNotEmpty).join(' ');
    if (bn.isEmpty && en.isEmpty) return null;
    return (bn: bn, en: en);
  }

  static ({String bn, String en})? _answerForQuestion({
    required String questionId,
    required String moduleId,
    required RuleExecutor executor,
  }) {
    // First check rules that fire on this questionId (these have rich actions)
    final rules = executor.allRulesForModule(moduleId).where((r) =>
        r.conditionSet.any((c) => c.questionId == questionId))
        .toList();
    if (rules.isEmpty) {
      // No rule yet — fall back to just describing the question itself
      final qs = executor.questionsForModule(moduleId);
      final q = qs[questionId];
      if (q == null) return null;
      return (
        bn: 'এটি একটি গুরুত্বপূর্ণ বিপদচিহ্ন: "${q.textBn}"',
        en: 'This is an important danger sign: "${q.textEn}"',
      );
    }

    rules.sort((a, b) => _bandPriority(a.band) - _bandPriority(b.band));
    final winner = rules.first;
    return (bn: winner.actionBn, en: winner.actionEn);
  }

  static int _bandPriority(String band) {
    switch (band.toUpperCase()) {
      case 'RED':    return 0;
      case 'YELLOW': return 1;
      case 'GREEN':  return 2;
      default:       return 3;
    }
  }
}
