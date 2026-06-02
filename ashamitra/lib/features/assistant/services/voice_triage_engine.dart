// ─────────────────────────────────────────────────────────────────────────────
// VoiceTriageEngine — conducts a triage interview entirely by voice.
//
// Why this exists:
//   Today an ASHA worker who says "Start checkup for Ruma" is dropped on the
//   triage screen and has to re-speak every answer there. The hand-off is
//   the worst-feeling part of the assistant — same conversation, two
//   different UIs, and the second one demands a tap to start. This engine
//   lets the assistant *be* the triage screen for the duration of the
//   conversation: load the case's questions, ask Q1, capture A1, ask Q2,
//   capture A2, ... eventually run the same RuleExecutor the visual screen
//   uses and announce the outcome.
//
// What stays SHARED:
//   - CaseDetectionService.loadCases() — same JSON, same QuestionModel
//   - RuleExecutor.execute() — same 11-layer pipeline that produces the
//     authoritative band (GREEN / YELLOW / RED) the visual screen would
//     have arrived at given the same answers. The engine never makes
//     clinical decisions of its own.
//   - QuestionModel.options — the yes/no/etc choices on each question
//
// What's NEW here:
//   - Iteration state (current question index)
//   - Spoken-answer → option mapping (handles "হ্যাঁ আছে", "নাই", "yes",
//     "নো" etc. by fuzzy-matching against the canonical option list)
//   - Early termination: if a hard-stop question fires RED, we don't
//     ask the remaining questions — the worker has a screaming-red
//     baby in their arms and doesn't need to be asked the next four
//     yes/nos before being told to refer
//
// What this DOES NOT do (yet — by design for v1):
//   - Multi-language asking. Plumbs Bengali only for now; Hindi/English
//     mode can be layered in once the answer mappings are validated in
//     field testing.
//   - Slot-fill numeric vitals (BP, weight, temp). Those still need
//     the visual screen's structured input. v2 will add it.
//   - Save the report — assistant handles offering save after this
//     engine returns the outcome.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:get/get.dart';
import '../../../core/services/case_detection_service.dart';
import '../../../core/services/rule_executor.dart';
import '../../triage/data/models/question_model.dart';
import '../../triage/data/models/triage_case_model.dart';

/// The final outcome of a voice triage session. All fields except [band]
/// are derived for display / TTS use — the engine's execute() result is
/// the canonical source.
class VoiceTriageOutcome {
  /// 'RED' | 'YELLOW' | 'GREEN' — same vocabulary the visual screen uses.
  final String band;

  /// One-line spoken summary in Bengali ("সতর্কতা! এখনই রেফার করুন।")
  /// suitable for speakBytes through the regular TTS pipeline.
  final String spokenSummary;

  /// Action sentence (referral instructions, etc.) from the engine.
  /// Shown in the assistant's text bubble and bundled into the report.
  final String action;

  /// Map of questionId → answer ('হ্যাঁ'/'না'/etc) captured during the
  /// session. Used by the save-as-report flow to populate the report
  /// without re-asking the worker anything.
  final Map<String, String> answers;

  /// If a hard-stop fired, the questionId of the first one that did.
  /// Lets the assistant phrase the spoken summary with the exact
  /// danger sign ("শ্বাস-প্রশ্বাস কষ্টকর — এখনই FRU-তে নিয়ে যান")
  /// instead of a generic "RED, refer".
  final String? hardStopQuestionId;

  const VoiceTriageOutcome({
    required this.band,
    required this.spokenSummary,
    required this.action,
    required this.answers,
    this.hardStopQuestionId,
  });
}

class VoiceTriageEngine {
  /// Optional: only Get.find these on first start() so a screen that
  /// imports this file doesn't pay the lookup cost if it never starts
  /// a session.
  CaseDetectionService? _cases;
  RuleExecutor? _rules;

  TriageCaseModel? _case;
  int _index = 0;
  final Map<String, String> _answers = {};
  VoiceTriageOutcome? _outcome;

