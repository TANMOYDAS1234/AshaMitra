// ─────────────────────────────────────────────────────────────────────────────
// CLUP Layer 3 — Clarification Engine
//
// Generates safe, protocol-driven follow-up questions when:
//   - Intent is non_clinical → polite redirect
//   - Intent is clinical_vague → narrow the symptom
//   - Intent is third_party → redirect to current patient
//   - Intent is unclear → open clinical prompt
//   - Relevance filter says clarification needed
//
// GOLDEN RULE:
//   Never assume GREEN when clinical information is insufficient.
//   Always ask before concluding no symptoms.
// ─────────────────────────────────────────────────────────────────────────────

import 'intent_detector.dart';

class ClarificationOutput {
  final String questionBn;       // Bengali question to speak/display
  final String questionEn;       // English (for logs)
  final ClarificationType type;
  final bool blockRuleEngine;    // true = do not run rule engine yet

  const ClarificationOutput({
    required this.questionBn,
    required this.questionEn,
    required this.type,
    required this.blockRuleEngine,
  });

  Map<String, dynamic> toMap() => {
    'question_bn': questionBn,
    'question_en': questionEn,
    'type': type.name,
    'block_rule_engine': blockRuleEngine,
  };
}

enum ClarificationType {
  nonClinicalRedirect,   // "salary বেড়েছে" → ask about health
  thirdPartyRedirect,    // "স্বামীর জ্বর" → ask about self
  vagueSymptomNarrow,    // "শরীর খারাপ" → ask what specifically
  historicalClarify,     // "আগে জ্বর ছিল" → ask if current
  moduleSpecificPrompt,  // module-aware follow-up
  insufficientInfo,      // no clinical info at all
}

class ClarificationEngine {
  // ── Non-clinical redirects ────────────────────────────────────────────────
  static const _nonClinicalResponses = [
    (
      bn: 'আপনার কি কোনো শারীরিক সমস্যা বা অসুবিধা হচ্ছে?',
      en: 'Are you experiencing any physical problem or discomfort?',
    ),
    (
      bn: 'আপনার শরীরে কি কোনো কষ্ট বা ব্যথা আছে?',
      en: 'Do you have any pain or discomfort in your body?',
    ),
    (
      bn: 'আপনার স্বাস্থ্য সম্পর্কে কিছু বলুন — কোনো সমস্যা হচ্ছে?',
      en: 'Tell me about your health — are you having any problems?',
    ),
  ];

  // ── Third-party redirects ─────────────────────────────────────────────────
  static const _thirdPartyResponses = [
    (
      bn: 'আপনার নিজের কোনো শারীরিক সমস্যা হচ্ছে?',
      en: 'Are you yourself experiencing any physical problem?',
    ),
    (
      bn: 'আপনার শরীরে কি কোনো অসুবিধা আছে?',
      en: 'Do you have any discomfort in your own body?',
    ),
  ];

  // ── Vague symptom narrowing — per module ─────────────────────────────────
  static const _vagueNarrowByModule = <String, List<({String bn, String en})>>{
    'pregnancy': [
      (bn: 'মাথা ব্যথা, পা ফোলা, বা রক্তপাত হচ্ছে?', en: 'Headache, leg swelling, or bleeding?'),
      (bn: 'বাচ্চার নড়াচড়া কি স্বাভাবিক আছে?', en: 'Is the baby moving normally?'),
      (bn: 'চোখে ঝাপসা বা মাথা ঘুরছে?', en: 'Blurred vision or dizziness?'),
    ],
    'newborn': [
      (bn: 'শিশু কি বুকের দুধ খাচ্ছে?', en: 'Is the baby breastfeeding?'),
      (bn: 'শিশুর জ্বর বা শ্বাসকষ্ট আছে?', en: 'Does the baby have fever or breathing difficulty?'),
      (bn: 'শিশু কি নড়াচড়া করছে স্বাভাবিকভাবে?', en: 'Is the baby moving normally?'),
    ],
    'child': [
      (bn: 'জ্বর, কাশি, বা ডায়রিয়া হচ্ছে?', en: 'Fever, cough, or diarrhoea?'),
      (bn: 'শিশু কি খাচ্ছে?', en: 'Is the child eating?'),
      (bn: 'শিশুর চোখ কি গর্তে বসে গেছে?', en: 'Are the child\'s eyes sunken?'),
    ],
    'delivery_pnc': [
      (bn: 'অতিরিক্ত রক্তপাত বা দুর্গন্ধযুক্ত স্রাব হচ্ছে?', en: 'Excessive bleeding or foul discharge?'),
      (bn: 'জ্বর বা পেটে ব্যথা হচ্ছে?', en: 'Fever or abdominal pain?'),
      (bn: 'খুব দুর্বল বা মাথা ঘুরছে?', en: 'Extreme weakness or dizziness?'),
    ],
    'immunisation': [
      (bn: 'কোন টিকা মিস হয়েছে?', en: 'Which vaccine was missed?'),
      (bn: 'শিশুর বয়স কত মাস?', en: 'What is the child\'s age in months?'),
    ],
    'emergency': [
      (bn: 'খিঁচুনি, অজ্ঞান, বা শ্বাস বন্ধ হয়েছে?', en: 'Seizure, unconsciousness, or stopped breathing?'),
      (bn: 'রক্তপাত থামছে না?', en: 'Is bleeding not stopping?'),
    ],
  };

