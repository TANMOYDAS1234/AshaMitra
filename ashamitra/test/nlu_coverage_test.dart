// Coverage test for the speech-understanding layer (the weak link). Feeds
// realistic Bengali phrasings per danger sign through the REAL offline keyword
// extractor + AnswerCodes.fromSpeech and asserts they map to the right
// question / code. A failure here = a real recognition gap to harden.
//
// NOTE: this only measures the OFFLINE keyword path. Online (Gemini) is more
// flexible and not covered here — and neither path is a guarantee for arbitrary
// real-world speech; that needs field testing.

import 'package:flutter_test/flutter_test.dart';
import 'package:asha_mitra/core/services/clup/situation_extractor.dart';
import 'package:asha_mitra/core/services/answer_codes.dart';

void main() {
  final ex = SituationExtractor();

  // (moduleId, spoken phrase, expected questionId it should set)
  const fixtures = <List<String>>[
    // newborn
    ['newborn', 'বাচ্চা দুধ খাচ্ছে না', 'n1'],
    ['newborn', 'শরীরে জ্বর আছে', 'n2'],
    ['newborn', 'শ্বাসকষ্ট হচ্ছে', 'n3'],
    ['newborn', 'নাভিতে পুঁজ', 'n4'],
    ['newborn', 'খুব নিস্তেজ', 'n5'],
    ['newborn', 'ত্বক হলুদ হয়ে গেছে', 'n6'],
    ['newborn', 'খিঁচুনি হচ্ছে', 'n7'],
    ['newborn', 'শরীর ঠান্ডা লাগছে', 'n8'],
    ['newborn', 'কান থেকে পুঁজ পড়ছে', 'n9'],
    ['newborn', 'মাথার তালু ফুলে উঁচু', 'n10'],
    // child
    ['child', 'পাঁচ দিনের বেশি জ্বর', 'c1'],
    ['child', 'কাশি হচ্ছে', 'c2'],
    ['child', 'ডায়রিয়া হচ্ছে', 'c3'],
    ['child', 'খেতে চাইছে না', 'c4'],
    ['child', 'চোখ গর্তে বসে গেছে', 'c5'],
    ['child', 'ওজন অনেক কম', 'c6'],
    ['child', 'খিঁচুনি হয়েছে', 'c7'],
    ['child', 'অজ্ঞান হয়ে গেছে', 'c8'],
    ['child', 'যা খাচ্ছে সব বমি করছে', 'c9'],
    ['child', 'ঘাড় শক্ত হয়ে গেছে', 'c10'],
    ['child', 'আমাশা হয়েছে', 'c11'],
    ['child', 'পায়খানার সাথে রক্ত যাচ্ছে', 'c11'],
    ['child', 'হাতের তালু খুব ফ্যাকাশে', 'c12'],
    // pregnancy
    ['pregnancy', 'রক্তচাপ বেশি', 'p1'],
    ['pregnancy', 'পা ফুলেছে', 'p2'],
    ['pregnancy', 'রক্তপাত হচ্ছে', 'p3'],
    ['pregnancy', 'বাচ্চা নড়ছে না', 'p4'],
    ['pregnancy', 'চেকআপ হয়নি', 'p5'],
    ['pregnancy', 'চোখে ঝাপসা দেখছে', 'p6'],
    ['pregnancy', 'খিঁচুনি হয়েছে', 'p7'],
    ['pregnancy', 'খুব ফ্যাকাশে লাগছে', 'p8'],
    ['pregnancy', 'কাঁপুনি দিয়ে জ্বর', 'p9'],
    ['pregnancy', 'যোনিপথে জল ভেঙেছে', 'p10'],
    ['pregnancy', 'মাথা ব্যথা হচ্ছে', 'p11'],
    ['pregnancy', 'মাথা ঘুরছে', 'p12'],
    // postpartum
    ['delivery_pnc', 'অতিরিক্ত রক্তপাত হচ্ছে', 'pp1'],
    ['delivery_pnc', 'জ্বর আছে', 'pp2'],
    ['delivery_pnc', 'স্তনে ব্যথা', 'pp3'],
    ['delivery_pnc', 'পেটে তীব্র ব্যথা', 'pp4'],
    ['delivery_pnc', 'প্রস্রাবে জ্বালা', 'pp5'],
    ['delivery_pnc', 'খুব দুর্বল', 'pp6'],
    ['delivery_pnc', 'খিঁচুনি হয়েছে', 'pp7'],
    ['delivery_pnc', 'শ্বাস নিতে কষ্ট', 'pp8'],
    ['delivery_pnc', 'মন খুব খারাপ কান্না পাচ্ছে', 'pp9'],
    // emergency
    ['emergency', 'অতিরিক্ত রক্তপাত', 'e1'],
    ['emergency', 'অজ্ঞান হয়ে গেছে', 'e2'],
    ['emergency', 'শ্বাস বন্ধ', 'e3'],
    ['emergency', 'সাড়া দিচ্ছে না', 'e4'],
    ['emergency', 'সাপে কামড়েছে', 'e5'],
    ['emergency', 'বিষ খেয়েছে', 'e6'],
    ['emergency', 'ঠান্ডা ঘাম দুর্বল নাড়ি', 'e7'],
    ['emergency', 'গুরুতর আঘাত বড় ক্ষত', 'e8'],
    // immunisation
    ['immunisation', 'টিকা মিস হয়েছে', 'im2'],
    ['immunisation', 'এখন অসুস্থ', 'im4'],
    ['immunisation', 'বুস্টার ডোজ মিস', 'im5'],
    ['immunisation', 'আগের টিকার পর গুরুতর প্রতিক্রিয়া', 'im6'],
  ];

  group('offline extractor maps danger-sign phrasings', () {
    var hit = 0;
    for (final f in fixtures) {
      final mid = f[0], phrase = f[1], qid = f[2];
      test('[$mid] "$phrase" → $qid', () {
        final r = ex.extract(situation: phrase, moduleId: mid);
        expect(r.preAnswers[qid], true, reason: '"$phrase" should set $qid=true');
      });
      final r = ex.extract(situation: phrase, moduleId: mid);
      if (r.preAnswers[qid] == true) hit++;
    }
    test('coverage summary', () {
      // ignore: avoid_print
      print('OFFLINE extractor coverage: $hit/${fixtures.length} '
          '(${(hit * 100 / fixtures.length).toStringAsFixed(0)}%)');
      expect(hit, fixtures.length, reason: 'all listed phrasings should map');
    });
  });

  group('graded answer parsing (fromSpeech)', () {
    const codeFixtures = <List<String>>[
      ['হ্যাঁ', AnswerCodes.yes],
      ['হ্যাঁ আছে', AnswerCodes.yes],
      ['জ্বর আছে', AnswerCodes.yes],
      ['না', AnswerCodes.no],
      ['নরমালি আছে', AnswerCodes.no],
      ['না তেমন কোন ব্যাপার নেই নরমালি আছে', AnswerCodes.no],
      ['না এসব কিছু হচ্ছে না', AnswerCodes.no],
      ['কিছু হয়নি', AnswerCodes.no],
      ['একটু', AnswerCodes.mild],
      ['মাঝে মাঝে হয়', AnswerCodes.mild],
      ['খুব বেশি', AnswerCodes.severe],
      ['অনেক', AnswerCodes.severe],
      ['নিশ্চিত না', AnswerCodes.unsure],
      ['জানি না', AnswerCodes.unsure],
    ];
    for (final f in codeFixtures) {
      test('fromSpeech("${f[0]}") → ${f[1]}', () {
        expect(AnswerCodes.fromSpeech(f[0]), f[1]);
      });
    }
  });
}
