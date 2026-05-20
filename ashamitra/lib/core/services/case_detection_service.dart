import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../features/triage/data/models/triage_case_model.dart';

class CaseDetectionService {
  static const _geminiKey = 'AIzaSyAza9BlFFmv9uSpd93g-ibAK6IcbgtIxic';
  static const _geminiUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$_geminiKey';
  static const _confidenceThreshold = 0.80;

  List<TriageCaseModel>? _cases;
  List<BandResolutionRule>? _bandRules;

  List<TriageCaseModel>? get cachedCases => _cases;
  List<BandResolutionRule>? get bandResolutionRules => _bandRules;

  Future<List<TriageCaseModel>> loadCases() async {
    if (_cases != null) return _cases!;
    final raw = await rootBundle.loadString('assets/data/triage_cases.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    _bandRules = (json['bandResolutionRules'] as List? ?? [])
        .map((e) => BandResolutionRule.fromJson(e as Map<String, dynamic>))
        .toList();
    _cases = (json['cases'] as List)
        .map((e) => TriageCaseModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return _cases!;
  }

  /// Returns detected case id + confidence (0.0–1.0).
  /// If confidence == 0.0 the situation was completely unrecognised;
  /// callers should show a manual-selection prompt instead of proceeding.
  Future<({String caseId, double confidence, String method})> detect(
      String transcript) async {
    final cases = await loadCases();

    // ── Stage 1: Rule-based keyword matching ──────────────────
    final ruleResult = _ruleBasedDetect(transcript, cases);
    if (ruleResult.confidence >= _confidenceThreshold) {
      return (
        caseId: ruleResult.caseId,
        confidence: ruleResult.confidence,
        method: 'rule'
      );
    }

    // ── Stage 2: Gemini AI fallback (only if we have some signal) ─
    // Skip Gemini entirely when zero keywords matched — it would just
    // hallucinate a case from a non-clinical utterance.
    if (ruleResult.confidence > 0.0) {
      try {
        final aiResult = await _geminiDetect(transcript, cases);
        if (aiResult.confidence > ruleResult.confidence) {
          return (
            caseId: aiResult.caseId,
            confidence: aiResult.confidence,
            method: 'ai'
          );
        }
      } catch (_) {
        // Gemini failed — fall through to best rule-based result
      }
    }

    return (
      caseId: ruleResult.caseId,
      confidence: ruleResult.confidence,
      method: 'rule'
    );
  }

  // ── Rule-based detection ─────────────────────────────────────
  ({String caseId, double confidence}) _ruleBasedDetect(
      String transcript, List<TriageCaseModel> cases) {
    final lower = transcript.toLowerCase();
    String bestId = cases.first.id;
    double bestScore = 0;

    for (final c in cases) {
      int hits = 0;
      for (final kw in c.keywords) {
        if (lower.contains(kw.toLowerCase())) hits++;
      }
      final score = hits / c.keywords.length;
      if (score > bestScore) {
        bestScore = score;
        bestId = c.id;
      }
    }

    // Normalize: 0 keyword hits → 0.0 confidence (unknown situation)
    // 1 hit → 0.6, 2 hits → 0.8, 3+ → 1.0
    final normalized = bestScore == 0
        ? 0.0
        : (0.5 + (bestScore * 0.5)).clamp(0.0, 1.0);

    return (caseId: bestId, confidence: normalized);
  }

  // ── Gemini AI detection ──────────────────────────────────────
  Future<({String caseId, double confidence})> _geminiDetect(
      String transcript, List<TriageCaseModel> cases) async {
    final caseList = cases.map((c) => '${c.id}: ${c.titleEn}').join('\n');
    final prompt = '''
You are a medical triage classifier for ASHA workers in rural India.
Given the following speech transcript, classify it into exactly one case type.

Available cases:
$caseList

Transcript: "$transcript"

Respond with ONLY a JSON object like:
{"caseId": "pregnancy", "confidence": 0.95}

Rules:
- caseId must be one of: ${cases.map((c) => c.id).join(', ')}
- confidence must be between 0.0 and 1.0
- No explanation, no markdown, just the JSON object
''';

    final response = await http
        .post(
          Uri.parse(_geminiUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': prompt}
                ]
              }
            ],
            'generationConfig': {'temperature': 0.1, 'maxOutputTokens': 64}
          }),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) throw Exception('Gemini error');

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final text = (body['candidates'][0]['content']['parts'][0]['text'] as String)
        .trim()
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();

    final result = jsonDecode(text) as Map<String, dynamic>;
    return (
      caseId: result['caseId'] as String,
      confidence: (result['confidence'] as num).toDouble(),
    );
  }
}
