// ─────────────────────────────────────────────────────────────────────────────
// IntentDispatcher — maps a classified intent to an in-app action.
//
// Sits between the rule-based intent classifier and the actual
// navigation / system calls. Returns a [DispatchResult] with the
// outcome and a spoken confirmation phrase that the assistant says
// back to the worker so they get audible feedback that the command
// was understood.
//
// Every action here works fully offline — they use Get.toNamed (in-app
// navigation) or url_launcher (dialer intent). None of them hit the
// network, which is the whole point of intent classification: common
// commands work instantly even in a hut with no signal.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/routes.dart';
import 'assistant_chat_service.dart' show AssistantLang;
import 'intent_classifier.dart';

class DispatchResult {
  /// True when the dispatcher executed the action (or attempted it).
  /// False means the intent was recognized but couldn't be handled
  /// from here, and caller should fall through to the LLM path.
  final bool handled;

  /// Short phrase the assistant should speak back to confirm the
  /// command was understood and executed. Already in the worker's
  /// active language.
  final String spokenConfirmation;

  /// True when the action's full effect requires network (e.g. saving
  /// a report syncs to backend). Caller may use this to warn the
  /// worker. None of the v1 intents set this — they're all local.
  final bool requiresNetwork;

  const DispatchResult({
    required this.handled,
    required this.spokenConfirmation,
    this.requiresNetwork = false,
  });

  static const notHandled = DispatchResult(
    handled: false,
    spokenConfirmation: '',
  );
}

class IntentDispatcher {
  final AssistantLang lang;
  IntentDispatcher({required this.lang});