  // ── Lifecycle ────────────────────────────────────────────────────────────
  bool get isActive => _case != null && _outcome == null;
  bool get isFinished => _outcome != null;
  VoiceTriageOutcome? get outcome => _outcome;
  TriageCaseModel? get currentCase => _case;
  /// 1-indexed position of the question we're currently asking.
  /// Returns 0 when no session is active.
  int get currentQuestionNumber => _case == null ? 0 : _index + 1;
  /// Total questions in the active case.
  int get totalQuestions => _case?.questions.length ?? 0;
  /// Map of question text → captured answer. Used by the pre-submit
  /// review screen so the worker can see what the engine will receive
  /// before it commits.
  Map<String, String> get capturedAnswers {
    final c = _case;
    if (c == null) return const {};
    return {
      for (final entry in _answers.entries)
        if (c.questions.firstWhereOrNull((q) => q.id == entry.key) != null)
          c.questions.firstWhere((q) => q.id == entry.key).text: entry.value,
    };
  }

  /// Load case [caseId] and seek to question 0. Returns the first
  /// QuestionModel to ask, or null if the case wasn't found.
  Future<QuestionModel?> start(String caseId) async {
    _cases ??= Get.find<CaseDetectionService>();
    _rules ??= Get.find<RuleExecutor>();
    final all = await _cases!.loadCases();
    final c = all.firstWhereOrNull((c) => c.id == caseId);
    if (c == null) return null;
    _case = c;
    _index = 0;
    _answers.clear();
    _outcome = null;
    return currentQuestion();
  }

  void cancel() {
    _case = null;
    _index = 0;
    _answers.clear();
    _outcome = null;
  }

  /// The question we're currently waiting on an answer for, or null if
  /// the session has finished (check [outcome] in that case).
  QuestionModel? currentQuestion() {
    final c = _case;
    if (c == null) return null;
    if (_index >= c.questions.length) return null;
    return c.questions[_index];
  }

  /// Record the worker's spoken answer to the current question.
  /// Returns:
  ///   - the next QuestionModel if there is one
  ///   - null if the session is now finished (caller should read [outcome])
  ///
  /// If [spoken] can't be mapped to a yes/no, the question is repeated
  /// — the same QuestionModel is returned and [_index] doesn't advance.
  /// The assistant should phrase the re-ask differently ("ক্ষমা করবেন,
  /// 'হ্যাঁ' বা 'না' বলুন") rather than just repeating the question.
  Future<QuestionModel?> submitAnswer(String spoken) async {
    final q = currentQuestion();
    if (q == null) return null;
    final mapped = _mapAnswer(spoken, q.options);
    if (mapped == null) return q; // ambiguous — re-ask
    _answers[q.id] = mapped;

    // Hard-stop check: if a hard-stop question is answered হ্যাঁ, we
    // skip the rest and finalize as RED immediately. Worker is in an
    // emergency — quizzing them on the next 4 yes/nos is harmful.
    if (q.hardStop && mapped == 'হ্যাঁ') {
      _finalize(hardStopQuestionId: q.id);
      return null;
    }

    _index++;
    if (_index >= _case!.questions.length) {
      _finalize();
      return null;
    }
    return currentQuestion();
  }

  // ── Internal: spoken → option mapping ────────────────────────────────────
  //
  // Workers say a lot of things that all mean "yes" — "হ্যাঁ", "হাঁ",
  // "হাঁরে", "জি", "জী", "yes", "yeah", "yup", "আছে", "হয়েছে", "achhe".
  // And likewise for "না" — "নাই", "নেই", "নো", "no", "nope", "nah".
  // We do a forgiving substring match in the worker's reply so any of
  // these phrasings hit the right canonical option.
  static const _yesTokens = <String>[
    'হ্যাঁ', 'হা', 'হাঁ', 'হ্যা', 'জি', 'জী',
    'হ্যাঁ আছে', 'আছে', 'হয়েছে', 'হয়',
    'yes', 'yeah', 'yup', 'haa', 'ha', 'ji',
  ];

  static const _noTokens = <String>[
    'না', 'নাই', 'নেই', 'নয়',
    'no', 'nope', 'nah', 'na', 'nai', 'nei',
  ];

