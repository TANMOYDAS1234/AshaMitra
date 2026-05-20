// ─────────────────────────────────────────────────────────────────────────────
// CLUP Layer 1 — Intent Detector
//
// Classifies raw speech BEFORE any symptom extraction.
// Prevents non-clinical speech from polluting clinical state.
//
// Intent classes:
//   clinical_symptom   — describes a physical symptom
//   emergency          — describes an emergency danger sign
//   clinical_vague     — medically relevant but needs clarification
//   non_clinical       — salary, weather, family news, small talk
//   administrative     — asking about appointment, medicine name, etc.
//   third_party        — symptom belongs to someone else ("স্বামীর জ্বর")
//   unclear            — cannot determine intent
// ─────────────────────────────────────────────────────────────────────────────

enum IntentClass {
  clinicalSymptom,
  emergency,
  clinicalVague,
  nonClinical,
  administrative,
  thirdParty,
  unclear,
}

class IntentResult {
  final IntentClass intent;
  final double confidence;       // 0.0 – 1.0
  final List<String> matchedTokens;
  final String? extractedClinicalSegment; // non-null if mixed sentence
  final String? ignoredSegment;

  const IntentResult({
    required this.intent,
    required this.confidence,
    required this.matchedTokens,
    this.extractedClinicalSegment,
    this.ignoredSegment,
  });

  bool get isClinical =>
      intent == IntentClass.clinicalSymptom ||
      intent == IntentClass.emergency ||
      intent == IntentClass.clinicalVague;

  bool get isEmergency => intent == IntentClass.emergency;
  bool get needsClarification => intent == IntentClass.clinicalVague;
  bool get isNonClinical => intent == IntentClass.nonClinical;
  bool get isThirdParty => intent == IntentClass.thirdParty;

  Map<String, dynamic> toMap() => {
    'intent': intent.name,
    'confidence': confidence,
    'matched_tokens': matchedTokens,
    'extracted_clinical_segment': extractedClinicalSegment,
    'ignored_segment': ignoredSegment,
  };
}

class IntentDetector {
  // ── Emergency tokens — highest priority, checked first ───────────────────
  static const _emergencyTokens = [
    // Bengali
    'খিঁচুনি', 'খিচুনি', 'কাঁপছে', 'কাঁপুনি', 'ঝাঁকুনি',
    'অজ্ঞান', 'জ্ঞান নেই', 'সাড়া নেই', 'চোখ উল্টে', 'চোখ উল্টানো',
    'শ্বাস বন্ধ', 'দম বন্ধ', 'শ্বাস নিতে পারছে না', 'নীল হয়ে',
    'রক্ত থামছে না', 'অনেক রক্ত', 'রক্ত পড়ছে', 'রক্তক্ষরণ',
    'নাড়ছে না', 'নড়ছে না একদম', 'মরে গেছে', 'মরে যাচ্ছে',
    // Hinglish / transliterated
    'khichuni', 'behosh', 'sans nahi', 'khoon band nahi',
    'unconscious', 'seizure', 'convulsion', 'not breathing',
  ];

