// ─────────────────────────────────────────────────────────────────────────────
// CLUP Layer 1 — Intent Detector — Gap 2 Fix
//
// Full dialect coverage:
//   West Bengal: Rarhi, Varendra (Murshidabad/Malda), Medinipur, Cooch Behar,
//                Sundarbans, North Bengal
//   All-India:   Hindi, Bhojpuri, Chhattisgarhi, Odia, Santali, Sadri
//   Transliterated Bengali/Hindi in Roman script
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
  final double confidence;
  final List<String> matchedTokens;
  final String? extractedClinicalSegment;
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
  // ── Emergency tokens ─────────────────────────────────────────────────────
  static const _emergencyTokens = [
    // Standard Bengali
    'খিঁচুনি', 'খিচুনি', 'কাঁপছে', 'কাঁপুনি', 'ঝাঁকুনি',
    'অজ্ঞান', 'জ্ঞান নেই', 'সাড়া নেই', 'চোখ উল্টে', 'চোখ উল্টানো',
    'শ্বাস বন্ধ', 'দম বন্ধ', 'শ্বাস নিতে পারছে না', 'নীল হয়ে',
    'রক্ত থামছে না', 'অনেক রক্ত', 'রক্তক্ষরণ',
    'নড়ছে না একদম', 'মরে গেছে', 'মরে যাচ্ছে',
    // Rarhi (Birbhum, Burdwan, Bankura, Hooghly)
    'খিঁচুনি হইছে', 'খিচুনি দিছে', 'অজ্ঞান হয়ে গেছে', 'জ্ঞান নাই',
    'সাড়া দিতেছে না', 'সাড়া নাই', 'শ্বাস বন্ধ হয়ে গেছে',
    'দম বন্ধ হয়ে গেছে', 'রক্ত থামতেছে না', 'কাঁপতেছে',
    'চোখ উল্টে গেছে', 'নীল হয়ে গেছে',
    // Medinipur / Jhargram
    'খিঁচুনি হচ্ছে গো', 'অজ্ঞান হয়ে গেছে গো', 'সাড়া নেই গো',
    'শ্বাস বন্ধ হয়ে গেছে গো', 'রক্ত থামছে না গো',
    // Murshidabad / Malda (Varendra)
    'খিঁচুনি হইছে', 'অজ্ঞান হইয়া গেছে', 'জ্ঞান নাই',
    'শ্বাস বন্ধ হইয়া গেছে', 'রক্ত থামতেছে না',
    // Cooch Behar / North Bengal
    'খিঁচুনি উঠছে', 'অজ্ঞান হইছে', 'সাড়া নাই',
    // Sundarbans
    'খিঁচুনি হইছে রে', 'অজ্ঞান রে', 'সাড়া নাই রে',
    // Hindi / Bhojpuri
    'mirgi', 'behosh', 'hosh nahi', 'aankhein palat gayi', 'kaanp raha',
    'sans band', 'dam ghut gaya', 'khoon band nahi', 'khoon ruk nahi raha',
    'behosh ho gaili', 'mirgi aagel', 'sans band ho gaili',
    // Chhattisgarhi
    'mirgi aagel', 'behosh ho gis', 'sans band ho gis',
    // Odia
    'khichuni', 'behosh hoi gala', 'nishwas bandi', 'rakta bandha heunahin',
    // Santali / Sadri
    'khichuni', 'behosh', 'sans nai aata',
    // English / transliterated
    'unconscious', 'seizure', 'convulsion', 'not breathing', 'fits',
    'khichuni', 'behosh', 'sans nahi', 'khoon band nahi',
  ];

  // ── Clinical symptom tokens ───────────────────────────────────────────────
  static const _clinicalTokens = [
    // Standard Bengali
    'জ্বর', 'জ্বর আছে', 'গা গরম', 'গা পুড়ছে', 'তাপ আছে',
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
    'ব্যথা', 'যন্ত্রণা', 'কষ্ট হচ্ছে',
    // Rarhi dialect variants
    'জ্বর আইছে', 'জ্বর উঠছে', 'জ্বর হইছে', 'গা জ্বলছে', 'গা জ্বলতেছে',
    'মাথা ব্যথা করছে', 'মাথা ধরছে', 'মাথা ঘুরাইতেছে', 'মাথা ঘুরতেছে',
    'বমি হইছে', 'বমি করতেছে', 'বমি উঠছে',
    'পেটে ব্যথা হচ্ছে', 'পেট ব্যথা করছে', 'পেট কামড়াইতেছে',
    'শ্বাস নিতে পারতেছে না', 'দম নিতে পারছে না', 'শ্বাস আটকে যাচ্ছে',
    'কাশতেছে', 'কাশি উঠছে', 'কাশি হইছে',
    'রক্ত পড়তেছে', 'রক্ত যাইতেছে',
    'পা ফুলছে', 'মুখ ফুলছে', 'পা ফুলে গেছে',
    'দুর্বল হয়ে গেছে', 'শক্তি নাই',
    'দুধ খাইতেছে না', 'দুধ খায় না', 'দুধ ধরছে না',
    'নড়তেছে না', 'ঢিলা হয়ে গেছে', 'নিস্তেজ হয়ে গেছে',
    'চোখ গর্তে ঢুকে গেছে', 'ঠোঁট শুকাইয়া গেছে',
    'প্রস্রাবে জ্বালা করছে', 'প্রস্রাব করতে কষ্ট হচ্ছে',
    'নাভি পেকেছে', 'নাভিতে ঘা', 'নাভি থেকে পুঁজ পড়ছে',
    'গা হলদে হয়ে গেছে', 'চোখ হলদে',
    // Medinipur / Jhargram
    'জ্বর হচ্ছে গো', 'গা গরম গো', 'মাথা ব্যথা হচ্ছে গো',
    'বমি হচ্ছে গো', 'পেট ব্যথা হচ্ছে গো', 'কাশছে গো',
    'রক্ত পড়ছে গো', 'পা ফুলেছে গো', 'দুর্বল হয়ে গেছে গো',
    'দুধ খাচ্ছে না গো', 'নড়ছে না গো', 'ঠোঁট শুকনো গো',
    // Murshidabad / Malda (Varendra)
    'জ্বর আইছে', 'মাথা ব্যথা আছে', 'বমি হইতেছে',
    'পেটে ব্যথা আছে', 'কাশতেছে', 'রক্ত পড়তেছে',
    'পা ফুলছে', 'দুর্বল হইয়া গেছে', 'দুধ খাইছে না',
    'নড়তেছে না', 'ঠোঁট শুকাইছে',
    // Cooch Behar / North Bengal
    'জ্বর উঠছে', 'মাথা ব্যথা করছে', 'বমি হচ্ছে',
    'পেটে ব্যথা', 'কাশছে', 'পা ফুলছে',
    // Sundarbans
    'জ্বর আইছে রে', 'গা গরম রে', 'মাথা ব্যথা রে',
    // Hindi / Bhojpuri
    'bukhar', 'bukhaar', 'jwar', 'jor', 'tap', 'garmi',
    'sir dard', 'sar dard', 'matha dard',
    'ulti', 'vomit', 'ulti ho rahi', 'pet mein dard', 'pet dard',
    'saans ki takleef', 'sans lene mein takleef', 'dam phool raha',
    'khansi', 'khaansi',
    'khoon aa raha', 'khoon nikal raha',
    'pair sooja', 'munh sooja', 'sujan',
    'kamzor', 'takat nahi',
    'doodh nahi', 'doodh nahi pi raha',
    'hilta nahi', 'dhila ho gaya',
    'aankhein andar dhans gayi', 'honth sukhe',
    'peshab mein jalan',
    'naaf mein pus', 'naaf lal',
    'peela ho gaya', 'aankhein peeli', 'piliya',
    // Chhattisgarhi
    'bukhar aaye', 'matha dukhath', 'pet dukhath', 'khansi aagel',
    'khoon aavat hae', 'sujan aagel',
    // Odia
    'jara', 'jwara', 'tapa', 'matha byatha', 'banti', 'jhada',
    'nishwas neba kathin', 'khansi', 'rakta paruchi',
    'pada phulichi', 'durbala', 'dudha khaucha nahi',
    'nuhale nahi', 'thota shukhi gala', 'prastab re jwala',
    'nabhi lal', 'pita hoi gala',
    // Santali / Sadri
    'duku', 'jor', 'tap', 'pet dard', 'khansi', 'khoon',
    'sujan', 'kamzor', 'doodh nai', 'hilta nai',
    // English / transliterated
    'fever', 'headache', 'vomiting', 'stomach pain', 'breathing difficulty',
    'cough', 'bleeding', 'swelling', 'weakness', 'not feeding',
    'not moving', 'lethargic', 'sunken eyes', 'dry lips',
    'burning urination', 'jaundice', 'yellow skin', 'cyanosis',
    'blood', 'pain', 'diarrhea', 'diarrhoea',
    // Transliterated Bengali
    'jor', 'matha byatha', 'bomi', 'pet byatha', 'shwaskoshto',
    'kashi', 'roktopat', 'fola', 'durbolta', 'nistej',
  ];

  // ── Vague clinical tokens ─────────────────────────────────────────────────
  static const _vagueTokens = [
    // Standard Bengali
    'শরীর খারাপ', 'শরীর ভালো না', 'অসুস্থ', 'অসুখ',
    'কিছু একটা হচ্ছে', 'ঠিক নেই', 'ভালো লাগছে না',
    'সমস্যা আছে', 'কষ্ট হচ্ছে', 'কষ্ট পাচ্ছে',
    'মনে হচ্ছে কিছু একটা', 'একটু অসুবিধা',
    // Rarhi
    'শরীর ভালো নাই', 'শরীর খারাপ লাগছে', 'ভালো লাগতেছে না',
    'কষ্ট হইতেছে', 'সমস্যা হইছে', 'ঠিক নাই',
    // Medinipur
    'শরীর ভালো না গো', 'কষ্ট হচ্ছে গো', 'ঠিক নেই গো',
    // Murshidabad
    'শরীর ভালো নাই', 'কষ্ট হইতেছে',
    // Hindi / Bhojpuri
    'tabiyat theek nahi', 'theek nahi', 'problem hai', 'takleef',
    'kuch ho raha', 'achha nahi lag raha', 'tabiyat kharab',
    'tabiyat theek naikhe',
    // Chhattisgarhi
    'tabiyat theek nai hae', 'kuch ho gis',
    // Odia
    'sharira kharap', 'bhala nahi', 'kichhi heucha',
    // Sadri
    'tabiyat theek nai', 'kuch ho raha',
    // English
    'not feeling well', 'something wrong', 'not good', 'unwell',
  ];

  // ── Non-clinical tokens ───────────────────────────────────────────────────
  static const _nonClinicalTokens = [
    // Financial
    'salary', 'বেতন', 'টাকা', 'পয়সা', 'ব্যাংক', 'loan', 'ঋণ',
    'কেনাকাটা', 'বাজার', 'দাম', 'দোকান', 'paisa', 'paise',
    // Weather — but NOT 'গরম' alone (could be fever)
    'বৃষ্টি', 'রোদ', 'আবহাওয়া', 'ঝড়', 'mausam', 'barish',
    // Social
    'বিয়ে', 'অনুষ্ঠান', 'পার্টি', 'উৎসব', 'ঈদ', 'পূজা',
    'স্কুল', 'পরীক্ষা', 'রেজাল্ট', 'চাকরি', 'অফিস',
    'shaadi', 'school', 'naukri',
    // Positive wellbeing
    'ভালো আছি', 'সুস্থ আছি', 'ঠিক আছি', 'কোনো সমস্যা নেই',
    'sab theek hai', 'bilkul theek',
  ];

  // ── Third-party markers ───────────────────────────────────────────────────
  static const _thirdPartyMarkers = [
    // Standard Bengali
    'স্বামীর', 'স্বামী অসুস্থ', 'ছেলের', 'মেয়ের', 'বাবার', 'মায়ের',
    'শাশুড়ির', 'পাশের বাড়ির', 'প্রতিবেশীর',
    // Rarhi
    'স্বামীর জ্বর', 'ছেলের জ্বর', 'মেয়ের জ্বর', 'বাবার অসুখ',
    // Murshidabad
    'স্বামীর অসুখ', 'ছেলের অসুখ',
    // Hindi
    'pati ko', 'pati ki', 'bete ko', 'beti ko', 'maa ko', 'baap ko',
    'padosi ko', 'husband ko', 'neighbor ko',
    // English
    'my husband', 'my son', 'my daughter', 'my mother', 'my father',
    'neighbour', 'neighbor',
  ];

  // ── Conjunction splitters ─────────────────────────────────────────────────
  static const _conjunctions = [
    'কিন্তু', 'তবে', 'আর', 'এবং', 'but', 'however', 'and',
    'kintu', 'tobe', 'ar', 'ebong', 'lekin', 'aur', 'magar',
  ];

  // ── Main classify ─────────────────────────────────────────────────────────
  IntentResult classify(String input, {String? moduleId}) {
    final text = input.trim().toLowerCase();
    if (text.isEmpty) {
      return IntentResult(intent: IntentClass.unclear, confidence: 1.0, matchedTokens: []);
    }

    // Step 1: Emergency — highest priority
    final emergencyMatches = _matchTokens(text, _emergencyTokens);
    if (emergencyMatches.isNotEmpty) {
      return IntentResult(
        intent: IntentClass.emergency,
        confidence: 0.97,
        matchedTokens: emergencyMatches,
      );
    }

    // Step 2: Third-party check
    final thirdPartyMatches = _matchTokens(text, _thirdPartyMarkers);
    if (thirdPartyMatches.isNotEmpty) {
      final selfClinical = _matchTokens(text, _clinicalTokens);
      if (selfClinical.isEmpty) {
        return IntentResult(
          intent: IntentClass.thirdParty,
          confidence: 0.92,
          matchedTokens: thirdPartyMatches,
        );
      }
      return IntentResult(
        intent: IntentClass.clinicalSymptom,
        confidence: 0.75,
        matchedTokens: selfClinical,
        ignoredSegment: thirdPartyMatches.join(', '),
      );
    }

    // Step 3: Mixed sentence splitting
    final segments = _splitOnConjunctions(text);
    if (segments.length > 1) {
      final clinicalSegments = <String>[];
      final ignoredSegments = <String>[];
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

    // Step 4: Non-clinical check
    final nonClinicalMatches = _matchTokens(text, _nonClinicalTokens);
    final clinicalMatches = _matchTokens(text, _clinicalTokens);
    if (nonClinicalMatches.isNotEmpty && clinicalMatches.isEmpty) {
      return IntentResult(
        intent: IntentClass.nonClinical,
        confidence: _scoreConfidence(nonClinicalMatches, text),
        matchedTokens: nonClinicalMatches,
      );
    }

    // Step 5: Clinical symptom
    if (clinicalMatches.isNotEmpty) {
      return IntentResult(
        intent: IntentClass.clinicalSymptom,
        confidence: _scoreConfidence(clinicalMatches, text),
        matchedTokens: clinicalMatches,
      );
    }

    // Step 6: Vague clinical
    final vagueMatches = _matchTokens(text, _vagueTokens);
    if (vagueMatches.isNotEmpty) {
      return IntentResult(
        intent: IntentClass.clinicalVague,
        confidence: _scoreConfidence(vagueMatches, text),
        matchedTokens: vagueMatches,
      );
    }

    // Step 7: Unclear
    return IntentResult(intent: IntentClass.unclear, confidence: 0.5, matchedTokens: []);
  }

  List<String> _matchTokens(String text, List<String> tokens) {
    final matched = <String>[];
    for (final token in tokens) {
      if (text.contains(token.toLowerCase())) matched.add(token);
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
