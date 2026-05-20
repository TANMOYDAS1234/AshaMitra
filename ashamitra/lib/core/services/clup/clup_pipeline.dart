// ─────────────────────────────────────────────────────────────────────────────
// CLUP Pipeline — Conversational Language Understanding Pipeline
//
// Orchestrates:
//   Layer 1: IntentDetector
//   Layer 2: ClinicalRelevanceFilter
//   Layer 3: ClarificationEngine
//
// Returns CLUPDecision which tells VoiceTriageScreen exactly what to do:
//   - proceed    → pass to RuleExecutor
//   - clarify    → ask follow-up question
//   - ignore     → discard input, do nothing
//   - emergency  → bypass all layers, lock RED immediately
// ─────────────────────────────────────────────────────────────────────────────

import 'intent_detector.dart';
import 'clinical_relevance_filter.dart';
import 'clarification_engine.dart';

enum CLUPAction {
  proceedToRuleEngine,  // clinical, relevant, current → run rules
  askClarification,     // vague, non-clinical, third-party, historical
  ignoreInput,          // pure non-clinical with no clinical segment
  emergencyLockRed,     // emergency detected → bypass everything
}

class CLUPDecision {
  final CLUPAction action;
  final IntentResult intentResult;
  final RelevanceResult? relevanceResult;
  final ClarificationOutput? clarification;

  // If action == proceedToRuleEngine, these are the extracted clinical tokens
  final List<String> extractedSymptoms;
  final String? cleanedText; // clinical segment only (mixed sentence stripped)

  // Audit
  final String rawInput;
  final String moduleId;
  final DateTime timestamp;

  const CLUPDecision({
    required this.action,
    required this.intentResult,
    required this.relevanceResult,
    required this.clarification,
    required this.extractedSymptoms,
    required this.cleanedText,
    required this.rawInput,
    required this.moduleId,
    required this.timestamp,
  });

  bool get shouldProceed  => action == CLUPAction.proceedToRuleEngine;
  bool get shouldClarify  => action == CLUPAction.askClarification;
  bool get shouldIgnore   => action == CLUPAction.ignoreInput;
  bool get isEmergency    => action == CLUPAction.emergencyLockRed;

  Map<String, dynamic> toMap() => {
    'action': action.name,
    'intent': intentResult.toMap(),
    'relevance': relevanceResult?.toMap(),
    'clarification': clarification?.toMap(),
    'extracted_symptoms': extractedSymptoms,
    'cleaned_text': cleanedText,
    'raw_input': rawInput,
    'module_id': moduleId,
    'timestamp': timestamp.toIso8601String(),
  };
}

class CLUPPipeline {
  final _intentDetector    = IntentDetector();
  final _relevanceFilter   = ClinicalRelevanceFilter();
  final _clarificationEngine = ClarificationEngine();