  String? _mapAnswer(String spoken, List<String> options) {
    final s = spoken.toLowerCase().trim();
    if (s.isEmpty) return null;

    // 1) Direct option match — if the worker said the exact option text
    //    (e.g. "খুব কম" for a 3-way question), use it as-is.
    for (final opt in options) {
      if (s.contains(opt.toLowerCase())) return opt;
    }

    // 2) "Not sure" type answers map to the third option if the question
    //    has one (most yes/no/not-sure questions); otherwise to 'না' as
    //    the safer default since unknowns shouldn't escalate.
    const uncertain = ['নিশ্চিত না', 'জানি না', 'maybe', 'not sure', 'idk'];
    if (uncertain.any(s.contains)) {
      if (options.length >= 3) return options[2];
      return 'না';
    }

    // 3) Yes-equivalent tokens → first option (which is always 'হ্যাঁ'
    //    in the case JSON by convention).
    if (_yesTokens.any(s.contains)) {
      return options.isNotEmpty ? options[0] : 'হ্যাঁ';
    }
    // 4) No-equivalent tokens → second option (always 'না' by convention).
    if (_noTokens.any(s.contains)) {
      return options.length >= 2 ? options[1] : 'না';
    }
    return null; // couldn't map — caller will re-ask
  }

  // ── Finalize: run the rule engine + bake the outcome ─────────────────────
  void _finalize({String? hardStopQuestionId}) {
    // Convert the captured spoken answers into the engine's expected
    // shape: question IDs whose answer was হ্যাঁ map to `true`, others
    // to `false`. The 3rd "uncertain" option also counts as false so
    // we don't escalate unknowns.
    final engineAnswers = <String, dynamic>{
      for (final entry in _answers.entries)
        entry.key: entry.value == 'হ্যাঁ',
    };

    final c = _case;
    if (c == null || _rules == null) {
      _outcome = const VoiceTriageOutcome(
        band: 'GREEN',
        spokenSummary: 'ফলাফল প্রস্তুত করতে পারলাম না।',
        action: '',
        answers: {},
      );
      return;
    }

    final result = _rules!.execute(
      moduleId: c.module.isNotEmpty ? c.module : c.id,
      answers: engineAnswers,
      caseId: c.id,
    );

    // pipelineBlocked means the engine couldn't decide (validation /
    // contradiction errors). Treat as GREEN with a "could not complete"
    // message — worker should redo via visual screen.
    final band = result.pipelineBlocked ? 'GREEN' : result.band;

    // Pull the first hard-stop's action when one fired; otherwise use
    // the engine's primary action sentence.
    String action = '';
    if (hardStopQuestionId != null) {
      final hardStopQ = c.questions.firstWhereOrNull(
        (q) => q.id == hardStopQuestionId,
      );
      action = hardStopQ?.action ?? '';
    }
    if (action.isEmpty) {
      // Use the engine's Bengali action card summary (same wording the
      // visual result screen would show).
      action = result.actionBn;
    }

    _outcome = VoiceTriageOutcome(
      band: band,
      spokenSummary: _spokenSummaryFor(
        band: band,
        hardStopQuestionId: hardStopQuestionId,
        case_: c,
        confirmedCount: engineAnswers.values.where((v) => v == true).length,
      ),
      action: action,
      answers: Map.unmodifiable(_answers),
      hardStopQuestionId: hardStopQuestionId,
    );
  }

  String _spokenSummaryFor({
    required String band,
    required String? hardStopQuestionId,
    required TriageCaseModel case_,
    required int confirmedCount,
  }) {
    if (band == 'RED') {
      if (hardStopQuestionId != null) {
        final q = case_.questions.firstWhereOrNull(
          (q) => q.id == hardStopQuestionId,
        );
        if (q != null) {
          // Pull the substantive danger sign from the question text
          // (strip the trailing ? so the spoken summary flows).
          final sign = q.text.replaceAll('?', '').trim();
          return 'সতর্কতা! $sign — এখনই রেফার করুন।';
        }
      }
      return 'সতর্কতা! গুরুতর বিপদচিহ্ন পাওয়া গেছে। এখনই রেফার করুন।';
    }
    if (band == 'YELLOW') {
      return 'সাবধান। $confirmedCount টি বিপদচিহ্ন পাওয়া গেছে। ২৪ ঘণ্টার মধ্যে PHC-তে নিয়ে যান।';
    }
    if (confirmedCount == 0) {
      return 'ভালো খবর। কোনো গুরুতর বিপদচিহ্ন পাওয়া যায়নি। বাড়িতে যত্ন চালিয়ে যান।';
    }
    return 'ভালো অবস্থা। স্বাভাবিক যত্ন চালিয়ে যান।';
  }
}
