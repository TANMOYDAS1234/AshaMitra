// Exhaustive test of the LIVE decision engine: loads the real asha_engine.json,
// parses it with the real EngineModule.fromJson, and asserts that EVERY rule in
// EVERY module fires its declared band — plus graded-answer + safety invariants.
// This proves the deterministic decision layer (answers → band). It does NOT
// test speech understanding (see nlu_coverage_test.dart for that).

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:asha_mitra/core/services/layers/rule_engine.dart';

void main() {
  final raw = File('assets/data/asha_engine.json').readAsStringSync();
  final json = jsonDecode(raw) as Map<String, dynamic>;
  final modules = <String, EngineModule>{};
  for (final m in (json['modules'] as List)) {
    final mod = EngineModule.fromJson(m as Map<String, dynamic>);
    modules[mod.moduleId] = mod;
  }
  final engine = RuleEngine();

  // Build an answers+vitals map that satisfies a rule's condition_set.
  (Map<String, dynamic>, Map<String, dynamic>) satisfy(EngineRule r) {
    final a = <String, dynamic>{};
    final v = <String, dynamic>{};
    for (final c in r.conditionSet) {
      if (c.questionId != null) {
        a[c.questionId!] = c.operator == 'IN' ? (c.value as List).first : c.value;
      } else if (c.vital != null) {
        final val = c.value;
        switch (c.operator) {
          case 'LESS_THAN':              v[c.vital!] = (val as num) - 1; break;
          case 'GREATER_THAN':           v[c.vital!] = (val as num) + 1; break;
          case 'GREATER_THAN_OR_EQUAL':  v[c.vital!] = val; break;
          case 'LESS_THAN_OR_EQUAL':     v[c.vital!] = val; break;
          case 'EQUALS':                 v[c.vital!] = val; break;
          case 'BETWEEN':
            final l = val as List;
            v[c.vital!] = ((l[0] as num) + (l[1] as num)) / 2;
            break;
        }
      }
    }
    return (a, v);
  }

  group('every rule fires its declared band', () {
    modules.forEach((mid, mod) {
      final rules = <(EngineRule, String, String)>[
        for (final r in mod.hardStopRules) (r, 'RED', 'hard_stop'),
        for (final r in mod.combinationRules) (r, r.band, 'combination'),
        for (final r in mod.numericRules) (r, r.band, 'numeric'),
        for (final r in mod.yellowRules) (r, r.band, 'yellow'),
      ];
      for (final (r, expected, kind) in rules) {
        test('$mid/$kind/${r.ruleId} → $expected', () {
          final (a, v) = satisfy(r);
          final res = engine.evaluate(module: mod, answers: a, vitals: v);
          if (expected == 'RED') {
            expect(res.provisionalBand, 'RED', reason: '${r.ruleId} must lock RED');
          } else {
            // A YELLOW rule must at least raise the band off GREEN.
            expect(res.provisionalBand, isNot('GREEN'),
                reason: '${r.ruleId} must be at least YELLOW');
          }
        });
      }
    });
  });

  group('safety invariants & graded answers', () {
    modules.forEach((mid, mod) {
      test('$mid: all-NO → GREEN', () {
        final a = {for (final q in mod.questions.keys) q: false};
        expect(engine.evaluate(module: mod, answers: a, vitals: {}).provisionalBand,
            'GREEN');
      });
    });

    test('newborn: severe → RED (graded affirmative)', () {
      expect(
          engine.evaluate(module: modules['newborn']!, answers: {'n1': 'severe'}, vitals: {})
              .provisionalBand,
          'RED');
    });
    test('newborn: legacy bool true → RED (back-compat)', () {
      expect(
          engine.evaluate(module: modules['newborn']!, answers: {'n1': true}, vitals: {})
              .provisionalBand,
          'RED');
    });
    test('child: mild → at least YELLOW', () {
      expect(
          engine.evaluate(module: modules['child']!, answers: {'c2': 'mild'}, vitals: {})
              .provisionalBand,
          isNot('GREEN'));
    });
    test('child: unsure → blocks GREEN', () {
      expect(
          engine.evaluate(module: modules['child']!, answers: {'c2': 'unsure'}, vitals: {})
              .provisionalBand,
          isNot('GREEN'));
    });
    test('child: RED beats mild on another question', () {
      final res = engine.evaluate(
          module: modules['child']!, answers: {'c7': true, 'c2': 'mild'}, vitals: {});
      expect(res.provisionalBand, 'RED');
    });
    test('pregnancy: isolated fever (p9) → YELLOW, not RED', () {
      expect(
          engine.evaluate(module: modules['pregnancy']!, answers: {'p9': true}, vitals: {})
              .provisionalBand,
          'YELLOW');
    });
    test('pregnancy: isolated headache (p11) → YELLOW, not RED', () {
      expect(
          engine.evaluate(module: modules['pregnancy']!, answers: {'p11': true}, vitals: {})
              .provisionalBand,
          'YELLOW');
    });
    test('pregnancy: BP high (p1) stays RED', () {
      expect(
          engine.evaluate(module: modules['pregnancy']!, answers: {'p1': true}, vitals: {})
              .provisionalBand,
          'RED');
    });
  });
}
