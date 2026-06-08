// Regression guard for the two clinical-audit CODE safety fixes:
//   1. CONTRA_NB_002 must be WARN-ONLY (blocking:false) — cyanosis (n6) reported
//      without breathing difficulty (n3) is valid (cyanotic CHD) and must NEVER
//      halt the pipeline, or NB-006 (cyanosis → RED) is suppressed and a blue
//      neonate gets no band.
//   2. No blocking contradiction may reference a danger-sign answer question.
//
//   flutter test test/contradiction_failsafe_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:asha_mitra/core/services/layers/contradiction_checker.dart';

void main() {
  final checker = ContradictionChecker();

  test('cyanosis (n6) + no breathing difficulty (n3) does NOT block', () {
    final res = checker.check(
      moduleId: 'newborn',
      answers: {'n6': true, 'n3': false},
      vitals: {},
    );
    // CONTRA_NB_002 may still warn, but it must not be blocking.
    final nb002 =
        res.contradictions.where((c) => c.code == 'CONTRA_NB_002').toList();
    if (nb002.isNotEmpty) {
      expect(nb002.single.blocking, isFalse,
          reason: 'CONTRA_NB_002 must be warn-only so cyanosis still reaches RED');
    }
    // The crucial invariant: nothing in this result halts the pipeline.
    expect(res.contradictions.any((c) => c.blocking), isFalse,
        reason: 'a cyanosis answer must never trigger a blocking contradiction');
  });

  test('no blocking contradiction is keyed on a newborn danger-sign question',
      () {
    // Danger-sign answer questions for the newborn module (n1..n10). A blocking
    // contradiction on any of these would suppress its RED hard-stop.
    const dangerSignQs = {
      'n1', 'n2', 'n3', 'n4', 'n5', 'n6', 'n7', 'n8', 'n9', 'n10'
    };
    // Fire every possible newborn pair both ways; assert none blocks on a
    // danger-sign question.
    for (final qa in dangerSignQs) {
      for (final qb in dangerSignQs) {
        for (final va in [true, false]) {
          for (final vb in [true, false]) {
            final res = checker.check(
              moduleId: 'newborn',
              answers: {qa: va, qb: vb},
              vitals: {},
            );
            for (final c in res.contradictions) {
              if (c.blocking) {
                expect(dangerSignQs.contains(c.questionA), isFalse,
                    reason:
                        'blocking ${c.code} keyed on danger sign ${c.questionA}');
              }
            }
          }
        }
      }
    }
  });
}
