// ─────────────────────────────────────────────────────────────────────────────
// CLUP Layer 2 — Clinical Relevance Filter
//
// After IntentDetector confirms clinical intent, this layer checks:
//   1. Is the symptom relevant to the ACTIVE MODULE?
//   2. Is it about the CURRENT PATIENT (not a family member)?
//   3. Is it CURRENT (not historical)?
//   4. What is the module-specific relevance score?
//
// This prevents:
//   - Pregnancy module getting polluted with child symptoms
//   - "স্বামীর জ্বর" being treated as patient's fever
//   - Historical symptoms being treated as current
// ─────────────────────────────────────────────────────────────────────────────

class RelevanceResult {
  final bool relevant;
  final double score;           // 0.0 – 1.0
  final List<String> relevantSymptoms;
  final List<String> irrelevantSymptoms;
  final bool isHistorical;
  final String? clarificationNeeded;

  const RelevanceResult({
    required this.relevant,
    required this.score,
    required this.relevantSymptoms,
    required this.irrelevantSymptoms,
    required this.isHistorical,
    this.clarificationNeeded,
  });

  Map<String, dynamic> toMap() => {
    'relevant': relevant,
    'score': score,
    'relevant_symptoms': relevantSymptoms,
    'irrelevant_symptoms': irrelevantSymptoms,
    'is_historical': isHistorical,
    'clarification_needed': clarificationNeeded,
  };
}

class ClinicalRelevanceFilter {
  // ── Module-specific symptom keyword sets ─────────────────────────────────
  static const _moduleSymptoms = <String, List<String>>{
    'newborn': [
      'দুধ খাচ্ছে না', 'দুধ টানছে না', 'খাচ্ছে না', 'বুকের দুধ',
      'জ্বর', 'গা গরম', 'শ্বাস', 'শ্বাসকষ্ট', 'নাভি', 'নাভি লাল',
      'নিস্তেজ', 'ঢিলে', 'নড়ছে না', 'হলুদ', 'জন্ডিস', 'নীল',
      'কাঁদছে না', 'কান্না নেই', 'ওজন কম',
      'not feeding', 'fever', 'breathing', 'umbilicus', 'lethargic',
      'jaundice', 'cyanosis', 'not crying',
    ],
    'child': [
      'জ্বর', 'কাশি', 'শ্বাসকষ্ট', 'ডায়রিয়া', 'বমি', 'পাতলা পায়খানা',
      'খাচ্ছে না', 'চোখ গর্তে', 'ঠোঁট শুকনো', 'ওজন কম', 'শুকিয়ে গেছে',
      'fever', 'cough', 'diarrhoea', 'vomiting', 'not eating',
      'sunken eyes', 'dry lips', 'weight loss',
    ],
    'pregnancy': [
      'মাথা ব্যথা', 'মাথা ধরেছে', 'রক্তচাপ', 'বিপি', 'bp',
      'পা ফুলেছে', 'মুখ ফুলেছে', 'ফোলা',
      'রক্তপাত', 'রক্ত পড়ছে', 'পেট ব্যথা',
      'বাচ্চা নড়ছে না', 'বাচ্চা কম নড়ছে', 'নড়াচড়া কম',
      'চোখে ঝাপসা', 'ঝাপসা দেখছে', 'মাথা ঘুরছে',
      'anc', 'checkup বাদ', 'checkup মিস',
      'headache', 'blood pressure', 'swelling', 'bleeding',
      'fetal movement', 'blurred vision', 'dizziness',
    ],
    'delivery_pnc': [
      'রক্তপাত', 'রক্ত পড়ছে', 'দুর্গন্ধ', 'স্রাব',
      'জ্বর', 'ঠান্ডা লাগছে', 'কাঁপছে',
      'স্তন ব্যথা', 'বুকে ব্যথা', 'দুধ জমেছে',
      'পেট ব্যথা', 'সেলাই', 'ক্ষত',
      'প্রস্রাবে জ্বালা', 'প্রস্রাব কষ্ট',
      'দুর্বল', 'মাথা ঘুরছে', 'ফ্যাকাশে',
      'bleeding', 'discharge', 'fever', 'breast pain',
      'wound', 'suture', 'urination', 'weakness',
    ],
    'immunisation': [
      'টিকা', 'ভ্যাকসিন', 'টিকা মিস', 'টিকা দেওয়া হয়নি',
      'bcg', 'opv', 'dpt', 'measles', 'mmr', 'pentavalent',
      'vaccine', 'immunization', 'vaccination',
    ],
    'emergency': [
      'খিঁচুনি', 'অজ্ঞান', 'শ্বাস বন্ধ', 'রক্ত থামছে না',
      'নীল হয়ে', 'সাড়া নেই', 'জ্ঞান নেই',
      'seizure', 'unconscious', 'not breathing', 'haemorrhage',
    ],
  };

