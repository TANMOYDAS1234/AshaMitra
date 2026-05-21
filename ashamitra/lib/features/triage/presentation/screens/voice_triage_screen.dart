import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../shared/widgets/voice_orb.dart';
import '../../../../shared/widgets/mic_button.dart';
import '../../../../core/services/gemini_conversation_service.dart';
import '../../../../core/services/rule_executor.dart';
import '../../../../core/services/offline_brain.dart';
import '../../../../core/services/immediate_action_engine.dart';
import '../../../../core/services/clup/clup_pipeline.dart';
import '../../../../core/services/clup/situation_extractor.dart';
import '../../../../features/auth/controller/auth_controller.dart';
import '../../../../core/services/local_storage_service.dart';
import '../../../../core/services/tts_service.dart';

class VoiceTriageScreen extends StatefulWidget {
  const VoiceTriageScreen({super.key});

  @override
  State<VoiceTriageScreen> createState() => _VoiceTriageScreenState();
}

class _VoiceTriageScreenState extends State<VoiceTriageScreen> {
  // ── Services ──────────────────────────────────────────────────
  final _conversationService = GeminiConversationService();
  final _clup = CLUPPipeline();
  final _situationExtractor = SituationExtractor();
  final _offlineBrain = OfflineBrain();
  final _tts = TtsService();

  // ── Case info ─────────────────────────────────────────────────
  late String _caseType;
  late String _caseTitle;
  late String _moduleId;

  // Set when triage is started from an existing patient — links the
  // resulting report back to that patient instead of creating a duplicate.
  String? _patientId;
  String? _patientName;

  // ── Conversation state ────────────────────────────────────────
  final List<ConversationTurn> _history = [];
  final Map<String, bool> _extractedAnswers = {};
  final Map<String, double> _extractedVitals = {};
  String _streamingPartial = ''; // live text from SSE stream
  String _riskLevel = 'low';
  int _turnCount = 0;

  // ── Voice state ───────────────────────────────────────────────
  final SpeechToText _stt = SpeechToText();
  final SpeechToText _sttFallback = SpeechToText();
  bool _sttAvailable = false;
  bool _isListening = false;
  bool _isOffline = false;
  bool _isProcessing = false;
  String _transcript = '';
  String _statusText = '';
  double _confidence = 0.0;
  OrbState _orbState = OrbState.idle;

  // ── Offline fallback questions ────────────────────────────────
  List<EngineQuestion> _offlineQuestions = [];
  // The engine yes/no question OfflineBrain last asked — lets a terse
  // "হ্যাঁ/না" reply be recorded against it.
  EngineQuestion? _lastAskedQuestion;


  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    final map = args is Map<String, dynamic> ? args : <String, dynamic>{};
    _caseType  = map['caseId']    as String? ?? 'pregnancy';
    _caseTitle = map['caseTitle'] as String? ?? '🤰 গর্ভবতী মায়ের চেকআপ';
    _moduleId  = _toModuleId(_caseType);
    _patientId   = map['patientId']   as String?;
    _patientName = map['patientName'] as String?;
    _statusText = 'মাইক ট্যাপ করুন কথা বলতে';
    _offlineBrain.init(Get.find<RuleExecutor>());
    _initTts();
    _initStt();