  /// Execute the action for [intent]. Returns [DispatchResult.notHandled]
  /// for [AssistantIntent.unknown] so the caller knows to fall through
  /// to the LLM. All other intents return [handled] = true with a
  /// language-matched spoken confirmation.
  Future<DispatchResult> dispatch(ClassifiedIntent intent, {String rawInput = ''}) async {
    HapticFeedback.lightImpact();
    switch (intent.intent) {
      case AssistantIntent.callAmbulance:
        // 108 = all-purpose emergency medical ambulance (matches the clinical
        // engine's RED-band action and the vitals danger alerts, which all
        // say "Call 108"). Single source of truth for the emergency number.
        return _callNumber('108');

      case AssistantIntent.findNearestPHC:
        // Open the live facilities map (device GPS + OSRM) so the worker sees
        // REAL road distances and drive times. The assistant deliberately does
        // NOT speak any number itself — it points to the map, which has the
        // actual figures, instead of inventing "৫-৭ কিমি, ১৫-২০ মিনিট".
        Get.toNamed(AppRoutes.nearestFacilities);
        return DispatchResult(
          handled: true,
          spokenConfirmation: _confirm(
            bn: 'কাছের স্বাস্থ্যকেন্দ্র ম্যাপে দেখাচ্ছি — দূরত্ব আর সময় ওখানে দেখুন।',
            hi: 'पास के स्वास्थ्य केंद्र मैप पर दिखा रही हूँ — दूरी और समय वहाँ देखें।',
            en: 'Showing nearby health centres on the map — distance and time are there.',
          ),
        );

      case AssistantIntent.openEmergency:
        Get.toNamed(AppRoutes.emergency);
        return DispatchResult(
          handled: true,
          spokenConfirmation: _confirm(
            bn: 'জরুরি স্ক্রিন খুলছি।',
            hi: 'इमरजेंसी स्क्रीन खोल रही हूँ।',
            en: 'Opening the emergency screen.',
          ),
        );

      case AssistantIntent.addPatient:
        // Pull a name out of the spoken command ("সায়নি দাস কে অ্যাড করো" →
        // "সায়নি দাস") and pre-fill the form so the worker doesn't retype it.
        final addName = _extractPatientName(rawInput);
        Get.toNamed(AppRoutes.addPatient, arguments: {
          if (addName != null && addName.isNotEmpty) 'name': addName,
        });
        return DispatchResult(
          handled: true,
          spokenConfirmation: (addName != null && addName.isNotEmpty)
              ? _confirm(
                  bn: '$addName-কে যোগ করছি — বাকি তথ্য পূরণ করুন।',
                  hi: '$addName को जोड़ रही हूँ — बाक़ी जानकारी भरें।',
                  en: 'Adding $addName — fill in the rest.',
                )
              : _confirm(
                  bn: 'নতুন রোগী যোগ করার পাতা খুলছি।',
                  hi: 'नया मरीज़ जोड़ने का पन्ना खोल रही हूँ।',
                  en: 'Opening the add-patient screen.',
                ),
        );

      case AssistantIntent.openPatientList:
        Get.toNamed(AppRoutes.patientList);
        return DispatchResult(
          handled: true,
          spokenConfirmation: _confirm(
            bn: 'রোগীদের তালিকা দেখাচ্ছি।',
            hi: 'मरीज़ों की सूची दिखा रही हूँ।',
            en: 'Showing the patient list.',
          ),
        );

      case AssistantIntent.openReports:
        // Parse the spoken request into Reports filters (time / band / search)
        // so "আজকের রিপোর্ট" or "আফানের রিপোর্ট" open the list pre-filtered.
        final rf = _reportFilters(rawInput);
        Get.toNamed(AppRoutes.reports, arguments: {
          if (rf.time != null) 'time': rf.time,
          if (rf.band != null) 'band': rf.band,
          if (rf.search != null) 'search': rf.search,
        });
        String rBn, rHi, rEn;
        if (rf.search != null) {
          rBn = '${rf.search}-এর রিপোর্ট দেখাচ্ছি।';
          rHi = '${rf.search} की रिपोर्ट दिखा रही हूँ।';
          rEn = 'Showing reports for ${rf.search}.';
        } else {
          const timeBn = {'today': 'আজকের', 'yesterday': 'গতকালের', 'week': 'এই সপ্তাহের', 'month': 'এই মাসের'};
          const bandBn = {'emergency': 'জরুরি', 'attention': 'মনোযোগের', 'safe': 'নিরাপদ'};
          const timeEn = {'today': "today's", 'yesterday': "yesterday's", 'week': "this week's", 'month': "this month's"};
          const bandEn = {'emergency': 'urgent', 'attention': 'attention', 'safe': 'safe'};
          final pBn = [if (timeBn[rf.time] != null) timeBn[rf.time]!, if (bandBn[rf.band] != null) bandBn[rf.band]!];
          final pEn = [if (timeEn[rf.time] != null) timeEn[rf.time]!, if (bandEn[rf.band] != null) bandEn[rf.band]!];
          if (pBn.isEmpty) {
            rBn = 'রিপোর্ট খুলছি।';
            rHi = 'रिपोर्ट खोल रही हूँ।';
            rEn = 'Opening reports.';
          } else {
            rBn = '${pBn.join(' ')} রিপোর্ট দেখাচ্ছি।';
            rHi = 'रिपोर्ट दिखा रही हूँ।';
            rEn = 'Showing ${pEn.join(' ')} reports.';
          }
        }
        return DispatchResult(
          handled: true,
          spokenConfirmation: _confirm(bn: rBn, hi: rHi, en: rEn),
        );

      case AssistantIntent.openProfile:
        Get.toNamed(AppRoutes.profile);
        return DispatchResult(
          handled: true,
          spokenConfirmation: _confirm(
            bn: 'প্রোফাইল খুলছি।',
            hi: 'प्रोफ़ाइल खोल रही हूँ।',
            en: 'Opening profile.',
          ),
        );

      case AssistantIntent.startTriage:
        Get.toNamed(AppRoutes.selectCase);
        return DispatchResult(
          handled: true,
          spokenConfirmation: _confirm(
            bn: 'ট্রিয়াজ শুরু করছি — কেস বেছে নিন।',
            hi: 'ट्राइएज शुरू कर रही हूँ — केस चुनिए।',
            en: 'Starting triage — pick a case.',
          ),
        );

      case AssistantIntent.openHome:
        Get.offAllNamed(AppRoutes.home);
        return DispatchResult(
          handled: true,
          spokenConfirmation: _confirm(
            bn: 'হোম খুলছি।',
            hi: 'होम खोल रही हूँ।',
            en: 'Opening home.',
          ),
        );

      case AssistantIntent.goBack:
        if (Get.key.currentState?.canPop() ?? false) {
          Get.back();
          return DispatchResult(
            handled: true,
            spokenConfirmation: _confirm(
              bn: 'আগের পাতায় ফিরছি।',
              hi: 'पिछले पन्ने पर जा रही हूँ।',
              en: 'Going back.',
            ),
          );
        }
        return DispatchResult(
          handled: true,
          spokenConfirmation: _confirm(
            bn: 'এর আগে আর কোনো পাতা নেই।',
            hi: 'इससे पहले कोई पन्ना नहीं है।',
            en: 'There is no previous screen.',
          ),
        );

      case AssistantIntent.unknown:
        return DispatchResult.notHandled;
    }
  }

