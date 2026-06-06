// ─────────────────────────────────────────────────────────────────────────────
// RuleBasedIntentClassifier — offline-first action intent matching with
// smart keyword / synonym / stem matching (not just substring).
//
// Why this exists:
//   The assistant should be able to execute common app actions (call
//   ambulance, find nearest PHC, add patient, open reports etc.) without
//   needing a network round-trip to Gemini. ASHA workers live in areas
//   with patchy 2G/3G signal, and a 5-second wait every time they say
//   "open patients" would make the assistant feel broken. Rule-based
//   matching gives <50 ms response and works fully offline.
//
// How matching works (v2):
//   Each intent declares N "keyword groups". A keyword group is a list
//   of synonyms — Bengali / Hindi / English / Banglish words that all
//   mean the same thing (e.g. {রোগী, রুগী, পেশেন্ট, मरीज़, mariz,
//   patient}). Matching is:
//
//     1. Normalize input — lowercase, collapse whitespace, soft-strip
//        common Bengali/Hindi verb suffixes (করো → কর, দেখাও → দেখ).
//     2. For each intent, count how many of its keyword groups have at
//        least one synonym appearing anywhere in the normalized input.
//     3. Intent matches if the matched-group count >= minGroupsMatched
//        (default 2). The intent with the highest matched-ratio wins.
//
//   This makes the matcher flexible:
//     "এই নতুন রোগীকে এক্ষুনি যোগ করতে চাই" → "নতুন" + "রোগী" + "যোগ"
//        all hit different groups → addPatient
//     "পেশেন্টের লিস্ট খোলো" → "পেশেন্ট" + "লিস্ট" + "খোল" → openPatientList
//     "একটা অ্যাম্বুলেন্স ডাকো এখনই" → "অ্যাম্বুলেন্স" + "ডাক" → callAmbulance
//
//   The substring-based v1 patterns rejected all three.
// ─────────────────────────────────────────────────────────────────────────────

import 'assistant_chat_service.dart' show AssistantLang;

/// Actions the assistant can dispatch without going through the LLM.
/// [unknown] means rule matching didn't find a confident hit — caller
/// should fall through to the LLM-based path.
enum AssistantIntent {
  callAmbulance,
  findNearestPHC,
  openEmergency,
  addPatient,
  openPatientList,
  openReports,
  openProfile,
  startTriage,
  openHome,
  goBack,
  unknown,
}

/// Result of a classification attempt. [confidence] is a rough 0..1
/// score; rule matches floor at 0.45 so the assistant treats any
/// rule match as strong evidence to dispatch.
class ClassifiedIntent {
  final AssistantIntent intent;
  final double confidence;
  final String matchedPattern;

  const ClassifiedIntent({
    required this.intent,
    required this.confidence,
    this.matchedPattern = '',
  });

  static const unknown = ClassifiedIntent(
    intent: AssistantIntent.unknown,
    confidence: 0.0,
  );

  bool get isHandled => intent != AssistantIntent.unknown;
}

/// One declarative rule: an intent + N keyword groups (synonym sets).
/// Matches when at least [minGroupsMatched] groups each have one
/// synonym hit anywhere in the normalized input.
class _IntentRule {
  final AssistantIntent intent;
  final List<List<String>> keywordGroups;
  final int minGroupsMatched;

  const _IntentRule({
    required this.intent,
    required this.keywordGroups,
    this.minGroupsMatched = 2,
  });
}