    // If situation was pre-spoken at SelectCaseScreen, start with it
    final situation = map['situation'] as String? ?? '';
    if (situation.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _processInput(situation);
      });
    }
  }

  static String _toModuleId(String c) => switch (c) {
    'newborn'      => 'newborn',
    'infant'       => 'child',
    'child'        => 'child',
    'pregnancy'    => 'pregnancy',
    'postpartum'   => 'delivery_pnc',
    'immunization' => 'immunisation',
    _              => 'emergency',
  };

  // ── TTS init ──────────────────────────────────────────────────
  Future<void> _initTts() async {
    _tts.onStart    = () { if (mounted) setState(() => _orbState = OrbState.processing); };
    _tts.onComplete = () { if (mounted) setState(() => _orbState = OrbState.idle); };
    _tts.onError    = () { if (mounted) setState(() => _orbState = OrbState.idle); };
    await _tts.init();
    await Future.delayed(const Duration(milliseconds: 600));
    await _tts.speak('পরিস্থিতি বলুন বা প্রশ্ন করুন');
  }

  // ── Natural speech helper (delegates to TtsService) ─────────────────────
  Future<void> _speakNatural(String text) => _tts.speak(text);

  // ── STT init ──────────────────────────────────────────────────
  Future<void> _initStt() async {
    _sttAvailable = await _stt.initialize(
      onError: (_) {
        if (mounted) setState(() { _isListening = false; _orbState = OrbState.idle; });
      },
      onStatus: (status) {
        if (!mounted) return;
        if ((status == SpeechToText.doneStatus ||
                status == SpeechToText.notListeningStatus) &&
            _isListening) {
          setState(() { _isListening = false; _orbState = OrbState.idle; });
          if (_transcript.isNotEmpty) _processInput(_transcript);
        }
      },
    );
    await _sttFallback.initialize(onError: (_) {}, onStatus: (_) {});
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tts.stop();
    _stt.stop();
    _sttFallback.stop();
    _clup.resetSession();
    super.dispose();
  }

  Future<bool> _hasInternet() async {
    final r = await Connectivity().checkConnectivity();
    return r.any((c) => c != ConnectivityResult.none);
  }

  // ── Toggle mic ────────────────────────────────────────────────
  Future<void> _toggleListening() async {
    if (_isListening) {
      await _stt.stop();
      await _sttFallback.stop();
      setState(() { _isListening = false; _orbState = OrbState.idle; });
      if (_transcript.isNotEmpty) _processInput(_transcript);
      return;
    }
    if (!_sttAvailable || _isProcessing) return;
    await _tts.stop();

    final online = await _hasInternet();
    _isOffline = !online;

    setState(() {
      _isListening = true;
      _transcript = '';
      _orbState = OrbState.listening;
      _statusText = _isOffline ? '🔴 অফলাইন — বলুন...' : '🟢 শুনছি — বলুন...';
      _confidence = 0.0;
    });

    final opts = SpeechListenOptions(
      listenMode: ListenMode.dictation,
      onDevice: _isOffline,
      partialResults: true,
      cancelOnError: false,
    );

    await _stt.listen(
      localeId: 'bn_IN',
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 7), // Gap 6: rural workers speak slowly
      listenOptions: opts,
      onResult: _onSpeechResult,
      onSoundLevelChange: (level) {
        if (mounted && _isListening) {
          final n = ((level + 2) / 12).clamp(0.0, 1.0);
          if (n > 0.15) setState(() => _orbState = OrbState.listening);
        }
      },
    );

    if (!_isOffline) {
      _sttFallback.listen(
        localeId: 'hi_IN',
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 7),
        listenOptions: opts,
        onResult: _onSpeechResult,
      );
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!mounted) return;
    final text = result.recognizedWords.trim();
    if (text.isEmpty) return;
    setState(() {
      _transcript = text;
      _confidence = result.confidence;
    });
    if (result.finalResult) {
      _stt.stop();
      _sttFallback.stop();
      setState(() { _isListening = false; _orbState = OrbState.processing; });
      _processInput(text);
    }
  }

  // ── Core: process any input through conversational AI ─────────
  Future<void> _processInput(String input) async {
    if (input.trim().isEmpty || _isProcessing) return;
    // Gap 5: detect uncertainty before processing
    final uncertain = _isUncertain(input);
    setState(() {
      _isProcessing = true;
      _transcript = input;
      _orbState = OrbState.processing;
      _statusText = 'সংযোগ করছি...';
    });
    _history.add(ConversationTurn(role: 'asha', text: input));
    _turnCount++;
    final online = await _hasInternet();
    _isOffline = !online;
    if (_isOffline) {
      await _processOffline(input, uncertain: uncertain);
    } else {
      await _processOnline(input, uncertain: uncertain);
    }
  }

  // ── Online: true Gemini conversation ──────────────────────────
  Future<void> _processOnline(String input, {bool uncertain = false}) async {
    try {
      final authToken = LocalStorageService.get('jwt_token');
      if (mounted) setState(() => _statusText = 'সংযোগ করছি...');
      final response = await _conversationService.respond(
        caseType: _caseType,
        moduleId: _moduleId,
        history: List.from(_history)..removeLast(),
        newInput: input,
        currentAnswers: Map.from(_extractedAnswers),
        turnNumber: _turnCount,
        maxTurns: 8,
        authToken: authToken,
        onPartialResponse: (partial) {
          if (mounted) setState(() => _streamingPartial = partial);
        },
      );

      if (!mounted) return;
      setState(() {
        _streamingPartial = '';
        _statusText = 'বিশ্লেষণ করছি...';
      });

      // Gap 5: if uncertain, only accept false (no danger) extractions
      final toMerge = uncertain
          ? Map.fromEntries(
              response.extractedAnswers.entries.where((e) => e.value == false))
          : response.extractedAnswers;
      _extractedAnswers.addAll(toMerge);
      _extractedVitals.addAll(response.extractedVitals); // accumulate vitals
      // Live risk band — the SAME RuleExecutor that TriageResultScreen runs,
      // so the badge always matches the final result. Gemini's risk_level is
      // intentionally not used here (the result screen does not use it either).
      _riskLevel = _computeLocalRiskLevel();
      // Add assistant turn to history
      _history.add(ConversationTurn(
          role: 'assistant', text: response.spokenResponse));

      setState(() {
        _isProcessing = false;
        _orbState = OrbState.idle;
        _statusText = 'মাইক ট্যাপ করুন কথা বলতে';
        _transcript = '';
      });

      // Speak the response
      await _speakNatural(response.spokenResponse);

      if (!mounted) return;

      // Finish if Gemini says so or max turns reached
      if (response.shouldFinish || _turnCount >= 8) {
        await Future.delayed(const Duration(milliseconds: 500));
        _submitAnswers();
      }
    } catch (e) {
      // Online path failed — server cold-start, AI quota (503), or a weak
      // signal. Fall back to the offline engine instead of dead-ending on a
      // "network issue" the worker cannot get past.
      if (!mounted) return;
      _isOffline = true;
      await _processOffline(input, uncertain: uncertain);
    }
  }

  // Unreachable legacy error UI — superseded by the offline fallback in
  // _processOnline above. This whole method is dead code; safe to delete.
  // ignore: unused_element
  void _legacyOnlineErrorUi() {
    try {
      setState(() {
        _isProcessing = false;
        _orbState = OrbState.idle;
        _statusText = 'সার্ভার সাড়া দিচ্ছে না — আবার চেষ্টা করুন';
        _transcript = '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _orbState = OrbState.idle;
        _statusText = 'নেটওয়ার্ক সমস্যা — আবার চেষ্টা করুন';
        _transcript = '';
      });
    }
  }

  // ── Offline: CLUP + OfflineBrain dialogue ─────────────────────
  Future<void> _processOffline(String input, {bool uncertain = false}) async {
    if (!mounted) return;

    final extraction = _situationExtractor.extract(
      situation: input,
      moduleId: _moduleId,
    );
    // Gap 5: uncertain input — only accept false (no danger) extractions
    if (uncertain) {
      _extractedAnswers.addAll(Map.fromEntries(
          extraction.preAnswers.entries.where((e) => e.value == false)));
    } else {
      _extractedAnswers.addAll(extraction.preAnswers);
    }

    // Capture a terse yes/no reply to the question OfflineBrain just asked.
    // The keyword extractor only catches symptom words, so a bare "হ্যাঁ/না"
    // would otherwise be lost. Every engine yes/no question shares one
    // polarity (verified against asha_engine.json): yes = danger present.
    String? lastTurnId = extraction.preAnswers.keys.firstOrNull;
    bool lastTurnYes = extraction.preAnswers.values.firstOrNull ?? false;
    final lastQ = _lastAskedQuestion;
    if (!uncertain &&
        lastQ != null &&
        extraction.preAnswers.isEmpty &&
        _isYesNoQuestion(lastQ) &&
        !_extractedAnswers.containsKey(lastQ.id)) {
      final yn = _detectYesNo(input);
      if (yn != null) {
        _extractedAnswers[lastQ.id] = yn;
        lastTurnId = lastQ.id;
        lastTurnYes = yn;
      }
    }

    // Update risk band deterministically after every extraction
    _riskLevel = _computeLocalRiskLevel();

    // Auto-finish when the engine returns a RED band
    if (_riskLevel == 'emergency') {
      final confirmedSigns = _extractedAnswers.entries
          .where((e) => e.value == true)
          .length;
      final emergencyText =
          'সতর্কতা! $confirmedSignsটি গুরুত্বর বিপদচিহ্ন পাওয়া গেছে। এখনই ১০৮ কল করুন এবং রোগীকে FRU-তে রেফার করুন।';
      _history.add(
          ConversationTurn(role: 'assistant', text: emergencyText));
      setState(() {
        _isProcessing = false;
        _orbState = OrbState.idle;
        _statusText = 'মাইক ট্যাপ করুন কথা বলতে';
        _transcript = '';
      });
      await _speakNatural(emergencyText);
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 800));
        _submitAnswers();
      }
      return;
    }

    // Check for emergency via CLUP (keyword-based, catches things extractor misses)
    final decision = _clup.process(input: input, moduleId: _moduleId);
    if (decision.isEmergency) {
      const emergencyText =
          'এটি জরুরি অবস্থা! এখনই ১০৮ কল করুন এবং রোগীকে বাম কাতে শোয়ান।';
      _history.add(
          const ConversationTurn(role: 'assistant', text: emergencyText));
      setState(() {
        _isProcessing = false;
        _riskLevel = 'emergency';
        _orbState = OrbState.idle;
        _statusText = 'মাইক ট্যাপ করুন কথা বলতে';
        _transcript = '';
      });
      await _speakNatural(emergencyText);
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 800));
        _submitAnswers();
      }
      return;
    }

    // Load offline questions if not loaded yet
    if (_offlineQuestions.isEmpty) {
      _offlineQuestions = Get.find<RuleExecutor>()
          .questionIndex()
          .where((q) => q.moduleId == _moduleId)
          .where((q) => !_extractedAnswers.containsKey(q.id))
          .toList();
    }

    // Check immediate action for any confirmed danger signs
    String? immediateAction;
    for (final entry in extraction.preAnswers.entries) {
      if (entry.value) {
        final action = ImmediateActionEngine.getAction(
          answeredId: entry.key,
          answerWasYes: true,
          confirmedYes: _extractedAnswers.entries
              .where((e) => e.value == true)
              .map((e) => e.key)
              .toSet(),
        );
        if (action != null) {
          immediateAction = action.textBn;
          break;
        }
      }
    }

    // Pick next question via OfflineBrain
    final confirmedYes = _extractedAnswers.entries
        .where((e) => e.value == true)
        .map((e) => e.key)
        .toSet();

    final remaining = _offlineQuestions
        .where((q) => !_extractedAnswers.containsKey(q.id))
        .toList();

    String responseText;

    if (remaining.isEmpty || confirmedYes.length >= 3 || _turnCount >= 8) {
      // Ensure risk level is current before finishing
      _riskLevel = _computeLocalRiskLevel();
      final summary = confirmedYes.isEmpty
          ? 'ধন্যবাদ। কোনো গুরুতর বিপদচিহ্ন পাওয়া যায়নি।'
          : 'ধন্যবাদ। ${confirmedYes.length}টি বিপদচিহ্ন পাওয়া গেছে। ফলাফল দেখাচ্ছি।';
      responseText = immediateAction != null
          ? '$immediateAction $summary'
          : summary;
      _history.add(ConversationTurn(role: 'assistant', text: responseText));
      setState(() {
        _isProcessing = false;
        _orbState = OrbState.idle;
        _statusText = 'মাইক ট্যাপ করুন কথা বলতে';
        _transcript = '';
      });
      await _speakNatural(responseText);
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 500));
        _submitAnswers();
      }
      return;
    }

    // Get next question from OfflineBrain
    final next = _offlineBrain.getNextQuestion(
      remaining: remaining,
      confirmedYes: confirmedYes,
      lastAnsweredId: lastTurnId,
      lastAnswerWasYes: lastTurnYes,
    );

    // If a combination fired, speak the alert and finish immediately
    if (next.combinationAlertBn != null) {
      _riskLevel = 'emergency';
      _history.add(ConversationTurn(role: 'assistant', text: next.combinationAlertBn!));
      setState(() {
        _isProcessing = false;
        _orbState = OrbState.idle;
        _statusText = 'মাইক ট্যাপ করুন কথা বলতে';
        _transcript = '';
      });
      await _speakNatural(next.combinationAlertBn!);
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 800));
        _submitAnswers();
      }
      return;
    }

    final nextQ = next.question ?? remaining.first;
    _lastAskedQuestion = nextQ;

    // Build natural response: acknowledge + combo alert OR immediate action + next question
    final ack = _buildAcknowledgement(input, extraction.extractedSymptoms);
    final alert =
        next.combinationAlertBn ?? immediateAction ?? next.immediateActionBn;
    responseText = alert != null
        ? '$ack $alert ${nextQ.textBn}'
        : '$ack ${nextQ.textBn}';

    _history.add(ConversationTurn(role: 'assistant', text: responseText));
    setState(() {
      _isProcessing = false;
      _orbState = OrbState.idle;
      _statusText = 'মাইক ট্যাপ করুন কথা বলতে';
      _transcript = '';
    });

    await _speakNatural(responseText);
  }

  String _buildAcknowledgement(String input, List<String> symptoms) {
    if (symptoms.isNotEmpty) {
      return 'বুঝেছি, ${symptoms.join(" এবং ")} আছে।';
    }
    final lower = input.toLowerCase();
    if (lower.contains('হ্যাঁ') || lower.contains('আছে') || lower.contains('হয়')) {
      return 'বুঝেছি।';
    }
    if (lower.contains('না') || lower.contains('নেই')) {
      return 'ঠিক আছে।';
    }
    return 'বুঝেছি।';
  }

  // ── Deterministic risk band ───────────────────────────────────────────
  // Runs the SAME 11-layer RuleExecutor that TriageResultScreen uses, so the
  // live badge always matches the final result. A hardcoded YES-count
  // heuristic could not — it missed combination rules that escalate two
  // YELLOW signs to a RED band.
  String _computeLocalRiskLevel() {
    if (_extractedAnswers.isEmpty) return 'low';
    final result = Get.find<RuleExecutor>().execute(
      moduleId: _moduleId,
      answers: Map<String, dynamic>.from(_extractedAnswers),
      vitals: Map<String, dynamic>.from(_extractedVitals),
    );
    final band = result.pipelineBlocked ? 'GREEN' : result.band;
    return switch (band) {
      'RED'    => 'emergency',
      'YELLOW' => 'medium',
      _        => 'low',
    };
  }

  // ── Submit to rule engine — Gap 4 Fix ────────────────────────
  void _submitAnswers() {
    // Build proper Q&A pairs: assistant question → ASHA answer
    final qaPairs = <String>[];
    for (int i = 0; i < _history.length - 1; i++) {
      if (_history[i].role == 'assistant' && _history[i + 1].role == 'asha') {
        qaPairs.add('${_history[i].text}|||${_history[i + 1].text}');
      }
    }
    final args = <String, dynamic>{
      '_caseType': _caseType,
      '_situation': _history.isNotEmpty ? _history.first.text : '',
      '_qaList': qaPairs.join(';;'),
      '_vitals': Map<String, dynamic>.from(_extractedVitals),
      '_riskLevel': _riskLevel,
      if (_patientId != null && _patientId!.isNotEmpty)
        '_patientId': _patientId,
      if (_patientName != null && _patientName!.isNotEmpty)
        '_patientName': _patientName,
      ..._extractedAnswers,
    };
    Get.toNamed(AppRoutes.triageResult, arguments: args);
  }

  // ── Gap 5: uncertainty detection ─────────────────────────────
  static const _uncertaintyWords = [
    'মনে হয়', 'মনে হচ্ছে', 'হয়তো', 'নিশ্চিত না', 'জানি না',
    'মনে হইতেছে', 'মনে হয় গো', 'হয়তো গো', 'নিশ্চিত না গো',
    'একটু', 'হালকা', 'কিছুটা', 'মাঝে মাঝে',
    'maybe', 'not sure', 'shayad', 'pata nahi', 'lagta hai',
    'thoda', 'halka', 'kabhi kabhi',
  ];

  bool _isUncertain(String text) {
    final lower = text.toLowerCase();
    return _uncertaintyWords.any((w) => lower.contains(w));
  }

  // ── Terse yes/no detection for offline answers ───────────────────────────
  // Returns true (yes), false (no), or null when the reply is not a clear
  // yes/no. Whole-word matching avoids false hits (e.g. "নাভি" contains "না").
  static const _ynYes = {
    'হ্যাঁ', 'হ্যা', 'হাঁ', 'হা', 'yes', 'haan', 'han', 'ji',
  };
  static const _ynNo = {
    'না', 'নেই', 'নাই', 'হয়নি', 'নো', 'no', 'nahi', 'nahin', 'nai', 'nei',
  };
  static bool? _detectYesNo(String input) {
    final words = input
        .toLowerCase()
        .trim()
        .split(RegExp(r'[\s।,!?.]+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty || words.length > 5) return null;
    final yes = words.any(_ynYes.contains);
    final no = words.any(_ynNo.contains);
    if (yes != no) return yes;
    // A bare one-word verb reply ("আছে" / "হয়েছে") is also a clear yes.
    if (words.length == 1 &&
        const {'আছে', 'হয়েছে', 'হইছে', 'achhe', 'ache'}.contains(words.first)) {
      return true;
    }
    return null;
  }

  static bool _isYesNoQuestion(EngineQuestion q) =>
      q.options.length == 2 &&
      q.options.contains('হ্যাঁ') &&
      q.options.contains('না');

  // ── Risk color ────────────────────────────────────────────────
  Color get _riskColor => switch (_riskLevel) {
    'emergency' => AppColors.emergencyRed,
    'high'      => AppColors.emergencyRed,
    'medium'    => AppColors.warningYellow,
    _           => AppColors.safeGreen,
  };

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final orbSize = screenHeight < 700 ? 80.0 : 110.0;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () { _tts.stop(); _stt.stop(); Get.back(); },
                      child: Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 8)],
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_caseTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary)),
                          Text(
                            _isOffline ? '🔴 অফলাইন মোড' : '🟢 আশামিত্র AI',
                            style: TextStyle(
                                fontSize: 11,
                                color: _isOffline
                                    ? AppColors.warningYellow
                                    : AppColors.safeGreen),
                          ),
                        ],
                      ),
                    ),
                    // Risk indicator
                    if (_riskLevel != 'low')
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _riskColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: _riskColor.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          switch (_riskLevel) {
                            'emergency' => '🚨 জরুরি',
                            'high'      => '⚠️ উচ্চ ঝুঁকি',
                            'medium'    => '⚡ মাঝারি',
                            _           => '',
                          },
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _riskColor),
                        ),
                      ),
                  ],
                ),
              ),

              // ── Conversation history ────────────────────────────
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  itemCount: _history.length + (_isProcessing ? 1 : 0),
                  itemBuilder: (context, i) {
                    // Typing indicator
                    if (_isProcessing && i == _history.length) {
                      return _buildTypingIndicator();
                    }
                    final turn = _history[i];
                    return _buildChatBubble(turn);
                  },
                ),
              ),

              // ── Voice orb + transcript ──────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    VoiceOrb(size: orbSize, state: _orbState),
                    const SizedBox(height: 8),
                    if (_transcript.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text('"$_transcript"',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.onBackground)),
                            ),
                            if (_confidence > 0)
                              Text(
                                '${(_confidence * 100).toStringAsFixed(0)}%',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: _confidence > 0.7
                                        ? AppColors.safeGreen
                                        : AppColors.warningYellow,
                                    fontWeight: FontWeight.w600),
                              ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),

              // ── Mic button + status ─────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  children: [
                    MicButton(
                      isListening: _isListening,
                      onToggleOn: _toggleListening,
                      onToggleOff: _toggleListening,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isProcessing
                          ? _statusText
                          : _isListening
                              ? '🔴 শুনছি — থামাতে আবার চাপুন'
                              : _statusText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: _isListening
                            ? AppColors.safeGreen
                            : _isProcessing
                                ? AppColors.primary
                                : AppColors.textSecondary,
                        fontWeight: (_isListening || _isProcessing)
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Manual finish button
                    if (_history.length >= 2)
                      TextButton(
                        onPressed: _submitAnswers,
                        child: const Text('ফলাফল দেখুন →',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Chat bubble ───────────────────────────────────────────────
  Widget _buildChatBubble(ConversationTurn turn) {
    final isAsha = turn.role == 'asha';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isAsha ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isAsha) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: const Text('আ', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isAsha
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isAsha ? 16 : 4),
                  bottomRight: Radius.circular(isAsha ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2)),
                ],
              ),
              child: Text(
                turn.text,
                style: TextStyle(
                  fontSize: 14,
                  color: isAsha
                      ? AppColors.primary
                      : AppColors.onBackground,
                  height: 1.5,
                ),
              ),
            ),
          ),
          if (isAsha) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: const Icon(Icons.person_rounded,
                  size: 16, color: AppColors.primary),
            ),
          ],
        ],
      ),
    );
  }

  // ── Typing indicator ──────────────────────────────────────────
  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: const Text('আ',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                  bottomLeft: Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2)),
                ],
              ),
              child: _streamingPartial.isNotEmpty
                  ? Text(
                      _streamingPartial,
                      style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.onBackground,
                          height: 1.5),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        3,
                        (i) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

