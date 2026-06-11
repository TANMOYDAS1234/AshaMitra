import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../../features/triage/data/models/triage_case_model.dart';

class CaseDetectionService {
  // The Gemini call lives on the backend (/api/detect-case) so the API key
  // never ships inside the APK. Stage-1 rule matching below stays fully
  // on-device; only the ambiguous-confidence fallback touches the network.
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
  ///
  /// [forceAi] — when the caller already KNOWS the text is clinical (e.g. the
  /// assistant "save as report" flow, where a full health conversation just
  /// happened), pass true so Gemini still classifies even when no literal
  /// keyword matched. Without it, terse answers ("শুধু প্যারাসিটাম", "হ্যাঁ")
  /// score 0 and we'd wrongly fall back to the manual picker.
  Future<({String caseId, double confidence, String method})> detect(
      String transcript, {bool forceAi = false}) async {
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

    // ── Stage 2: Gemini AI fallback ──────────────────────────────
    // Normally we skip Gemini when zero keywords matched — it would just
    // hallucinate a case from a non-clinical utterance. But [forceAi] callers
    // (known-clinical context) want classification regardless.
    if (ruleResult.confidence > 0.0 || forceAi) {
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

  // ── AI detection (server-routed) ─────────────────────────────
  // Posts the transcript + case list to the backend /api/detect-case,
  // which runs the same low-temperature Gemini classification through its
  // rotating keys and returns {caseId, confidence}. The Gemini key stays
  // on the server and never ships in the APK. Any failure (network, AI
  // quota, unparseable output → non-200) throws, and the caller in
  // detect() falls back to the rule-based result, so triage never blocks.
  Future<({String caseId, double confidence})> _geminiDetect(
      String transcript, List<TriageCaseModel> cases) async {
    final response = await http
        .post(
          Uri.parse('${ApiConstants.baseUrl}/detect-case'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'transcript': transcript,
            'cases': [
              for (final c in cases) {'id': c.id, 'titleEn': c.titleEn},
            ],
          }),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) throw Exception('detect-case error');

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['success'] != true) throw Exception('detect-case failed');
    return (
      caseId: body['caseId'] as String,
      confidence: (body['confidence'] as num).toDouble(),
    );
  }
}
