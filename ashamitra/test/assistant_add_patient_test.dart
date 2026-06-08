// Proves the assistant's "add patient" voice parser pulls the right name (and
// age) out of the natural phrasings ASHAs use — the cases that were failing
// on-device: keeping "যার", extracting the verb "করতে পারো" as a name, or
// giving up (blank form) when an age phrase was present.
//
//   flutter test test/assistant_add_patient_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:asha_mitra/features/assistant/services/intent_dispatcher.dart';

void main() {
  ({String? name, String? age, String? ageUnit}) p(String s) =>
      IntentDispatcher.parseAddPatient(s);

  group('name extraction (the on-device failures)', () {
    test('রোগীর নাম … বয়স … বছর → name only, no blank', () {
      final r = p('তুমি নতুন রোগী অ্যাড করো রোগীর নাম রিয়া বিশ্বাস রোগীর বয়স ত্রিশ বছর');
      expect(r.name, 'রিয়া বিশ্বাস');
    });
    test('যার নাম … → drops "যার"', () {
      expect(p('তুমি নতুন রোগী অ্যাড করো যার নাম রিয়া বিশ্বাস').name, 'রিয়া বিশ্বাস');
    });
    test('"করতে পারো" is NOT a name', () {
      expect(p('তুমি নতুন রোগী এড করতে পারো').name, isNull);
    });
    test('name + age, no marker', () {
      expect(p('নতুন রোগী রিয়া বিশ্বাস বয়স ত্রিশ বছর').name, 'রিয়া বিশ্বাস');
    });
    test('add command + name + age', () {
      expect(p('তুমি নতুন রোগী অ্যাড করো রিয়া বিশ্বাস বয়স ত্রিশ বছর').name, 'রিয়া বিশ্বাস');
    });
    test('classic "<name> কে অ্যাড করো"', () {
      expect(p('সায়নি দাস কে অ্যাড করো').name, 'সায়নি দাস');
    });
    test('object-suffix attached: রিয়াকে → রিয়া', () {
      expect(p('রিয়াকে অ্যাড করো').name, 'রিয়া');
    });
    test('no name in command → null (open blank)', () {
      expect(p('এই পেশেন্ট অ্যাড করো').name, isNull);
    });
  });

  group('age extraction', () {
    test('ত্রিশ বছর → 30 years', () {
      final r = p('রোগীর নাম রিয়া বিশ্বাস বয়স ত্রিশ বছর');
      expect(r.age, '30');
      expect(r.ageUnit, 'years');
    });
    test('Bengali digits ২৫ বছর → 25 years', () {
      final r = p('রিয়া বিশ্বাস বয়স ২৫ বছর');
      expect(r.age, '25');
      expect(r.ageUnit, 'years');
    });
    test('ASCII digits + months: ৬ মাস', () {
      final r = p('নতুন রোগী টুনি বয়স ছয় মাস');
      expect(r.age, '6');
      expect(r.ageUnit, 'months');
    });
    test('no age → null', () {
      expect(p('সায়নি দাস কে অ্যাড করো').age, isNull);
    });
    test('age phrase never leaks into the name', () {
      final r = p('তুমি নতুন রোগী অ্যাড করো রিয়া বিশ্বাস বয়স ত্রিশ বছর');
      expect(r.name, isNot(contains('বছর')));
      expect(r.name, isNot(contains('ত্রিশ')));
      expect(r.name, isNot(contains('বয়স')));
    });
  });
}