  /// Open [number] in the phone's default call app. externalApplication
  /// forces Android to hand the tel: intent to the default dialer/phone
  /// app (or show the call-app chooser if none is set) rather than the
  /// in-app/platform-default handling, which doesn't reliably surface a
  /// dialer on every device. We open the dialer rather than placing the
  /// call directly so the worker has one final chance to confirm —
  /// important when the assistant might have misheard a non-emergency
  /// utterance as "call 108".
  Future<DispatchResult> _callNumber(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    bool launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      launched = false;
    }
    return DispatchResult(
      handled: true,
      spokenConfirmation: launched
          ? _confirm(
              bn: 'অ্যাম্বুলেন্সে ফোন করছি — $number।',
              hi: 'एम्बुलेंस को कॉल कर रही हूँ — $number।',
              en: 'Calling the ambulance on $number.',
            )
          : _confirm(
              bn: 'ফোন অ্যাপ খুলতে পারলাম না — দয়া করে নিজে $number ডায়াল করুন।',
              hi: 'फ़ोन ऐप नहीं खुल पाया — कृपया $number ख़ुद डायल करें।',
              en: 'Could not open the dialer — please dial $number yourself.',
            ),
    );
  }

  /// Best-effort patient-name extraction from an "add patient" command.
  /// Strips command / filler words; the readable remainder is treated as the
  /// name ("সায়নি দাস কে অ্যাড করো" → "সায়নি দাস"). Returns null when nothing
  /// name-like is left (e.g. "এই পেশেন্ট অ্যাড করো" — the name was in earlier
  /// context, so we open the form blank rather than guess wrong).
  static String? _extractPatientName(String input) {
    if (input.trim().isEmpty) return null;
    final s = input.replaceAll(RegExp(r'[।,.!?;:"()\[\]{}]+'), ' ');
    const stop = {
      'তুমি', 'আপনি', 'এই', 'এটা', 'এটাকে', 'ওই', 'একটা', 'একজন', 'নতুন',
      'রোগী', 'রোগীকে', 'রুগী', 'পেশেন্ট', 'পেশেন্টকে', 'প্যাশেন্ট', 'কে',
      'অ্যাড', 'এড', 'যোগ', 'করে', 'করো', 'কর', 'করুন', 'দাও', 'দিন', 'দে',
      'রেজিস্টার', 'নাম', 'করছি', 'দিচ্ছি',
      'मरीज़', 'मरीज', 'नया', 'जोड़', 'जोड़ो', 'करो', 'दो', 'को', 'यह', 'इस',
      'नाम', 'रजिस्टर',
      'add', 'new', 'patient', 'register', 'create', 'enroll', 'this', 'the',
      'a', 'an', 'please', 'naam', 'natun', 'joro', 'rogi', 'mariz',
    };
    final tokens = s
        .split(RegExp(r'\s+'))
        .map((t) => t.replaceAll(RegExp(r'(কে|को)$'), '').trim())
        .where((t) => t.isNotEmpty && !stop.contains(t.toLowerCase()))
        .toList();
    if (tokens.isEmpty || tokens.length > 4) return null;
    final name = tokens.join(' ').trim();
    return name.length < 2 ? null : name;
  }

  /// Parse a "show reports" utterance into Reports filters.
  /// Returns (time ∈ today/week/month, band ∈ emergency/attention/safe,
  /// search = patient name or case word). Any field may be null.
  static ({String? time, String? band, String? search}) _reportFilters(String input) {
    final s = ' ${input.toLowerCase()} ';
    String? time;
    // Yesterday FIRST — "কালকের"/"গতকাল" must not fall through to today.
    if (RegExp(r'গতকাল|কালকের|কালকে| কাল |yesterday|kal ').hasMatch(s)) {
      time = 'yesterday';
    } else if (RegExp(r'আজ|today|aaj').hasMatch(s)) {
      time = 'today';
    } else if (RegExp(r'সপ্তাহ|সাত\s*দিন|৭\s*দিন|7\s*din|week|saptah').hasMatch(s)) {
      time = 'week';
    } else if (RegExp(r'মাস|month|maah').hasMatch(s)) {
      time = 'month';
    }
    String? band;
    if (RegExp(r'জরুরি|জরুরী|লাল|emergency|urgent|red').hasMatch(s)) {
      band = 'emergency';
    } else if (RegExp(r'মনোযোগ|হলুদ|attention|yellow').hasMatch(s)) {
      band = 'attention';
    } else if (RegExp(r'নিরাপদ|সবুজ|safe|green').hasMatch(s)) {
      band = 'safe';
    }
    return (time: time, band: band, search: _extractReportSearch(input));
  }

  /// Free-text search term (patient name / case word) from a reports command.
  /// Strips command/time/band words; trailing possessive suffixes are trimmed
  /// (substring matching on the screen is forgiving, so over-trimming is safe).
  static String? _extractReportSearch(String input) {
    final s = input.replaceAll(RegExp(r'[।,.!?;:"()\[\]{}]+'), ' ');
    const stop = {
      // command / report words
      'রিপোর্ট', 'রিপোর্টের', 'রিপোর্টগুলো', 'রিপোর্টগুলি', 'রিপোর্টস', 'সব', 'সবগুলো',
      'সমস্ত', 'যতগুলো', 'আছে', 'দেখাও', 'দেখ', 'দেখান', 'দেখাচ্ছি', 'দাও', 'চাই',
      'দরকার', 'খোলো', 'খোল', 'খুলে', 'গুলো', 'গুলি',
      // pronouns ("to me / my") — these were leaking in as "আমা" after suffix-strip
      'আমাকে', 'আমায়', 'আমার', 'মোকে', 'মোর', 'তুমি', 'তোমার', 'তুই', 'আমা',
      // time words
      'আজ', 'আজকের', 'আজকে', 'কাল', 'কালকে', 'কালকের', 'গতকাল', 'গতকালের', 'গত',
      'সপ্তাহ', 'সপ্তাহের', 'সাত', 'দিন', 'মাস', 'মাসের', 'এই', 'এর',
      // band words
      'জরুরি', 'জরুরী', 'লাল', 'মনোযোগ', 'হলুদ', 'নিরাপদ', 'সবুজ',
      // hindi
      'रिपोर्ट', 'दिखा', 'दिखाओ', 'दो', 'सब', 'मुझे', 'मेरा', 'आज', 'कल', 'सप्ताह', 'महीना',
      // english
      'report', 'reports', 'show', 'open', 'give', 'all', 'me', 'my', 'the', 'of',
      'please', 'today', 'yesterday', 'week', 'month', 'red', 'yellow', 'green',
      'urgent', 'emergency',
    };
    bool isStop(String t) => stop.contains(t.toLowerCase());
    final tokens = s
        .split(RegExp(r'\s+'))
        .map((t) => t.trim())
        // Drop stop words on the ORIGINAL token FIRST — so "আমাকে" is removed
        // before its "কে" is stripped to a bogus "আমা".
        .where((t) => t.isNotEmpty && !isStop(t))
        // Only then trim trailing possessive/objective suffixes for matching.
        // "ের" (e-kar genitive, e.g. দাসের→দাস, আফানের→আফান) must come before a
        // bare "র" or only the র strips and a dangling "ে" is left behind.
        .map((t) =>
            t.replaceAll(RegExp(r'(কের|ের|এর|কে|য়ে|য়|ে|র)$'), '').trim())
        .where((t) => t.isNotEmpty && !isStop(t))
        .toList();
    if (tokens.isEmpty || tokens.length > 3) return null;
    final term = tokens.join(' ').trim();
    return term.length < 2 ? null : term;
  }

  String _confirm({required String bn, required String hi, required String en}) {
    return switch (lang) {
      AssistantLang.bn => bn,
      AssistantLang.hi => hi,
      AssistantLang.en => en,
    };
  }

  /// Test hook — exposes the spoken-reports parser so tests can prove the
  /// dynamic time / band / name filtering end-to-end without a live navigator.
  /// Not referenced by production code.
  @visibleForTesting
  static ({String? time, String? band, String? search}) debugParseReportFilters(
          String input) =>
      _reportFilters(input);
}
