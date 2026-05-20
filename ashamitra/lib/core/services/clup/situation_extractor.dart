// ─────────────────────────────────────────────────────────────────────────────
// Situation Extractor
// Maps a free-speech situation description to pre-answered engine question IDs.
// Called ONCE after the ASHA describes the situation.
// Output feeds VoiceTriageScreen so already-described symptoms are skipped.
// ─────────────────────────────────────────────────────────────────────────────

class SituationExtraction {
  /// questionId → true/false pre-answer extracted from situation
  final Map<String, bool> preAnswers;

  /// Human-readable summary of what was extracted (for UI display)
  final List<String> extractedSymptoms;

  const SituationExtraction({
    required this.preAnswers,
    required this.extractedSymptoms,
  });

  bool get hasPreAnswers => preAnswers.isNotEmpty;
}

class SituationExtractor {
  // ── Symptom → question ID mapping per module ──────────────────────────────
  // Each entry: list of trigger phrases → question_id + answer (true=yes)
  static const _moduleMap = <String, List<_SymptomRule>>{

    'newborn': [
      _SymptomRule(triggers: ['দুধ খাচ্ছে না', 'দুধ টানছে না', 'বুকের দুধ খাচ্ছে না',
        'খাচ্ছে না', 'feeding নেই', 'not feeding', 'doodh nahi'],
        questionId: 'n1', answer: true, label: 'দুধ খাচ্ছে না'),

      _SymptomRule(triggers: ['জ্বর', 'গা গরম', 'গা পুড়ছে', 'গা পুড়ে', 'fever',
        'bukhar', 'jor', 'গরম লাগছে'],
        questionId: 'n2', answer: true, label: 'জ্বর'),

      _SymptomRule(triggers: ['শ্বাস', 'শ্বাসকষ্ট', 'শ্বাস কষ্ট', 'শ্বাস দ্রুত',
        'শ্বাস টান', 'breathing', 'sans', 'দম', 'শ্বাস নিতে'],
        questionId: 'n3', answer: true, label: 'শ্বাসকষ্ট'),

      _SymptomRule(triggers: ['নাভি লাল', 'নাভি ফুলে', 'নাভিতে পুঁজ', 'নাভি থেকে',
        'নাভি', 'umbilicus', 'cord'],
        questionId: 'n4', answer: true, label: 'নাভিতে সমস্যা'),

      _SymptomRule(triggers: ['নড়ছে না', 'নিস্তেজ', 'ঢিলে', 'নেতিয়ে', 'সাড়া নেই',
        'lethargic', 'weak', 'কম নড়ছে', 'নড়াচড়া নেই'],
        questionId: 'n5', answer: true, label: 'নিস্তেজ'),

      _SymptomRule(triggers: ['হলুদ', 'জন্ডিস', 'নীল', 'নীলাভ', 'গা হলুদ',
        'চোখ হলুদ', 'jaundice', 'cyanosis', 'blue'],
        questionId: 'n6', answer: true, label: 'ত্বকের রঙ পরিবর্তন'),
    ],

    'child': [
      _SymptomRule(triggers: ['পাঁচ দিন', '৫ দিন', 'পাঁচদিন', 'অনেকদিন জ্বর',
        'দীর্ঘদিন জ্বর', 'five days fever'],
        questionId: 'c1', answer: true, label: '৫ দিনের বেশি জ্বর'),

      _SymptomRule(triggers: ['কাশি', 'শ্বাসকষ্ট', 'শ্বাস কষ্ট', 'cough', 'breathing'],
        questionId: 'c2', answer: true, label: 'কাশি/শ্বাসকষ্ট'),

      _SymptomRule(triggers: ['ডায়রিয়া', 'পাতলা পায়খানা', 'বমি', 'diarrhoea',
        'vomiting', 'loose stool'],
        questionId: 'c3', answer: true, label: 'ডায়রিয়া/বমি'),

      _SymptomRule(triggers: ['খাচ্ছে না', 'খেতে চাইছে না', 'খাওয়া বন্ধ',
        'not eating', 'refusing food'],
        questionId: 'c4', answer: true, label: 'খাচ্ছে না'),

      _SymptomRule(triggers: ['চোখ গর্তে', 'চোখ বসে', 'ঠোঁট শুকনো', 'পানিশূন্য',
        'sunken eyes', 'dehydration', 'dry lips'],
        questionId: 'c5', answer: true, label: 'পানিশূন্যতা'),

      _SymptomRule(triggers: ['ওজন কম', 'শুকিয়ে গেছে', 'রোগা', 'weight loss',
        'wasting', 'thin'],
        questionId: 'c6', answer: true, label: 'ওজন কম'),
    ],

    'pregnancy': [
      _SymptomRule(triggers: ['মাথা ব্যথা', 'মাথা ধরেছে', 'রক্তচাপ', 'বিপি',
        'headache', 'bp high', 'blood pressure'],
        questionId: 'p1', answer: true, label: 'মাথা ব্যথা/উচ্চ রক্তচাপ'),

      _SymptomRule(triggers: ['পা ফুলেছে', 'মুখ ফুলেছে', 'ফোলা', 'swelling',
        'oedema', 'পা ফুলে'],
        questionId: 'p2', answer: true, label: 'ফোলা'),

      _SymptomRule(triggers: ['রক্তপাত', 'রক্ত পড়ছে', 'পেট ব্যথা', 'bleeding',
        'abdominal pain', 'রক্ত যাচ্ছে'],
        questionId: 'p3', answer: true, label: 'রক্তপাত/পেট ব্যথা'),

      _SymptomRule(triggers: ['বাচ্চা নড়ছে না', 'নড়াচড়া কম', 'বাচ্চা নড়ে না',
        'fetal movement', 'baby not moving', 'কম নড়ছে'],
        questionId: 'p4', answer: true, label: 'বাচ্চার নড়াচড়া কম'),

      _SymptomRule(triggers: ['checkup হয়নি', 'anc মিস', 'checkup বাদ',
        'missed anc', 'no checkup'],
        questionId: 'p5', answer: true, label: 'ANC মিস'),

      _SymptomRule(triggers: ['চোখে ঝাপসা', 'ঝাপসা দেখছে', 'মাথা ঘুরছে',
        'blurred vision', 'dizziness', 'চোখ ঝাপসা'],
        questionId: 'p6', answer: true, label: 'ঝাপসা দৃষ্টি/মাথা ঘোরা'),
    ],

    'delivery_pnc': [
      _SymptomRule(triggers: ['রক্তপাত', 'রক্ত পড়ছে', 'দুর্গন্ধ স্রাব', 'bleeding',
        'foul discharge', 'অনেক রক্ত'],
        questionId: 'pp1', answer: true, label: 'রক্তপাত/দুর্গন্ধ স্রাব'),

      _SymptomRule(triggers: ['জ্বর', 'ঠান্ডা লাগছে', 'কাঁপছে', 'fever', 'chills'],
        questionId: 'pp2', answer: true, label: 'জ্বর'),

      _SymptomRule(triggers: ['স্তন ব্যথা', 'বুকে ব্যথা', 'স্তন ফুলেছে', 'breast pain',
        'mastitis', 'দুধ জমেছে'],
        questionId: 'pp3', answer: true, label: 'স্তনে ব্যথা'),

      _SymptomRule(triggers: ['পেট ব্যথা', 'সেলাই', 'ক্ষত', 'abdominal pain',
        'wound', 'suture'],
        questionId: 'pp4', answer: true, label: 'পেট ব্যথা/সেলাই'),

      _SymptomRule(triggers: ['প্রস্রাবে জ্বালা', 'প্রস্রাব কষ্ট', 'burning urination',
        'uti', 'dysuria'],
        questionId: 'pp5', answer: true, label: 'প্রস্রাবে জ্বালা'),

      _SymptomRule(triggers: ['দুর্বল', 'মাথা ঘুরছে', 'ফ্যাকাশে', 'weakness',
        'dizziness', 'pallor', 'অনেক দুর্বল'],
        questionId: 'pp6', answer: true, label: 'দুর্বলতা'),
    ],

    'immunisation': [],
    'emergency': [
      _SymptomRule(triggers: ['রক্ত থামছে না', 'অনেক রক্ত', 'রক্তপাত', 'bleeding',
        'haemorrhage'],
        questionId: 'e1', answer: true, label: 'রক্তপাত'),

      _SymptomRule(triggers: ['খিঁচুনি', 'অজ্ঞান', 'seizure', 'unconscious',
        'convulsion', 'চোখ উল্টে'],
        questionId: 'e2', answer: true, label: 'খিঁচুনি/অজ্ঞান'),

      _SymptomRule(triggers: ['শ্বাস বন্ধ', 'দম বন্ধ', 'শ্বাস নিতে পারছে না',
        'not breathing', 'respiratory distress'],
        questionId: 'e3', answer: true, label: 'শ্বাস বন্ধ'),

      _SymptomRule(triggers: ['সাড়া নেই', 'জ্ঞান নেই', 'unresponsive', 'unconscious'],
        questionId: 'e4', answer: true, label: 'সাড়া নেই'),
    ],
  };

  /// Extracts pre-answers from a situation description for a given module.
  SituationExtraction extract({
    required String situation,
    required String moduleId,
  }) {
    if (situation.trim().isEmpty) {
      return const SituationExtraction(preAnswers: {}, extractedSymptoms: []);
    }

    final text = situation.toLowerCase();
    final rules = _moduleMap[moduleId] ?? [];
    final preAnswers = <String, bool>{};
    final extractedSymptoms = <String>[];

    for (final rule in rules) {
      for (final trigger in rule.triggers) {
        if (text.contains(trigger.toLowerCase())) {
          preAnswers[rule.questionId] = rule.answer;
          if (!extractedSymptoms.contains(rule.label)) {
            extractedSymptoms.add(rule.label);
          }
          break; // one match per rule is enough
        }
      }
    }

    return SituationExtraction(
      preAnswers: preAnswers,
      extractedSymptoms: extractedSymptoms,
    );
  }
}

class _SymptomRule {
  final List<String> triggers;
  final String questionId;
  final bool answer;
  final String label;

  const _SymptomRule({
    required this.triggers,
    required this.questionId,
    required this.answer,
    required this.label,
  });
}
