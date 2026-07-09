/// One place that rewrites bookish/formal wording into the words ASHA workers
/// actually say and write — for every language the app ships. It runs at
/// runtime on BOTH the static UI strings (all locales) and the dynamic labels
/// that come from the server/DB (schedule events, reminders — always Bengali),
/// so the whole app reads the same way: "গৃহ ভিজিট" not "গৃহ পরিদর্শন",
/// "BP"/"সেভ" instead of the textbook terms.
///
/// Only *collision-free* swaps live here — each left-hand side is safe to
/// replace anywhere it appears. Context-sensitive words are deliberately NOT
/// here: e.g. Bengali পরবর্তী is also part of প্রসব-পরবর্তী (post-natal) and
/// টিকা-পরবর্তী (post-vaccination), so it is tuned by hand in the translation
/// file, never swapped globally.
class BengaliStyle {
  BengaliStyle._();

  /// Bengali (primary): formal → spoken + the English terms ASHAs use.
  /// Ordered so multi-word phrases are handled before single words.
  static const Map<String, String> _bn = {
    'গৃহভিত্তিক শিশু যত্ন': 'শিশুর গৃহ-যত্ন', // HBYC label (shorter, spoken)
    'নির্বাচন করুন': 'বেছে নিন', // select → choose
    'রক্তে শর্করা': 'ব্লাড সুগার', // blood sugar
    'সংরক্ষণ': 'সেভ', // save
    'পরিদর্শন': 'ভিজিট', // visit (also fixes "গৃহ পরিদর্শন")
    'রক্তচাপ': 'BP', // blood pressure
    'বকেয়া': 'Due', // overdue / pending → the English word workers use
  };

  /// Hindi: same philosophy — the common English terms people actually use.
  static const Map<String, String> _hi = {
    'रक्त शर्करा': 'ब्लड शुगर', // blood sugar
    'रक्तचाप': 'BP', // blood pressure
    'सहेजें': 'सेव करें', // save
  };

  // English is already the plain baseline — nothing to humanize.

  static String _apply(String s, Map<String, String> swaps) {
    if (s.isEmpty || swaps.isEmpty) return s;
    var out = s;
    for (final e in swaps.entries) {
      if (out.contains(e.key)) out = out.replaceAll(e.key, e.value);
    }
    return out;
  }

  /// Humanize Bengali text — the default, used for dynamic server labels
  /// (which are always Bengali). Idempotent.
  static String humanize(String s) => _apply(s, _bn);

  /// Humanize [s] for a GetX locale code ('en_US' | 'bn_BD' | 'hi_IN').
  static String humanizeFor(String s, String locale) {
    if (locale.startsWith('bn')) return _apply(s, _bn);
    if (locale.startsWith('hi')) return _apply(s, _hi);
    return s; // en — already plain
  }

  /// A whole translation map, humanized for its [locale].
  static Map<String, String> humanizeMap(
          Map<String, String> m, String locale) =>
      m.map((k, v) => MapEntry(k, humanizeFor(v, locale)));

  /// Returns [e] with its `label` humanized (Bengali schedule/reminder events).
  static Map<String, dynamic> humanizeEvent(Map<String, dynamic> e) {
    final label = e['label'];
    if (label is String && label.isNotEmpty) {
      final pretty = humanize(label);
      if (pretty != label) return {...e, 'label': pretty};
    }
    return e;
  }

  /// Humanizes the `label` on every event in a raw schedule list.
  static List<dynamic> humanizeEvents(List<dynamic> events) => events
      .map((e) =>
          e is Map ? humanizeEvent(e.cast<String, dynamic>()) : e)
      .toList();
}