  // ── Clinical symptom tokens ───────────────────────────────────────────────
  static const _clinicalTokens = [
    // Bengali symptoms
    'জ্বর', 'জ্বর আছে', 'গা গরম', 'গা পুড়ছে', 'গা পুড়ে যাচ্ছে',
    'মাথা ব্যথা', 'মাথা ধরেছে', 'মাথা ঘুরছে', 'মাথা ঘোরা',
    'বমি', 'বমি হচ্ছে', 'বমি বমি', 'বমি করছে',
    'পেট ব্যথা', 'পেট শক্ত', 'পেটে ব্যথা', 'পেট কামড়াচ্ছে',
    'শ্বাসকষ্ট', 'শ্বাস কষ্ট', 'শ্বাস নিতে কষ্ট', 'শ্বাস টান',
    'কাশি', 'কাশছে', 'কাশি হচ্ছে',
    'রক্তপাত', 'রক্ত পড়ছে', 'রক্ত যাচ্ছে',
    'ফুলে গেছে', 'ফোলা', 'পা ফুলেছে', 'মুখ ফুলেছে',
    'দুর্বল', 'দুর্বলতা', 'শক্তি নেই', 'উঠতে পারছে না',
    'খেতে পারছে না', 'খাচ্ছে না', 'দুধ খাচ্ছে না', 'দুধ টানছে না',
    'নড়ছে না', 'কম নড়ছে', 'নড়াচড়া কম',
    'ঢিলে', 'ঢিলে হয়ে গেছে', 'নিস্তেজ', 'নেতিয়ে পড়েছে',
    'চোখ গর্তে', 'চোখ বসে গেছে', 'ঠোঁট শুকনো',
    'প্রস্রাব কম', 'প্রস্রাব নেই', 'প্রস্রাবে জ্বালা',
    'ঘা', 'ক্ষত', 'পুঁজ', 'নাভি লাল', 'নাভি ফুলেছে',
    'হলুদ', 'জন্ডিস', 'চোখ হলুদ', 'গা হলুদ',
    'নীল', 'নীলাভ', 'ঠোঁট নীল',
    'ব্যথা', 'যন্ত্রণা', 'কষ্ট হচ্ছে', 'সমস্যা হচ্ছে',
    // Hinglish / transliterated
    'jor', 'jwar', 'bukhar', 'fever', 'sir dard', 'headache',
    'ulti', 'vomit', 'pet dard', 'stomach pain', 'sans', 'breathing',
    'khoon', 'blood', 'sujan', 'swelling', 'kamzor', 'weak',
    'doodh nahi', 'khana nahi', 'hilna nahi',
  ];

  // ── Vague clinical tokens — medically relevant but unclear ────────────────
  static const _vagueTokens = [
    'শরীর খারাপ', 'শরীর ভালো না', 'অসুস্থ', 'অসুখ',
    'কিছু একটা হচ্ছে', 'ঠিক নেই', 'ভালো লাগছে না',
    'সমস্যা আছে', 'কষ্ট হচ্ছে', 'কষ্ট পাচ্ছে',
    'মনে হচ্ছে কিছু একটা', 'একটু অসুবিধা',
    'tabiyat theek nahi', 'theek nahi', 'problem hai', 'takleef',
    'not feeling well', 'something wrong',
  ];

  // ── Non-clinical tokens — irrelevant to medicine ──────────────────────────
  static const _nonClinicalTokens = [
    // Financial
    'salary', 'বেতন', 'টাকা', 'পয়সা', 'ব্যাংক', 'loan', 'ঋণ',
    'কেনাকাটা', 'বাজার', 'দাম', 'দোকান',
    // Weather
    'বৃষ্টি', 'রোদ', 'গরম', 'ঠান্ডা', 'আবহাওয়া', 'ঝড়',
    // Social / family news (non-health)
    'বিয়ে', 'অনুষ্ঠান', 'পার্টি', 'উৎসব', 'ঈদ', 'পূজা',
    'স্কুল', 'পরীক্ষা', 'রেজাল্ট', 'চাকরি', 'অফিস',
    // Positive wellbeing (not a symptom)
    'ভালো আছি', 'সুস্থ আছি', 'ঠিক আছি', 'কোনো সমস্যা নেই',
    // Hinglish non-clinical
    'paisa', 'naukri', 'mausam', 'barish', 'shaadi', 'school',
  ];

  // ── Third-party markers — symptom belongs to someone else ─────────────────
  static const _thirdPartyMarkers = [
    'স্বামীর', 'স্বামীর জ্বর', 'স্বামী অসুস্থ',
    'ছেলের', 'মেয়ের', 'বাবার', 'মায়ের', 'শাশুড়ির',
    'পাশের বাড়ির', 'প্রতিবেশীর',
    'পति को', 'बच्चे को', 'husband ko', 'neighbor ko',
    'my husband', 'my son', 'my daughter', 'my mother',
  ];

  // ── Conjunction splitters — split mixed sentences ─────────────────────────
  static const _conjunctions = [
    'কিন্তু', 'তবে', 'আর', 'এবং', 'but', 'however', 'and',
    'kintu', 'tobe', 'ar', 'ebong',
  ];

