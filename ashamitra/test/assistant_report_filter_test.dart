// Proves the assistant's "show reports" voice parser resolves the dynamic
// filtering/search the worker asks for: time band (today/yesterday/week/month),
// risk band (emergency/attention/safe), and free-text patient-name search —
// individually and combined. Guards the fix for "assistant did not work for all
// filtration, searching tasks dynamically".
//
//   flutter test test/assistant_report_filter_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:asha_mitra/features/assistant/services/intent_dispatcher.dart';

void main() {
  ({String? time, String? band, String? search}) parse(String s) =>
      IntentDispatcher.debugParseReportFilters(s);

  group('time band', () {
    test('আজকের → today', () {
      expect(parse('আজকের রিপোর্ট দেখাও').time, 'today');
    });
    test('গতকালের → yesterday (must not fall through to today)', () {
      expect(parse('গতকালের রিপোর্ট দেখাও').time, 'yesterday');
    });
    test('কালকের → yesterday', () {
      expect(parse('কালকের রিপোর্টগুলো দেখাও').time, 'yesterday');
    });
    test('এই সপ্তাহের → week', () {
      expect(parse('এই সপ্তাহের রিপোর্ট').time, 'week');
    });
    test('সাত দিনের → week', () {
      expect(parse('সাত দিনের রিপোর্ট দাও').time, 'week');
    });
    test('এই মাসের → month', () {
      expect(parse('এই মাসের সব রিপোর্ট').time, 'month');
    });
    test('english yesterday', () {
      expect(parse("show yesterday's reports").time, 'yesterday');
    });
    test('no time word → null', () {
      expect(parse('সব রিপোর্ট দেখাও').time, isNull);
    });
  });

  group('risk band', () {
    test('জরুরি → emergency', () {
      expect(parse('জরুরি রিপোর্টগুলো দেখাও').band, 'emergency');
    });
    test('লাল → emergency', () {
      expect(parse('লাল রিপোর্ট').band, 'emergency');
    });
    test('মনোযোগ → attention', () {
      expect(parse('মনোযোগের রিপোর্ট দাও').band, 'attention');
    });
    test('হলুদ → attention', () {
      expect(parse('হলুদ রিপোর্ট').band, 'attention');
    });
    test('নিরাপদ → safe', () {
      expect(parse('নিরাপদ রিপোর্টগুলো').band, 'safe');
    });
    test('সবুজ → safe', () {
      expect(parse('সবুজ রিপোর্ট দেখাও').band, 'safe');
    });
    test('english urgent', () {
      expect(parse('show urgent reports').band, 'emergency');
    });
  });

  group('name / free-text search', () {
    test('plain name', () {
      expect(parse('সায়নি দাসের রিপোর্ট দেখাও').search, 'সায়নি দাস');
    });
    test('single name', () {
      expect(parse('আফানের রিপোর্ট').search, 'আফান');
    });
    test('"আমাকে ... দেখাও" must NOT pollute search with আমা', () {
      // Regression: "আমাকে" used to be suffix-stripped to "আমা" and leak in.
      final r = parse('আমাকে রিমার রিপোর্ট দেখাও');
      expect(r.search, 'রিমা');
    });
    test('pure command (no name) → null search', () {
      expect(parse('সব রিপোর্ট দেখাও').search, isNull);
    });
    test('time-only command → null search', () {
      expect(parse('আজকের রিপোর্ট দেখাও').search, isNull);
    });
    test('band-only command → null search', () {
      expect(parse('জরুরি রিপোর্ট দেখাও').search, isNull);
    });
  });

  group('combined dynamic cases', () {
    test('time + band together', () {
      final r = parse('আজকের জরুরি রিপোর্ট দেখাও');
      expect(r.time, 'today');
      expect(r.band, 'emergency');
      expect(r.search, isNull);
    });
    test('yesterday + safe', () {
      final r = parse('গতকালের নিরাপদ রিপোর্ট');
      expect(r.time, 'yesterday');
      expect(r.band, 'safe');
    });
    test('name + time (name survives, time captured)', () {
      final r = parse('আজকের রিমার রিপোর্ট দেখাও');
      expect(r.time, 'today');
      expect(r.search, 'রিমা');
    });
  });
}
