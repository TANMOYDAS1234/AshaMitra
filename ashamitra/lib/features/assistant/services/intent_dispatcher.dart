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
  Future<DispatchResult> dispatch(ClassifiedIntent intent) async {
    HapticFeedback.lightImpact();
    switch (intent.intent) {
      case AssistantIntent.callAmbulance:
        // 108 = all-purpose emergency medical ambulance (matches the clinical
        // engine's RED-band action and the vitals danger alerts, which all
        // say "Call 108"). Single source of truth for the emergency number.
        return _callNumber('108');

      case AssistantIntent.findNearestPHC:
        // No standalone "nearest PHC" screen yet — emergency screen
        // already has facility info / map. When facility JSON ships,
        // swap this for a dedicated route.
        Get.toNamed(AppRoutes.emergency);
        return DispatchResult(
          handled: true,
          spokenConfirmation: _confirm(
            bn: 'কাছের হাসপাতাল দেখাচ্ছি।',
            hi: 'पास का अस्पताल दिखा रही हूँ।',
            en: 'Showing the nearest hospital.',
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
        Get.toNamed(AppRoutes.addPatient);
        return DispatchResult(
          handled: true,
          spokenConfirmation: _confirm(
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
        Get.toNamed(AppRoutes.reports);
        return DispatchResult(
          handled: true,
          spokenConfirmation: _confirm(
            bn: 'রিপোর্ট খুলছি।',
            hi: 'रिपोर्ट खोल रही हूँ।',
            en: 'Opening reports.',
          ),
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

  String _confirm({required String bn, required String hi, required String en}) {
    return switch (lang) {
      AssistantLang.bn => bn,
      AssistantLang.hi => hi,
      AssistantLang.en => en,
    };
  }
}
