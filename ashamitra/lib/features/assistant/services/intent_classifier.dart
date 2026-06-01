// ─────────────────────────────────────────────────────────────────────────────
// RuleBasedIntentClassifier — offline-first action intent matching for the
// voice assistant.
//
// Why this exists:
//   The assistant should be able to execute common app actions (call
//   ambulance, find nearest PHC, add patient, open reports etc.) without
//   needing a network round-trip to Gemini. ASHA workers live in areas
//   with patchy 2G/3G signal, and a 5-second wait every time they say
//   "open patients" would make the assistant feel broken. Rule-based
//   matching gives <50 ms response, works fully offline, and handles
//   the top ~30 commands a worker says daily. Anything that doesn't
//   match falls through to the LLM as before.
//
// How matching works:
//   For each intent we keep a list of phrase fragments in Bengali, Hindi,
//   and English (workers often code-switch mid-sentence — "patient add
//   koro" or "ambulance call koro"). The classifier normalizes the
//   input (lowercase, collapse whitespace) and scores intents by
//   longest matching fragment. The intent with the longest match wins,
//   with a minimum 4-character fragment to avoid false positives on
//   short stop-words.
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
/// score derived from the matched-fragment length relative to the
/// input. Caller should treat anything below ~0.45 as a soft match
/// and consider whether to confirm with the worker before dispatch.
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

class RuleBasedIntentClassifier {
  /// Map: intent → list of phrase fragments that map to it. Each
  /// fragment is checked against the normalized input via `contains`.
  /// Order doesn't matter; longest match wins across all intents.
  ///
  /// Notes on coverage:
  ///   - Bengali phrases use both pure Bengali and Banglish ("call koro").
  ///   - Hindi entries cover Devanagari and common Romanized spellings.
  ///   - English covers the direct command form the worker is most likely
  ///     to use if they switch into English mid-sentence.
  ///   - Numbers (102 / 108) are kept as both Latin digits and Bengali/
  ///     Hindi digit transliterations since STT can return either.
  static const _patterns = <AssistantIntent, List<String>>{
    AssistantIntent.callAmbulance: [
      // bn
      'অ্যাম্বুলেন্স ডাক', 'অ্যাম্বুলেন্স ডাকো',
      'এম্বুলেন্স ডাক', 'এম্বুলেন্স ডাকো',
      'অ্যাম্বুলেন্স কল', 'অ্যাম্বুলেন্স কর',
      '১০২ কল', '১০২ ডাক', '১০৮ কল', '১০৮ ডাক',
      // hi
      'एम्बुलेंस बुला', 'एम्बुलेंस कॉल',
      'एंबुलेंस बुला', 'एंबुलेंस कॉल',
      '१०२ कॉल', '१०२ बुला', '१०८ कॉल',
      // en / banglish
      'call ambulance', 'dial ambulance',
      'call 102', 'dial 102', 'call 108', 'dial 108',
      'ambulance call', 'ambulance bula', 'ambulance dak',
    ],

    AssistantIntent.findNearestPHC: [
      // bn
      'কাছের হাসপাতাল', 'নিকটতম হাসপাতাল',
      'কাছাকাছি হাসপাতাল', 'নিকটস্থ স্বাস্থ্য কেন্দ্র',
      'কাছের স্বাস্থ্য কেন্দ্র', 'নিকটতম পিএইচসি',
      'কোথায় হাসপাতাল', 'হাসপাতাল কোথায়',
      'কাছের ক্লিনিক',
      // hi
      'नज़दीकी अस्पताल', 'पास का अस्पताल', 'नज़दीकी पीएचसी',
      'नज़दीकी स्वास्थ्य केंद्र', 'सबसे पास अस्पताल',
      'अस्पताल कहां',
      // en / banglish
      'nearest hospital', 'nearest phc', 'nearest health centre',
      'nearest health center', 'find hospital', 'where hospital',
      'closest hospital', 'kachher hospital',
    ],

    AssistantIntent.openEmergency: [
      // bn
      'জরুরি', 'জরুরী', 'জরুরি অবস্থা', 'জরুরি স্ক্রিন',
      // hi
      'आपातकाल', 'इमरजेंसी', 'इमरजेंसी खोलो',
      // en
      'emergency', 'open emergency', 'emergency screen',
    ],

    AssistantIntent.addPatient: [
      // bn
      'নতুন রোগী', 'নতুন রুগী', 'রোগী যোগ', 'রুগী যোগ',
      'রোগী অ্যাড', 'রোগী add', 'নতুন প্যাশেন্ট',
      'রোগী রেজিস্টার',
      // hi
      'नया मरीज़', 'नया मरीज', 'मरीज़ जोड़', 'मरीज जोड़',
      'मरीज़ ऐड', 'नया पेशेंट',
      // en / banglish
      'add patient', 'new patient', 'register patient',
      'patient add', 'patient register',
      'natun rogi', 'rogi add', 'rogi joro',
    ],

    AssistantIntent.openPatientList: [
      // bn
      'রোগীর তালিকা', 'রোগীদের তালিকা', 'সব রোগী', 'রোগী দেখাও',
      'রোগীর লিস্ট', 'রুগীর তালিকা',
      // hi
      'मरीज़ों की सूची', 'सभी मरीज़', 'मरीज़ दिखाओ',
      'मरीज़ की लिस्ट',
      // en / banglish
      'patient list', 'show patients', 'all patients', 'list patients',
      'rogi dekhao', 'rogider talika',
    ],

    AssistantIntent.openReports: [
      // bn
      'রিপোর্ট দেখাও', 'সব রিপোর্ট', 'রিপোর্ট খোলো', 'রিপোর্টের তালিকা',
      // hi
      'रिपोर्ट दिखाओ', 'सभी रिपोर्ट', 'रिपोर्ट खोलो',
      // en / banglish
      'show reports', 'open reports', 'all reports', 'report list',
      'report dekhao',
    ],

    AssistantIntent.openProfile: [
      // bn
      'প্রোফাইল', 'আমার প্রোফাইল', 'প্রোফাইল খোলো',
      // hi
      'प्रोफ़ाइल', 'प्रोफाइल', 'मेरी प्रोफाइल',
      // en
      'profile', 'open profile', 'my profile',
    ],

    AssistantIntent.startTriage: [
      // bn
      'ট্রিয়াজ', 'ট্রিয়াজ শুরু', 'স্ক্রিনিং শুরু', 'কেস শুরু',
      'নতুন কেস', 'চেক শুরু', 'রোগী চেক', 'রিস্ক চেক',
      // hi
      'ट्राइएज', 'स्क्रीनिंग शुरू', 'जाँच शुरू', 'नया केस',
      // en
      'start triage', 'new case', 'start screening', 'screen patient',
      'check patient',
    ],

    AssistantIntent.openHome: [
      // bn
      'হোম', 'হোমে যাও', 'মূল পাতা', 'মূল স্ক্রিন',
      // hi
      'होम', 'मुख्य पन्ना', 'घर',
      // en
      'home', 'go home', 'main screen', 'dashboard',
    ],

    AssistantIntent.goBack: [
      // bn
      'পিছনে যাও', 'ফিরে যাও', 'ব্যাক',
      // hi
      'पीछे जाओ', 'वापस जाओ', 'बैक',
      // en
      'go back', 'back', 'previous',
    ],
  };