  /// Processes raw speech input through the full CLUP pipeline.
  ///
  /// [input]    — raw speech transcript
  /// [moduleId] — active clinical module
  CLUPDecision process({
    required String input,
    required String moduleId,
  }) {
    final timestamp = DateTime.now();
    final trimmed = input.trim();

    // ── Empty input ───────────────────────────────────────────────────────
    if (trimmed.isEmpty) {
      final intent = IntentResult(
        intent: IntentClass.unclear,
        confidence: 1.0,
        matchedTokens: [],
      );
      return CLUPDecision(
        action: CLUPAction.askClarification,
        intentResult: intent,
        relevanceResult: null,
        clarification: _clarificationEngine.generate(
          intent: intent,
          moduleId: moduleId,
        ),
        extractedSymptoms: [],
        cleanedText: null,
        rawInput: trimmed,
        moduleId: moduleId,
        timestamp: timestamp,
      );
    }

    // ── Layer 1: Intent Detection ─────────────────────────────────────────
    final intent = _intentDetector.classify(trimmed, moduleId: moduleId);

    // ── Emergency: bypass everything ─────────────────────────────────────
    if (intent.isEmergency) {
      return CLUPDecision(
        action: CLUPAction.emergencyLockRed,
        intentResult: intent,
        relevanceResult: null,
        clarification: null,
        extractedSymptoms: intent.matchedTokens,
        cleanedText: trimmed,
        rawInput: trimmed,
        moduleId: moduleId,
        timestamp: timestamp,
      );
    }

    // ── Pure non-clinical with no clinical segment ────────────────────────
    if (intent.isNonClinical && intent.extractedClinicalSegment == null) {
      final clarification = _clarificationEngine.generate(
        intent: intent,
        moduleId: moduleId,
      );
      return CLUPDecision(
        action: CLUPAction.askClarification,
        intentResult: intent,
        relevanceResult: null,
        clarification: clarification,
        extractedSymptoms: [],
        cleanedText: null,
        rawInput: trimmed,
        moduleId: moduleId,
        timestamp: timestamp,
      );
    }

    // ── Third-party with no self-symptom ──────────────────────────────────
    if (intent.isThirdParty) {
      final clarification = _clarificationEngine.generate(
        intent: intent,
        moduleId: moduleId,
      );
      return CLUPDecision(
        action: CLUPAction.askClarification,
        intentResult: intent,
        relevanceResult: null,
        clarification: clarification,
        extractedSymptoms: [],
        cleanedText: null,
        rawInput: trimmed,
        moduleId: moduleId,
        timestamp: timestamp,
      );
    }

    // ── Vague or unclear → ask clarification ─────────────────────────────
    if (intent.needsClarification || intent.intent == IntentClass.unclear) {
      final clarification = _clarificationEngine.generate(
        intent: intent,
        moduleId: moduleId,
      );
      return CLUPDecision(
        action: CLUPAction.askClarification,
        intentResult: intent,
        relevanceResult: null,
        clarification: clarification,
        extractedSymptoms: [],
        cleanedText: null,
        rawInput: trimmed,
        moduleId: moduleId,
        timestamp: timestamp,
      );
    }

    // ── Layer 2: Clinical Relevance Filter ────────────────────────────────
    final textToFilter = intent.extractedClinicalSegment ?? trimmed;
    final relevance = _relevanceFilter.filter(
      text: textToFilter,
      moduleId: moduleId,
      matchedTokens: intent.matchedTokens,
    );

    // ── Historical → ask if current ───────────────────────────────────────
    if (relevance.isHistorical) {
      final clarification = _clarificationEngine.generate(
        intent: intent,
        moduleId: moduleId,
        isHistorical: true,
      );
      return CLUPDecision(
        action: CLUPAction.askClarification,
        intentResult: intent,
        relevanceResult: relevance,
        clarification: clarification,
        extractedSymptoms: [],
        cleanedText: null,
        rawInput: trimmed,
        moduleId: moduleId,
        timestamp: timestamp,
      );
    }

    // ── Not relevant to module → ask module-specific question ─────────────
    if (!relevance.relevant) {
      final clarification = _clarificationEngine.generate(
        intent: intent,
        moduleId: moduleId,
      );
      return CLUPDecision(
        action: CLUPAction.askClarification,
        intentResult: intent,
        relevanceResult: relevance,
        clarification: clarification,
        extractedSymptoms: [],
        cleanedText: null,
        rawInput: trimmed,
        moduleId: moduleId,
        timestamp: timestamp,
      );
    }

    // ── Relevant clinical symptom → proceed to rule engine ────────────────
    return CLUPDecision(
      action: CLUPAction.proceedToRuleEngine,
      intentResult: intent,
      relevanceResult: relevance,
      clarification: null,
      extractedSymptoms: relevance.relevantSymptoms,
      cleanedText: textToFilter,
      rawInput: trimmed,
      moduleId: moduleId,
      timestamp: timestamp,
    );
  }

  /// Resets clarification rotation for a new session.
  void resetSession() => _clarificationEngine.reset();
}
