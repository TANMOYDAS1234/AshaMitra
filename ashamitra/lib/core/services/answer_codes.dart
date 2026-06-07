// ─────────────────────────────────────────────────────────────────────────────
// AnswerCodes — canonical graded answer model for triage replies.
//
// The engine historically stored only booleans (true = danger sign present).
// To support graded spoken replies and safe uncertainty handling, answers may
// now also be one of these string codes. Everything is backward-compatible:
// a bool `true`/`false` still means yes/no.
//
//   yes     — danger sign present                        → fires (RED hard-stop)
//   severe  — present to a severe degree (অনেক/খুব কম/একবার) → fires (RED), same as yes
//   mild    — intermittent / partial (মাঝে মাঝে/কিছুটা/একটু) → at least YELLOW
//   no      — absent                                     → does not fire
//   unsure  — worker not certain (নিশ্চিত না/জানি না)     → BLOCKS GREEN (≥ YELLOW)
//
// A `value:true` rule condition fires on `yes` OR `severe` (affirmative).
// `mild` and `unsure` never fire a hard-stop but drive band via RuleEngine.
// ─────────────────────────────────────────────────────────────────────────────

class AnswerCodes {
  static const String yes = 'yes';
  static const String no = 'no';
  static const String severe = 'severe';
  static const String mild = 'mild';
  static const String unsure = 'unsure';

  /// Affirmative for a danger-sign question — fires a `value:true` condition.
  /// Accepts legacy bool `true`, the Bengali 'হ্যাঁ', and the string 'true'.
  static bool isAffirmative(dynamic v) =>
      v == true || v == yes || v == severe || v == 'true' || v == 'হ্যাঁ';

  /// Negative — fires a `value:false` condition.
  static bool isNegative(dynamic v) =>
      v == false || v == no || v == 'false' || v == 'না';

  static bool isMild(dynamic v) => v == mild;
  static bool isUnsure(dynamic v) => v == unsure;

  // ── Speech → code ──────────────────────────────────────────────────────────
  // Keyword sets (Bengali + Hindi/romanised). Intermittent/partial words mean
  // `mild` (a real, lesser sign) — NOT uncertainty. Genuine uncertainty
  // ("না জানি", "মনে হয়") maps to `unsure` so it can never silently clear GREEN.

  static const _severeWords = {
    'খুব কম', 'খুবই কম', 'অনেক', 'অনেক বেশি', 'খুব বেশি', 'ভীষণ', 'প্রচণ্ড',
    'গুরুতর', 'মারাত্মক', 'একবার', // "once" (a single convulsion/faint) = severe
    'severe', 'a lot', 'lot', 'very', 'bahut', 'jyada', 'zyada',
  };
  static const _mildWords = {
    'মাঝে মাঝে', 'মাঝেমাঝে', 'কিছুটা', 'একটু', 'একটুখানি', 'অল্প', 'হালকা',
    'মৃদু', 'সামান্য', 'কখনো কখনো',
    'mild', 'slight', 'sometimes', 'a little', 'thoda', 'halka', 'kabhi kabhi',
  };
  static const _unsureWords = {
    'নিশ্চিত না', 'নিশ্চিত নই', 'নিশ্চিত নয়', 'জানি না', 'জানিনা', 'বুঝতে পারছি না',
    'মনে হয়', 'মনে হচ্ছে', 'হয়তো', 'হতে পারে', 'বলতে পারব না',
    'maybe', 'not sure', 'unsure', 'dont know', "don't know", 'pata nahi',
    'pata nahin', 'shayad', 'lagta hai',
  };
  static const _yesWords = {
    'হ্যাঁ', 'হ্যা', 'হাঁ', 'হা', 'আছে', 'হয়েছে', 'হইছে', 'হয়', 'করছে',
    'yes', 'haan', 'han', 'ji', 'hticche', 'achhe', 'ache',
  };
  static const _noWords = {
    'না', 'নেই', 'নাই', 'হয়নি', 'করেনি',
    'no', 'nahi', 'nahin', 'nai', 'nei', 'nahito',
  };

  /// Returns the graded code for a terse reply, or null when the reply is not a
  /// clear single answer (long multi-symptom free text → let the extractor work).
  static String? fromSpeech(String input) {
    final lower = input.toLowerCase().trim();
    if (lower.isEmpty) return null;
    final wordCount = lower.split(RegExp(r'[\s।,!?.]+')).where((w) => w.isNotEmpty).length;
    if (wordCount > 6) return null; // not a terse reply

    bool has(Set<String> set) => set.any((w) => lower.contains(w));
    final hasUnsure = has(_unsureWords);
    final hasSevere = has(_severeWords);
    final hasMild = has(_mildWords);
    final hasYes = has(_yesWords);
    final hasNo = has(_noWords);

    // Precedence (safety-biased): an explicit degree wins over a plain yes;
    // genuine uncertainty beats a bare "না" inside "নিশ্চিত না".
    if (hasSevere) return severe;
    if (hasYes) return hasMild ? mild : yes; // "হ্যাঁ একটু" → mild
    if (hasMild) return mild;
    if (hasUnsure) return unsure;
    if (hasNo) return no;
    return null;
  }
}