  // ── Historical markers — symptom is past, not current ─────────────────────
  static const _historicalMarkers = [
    'আগে', 'আগে ছিল', 'আগে হয়েছিল', 'গতকাল', 'গত সপ্তাহে',
    'গত মাসে', 'আগে একবার', 'ছিল', 'হয়েছিল', 'হয়েছে ছিল',
    'pehle', 'kal', 'pichhle hafte', 'was', 'had', 'used to',
  ];

  // ── Self-reference markers — confirms symptom is about current patient ────
  static const _selfMarkers = [
    'আমার', 'আমি', 'আমাকে', 'নিজের', 'নিজে',
    'mera', 'mujhe', 'my', 'i have', 'i am',
  ];

  // ── Other-person markers ──────────────────────────────────────────────────
  static const _otherPersonMarkers = [
    'স্বামীর', 'স্বামী', 'ছেলের', 'মেয়ের', 'বাবার', 'মায়ের',
    'শাশুড়ির', 'ননদের', 'দেবরের', 'পাশের বাড়ির',
    'husband', 'son', 'daughter', 'father', 'mother', 'neighbor',
    'pati', 'bete', 'beti',
  ];

  /// Filters clinical content for relevance to the active module.
  RelevanceResult filter({
    required String text,
    required String moduleId,
    required List<String> matchedTokens,
  }) {
    final lower = text.toLowerCase();
    final moduleKeywords = _moduleSymptoms[moduleId] ?? [];

    // ── Check if about another person ─────────────────────────────────────
    final isOtherPerson = _otherPersonMarkers.any((m) => lower.contains(m));
    final isSelf = _selfMarkers.any((m) => lower.contains(m));

    if (isOtherPerson && !isSelf) {
      return RelevanceResult(
        relevant: false,
        score: 0.0,
        relevantSymptoms: [],
        irrelevantSymptoms: matchedTokens,
        isHistorical: false,
        clarificationNeeded: 'আপনার নিজের কোনো সমস্যা হচ্ছে?',
      );
    }

    // ── Check if historical ───────────────────────────────────────────────
    final isHistorical = _historicalMarkers.any((m) => lower.contains(m));

    // ── Score module relevance ────────────────────────────────────────────
    final relevantSymptoms   = <String>[];
    final irrelevantSymptoms = <String>[];

    for (final token in matchedTokens) {
      final isModuleRelevant = moduleKeywords.any(
        (kw) => kw.toLowerCase().contains(token.toLowerCase()) ||
                token.toLowerCase().contains(kw.toLowerCase()),
      );
      if (isModuleRelevant) {
        relevantSymptoms.add(token);
      } else {
        irrelevantSymptoms.add(token);
      }
    }

    // If no module-specific match but tokens exist, still partially relevant
    final score = matchedTokens.isEmpty
        ? 0.0
        : relevantSymptoms.length / matchedTokens.length;

    final relevant = relevantSymptoms.isNotEmpty ||
        (matchedTokens.isNotEmpty && score >= 0.3);

    // ── Clarification needed? ─────────────────────────────────────────────
    String? clarification;
    if (relevant && isHistorical) {
      clarification = 'এটা কি এখনও হচ্ছে, নাকি আগে হয়েছিল?';
    } else if (!relevant && matchedTokens.isNotEmpty) {
      clarification = _moduleSpecificPrompt(moduleId);
    }

    return RelevanceResult(
      relevant: relevant,
      score: score.clamp(0.0, 1.0),
      relevantSymptoms: relevantSymptoms,
      irrelevantSymptoms: irrelevantSymptoms,
      isHistorical: isHistorical,
      clarificationNeeded: clarification,
    );
  }

  String _moduleSpecificPrompt(String moduleId) => switch (moduleId) {
    'pregnancy'    => 'আপনার গর্ভাবস্থায় কোনো সমস্যা হচ্ছে?',
    'newborn'      => 'শিশুর কোনো সমস্যা হচ্ছে?',
    'child'        => 'শিশুর কোনো শারীরিক সমস্যা হচ্ছে?',
    'delivery_pnc' => 'প্রসবের পর কোনো সমস্যা হচ্ছে?',
    'immunisation' => 'শিশুর টিকা সংক্রান্ত কোনো সমস্যা আছে?',
    _              => 'আপনার কোনো শারীরিক সমস্যা হচ্ছে?',
  };
}
