// Regression tests for the ambulance false-trigger fix.
//
// Before the fix, the rule classifier dialed an ambulance whenever a message
// merely contained "102"/"108" OR the 2-char substring "কল" (which hides
// inside ordinary words like "থাকলে"). Fever questions were being hijacked
// into emergency calls. The fix: ambulance triggers ONLY on the explicit
// ambulance word, with token-aware (not substring) matching.

import 'package:flutter_test/flutter_test.dart';
import 'package:asha_mitra/features/assistant/services/intent_classifier.dart';
import 'package:asha_mitra/features/assistant/services/assistant_chat_service.dart';

void main() {
  final c = RuleBasedIntentClassifier();

  group('Ambulance false-trigger is fixed', () {
    test('fever question containing "102" does NOT call ambulance', () {
      final r = c.classify('আচ্ছা ১০২ সেলসিয়াসের জ্বর থাকলে কি করব', AssistantLang.bn);
      expect(r.intent, isNot(AssistantIntent.callAmbulance));
    });

    test('"৫০০ জ্বর থাকলে" (থাকলে⊅কল) does NOT call ambulance', () {
      final r = c.classify('৫০০ জ্বর থাকলে কি করবে', AssistantLang.bn);
      expect(r.intent, isNot(AssistantIntent.callAmbulance));
    });

    test('"মাকে ফোন করো" does NOT call ambulance', () {
      final r = c.classify('মাকে ফোন করো', AssistantLang.bn);
      expect(r.intent, isNot(AssistantIntent.callAmbulance));
    });
  });

  group('Genuine intents still work', () {
    test('explicit ambulance request DOES trigger', () {
      final r = c.classify('একটা অ্যাম্বুলেন্স ডাকো এখনই', AssistantLang.bn);
      expect(r.intent, AssistantIntent.callAmbulance);
    });

    test('"ambulance" (English) DOES trigger', () {
      final r = c.classify('please call an ambulance', AssistantLang.en);
      expect(r.intent, AssistantIntent.callAmbulance);
    });

    test('open patient list still classifies correctly', () {
      final r = c.classify('রোগীদের তালিকা দেখাও', AssistantLang.bn);
      expect(r.intent, AssistantIntent.openPatientList);
    });
  });
}
