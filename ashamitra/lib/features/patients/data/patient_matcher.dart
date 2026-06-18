import 'models/patient_model.dart';

/// One possible-duplicate hit, with a worker-readable reason for the prompt.
class DuplicateMatch {
  final PatientModel patient;
  /// Bengali reason shown in the "possible duplicate?" sheet.
  final String reason;
  /// Strong = an unambiguous key matched (RCH/MCTS id, or same mother+DOB+order
  /// for a child). Soft = name + phone/village heuristic (worker must decide).
  final bool strong;
  const DuplicateMatch(this.patient, this.reason, this.strong);
}

/// Identity matching for the patient register.
///
/// Why this exists: two real people can share a name and a household phone, and
/// a child often has neither Aadhaar nor a phone — so the app must NOT silently
/// merge on name+mobile. Instead it surfaces candidates to the worker (who
/// knows her ~1000-population caseload) and lets her decide. Strong keys (RCH
/// id, or mother+DOB+birth-order for a child) are treated as near-certain.
class PatientMatcher {
  /// Normalise a name for comparison: trim, collapse spaces, case-fold, and
  /// drop common honorifics/transliteration noise so "Md. Rahim" ≈ "rahim".
  static String normName(String s) {
    var t = s.toLowerCase().trim();
    t = t.replaceAll(
        RegExp(r'\b(md|mohammad|mohammed|smt|smt\.|sri|mr|mrs|ms|miss)\.?\b'), ' ');
    t = t.replaceAll(RegExp(r'[.,]'), ' ');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t;
  }

  /// Phone reduced to its last 10 digits (drops +91 / leading 0 / spaces) so
  /// the same number written differently still matches. Empty stays empty —
  /// and an empty phone is treated as "unknown", never a joinable value.
  static String normPhone(String s) {
    final d = s.replaceAll(RegExp(r'\D'), '');
    return d.length > 10 ? d.substring(d.length - 10) : d;
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Finds possible duplicates of the candidate among [existing] (the worker's
  /// own list). [excludeId] skips self when editing. Returns strong matches
  /// first. An empty list means "no likely duplicate — safe to create".
  static List<DuplicateMatch> find({
    required List<PatientModel> existing,
    required String name,
    required String mobile,
    required String village,
    String rchId = '',
    String? motherId,
    DateTime? dob,
    int birthOrder = 0,
    String? excludeId,
  }) {
    final out = <DuplicateMatch>[];
    final nName = normName(name);
    final nPhone = normPhone(mobile);
    final nVillage = village.toLowerCase().trim();
    final nRch = rchId.trim();

    for (final p in existing) {
      if (excludeId != null && p.id == excludeId) continue;
      if (p.syncState == SyncState.pendingDelete) continue;

      // 1. Strong — same government RCH/MCTS id.
      if (nRch.isNotEmpty && p.rchId.isNotEmpty && p.rchId == nRch) {
        out.add(DuplicateMatch(p, 'একই RCH/MCTS আইডি', true));
        continue;
      }
      // 2. Strong — same child: same mother + same DOB + same birth order.
      if (dob != null &&
          motherId != null &&
          motherId.isNotEmpty &&
          p.motherId == motherId &&
          p.dob != null &&
          _sameDay(p.dob!, dob) &&
          p.birthOrder == birthOrder) {
        out.add(DuplicateMatch(p, 'একই মায়ের একই জন্মতারিখের শিশু', true));
        continue;
      }
      // 3. Soft — same name AND (same phone OR same village). Worker decides.
      if (nName.isNotEmpty && normName(p.name) == nName) {
        final samePhone = nPhone.isNotEmpty && normPhone(p.mobile) == nPhone;
        final sameVillage =
            nVillage.isNotEmpty && p.village.toLowerCase().trim() == nVillage;
        if (samePhone || sameVillage) {
          out.add(DuplicateMatch(
              p, samePhone ? 'একই নাম ও মোবাইল নম্বর' : 'একই নাম ও গ্রাম', false));
        }
      }
    }

    out.sort((a, b) => (b.strong ? 1 : 0) - (a.strong ? 1 : 0));
    return out;
  }
}
