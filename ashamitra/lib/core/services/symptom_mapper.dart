import 'package:get/get.dart';
import 'rule_executor.dart';

/// Maps Gemini-generated Q&A pairs back to engine question IDs.
class SymptomMapper {
  List<EngineQuestion>? _questions;

  Future<void> load() async {
    if (_questions != null) return;
    _questions = Get.find<RuleExecutor>().questionIndex();
  }

  /// Returns a copy of [baseAnswers] enriched with engine question IDs.
  /// If Gemini questions don't match any engine questions (vague situation),
  /// falls back to injecting 'না' for all module questions so the engine
  /// can still evaluate and return GREEN (no danger signs found).
  Map<String, String> mapToEngineAnswers({
    required String moduleId,
    required List<Map<String, String>> qaList,
    required Map<String, String> baseAnswers,
  }) {
    assert(_questions != null, 'SymptomMapper.load() must be called first');

    final result = Map<String, String>.from(baseAnswers);
    final candidates = _questions!.where((q) => q.moduleId == moduleId).toList();
    int matchCount = 0;

    for (final qa in qaList) {
      final questionText = qa['question']?.toLowerCase() ?? '';
      final answerText   = qa['answer']?.toLowerCase()   ?? '';

      final isYes = _isAffirmative(answerText);
      final isNo  = _isNegative(answerText);
      if (!isYes && !isNo) continue;

      final matched = _findBestMatch(questionText, candidates);
      if (matched == null) continue;

      if (!result.containsKey(matched.id)) {
        result[matched.id] = isYes ? 'হ্যাঁ' : 'না';
        matchCount++;
      }
    }

    // If nothing matched (vague situation like "I don't feel well"),
    // inject 'না' for all module question IDs so the engine returns GREEN
    // rather than crashing or returning a meaningless result.
    if (matchCount == 0) {
      for (final eq in candidates) {
        result.putIfAbsent(eq.id, () => 'না');
      }
    }

    return result;
  }

  // ── Affirmative / negative detection ─────────────────────────────────────

  static const _yesTokens = [
    'হ্যাঁ', 'হা', 'আছে', 'হয়', 'হচ্ছে', 'হয়েছে', 'হইছে', 'হইতেছে',
    'তীব্র', 'অনেক', 'বেশি', 'একবার', 'একটু', 'কিছুটা', 'মাঝে মাঝে',
    'हाँ', 'है', 'हुआ', 'हो रहा',
    'yes', 'yeah', 'present', 'severe', 'high', 'fast', 'rapid',
    '১ দিন', '২-৩ দিন', '১ সপ্তাহ', '৩ দিনের বেশি', '৫ দিনের বেশি',
    '১-৭ দিন', '৮-১৪ দিন', '১৫-২৮ দিন',
    'কয়েক মিনিট', '১ ঘণ্টা', 'কয়েক ঘণ্টা',
    'খুব কম', 'বন্ধ', 'অস্বীকার',
  ];

  static const _noTokens = [
    'না', 'নাই', 'নেই', 'নয়', 'হয়নি', 'হয় নি',
    'नहीं', 'नही',
    'no', 'not', 'none', 'normal', 'absent',
  ];

  bool _isAffirmative(String text) =>
      _yesTokens.any((t) => text.contains(t.toLowerCase()));

  bool _isNegative(String text) =>
      _noTokens.any((t) => text.contains(t.toLowerCase()));

  // ── Best-match engine question ────────────────────────────────────────────

  EngineQuestion? _findBestMatch(
      String geminiQuestion, List<EngineQuestion> candidates) {
    int bestScore = 0;
    EngineQuestion? best;
    for (final eq in candidates) {
      final score = _matchScore(geminiQuestion, eq);
      if (score > bestScore) { bestScore = score; best = eq; }
    }
    return bestScore >= 1 ? best : null;
  }

  int _matchScore(String geminiQuestion, EngineQuestion eq) {
    int score = 0;
    final gq = geminiQuestion.toLowerCase();
    // Score 4 for each shared word with the engine's Bengali question text
    for (final word in _words(eq.textBn)) {
      if (gq.contains(word)) score += 4;
    }
    // Score 3 for each shared word with the engine's English question text
    for (final word in _words(eq.textEn)) {
      if (gq.contains(word)) score += 3;
    }
    // Score 1 for each shared word with the action text (secondary signal)
    for (final word in _words(eq.actionBn)) {
      if (gq.contains(word)) score += 1;
    }
    return score;
  }

  List<String> _words(String text) => text
      .toLowerCase()
      .split(RegExp(r'[\s,?।]+'))
      .where((w) => w.length > 2)
      .toList();
}