class RuleBasedIntentClassifier {
  /// Synonym sets per intent. Each inner list is a "group" — one hit
  /// from anywhere in the list counts as matching that group. The
  /// intent fires when [minGroupsMatched] (default 2) groups all
  /// have at least one hit. Lower the count to 1 for single-word
  /// commands (emergency, home, back).
  ///
  /// Coverage convention per group:
  ///   - pure Bengali (script + stem after suffix-strip)
  ///   - pure Hindi (Devanagari + stem)
  ///   - English + Banglish (Romanized Bengali/Hindi as a worker
  ///     might type or speak when code-switching)
  ///   - common numerals where relevant (102 / ১০২ / १०२)
  static final List<_IntentRule> _rules = [
    _IntentRule(
      intent: AssistantIntent.callAmbulance,
      keywordGroups: [
        [
          // Explicit ambulance words ONLY. Numerals (102 / 108) are
          // deliberately NOT triggers — they collide with spoken
          // temperatures ("102 জ্বর"), BP and counts, and were causing the
          // assistant to dial an ambulance on ordinary fever questions.
          // The old call-verb group (কল / ডাক / ফোন) was also removed: the
          // 2-char verbs matched inside unrelated words (থাকলে → কল), and
          // the explicit ambulance word is unambiguous on its own.
          'অ্যাম্বুলেন্স', 'এম্বুলেন্স', 'এম্বুলান্স',
          'एम्बुलेंस', 'एंबुलेंस', 'ऐम्बुलेंस',
          'ambulance',
        ],
      ],
      minGroupsMatched: 1,
    ),
    _IntentRule(
      intent: AssistantIntent.findNearestPHC,
      // 3 groups, any 2 fire it: proximity+facility, facility+distance, or
      // proximity+distance. Covers "কাছের হাসপাতাল", "হাসপাতালে পৌঁছাতে
      // কতক্ষণ", "নিয়ারেস্ট হসপিটাল কতদূর" — all route to the live map
      // instead of the LLM inventing a distance.
      keywordGroups: [
        [
          // proximity
          'কাছের', 'কাছাকাছি', 'নিকটতম', 'নিকটস্থ', 'নিকটবর্তী', 'আশেপাশে', 'আশপাশ', 'নিয়ারেস্ট',
          'पास', 'नज़दीकी', 'नजदीकी', 'सबसे पास', 'आसपास',
          'nearest', 'closest', 'near', 'nearby',
        ],
        [
          // facility — include the transliterations workers actually say
          'হাসপাতাল', 'হসপিটাল', 'স্বাস্থ্য কেন্দ্র', 'স্বাস্থ্যকেন্দ্র', 'হেলথ সেন্টার', 'হেল্থ সেন্টার',
          'হেল্প সেন্টার', 'হেলথ', 'মেডিকেল', 'পিএইচসি', 'ক্লিনিক', 'কেন্দ্র',
          'अस्पताल', 'हॉस्पिटल', 'स्वास्थ्य केंद्र', 'हेल्थ सेंटर', 'पीएचसी', 'क्लिनिक',
          'hospital', 'phc', 'chc', 'sncu', 'fru', 'health centre', 'health center', 'clinic', 'medical',
        ],
        [
          // distance / time / route — turns "how far / how long to reach" into
          // a real-map lookup instead of an invented LLM answer.
          'কতদূর', 'কত দূর', 'দূরত্ব', 'ডিসটেন্স', 'কতক্ষণ', 'কত ক্ষণ', 'পৌঁছাতে', 'পৌছাতে', 'রাস্তা', 'পথ',
          'दूरी', 'कितनी दूर', 'कितना समय', 'पहुँचने', 'रास्ता',
          'distance', 'how far', 'how long', 'route', 'kotodur', 'kotokkhon',
        ],
      ],
      minGroupsMatched: 2,
    ),
    _IntentRule(
      intent: AssistantIntent.openEmergency,
      keywordGroups: [
        [
          'জরুরি', 'জরুরী', 'আপৎকাল',
          'आपातकाल', 'इमरजेंसी', 'इमर्जेंसी',
          'emergency', 'urgent',
        ],
      ],
      minGroupsMatched: 1, // single strong cue is enough
    ),
    _IntentRule(
      intent: AssistantIntent.addPatient,
      keywordGroups: [
        [
          // patient noun
          'রোগী', 'রুগী', 'পেশেন্ট', 'প্যাশেন্ট',
          'मरीज़', 'मरीज', 'पेशेंट', 'मरीजों',
          'patient', 'rogi', 'rugi', 'mariz',
        ],
        [
          // add verb
          'যোগ', 'যোগ কর', 'অ্যাড', 'নতুন', 'রেজিস্টার', 'রেজি',
          'जोड़', 'नया', 'रजिस्टर', 'ऐड',
          'add', 'new', 'register', 'create', 'enroll',
          'joro', 'natun', 'naya',
        ],
      ],
      minGroupsMatched: 2,
    ),
    _IntentRule(
      intent: AssistantIntent.openPatientList,
      keywordGroups: [
        [
          // patient noun (same as addPatient)
          'রোগী', 'রুগী', 'পেশেন্ট', 'প্যাশেন্ট',
          'मरीज़', 'मरीज', 'पेशेंट',
          'patient', 'rogi', 'rugi', 'mariz',
        ],
        [
          // list / show verb
          'তালিকা', 'লিস্ট', 'দেখ', 'খোল', 'সব',
          'सूची', 'लिस्ट', 'दिखा', 'खोल', 'सभी', 'सब',
          'list', 'show', 'open', 'display', 'view',
          'dekhao', 'dekhan', 'kholo', 'sob',
        ],
      ],
      minGroupsMatched: 2,
    ),
    _IntentRule(
      intent: AssistantIntent.openReports,
      keywordGroups: [
        [
          'রিপোর্ট', 'রিপোর্টের', 'রিপোর্টগুলো', 'রিপোর্টগুলি',
          'रिपोर्ट',
          'report', 'reports',
        ],
        [
          'দেখ', 'খোল', 'সব', 'তালিকা', 'লিস্ট', 'দাও', 'চাই', 'দরকার',
          'दिखा', 'खोल', 'सभी', 'सूची', 'लिस्ट', 'दो', 'चाहिए',
          'show', 'open', 'list', 'all', 'view', 'give', 'want',
          'dekhao', 'dekhan', 'kholo', 'dao',
        ],
      ],
      minGroupsMatched: 2,
    ),
    _IntentRule(
      intent: AssistantIntent.openProfile,
      keywordGroups: [
        [
          'প্রোফাইল', 'প্রোফাইলে',
          'प्रोफ़ाइल', 'प्रोफाइल',
          'profile',
        ],
      ],
      minGroupsMatched: 1,
    ),
    _IntentRule(
      intent: AssistantIntent.startTriage,
      keywordGroups: [
        [
          // triage / case / screening noun
          'ট্রিয়াজ', 'ট্রায়াজ', 'কেস', 'স্ক্রিনিং', 'রিস্ক',
          'ट्राइएज', 'केस', 'स्क्रीनिंग',
          'triage', 'case', 'screening', 'risk', 'screen',
        ],
        [
          // start / new / check verb
          'শুরু', 'নতুন', 'চেক', 'করো',
          'शुरू', 'नया', 'जाँच',
          'start', 'new', 'check', 'begin',
        ],
      ],
      minGroupsMatched: 2,
    ),
    _IntentRule(
      intent: AssistantIntent.openHome,
      keywordGroups: [
        [
          'হোম', 'মূল পাতা', 'মূল স্ক্রিন', 'ড্যাশবোর্ড',
          'होम', 'मुख्य पन्ना', 'घर', 'डैशबोर्ड',
          'home', 'main screen', 'dashboard',
        ],
      ],
      minGroupsMatched: 1,
    ),
    _IntentRule(
      intent: AssistantIntent.goBack,
      keywordGroups: [
        [
          'পিছনে', 'ফিরে', 'ব্যাক', 'পেছনে',
          'पीछे', 'वापस', 'बैक',
          'back', 'previous', 'return',
        ],
      ],
      minGroupsMatched: 1,
    ),
  ];