  // ── Main classify method ──────────────────────────────────────────────────
  IntentResult classify(String input, {String? moduleId}) {
    final text = input.trim().toLowerCase();
    if (text.isEmpty) {
      return IntentResult(
        intent: IntentClass.unclear,
        confidence: 1.0,
        matchedTokens: [],
      );
    }

    // ── Step 1: Emergency check — highest priority ────────────────────────
    final emergencyMatches = _matchTokens(text, _emergencyTokens);
    if (emergencyMatches.isNotEmpty) {
      return IntentResult(
        intent: IntentClass.emergency,
        confidence: 0.97,
        matchedTokens: emergencyMatches,
      );
    }

    // ── Step 2: Third-party check ─────────────────────────────────────────
    final thirdPartyMatches = _matchTokens(text, _thirdPartyMarkers);
    if (thirdPartyMatches.isNotEmpty) {
      // Check if there's also a self-symptom in the same sentence
      final selfClinical = _matchTokens(text, _clinicalTokens);
      if (selfClinical.isEmpty) {
        return IntentResult(
          intent: IntentClass.thirdParty,
          confidence: 0.92,
          matchedTokens: thirdPartyMatches,
        );
      }
      // Mixed: third-party + self symptom — extract self part
      return IntentResult(
        intent: IntentClass.clinicalSymptom,
        confidence: 0.75,
        matchedTokens: selfClinical,
        ignoredSegment: thirdPartyMatches.join(', '),
      );
    }

    // ── Step 3: Mixed sentence splitting ─────────────────────────────────
    final segments = _splitOnConjunctions(text);
    if (segments.length > 1) {
      final clinicalSegments = <String>[];
      final ignoredSegments  = <String>[];
      final allClinicalTokens = <String>[];

      for (final seg in segments) {
        final cTokens = _matchTokens(seg, _clinicalTokens);
        final ncTokens = _matchTokens(seg, _nonClinicalTokens);
        if (cTokens.isNotEmpty) {
          clinicalSegments.add(seg);
          allClinicalTokens.addAll(cTokens);
        } else if (ncTokens.isNotEmpty) {
          ignoredSegments.add(seg);
        }
      }

      if (clinicalSegments.isNotEmpty) {
        return IntentResult(
          intent: IntentClass.clinicalSymptom,
          confidence: 0.85,
          matchedTokens: allClinicalTokens,
          extractedClinicalSegment: clinicalSegments.join(' '),
          ignoredSegment: ignoredSegments.join(' | '),
        );
      }
    }

    // ── Step 4: Non-clinical check ────────────────────────────────────────
    final nonClinicalMatches = _matchTokens(text, _nonClinicalTokens);
    final clinicalMatches    = _matchTokens(text, _clinicalTokens);

    if (nonClinicalMatches.isNotEmpty && clinicalMatches.isEmpty) {
      return IntentResult(
        intent: IntentClass.nonClinical,
        confidence: _scoreConfidence(nonClinicalMatches, text),
        matchedTokens: nonClinicalMatches,
      );
    }

    // ── Step 5: Clinical symptom check ───────────────────────────────────
    if (clinicalMatches.isNotEmpty) {
      return IntentResult(
        intent: IntentClass.clinicalSymptom,
        confidence: _scoreConfidence(clinicalMatches, text),
        matchedTokens: clinicalMatches,
      );
    }

    // ── Step 6: Vague clinical check ─────────────────────────────────────
    final vagueMatches = _matchTokens(text, _vagueTokens);
    if (vagueMatches.isNotEmpty) {
      return IntentResult(
        intent: IntentClass.clinicalVague,
        confidence: _scoreConfidence(vagueMatches, text),
        matchedTokens: vagueMatches,
      );
    }

    // ── Step 7: Unclear ───────────────────────────────────────────────────
    return IntentResult(
      intent: IntentClass.unclear,
      confidence: 0.5,
      matchedTokens: [],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  List<String> _matchTokens(String text, List<String> tokens) {
    final matched = <String>[];
    for (final token in tokens) {
      if (text.contains(token.toLowerCase())) {
        matched.add(token);
      }
    }
    return matched;
  }

  List<String> _splitOnConjunctions(String text) {
    var result = [text];
    for (final conj in _conjunctions) {
      final newResult = <String>[];
      for (final seg in result) {
        newResult.addAll(seg.split(conj));
      }
      result = newResult;
    }
    return result.map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }

  double _scoreConfidence(List<String> matched, String text) {
    final wordCount = text.split(RegExp(r'\s+')).length;
    final matchRatio = matched.length / wordCount.clamp(1, 100);
    return (0.6 + matchRatio * 0.4).clamp(0.0, 1.0);
  }
}