  /// Minimum matched-fragment length (in characters) for the match to
  /// count. Short matches like "go" or "open" alone would fire
  /// false positives constantly.
  static const _minFragmentLen = 4;

  /// Run rule matching. Returns [ClassifiedIntent.unknown] if no
  /// pattern fragment of [_minFragmentLen]+ chars matched the input.
  /// [lang] is currently unused in matching (we check all languages,
  /// since workers code-switch) but kept on the signature for future
  /// per-language weight tuning.
  // ignore: unused_element
  ClassifiedIntent classify(String input, AssistantLang lang) {
    final normalized = input.trim().toLowerCase();
    if (normalized.isEmpty) return ClassifiedIntent.unknown;

    AssistantIntent best = AssistantIntent.unknown;
    String bestFragment = '';
    int bestLen = 0;

    for (final entry in _patterns.entries) {
      for (final fragment in entry.value) {
        if (fragment.length < _minFragmentLen) continue;
        if (!normalized.contains(fragment.toLowerCase())) continue;
        if (fragment.length > bestLen) {
          best = entry.key;
          bestFragment = fragment;
          bestLen = fragment.length;
        }
      }
    }

    if (best == AssistantIntent.unknown) return ClassifiedIntent.unknown;

    // Confidence: matched-fragment length / input length, clamped to
    // 0.45..1.0. We deliberately floor at 0.45 because any rule match
    // is already much stronger evidence than nothing — we just want
    // longer matches to score higher for ranking purposes.
    final ratio = bestLen / normalized.length.clamp(1, double.maxFinite);
    final confidence = ratio < 0.45 ? 0.45 : (ratio > 1.0 ? 1.0 : ratio);

    return ClassifiedIntent(
      intent: best,
      confidence: confidence,
      matchedPattern: bestFragment,
    );
  }
}
