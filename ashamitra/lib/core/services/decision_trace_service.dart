import 'package:uuid/uuid.dart';
import 'rule_executor.dart';
import 'clinical_engine_service.dart';
import 'trace_database.dart';

/// Writes a complete ordered decision trace to SQLite after every
/// engine evaluation. Satisfies the MDSR audit requirement:
/// "An MDSR audit can reproduce the ASHA's decision flow exactly."
class DecisionTraceService {
  final _db = TraceDatabase();
  static const _uuid = Uuid();

  static String newSessionId() => _uuid.v4();

  /// Accepts either [DecisionOutput] (v2) or [EngineResult] (v1 adapter).
  Future<void> write({
    required String sessionId,
    required String caseId,
    required String moduleId,
    required Map<String, dynamic> answers,
    required dynamic result, // DecisionOutput | EngineResult
    required String? protocolHash,
  }) async {
    final String finalBand;
    final String firedRuleId;
    final bool hardStop;
    final bool invariantLocked;
    final bool signOffPending;
    final String referral;
    final String actionEn;
    final List<Map<String, dynamic>> ruleTrace;

    if (result is DecisionOutput) {
      finalBand = result.finalBand;
      firedRuleId = result.ruleId;
      hardStop = result.redLock;
      invariantLocked = result.redLock;
      signOffPending = result.signOffPending;
      referral = result.facilityType;
      actionEn = result.recommendedActions.isNotEmpty ? result.recommendedActions.first : '';
      ruleTrace = result.trace.map((t) => t.toMap()).toList();
    } else {
      final r = result as EngineResult;
      finalBand = r.band;
      firedRuleId = r.ruleId;
      hardStop = r.hardStop;
      invariantLocked = r.invariantLocked;
      signOffPending = r.signOffPending;
      referral = r.referral;
      actionEn = r.actionEn;
      ruleTrace = r.trace.map((t) => t.toMap()).toList();
    }

    final cleanAnswers = answers.entries
        .where((e) => !e.key.startsWith('_'))
        .map((e) => {'questionId': e.key, 'answer': e.value.toString()})
        .toList();

    await _db.insertTrace(
      sessionId: sessionId,
      caseId: caseId,
      moduleId: moduleId,
      finalBand: finalBand,
      firedRuleId: firedRuleId,
      hardStop: hardStop,
      invariantLocked: invariantLocked,
      signOffPending: signOffPending,
      protocolHash: protocolHash,
      referral: referral,
      actionEn: actionEn,
      answers: cleanAnswers,
      ruleTrace: ruleTrace,
    );
  }

  Future<List<Map<String, dynamic>>> readAll({int limit = 200}) =>
      _db.allTraces(limit: limit);

  Future<Map<String, dynamic>?> readSession(String sessionId) =>
      _db.traceBySession(sessionId);
}