  // ── Historical clarification ──────────────────────────────────────────────
  static const _historicalClarify = (
    bn: 'এটা কি এখনও হচ্ছে, নাকি আগে হয়েছিল?',
    en: 'Is this happening now, or did it happen before?',
  );

  // ── Insufficient info ─────────────────────────────────────────────────────
  static const _insufficientInfo = (
    bn: 'আপনার কোনো শারীরিক সমস্যা হচ্ছে? বিস্তারিত বলুন।',
    en: 'Are you having any physical problem? Please describe.',
  );

  int _nonClinicalIndex = 0;
  int _thirdPartyIndex  = 0;
  final Map<String, int> _vagueIndexByModule = {};

  /// Generates the appropriate clarification question.
  ///
  /// [intent]    — from IntentDetector
  /// [moduleId]  — active clinical module
  /// [isHistorical] — from RelevanceFilter
  ClarificationOutput generate({
    required IntentResult intent,
    required String moduleId,
    bool isHistorical = false,
  }) {
    // ── Historical clarification ──────────────────────────────────────────
    if (isHistorical) {
      return ClarificationOutput(
        questionBn: _historicalClarify.bn,
        questionEn: _historicalClarify.en,
        type: ClarificationType.historicalClarify,
        blockRuleEngine: true,
      );
    }

    // ── Non-clinical redirect ─────────────────────────────────────────────
    if (intent.intent == IntentClass.nonClinical) {
      final r = _nonClinicalResponses[
          _nonClinicalIndex % _nonClinicalResponses.length];
      _nonClinicalIndex++;
      return ClarificationOutput(
        questionBn: r.bn,
        questionEn: r.en,
        type: ClarificationType.nonClinicalRedirect,
        blockRuleEngine: true,
      );
    }

    // ── Third-party redirect ──────────────────────────────────────────────
    if (intent.intent == IntentClass.thirdParty) {
      final r = _thirdPartyResponses[
          _thirdPartyIndex % _thirdPartyResponses.length];
      _thirdPartyIndex++;
      return ClarificationOutput(
        questionBn: r.bn,
        questionEn: r.en,
        type: ClarificationType.thirdPartyRedirect,
        blockRuleEngine: true,
      );
    }

    // ── Vague symptom — module-specific narrowing ─────────────────────────
    if (intent.intent == IntentClass.clinicalVague) {
      final moduleQuestions = _vagueNarrowByModule[moduleId] ??
          _vagueNarrowByModule['emergency']!;
      final idx = (_vagueIndexByModule[moduleId] ?? 0) % moduleQuestions.length;
      _vagueIndexByModule[moduleId] = idx + 1;
      final q = moduleQuestions[idx];
      return ClarificationOutput(
        questionBn: q.bn,
        questionEn: q.en,
        type: ClarificationType.vagueSymptomNarrow,
        blockRuleEngine: true,
      );
    }

    // ── Unclear ───────────────────────────────────────────────────────────
    return ClarificationOutput(
      questionBn: _insufficientInfo.bn,
      questionEn: _insufficientInfo.en,
      type: ClarificationType.insufficientInfo,
      blockRuleEngine: true,
    );
  }

  /// Resets rotation counters for a new session.
  void reset() {
    _nonClinicalIndex = 0;
    _thirdPartyIndex  = 0;
    _vagueIndexByModule.clear();
  }
}