  /// Soft suffix stripping for common Bengali / Hindi verb endings.
  /// We replace these as plain substrings on the normalized input
  /// rather than do real morphological analysis — good enough for the
  /// 10 intents above.
  ///
  /// Order matters: longest suffixes first so we don't strip a prefix
  /// of a longer suffix prematurely.
  static const _suffixes = <String>[
    // bn verb endings (most common forms workers use)
    'করছিলেন', 'করছিলে', 'করেছেন', 'করেছিল', 'করেছ', 'করছি',
    'করুন', 'করো', 'করে', 'করব', 'করি', 'কর',
    'দেখাবেন', 'দেখাচ্ছি', 'দেখান', 'দেখাও', 'দেখো', 'দেখ',
    'খুলবেন', 'খুলছি', 'খুলুন', 'খোলো', 'খোল', 'খুল',
    // hi verb endings
    'कीजिए', 'कीजिये', 'करिये', 'करिए', 'करो', 'करूँ', 'करना',
    'दिखाइए', 'दिखाओ', 'दिखाएँ', 'दिखाएं',
    'खोलिए', 'खोलो', 'खोलें',
  ];

  static String _normalize(String input) {
    var s = input.trim().toLowerCase();
    // Strip Indic punctuation + common ASCII punctuation that breaks
    // token boundaries.
    s = s.replaceAll(RegExp(r'[।,.!?;:"()\[\]{}\\/]+'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    return s.trim();
  }

  /// Soft-strip common verb suffixes from the normalized text. Done
  /// as a global string replace — the suffixes are rare enough as
  /// non-verb substrings that false-strips are negligible.
  static String _stem(String normalized) {
    var s = normalized;
    for (final suffix in _suffixes) {
      // Strip only when the suffix sits at a token boundary so we don't
      // mangle nouns that happen to share a tail.
      s = s.replaceAll(RegExp('$suffix\\b'), ' ');
    }
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// True when [keyword] matches the input.
  /// - Multi-word keywords (containing a space) match as a substring of
  ///   [normalized] — e.g. "blood pressure", "স্বাস্থ্য কেন্দ্র".
  /// - Single tokens match a whole token OR a token *prefix*, so inflected
  ///   forms still hit ("ডাকো" → "ডাক", "রোগীদের" → "রোগী") while unrelated
  ///   words that merely *contain* the keyword do NOT ("থাকলে" does not
  ///   start with "কল"). This is what kills the old substring false-positives.
  static bool _keywordHit(String keyword, String normalized, Set<String> tokens) {
    if (keyword.contains(' ')) return normalized.contains(keyword);
    for (final t in tokens) {
      if (t == keyword || t.startsWith(keyword)) return true;
    }
    return false;
  }

  /// Run rule matching. Returns [ClassifiedIntent.unknown] if no
  /// intent satisfies its [minGroupsMatched] threshold.
  // ignore: unused_element
  ClassifiedIntent classify(String input, AssistantLang lang) {
    if (input.trim().isEmpty) return ClassifiedIntent.unknown;
    final normalized = _normalize(input);
    final stemmed = _stem(normalized);
    if (stemmed.isEmpty) return ClassifiedIntent.unknown;

    // Token set from both the normalized and stemmed forms. Matching is
    // token-aware (whole-token or token-prefix) rather than raw substring,
    // so a 2-char keyword like "কল" no longer matches inside "থাকলে".
    final tokens = <String>{
      ...normalized.split(' '),
      ...stemmed.split(' '),
    }..removeWhere((t) => t.isEmpty);

    AssistantIntent bestIntent = AssistantIntent.unknown;
    double bestScore = 0.0;
    String bestFragment = '';

    for (final rule in _rules) {
      int matchedGroups = 0;
      String longestHit = '';
      for (final group in rule.keywordGroups) {
        for (final synonym in group) {
          final lowered = synonym.toLowerCase();
          if (lowered.length < 2) continue;
          if (_keywordHit(lowered, normalized, tokens)) {
            matchedGroups++;
            if (synonym.length > longestHit.length) longestHit = synonym;
            break; // one hit per group is enough
          }
        }
      }
      if (matchedGroups < rule.minGroupsMatched) continue;
      // Score = ratio of groups matched. Ties broken by longest match
      // so multi-group hits beat single-keyword false positives.
      final score = matchedGroups / rule.keywordGroups.length;
      if (score > bestScore) {
        bestScore = score;
        bestIntent = rule.intent;
        bestFragment = longestHit;
      }
    }

    if (bestIntent == AssistantIntent.unknown) {
      return ClassifiedIntent.unknown;
    }

    // Floor confidence at 0.55 (any rule match is strong evidence)
    // and boost slightly when all groups matched.
    final confidence = (0.55 + (bestScore * 0.45)).clamp(0.55, 1.0);
    return ClassifiedIntent(
      intent: bestIntent,
      confidence: confidence,
      matchedPattern: bestFragment,
    );
  }
}
