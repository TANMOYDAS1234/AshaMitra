import 'rule_executor.dart';
import 'trace_database.dart';

/// Triggers MDSR audit hooks for RED outcomes in delivery_pnc and newborn.
/// Writes to SQLite mdsr_queue table for background sync to RCH portal.
class MdsrHookService {
  final _db = TraceDatabase();

  static const _mdsrModules = {'delivery_pnc', 'newborn'};

  /// Enqueues an MDSR entry if conditions are met.
  /// Accepts [DecisionOutput] (v2) or legacy [dynamic] for backward compat.
  Future<bool> evaluateAndEnqueue({
    required String sessionId,
    required String moduleId,
    required dynamic result, // DecisionOutput
    required Map<String, String> answers,
    String? patientId,
    String? patientName,
    String? ashaId,
  }) async {
    final String band;
    final String firedRuleId;
    final bool hardStop;
    final bool invariantLocked;
    final bool signOffPending;
    final String referral;
    final String actionEn;

    if (result is DecisionOutput) {
      band            = result.finalBand;
      firedRuleId     = result.ruleId;
      hardStop        = result.redLock;
      invariantLocked = result.redLock;
      signOffPending  = result.signOffPending;
      referral        = result.facilityType;
      actionEn        = result.actionCard.summaryEn;
    } else {
      // Legacy EngineResult path
      band            = result.band as String;
      firedRuleId     = result.ruleId as String;
      hardStop        = result.hardStop as bool;
      invariantLocked = result.invariantLocked as bool;
      signOffPending  = result.signOffPending as bool;
      referral        = result.referral as String;
      actionEn        = result.actionEn as String;
    }

    if (band != 'RED') return false;
    if (!_mdsrModules.contains(moduleId)) return false;

    await _db.insertMdsr(
      sessionId: sessionId,
      moduleId: moduleId,
      firedRuleId: firedRuleId,
      band: band,
      hardStop: hardStop,
      invariantLocked: invariantLocked,
      signOffPending: signOffPending,
      referral: referral,
      actionEn: actionEn,
      patientId: patientId,
      patientName: patientName,
      ashaId: ashaId,
      clinicalAnswers: answers.entries
          .where((e) => !e.key.startsWith('_'))
          .map((e) => {'questionId': e.key, 'answer': e.value})
          .toList(),
    );
    return true;
  }

  Future<List<Map<String, dynamic>>> pendingQueue() => _db.pendingMdsr();
  Future<void> markSynced(String sessionId) => _db.markMdsrSynced(sessionId);
}
