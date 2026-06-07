import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/voice_orb.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../../core/services/gemini_conversation_service.dart';
import '../../../../core/services/rule_executor.dart';
import '../../../../core/services/offline_brain.dart';
import '../../../../core/services/answer_codes.dart';
import '../../../../core/services/patient_triage_context.dart';
import '../../../../features/patients/data/models/patient_model.dart';
import '../../../../core/services/immediate_action_engine.dart';
import '../../../../core/services/clup/clup_pipeline.dart';
import '../../../../core/services/clup/situation_extractor.dart';
import '../../../../features/auth/controller/auth_controller.dart';
import '../../../../core/services/local_storage_service.dart';
import '../../../../core/services/tts_service.dart';
import '../../../../core/utils/permissions.dart';

class VoiceTriageScreen extends StatefulWidget {
  const VoiceTriageScreen({super.key});

  @override
  State<VoiceTriageScreen> createState() => _VoiceTriageScreenState();
}

class _VoiceTriageScreenState extends State<VoiceTriageScreen> {
  static const int _kMaxTurns = 10;

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
  // questionId → answer. Values are graded codes (yes/no/severe/mild/unsure,
  // see AnswerCodes) or legacy bool. Use AnswerCodes.isAffirmative(...) to read.
  final Map<String, dynamic> _extractedAnswers = {};
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
  // _confidence removed — STT confidence score is no longer shown.
  OrbState _orbState = OrbState.idle;
  // ── Continuous-listen state ────────────────────────────────────
  // When true (the default), the mic auto-restarts after each TTS
  // response completes — worker never has to tap mic between turns.
  // Toggled off when the user explicitly stops the mic (long press or
  // when the screen is disposed).
  //
  // Default false now: triage uses HOLD-TO-TALK (same as the assistant) —
  // the worker presses the orb to talk and releases to send, so the mic is
  // never auto-opened. This kills the always-listening churn / TTS-bleed and
  // matches the assistant UX. (The auto-restart code paths below stay but are
  // gated on _autoListen, so they no-op.)
  bool _autoListen = false;
  // When the current hold (press) began — used to ignore an accidental
  // sub-300ms tap so a stray touch never fires an empty turn.
  DateTime? _holdStartedAt;
  // Index for round-robin selection of ack fillers so the same short
  // phrase doesn't play three times in a row.
  int _ackFillerIndex = 0;
  // Short bridge phrases played the instant STT finalizes — covers the
  // 1-3 sec gap before the real LLM response can be spoken. Every
  // entry is pre-cached on disk by the prewarm service, so playback
  // is instant from local file (no network round-trip).
  static const _ackFillers = <String>[
    'বুঝেছি।',
    'একটু অপেক্ষা করুন।',
    'ধন্যবাদ।',
  ];

  // ── Offline fallback questions ────────────────────────────────
  List<EngineQuestion> _offlineQuestions = [];
  // The engine yes/no question OfflineBrain last asked — lets a terse
  // "হ্যাঁ/না" reply be recorded against it.
  EngineQuestion? _lastAskedQuestion;
  // The question id Gemini actually asked last turn (it reports it via
  // asked_question_id). A terse "না"/"হ্যাঁ" this turn is recorded against it,
  // so attribution no longer relies on a priority-list guess that could drift
  // out of sync with the prompt (that drift was the cause of the triage loop).
  String? _lastOnlineQuestionId;
  // Loop guard: how many turns in a row Gemini has asked the SAME question id.
  // If it re-asks one ≥3 times (model ignoring the "already answered" list),
  // we mark that question answered so the conversation always moves forward.
  String? _repeatAskId;
  int _repeatAskCount = 0;


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
    _statusText = 'tap_mic_to_speak'.tr;
    _offlineBrain.init(Get.find<RuleExecutor>());
    // Engine-grounded Q&A: lets the CLUP pipeline answer ASHA's clinical
    // questions ("জ্বর কত হলে বিপদ?") using the live rule engine offline.
    _clup.setRuleExecutor(Get.find<RuleExecutor>());
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
    // After every utterance finishes, auto-restart the mic if continuous
    // listening is on and we're not in the middle of a network turn.
    // This is what makes the experience feel "always listening" — the
    // worker never taps mic between turns.
    _tts.onComplete = () {
      if (!mounted) return;
      setState(() => _orbState = OrbState.idle);
      if (_autoListen && !_isProcessing && !_isListening) {
        _autoRestartListening();
      }
    };
    _tts.onError    = () { if (mounted) setState(() => _orbState = OrbState.idle); };
    await _tts.init();
    await Future.delayed(const Duration(milliseconds: 600));
    await _tts.speak('পরিস্থিতি বলুন বা প্রশ্ন করুন', tone: TtsTone.empathy);
    // The TTS completion handler above will fire after this opening
    // prompt finishes and start listening — no first-tap needed.
  }

  /// Idempotent auto-start of the mic, used by the TTS completion
  /// callback. Skips if STT isn't available, the screen is being torn
  /// down, the worker manually disabled autoListen, or processing is
  /// already in flight (e.g. offline path still computing).
  Future<void> _autoRestartListening() async {
    if (!mounted) return;
    if (!_autoListen || _isProcessing || _isListening || !_sttAvailable) return;
    // Wait for TTS audio to fully drain from the speaker before opening
    // the mic. Without this gate, the AI's own voice leaks into STT and
    // gets transcribed as the worker's "next input" — the LLM then
    // replies to its own previous sentence (the "TTS taken as input"
    // bug pilot users reported).
    // 1. Poll for audio player to report not-playing (max 2 sec)
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (_tts.isPlaying && DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 80));
    }
    // 2. Additional settle window so the Android audio channel fully
    //    releases the mic from echo-suppression mode before STT opens.
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted || !_autoListen || _isProcessing || _isListening) return;
    await _toggleListening();
  }

  // ── Natural speech helper (delegates to TtsService) ─────────────────────
  Future<void> _speakNatural(String text) => _tts.speakWithRisk(text, _riskLevel);
  Future<void> _speakQuestion(String text) => _tts.speakQuestion(text);
  Future<void> _speakEmpathy(String text) => _tts.speakEmpathy(text);
  Future<void> _speakEmergency(String text) => _tts.speakEmergency(text);

  /// "Listen again" — replays an assistant bubble's audio. Cache hit (no
  /// network / LLM) for phrases spoken this session; the first replay of an
  /// uncached phrase synthesises once via the VPS then caches. No-op while
  /// the mic is open so a replay can't bleed into a live capture.
  Future<void> _replayAssistantTurn(String text) async {
    if (_isListening) return;
    final say = text.trim();
    if (say.isEmpty) return;
    try { await _tts.stop(); } catch (_) {}
    await _tts.speak(say, tone: TtsTone.normal);
  }

  // ── STT init ──────────────────────────────────────────────────
  Future<void> _initStt() async {
    // Explicitly request mic permission FIRST. `speech_to_text` triggers
    // a system prompt internally on most Android versions, but on Xiaomi
    // / Vivo (very common in rural India) the implicit request can
    // silently fail — the worker taps the mic and gets no audio with no
    // error. Calling permission_handler directly surfaces an OS dialog
    // every time and lets us show a clear empty-state if denied.
    final micOk = await AppPermissions.requestMicrophone();
    if (!micOk) {
      if (mounted) {
        setState(() {
          _sttAvailable = false;
          _statusText = 'mic_permission_denied'.tr;
        });
      }
      return;
    }
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
          _submitTranscript(_transcript);
        }
      },
    );
    await _sttFallback.initialize(onError: (_) {}, onStatus: (_) {});
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    // Important: kill auto-listen FIRST so the TTS onComplete callback
    // (which can fire mid-teardown) doesn't try to reopen the mic on
    // a disposed state.
    _autoListen = false;
    _coldStartHintTimer?.cancel();
    _tts.stop();
    _stt.stop();
    _sttFallback.stop();
    _clup.resetSession();
    super.dispose();
  }

  /// Cache the last connectivity check for 30 seconds so a transient flap
  /// (common on weak rural signals) doesn't bounce the worker between
  /// 'online' and 'offline' modes every time they say a word.
  ///
  /// Without this cache, a brief Wi-Fi drop while the worker says "না" was
  /// being interpreted as 'permanently offline now', and the UI would flip
  /// to অফলাইন মোড mid-conversation. Pilot tester reported this as
  /// "saying no goes to offline mode" because the timing made it look
  /// causal even though the real trigger was the network flap.
  bool? _cachedOnline;
  DateTime? _cachedOnlineAt;
  static const _onlineCacheDuration = Duration(seconds: 30);

  Future<bool> _hasInternet() async {
    final now = DateTime.now();
    if (_cachedOnline != null &&
        _cachedOnlineAt != null &&
        now.difference(_cachedOnlineAt!) < _onlineCacheDuration) {
      return _cachedOnline!;
    }
    final r = await Connectivity().checkConnectivity();
    final online = r.any((c) => c != ConnectivityResult.none);
    _cachedOnline = online;
    _cachedOnlineAt = now;
    return online;
  }

  // ── Toggle mic ────────────────────────────────────────────────
  Future<void> _toggleListening() async {
    if (_isListening) {
      // Manual stop — also disable auto-restart so we don't fight the
      // worker by re-opening the mic after they explicitly closed it.
      _autoListen = false;
      await _stt.stop();
      await _sttFallback.stop();
      setState(() { _isListening = false; _orbState = OrbState.idle; });
      _submitTranscript(_transcript);
      return;
    }
    if (!_sttAvailable || _isProcessing) return;
    // Tap-to-start always re-enables continuous mode.
    _autoListen = true;
    _turnSubmitted = false; // new turn — allow exactly one submission
    await _tts.stop();

    // Pilot device pattern: first turn captures, every later turn
    // silently no-ops. Cancel + explicit delay so the native side
    // fully releases the audio session before we ask for it again.
    // 400 ms survived field testing on Infinix HiOS.
    try { await _stt.cancel(); } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 400));

    final online = await _hasInternet();
    _isOffline = !online;

    setState(() {
      _isListening = true;
      _transcript = '';
      _orbState = OrbState.listening;
      _statusText = _isOffline ? '🔴 অফলাইন — বলুন...' : '🟢 শুনছি — বলুন...';
    });

    final opts = SpeechListenOptions(
      listenMode: ListenMode.dictation,
      onDevice: _isOffline,
      partialResults: true,
      cancelOnError: false,
    );

    // pauseFor 5s — pilot feedback that 3s cut workers off mid-thought
    // when they paused to recall a number or check a register. 5s of
    // true silence is the sweet spot: workers don't feel rushed, but
    // the recognizer still commits before the worker forgets they
    // were speaking. partialResults stream keeps it alive between words.
    await _stt.listen(
      localeId: 'bn_IN',
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 5),
      listenOptions: opts,
      onResult: _onSpeechResult,
      onSoundLevelChange: (level) {
        if (mounted && _isListening) {
          final n = ((level + 2) / 12).clamp(0.0, 1.0);
          if (n > 0.15 && _orbState != OrbState.listening) setState(() => _orbState = OrbState.listening);
        }
      },
    );

    if (!_isOffline) {
      _sttFallback.listen(
        localeId: 'hi_IN',
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 5),
        listenOptions: opts,
        onResult: _onSpeechResult,
      );
    }
  }

  // ── Hold-to-talk (same UX as the assistant) ───────────────────
  // Press the orb → mic on; release → send. The worker owns the mic, so it
  // never auto-opens/closes between turns. Pressing also barges in (stops any
  // TTS). The online/offline hybrid is unchanged — _processInput still routes
  // to Gemini when online and the offline brain when not.
  Future<void> _onHoldStart() async {
    if (_isListening || _isProcessing || !_sttAvailable) return;
    _autoListen = false;
    _turnSubmitted = false; // new turn — allow exactly one submission
    await _tts.stop(); // barge-in
    // Release any lingering session before re-opening (Infinix HiOS).
    try { await _stt.cancel(); } catch (_) {}
    try { await _sttFallback.cancel(); } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 250));
    final online = await _hasInternet();
    _isOffline = !online;
    _holdStartedAt = DateTime.now();
    if (!mounted) return;
    setState(() {
      _isListening = true;
      _transcript = '';
      _orbState = OrbState.listening;
      _statusText = _isOffline ? '🔴 অফলাইন — ধরে রেখে বলুন' : '🟢 ধরে রেখে বলুন';
    });
    final opts = SpeechListenOptions(
      listenMode: ListenMode.dictation,
      onDevice: _isOffline,
      partialResults: true,
      cancelOnError: false,
    );
    // Long windows: the worker's RELEASE ends the turn, so silence must not
    // auto-commit (a pause to recall a number must not cut them off).
    await _stt.listen(
      localeId: 'bn_IN',
      listenFor: const Duration(seconds: 120),
      pauseFor: const Duration(seconds: 120),
      listenOptions: opts,
      onResult: _onSpeechResult,
      onSoundLevelChange: (level) {
        if (mounted && _isListening) {
          final n = ((level + 2) / 12).clamp(0.0, 1.0);
          if (n > 0.15 && _orbState != OrbState.listening) setState(() => _orbState = OrbState.listening);
        }
      },
    );
    if (!_isOffline) {
      _sttFallback.listen(
        localeId: 'hi_IN',
        listenFor: const Duration(seconds: 120),
        pauseFor: const Duration(seconds: 120),
        listenOptions: opts,
        onResult: _onSpeechResult,
      );
    }
  }

  Future<void> _onHoldEnd() async {
    if (!_isListening) return;
    final heldMs = _holdStartedAt == null
        ? 0
        : DateTime.now().difference(_holdStartedAt!).inMilliseconds;
    _holdStartedAt = null;
    // Ignore an accidental quick tap — never fire an empty turn.
    if (heldMs < 300) {
      try { await _stt.cancel(); } catch (_) {}
      try { await _sttFallback.cancel(); } catch (_) {}
      if (mounted) {
        setState(() {
          _isListening = false;
          _transcript = '';
          _orbState = OrbState.idle;
        });
      }
      return;
    }
    if (mounted) setState(() { _isListening = false; _orbState = OrbState.processing; });
    // stop() finalises → onStatus(done) / final onResult → _processInput
    // (guarded against double-calls). We also nudge it directly in case the
    // recognizer doesn't deliver a final event on this device.
    await _stt.stop();
    await _sttFallback.stop();
    _submitTranscript(_transcript);
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!mounted) return;
    final text = result.recognizedWords.trim();
    if (text.isEmpty) return;
    setState(() {
      _transcript = text;
    });
    if (result.finalResult) {
      _stt.stop();
      _sttFallback.stop();
      setState(() { _isListening = false; _orbState = OrbState.processing; });
      // Bridge the network gap — _submitTranscript plays a 1-second cached ack
      // ("বুঝেছি।") immediately so the worker never hears silence between
      // speaking and the LLM response. Deduped so the hold-release and
      // done-status callbacks can't process this same utterance again.
      _submitTranscript(text);
    }
  }

  /// Plays a short cached "got it" filler from disk while the LLM/TTS
  /// network round-trip is in flight. Round-robins through [_ackFillers]
  /// so the same phrase doesn't repeat back-to-back. No-op if the cache
  /// miss falls through to the network (we don't want to add latency).
  void _playAckFiller() {
    final phrase = _ackFillers[_ackFillerIndex % _ackFillers.length];
    _ackFillerIndex++;
    // Don't await — the main response will overwrite this when ready.
    // tone=normal keeps the cache key consistent with prewarmed assets.
    _tts.speak(phrase, tone: TtsTone.normal);
  }

  // Timer that escalates the status text from "connecting" to "waking
  // server" after 5s of waiting — gives the worker a real signal that
  // the cold-start is happening, not a frozen app. Cancelled as soon
  // as the response arrives (or _isProcessing flips off).
  Timer? _coldStartHintTimer;

  // ── Core: process any input through conversational AI ─────────
  // One spoken turn → exactly ONE submission. The final STT result, the
  // hold-release, and the STT done-status callback can all fire for the same
  // utterance; without this guard a single "না" was processed 2–3 times and
  // auto-answered the next question(s). Reset to false at every listen start.
  bool _turnSubmitted = false;
  void _submitTranscript(String text) {
    if (_turnSubmitted || _isProcessing) return;
    final t = text.trim();
    if (t.isEmpty) return;
    _turnSubmitted = true;
    _playAckFiller();
    _processInput(t);
  }

  Future<void> _processInput(String input) async {
    if (input.trim().isEmpty || _isProcessing) return;
    setState(() {
      _isProcessing = true;
      _transcript = input;
      _orbState = OrbState.processing;
      _statusText = 'connecting'.tr;
    });
    _history.add(ConversationTurn(role: 'asha', text: input));
    // Patient-info question (name/age/village/…)? Answer from the linked
    // profile and stop — it is not a triage answer, so don't advance the
    // questionnaire or call Gemini.
    if (_answerPatientInfoIfAsked(input)) return;
    _turnCount++;
    // Arm the cold-start hint. If a reply lands in < 5s the timer is
    // cancelled below; otherwise the worker sees "সার্ভার জাগাচ্ছি..."
    // so they don't think the app is broken.
    _coldStartHintTimer?.cancel();
    _coldStartHintTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _isProcessing) {
        setState(() => _statusText = 'waking_server'.tr);
      }
    });
    final online = await _hasInternet();
    _isOffline = !online;
    if (_isOffline) {
      await _processOffline(input);
    } else {
      await _processOnline(input);
    }
  }

  // Answers a worker's question about the LINKED patient (name/age/village/…)
  // straight from the profile — deterministic, offline, and the patient's name
  // never leaves the device (not sent to the LLM). Returns true if it handled
  // the input, so triage skips it (not treated as an answer, no Gemini call).
  bool _answerPatientInfoIfAsked(String input) {
    final t = input.toLowerCase();
    bool has(List<String> ks) => ks.any((k) => t.contains(k));
    final name    = has(['নাম', 'name']);
    final age     = has(['বয়স', 'কত বছর', 'কত মাস', 'বছরের', 'মাসের', 'age']);
    final gender  = has(['লিঙ্গ', 'ছেলে না মেয়ে', 'gender']);
    final village = has(['গ্রাম', 'ঠিকানা', 'village', 'address']);
    final phone   = has(['মোবাইল', 'ফোন', 'নম্বর', 'phone', 'mobile']);
    final visit   = has(['শেষ ভিজিট', 'শেষ কবে', 'আগের ভিজিট', 'last visit']);
    final risk    = has(['ঝুঁকি', 'রিস্ক', 'risk']);
    final details = has(['রোগীর তথ্য', 'পেশেন্ট', 'রোগী কে', 'patient detail', 'details', 'কার']);

    final strong = name || gender || village || phone || visit || risk || details;
    final looksLikeQuestion =
        has(['কত', 'বলো', 'বলবে', 'বলতে', 'পারবে', 'জানো', 'কী', 'কি', '?']);
    if (!strong && !(age && looksLikeQuestion)) return false;

    final PatientModel? p = PatientTriageContext.lookup(_patientId);
    String reply;
    if (p == null) {
      reply = 'এই ট্রায়াজটি কোনো নির্দিষ্ট রোগীর সাথে যুক্ত নয়, তাই রোগীর তথ্য বলতে পারছি না। '
          'রোগী নির্বাচন করে ট্রায়াজ শুরু করলে আমি নাম, বয়স ইত্যাদি বলতে পারব।';
    } else {
      String unitBn(String u) => switch (u) { 'days' => 'দিন', 'months' => 'মাস', _ => 'বছর' };
      final ageStr = p.age.trim().isEmpty ? '' : '${p.age} ${unitBn(p.ageUnit)}';
      final riskBn = switch (p.risk.name) {
        'emergency' => 'জরুরি',
        'high' => 'উচ্চ ঝুঁকি',
        _ => 'নিরাপদ',
      };
      final parts = <String>[];
      if (name) parts.add('নাম ${p.name}');
      if (age) parts.add(ageStr.isEmpty ? 'বয়স জানা নেই' : 'বয়স $ageStr');
      if (gender && p.gender.trim().isNotEmpty) parts.add('লিঙ্গ ${p.gender}');
      if (village && p.village.trim().isNotEmpty) parts.add('গ্রাম ${p.village}');
      if (phone && p.mobile.trim().isNotEmpty) parts.add('মোবাইল ${p.mobile}');
      if (visit && p.lastVisit.trim().isNotEmpty) parts.add('শেষ ভিজিট ${p.lastVisit}');
      if (risk) parts.add('শেষ ঝুঁকি $riskBn');
      if (details || parts.isEmpty) {
        final s = <String>['নাম ${p.name}'];
        if (ageStr.isNotEmpty) s.add('বয়স $ageStr');
        if (p.gender.trim().isNotEmpty) s.add('লিঙ্গ ${p.gender}');
        if (p.village.trim().isNotEmpty) s.add('গ্রাম ${p.village}');
        reply = 'এই রোগীর তথ্য — ${s.join(', ')}।';
      } else {
        reply = 'এই রোগীর — ${parts.join(', ')}।';
      }
    }

    _history.add(ConversationTurn(role: 'assistant', text: reply));
    if (mounted) {
      setState(() {
        _isProcessing = false;
        _orbState = OrbState.idle;
        _statusText = 'tap_mic_to_speak'.tr;
        _transcript = '';
      });
    }
    _speakNatural(reply);
    return true;
  }

  // Single Gemini/backend conversation call — extracted so the online path can
  // retry it once before falling back, without duplicating the request args.
  // Idempotent: history is copied (not mutated), so calling it twice is safe.
  Future<ConversationResponse> _callGemini(String input) async {
    final authToken = LocalStorageService.get('jwt_token');
    if (mounted) setState(() => _statusText = 'connecting'.tr);
    return _conversationService.respond(
      caseType: _caseType,
      moduleId: _moduleId,
      history: List.from(_history)..removeLast(),
      newInput: input,
      currentAnswers: Map.from(_extractedAnswers),
      turnNumber: _turnCount,
      maxTurns: _kMaxTurns,
      authToken: authToken,
      onPartialResponse: (partial) {
        if (mounted) setState(() => _streamingPartial = partial);
      },
    );
  }

  // ── Online: true Gemini conversation ──────────────────────────
  Future<void> _processOnline(String input) async {
    // Ensure offline question list is populated for yes/no capture
    if (_offlineQuestions.isEmpty) {
      _offlineQuestions = Get.find<RuleExecutor>()
          .questionIndex()
          .where((q) => q.moduleId == _moduleId)
          .toList();
    }

    // Step 1: capture bare yes/no against the question Gemini asked last turn
    // BEFORE sending to Gemini, so currentAnswers is already up to date.
    final localExtraction = _situationExtractor.extract(
        situation: input, moduleId: _moduleId);
    _extractedAnswers.addAll(localExtraction.preAnswers);
    // Terse graded reply against the question Gemini asked last turn — records
    // yes / no / severe / mild / unsure (unsure blocks GREEN downstream). A
    // long multi-symptom reply returns null here and is left to the extractor.
    if (_lastOnlineQuestionId != null) {
      final code = AnswerCodes.fromSpeech(input);
      if (code != null) _extractedAnswers[_lastOnlineQuestionId!] = code;
    }
    _lastOnlineQuestionId = null; // consume

    // ── Phase 1: network call ───────────────────────────────────────────
    // ONLY the network call is in this try block. Anything past it
    // (history.add, TTS playback, closing summary) is post-success work
    // and must NOT trigger the offline fallback — otherwise a TTS hiccup
    // would add a second contradictory message to the conversation
    // (the original cause of the "online + offline together" bug).
    late ConversationResponse response;
    try {
      response = await _callGemini(input);
    } catch (e) {
      // Gemini/backend call failed. Mode is decided ONLY by real connectivity,
      // re-probed here (skipping the 30s cache):
      //   • genuinely offline      → offline rules engine.
      //   • still online (a hiccup: cold-start / 503 / weak signal) → retry
      //     Gemini ONCE; if it still fails, finish THIS turn on the offline
      //     rules so triage never stalls (the band is the same deterministic
      //     engine) and STAY online — the next turn tries Gemini again. We
      //     never silently drop to offline while the device has internet.
      if (!mounted) return;
      _coldStartHintTimer?.cancel();
      _cachedOnline = null;
      final stillOnline = await _hasInternet();
      if (!mounted) return;
      if (stillOnline) {
        try {
          response = await _callGemini(input); // retry once, still online
        } catch (_) {
          if (!mounted) return;
          _turnCount--; // do not burn a wasted turn
          setState(() {
            _isProcessing = false;
            _orbState = OrbState.idle;
            _streamingPartial = '';
            _isOffline = false; // still online — only used rules for this turn
          });
          await _processOffline(input);
          return;
        }
        // retry succeeded → fall through to Phase 2 with `response`.
      } else {
        _turnCount--;
        setState(() {
          _isProcessing = false;
          _orbState = OrbState.idle;
          _streamingPartial = '';
          _isOffline = true; // genuinely offline
        });
        await _processOffline(input);
        return;
      }
    }

    // ── Phase 2: process the successful response ────────────────────────
    // Errors below this point (TTS playback, navigation, etc.) are NOT
    // caught here — they should bubble up and surface as their own
    // errors rather than silently dual-firing the offline engine.
    if (!mounted) return;
    setState(() {
      _streamingPartial = '';
      _statusText = 'analyzing'.tr;
    });

    // Merge Gemini extractions (Gemini handles complex multi-symptom replies)
    _extractedAnswers.addAll(response.extractedAnswers);

    // ── Attribute the worker's NEXT bare yes/no to the right question ──
    // Authoritative: Gemini tells us exactly which question it just asked
    // (asked_question_id), so a terse "হ্যাঁ"/"না" next turn lands on the
    // correct question. We no longer guess from a priority list that had
    // drifted out of sync with the prompt's order — that drift recorded the
    // reply against the wrong question, so Gemini never saw the real one
    // answered and re-asked it forever (the triage loop).
    String? asked = response.askedQuestionId;
    if (asked == null) {
      // Fallback only when the model omitted the id: first still-unanswered
      // question, in the SAME order the prompt prioritises (kept in sync).
      const fallbackOrder = {
        'pregnancy':    ['p7','p1','p3','p6','p9','p10','p8','p4','p11','p11d','p2','p12','p5'],
        'delivery_pnc': ['pp1','pp7','pp8','pp2','pp4','pp6','pp3','pp5','pp9'],
        'newborn':      ['n7','n1','n2','n3','n5','n4','n6','n8','n9','n10'],
        'child':        ['c7','c8','c9','c10','c1','c5','c2','c3','c11','c4','c6','c12'],
        'emergency':    ['e1','e2','e3','e4','e5','e6','e7','e8'],
        'immunisation': ['im4','im2','im1','im5','im3','im6'],
      };
      asked = (fallbackOrder[_moduleId] ?? const <String>[])
          .cast<String?>()
          .firstWhere((id) => !_extractedAnswers.containsKey(id),
              orElse: () => null);
    }

    // ── Loop guard ──
    // If Gemini keeps asking the SAME question (e.g. it ignored the answered
    // list), count the repeats; after 3, mark that question answered "no" and
    // stop attributing to it so the conversation always advances. "no" is
    // band-neutral here — an unanswered danger sign and an explicit "no"
    // produce the same band, and a later clear statement still upgrades it.
    if (asked != null && asked == _repeatAskId) {
      _repeatAskCount++;
      if (_repeatAskCount >= 3) {
        _extractedAnswers.putIfAbsent(asked, () => AnswerCodes.no);
        _repeatAskId = null;
        _repeatAskCount = 0;
        asked = null;
      }
    } else {
      _repeatAskId = asked;
      _repeatAskCount = asked == null ? 0 : 1;
    }
    _lastOnlineQuestionId = asked;

    _extractedVitals.addAll(response.extractedVitals);
    _riskLevel = _computeLocalRiskLevel();
    _history.add(ConversationTurn(
        role: 'assistant', text: response.spokenResponse));

    _coldStartHintTimer?.cancel();
    setState(() {
      _isProcessing = false;
      _orbState = OrbState.idle;
      _statusText = 'tap_mic_to_speak'.tr;
      _transcript = '';
    });

    // Speak the response. Wrapped in its own try so a TTS failure can't
    // accidentally trigger the offline fallback above.
    try {
      if (response.prefetchedAudio != null &&
          response.prefetchedAudio!.isNotEmpty) {
        await _tts.speakBytes(
          response.prefetchedAudio!,
          text: response.spokenResponse,
          tone: TtsTone.normal,
        );
      } else {
        await _speakNatural(response.spokenResponse);
      }
    } catch (_) { /* TTS failed — text already shown */ }

    if (!mounted) return;

    if (response.cancelSession) {
      _tts.stop();
      _stt.stop();
      Get.back();
      return;
    }

    if (response.shouldFinish || _turnCount >= _kMaxTurns) {
      await _speakClosingSummary();
      if (mounted) _submitAnswers();
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
  Future<void> _processOffline(String input) async {
    if (!mounted) return;

    // ── 1. Extract answers from free text ──────────────────────
    final extraction = _situationExtractor.extract(
      situation: input,
      moduleId: _moduleId,
    );
    _extractedAnswers.addAll(extraction.preAnswers);

    // ── 2. Capture terse graded reply against last asked question ────
    // Records a graded code (yes / no / severe / mild / unsure). `unsure`
    // never silently clears GREEN; `mild` is at least YELLOW (handled in the
    // engine). Clear _lastAskedQuestion only after use so a second bare reply
    // cannot double-record.
    String? lastTurnId = extraction.preAnswers.keys.firstOrNull;
    dynamic lastTurnVal = extraction.preAnswers.values.firstOrNull ?? false;
    final lastQ = _lastAskedQuestion;
    if (lastQ != null &&
        _isYesNoQuestion(lastQ) &&
        !extraction.preAnswers.containsKey(lastQ.id)) {
      final code = AnswerCodes.fromSpeech(input);
      if (code != null) {
        _extractedAnswers[lastQ.id] = code;
        lastTurnId = lastQ.id;
        lastTurnVal = code;
      }
    }
    // Consume the last question so a follow-up turn cannot re-record it.
    _lastAskedQuestion = null;

    // ── 3. Ensure question list is loaded / refreshed ──────────
    // Always rebuild from the full index so questions answered via
    // situation extraction (before the list was first loaded) are
    // correctly excluded and no stale entries cause an infinite loop.
    _offlineQuestions = Get.find<RuleExecutor>()
        .questionIndex()
        .where((q) => q.moduleId == _moduleId)
        .toList();

    // ── 4. Deterministic risk update ───────────────────────────
    _riskLevel = _computeLocalRiskLevel();

    // ── 5. Proactive combination check ─────────────────────────
    // Catches combos pre-filled by situation extraction (not just
    // turn-by-turn answers), which the OfflineBrain combo check misses.
    final confirmedYes = _extractedAnswers.entries
        .where((e) => AnswerCodes.isAffirmative(e.value))
        .map((e) => e.key)
        .toSet();
    final earlyCombo = _offlineBrain.checkCombinations(confirmedYes);
    if (earlyCombo != null) {
      _riskLevel = 'emergency';
      _history.add(ConversationTurn(role: 'assistant', text: earlyCombo));
      setState(() {
        _isProcessing = false;
        _orbState = OrbState.idle;
        _statusText = 'tap_mic_to_speak'.tr;
        _transcript = '';
      });
      await _speakEmergency(earlyCombo);
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 800));
        _submitAnswers();
      }
      return;
    }

    // ── 6. RED band → emergency finish ─────────────────────────
    if (_riskLevel == 'emergency') {
      final count = confirmedYes.length;
      final emergencyText =
          'সতর্কতা! ${count}টি গুরুত্বর বিপদচিহ্ন পাওয়া গেছে। এখনই ১০৮ কল করুন এবং রোগীকে FRU-তে রেফার করুন।';
      _history.add(ConversationTurn(role: 'assistant', text: emergencyText));
      setState(() {
        _isProcessing = false;
        _orbState = OrbState.idle;
        _statusText = 'tap_mic_to_speak'.tr;
        _transcript = '';
      });
      await _speakEmergency(emergencyText);
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 800));
        _submitAnswers();
      }
      return;
    }

    // ── 7. CLUP keyword emergency check ────────────────────────
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
        _statusText = 'tap_mic_to_speak'.tr;
        _transcript = '';
      });
      await _speakEmergency(emergencyText);
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 800));
        _submitAnswers();
      }
      return;
    }

    // ── 8. Immediate action for newly confirmed danger signs ───
    String? immediateAction;
    for (final entry in extraction.preAnswers.entries) {
      if (entry.value) {
        final action = ImmediateActionEngine.getAction(
          answeredId: entry.key,
          answerWasYes: true,
          confirmedYes: confirmedYes,
        );
        if (action != null) {
          immediateAction = action.textBn;
          break;
        }
      }
    }

    // ── 9. Remaining questions (always fresh) ──────────────────
    final remaining = _offlineQuestions
        .where((q) => !_extractedAnswers.containsKey(q.id))
        .toList();

    // ── 10. Finish conditions ───────────────────────────────────
    // Only finish on turn limit or no questions left — NOT on confirmedYes
    // count alone, so hard-stop questions are never skipped.
    if (remaining.isEmpty || _turnCount >= 10) {
      _riskLevel = _computeLocalRiskLevel();
      setState(() {
        _isProcessing = false;
        _orbState = OrbState.idle;
        _statusText = 'tap_mic_to_speak'.tr;
        _transcript = '';
      });
      await _speakClosingSummary();
      if (mounted) _submitAnswers();
      return;
    }

    // ── 11. Pick next question via OfflineBrain ─────────────────
    final next = _offlineBrain.getNextQuestion(
      remaining: remaining,
      confirmedYes: confirmedYes,
      lastAnsweredId: lastTurnId,
      lastAnswerWasYes: AnswerCodes.isAffirmative(lastTurnVal),
    );

    // Combination alert fired during question selection → emergency finish
    if (next.combinationAlertBn != null) {
      _riskLevel = 'emergency';
      _history.add(
          ConversationTurn(role: 'assistant', text: next.combinationAlertBn!));
      setState(() {
        _isProcessing = false;
        _orbState = OrbState.idle;
        _statusText = 'tap_mic_to_speak'.tr;
        _transcript = '';
      });
      await _speakEmergency(next.combinationAlertBn!);
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 800));
        _submitAnswers();
      }
      return;
    }

    // ── 12. Ask next question ───────────────────────────────────
    // Guard: brain signals finish (confirmedYes>=3) before questions exhaust.
    if (next.shouldFinish) {
      _riskLevel = _computeLocalRiskLevel();
      setState(() {
        _isProcessing = false;
        _orbState = OrbState.idle;
        _transcript = '';
      });
      await _speakClosingSummary();
      if (mounted) _submitAnswers();
      return;
    }
    final nextQ = next.question ?? remaining.first;
    _lastAskedQuestion = nextQ;

    final ack = _buildAcknowledgement(input, extraction.extractedSymptoms);
    final alert = immediateAction ?? next.immediateActionBn;
    final responseText = alert != null
        ? '$ack $alert ${nextQ.textBn}'
        : '$ack ${nextQ.textBn}';

    _history.add(ConversationTurn(role: 'assistant', text: responseText));
    setState(() {
      _isProcessing = false;
      _orbState = OrbState.idle;
      _statusText = 'tap_mic_to_speak'.tr;
      _transcript = '';
    });
    await _speakQuestion(responseText);
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
      demographics: PatientTriageContext.demographicsFor(_patientId),
      history: PatientTriageContext.historyFor(_patientId),
    );
    final band = result.pipelineBlocked ? 'GREEN' : result.band;
    return switch (band) {
      'RED'    => 'emergency',
      'YELLOW' => 'medium',
      _        => 'low',
    };
  }

  // ── Spoken closing summary before navigating to result ────────
  Future<void> _speakClosingSummary() async {
    if (!mounted) return;
    final confirmedCount =
        _extractedAnswers.values.where(AnswerCodes.isAffirmative).length;
    final String text;
    if (_riskLevel == 'emergency') {
      text = 'সতর্কতা! গুরুত্বর বিপদচিহ্ন পাওয়া গেছে। এখনই রেফার করুন।';
    } else if (confirmedCount == 0) {
      text = 'ধন্যবাদ। কোনো গুরুতর বিপদচিহ্ন পাওয়া যায়নি। ফলাফল দেখাচ্ছি।';
    } else {
      text = 'ধন্যবাদ। ${confirmedCount}টি বিপদচিহ্ন পাওয়া গেছে। ফলাফল দেখাচ্ছি।';
    }
    await _speakNatural(text);
    await Future.delayed(const Duration(milliseconds: 400));
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

  // Graded answer detection (yes / no / severe / mild / unsure) now lives in
  // AnswerCodes.fromSpeech — a single source of truth shared with the engine.

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
                    Material(
                      color: AppColors.surface,
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: () { _tts.stop(); _stt.stop(); Get.back(); },
                        customBorder: const CircleBorder(),
                        child: Ink(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            shape: BoxShape.circle,
                            boxShadow: AppShadows.low,
                          ),
                          child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _caseTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.labelLg.copyWith(color: AppColors.primary),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _isOffline ? AppColors.warningYellow : AppColors.safeGreen,
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Audio-offline indicator: shows a small mute icon
                              // when the last TTS call could not play (no cache,
                              // no bundled asset, no network). The on-screen
                              // text below is still rendered so the worker
                              // doesn't miss the question — this just tells
                              // them why Kore went silent. Disappears the
                              // moment any later phrase plays successfully.
                              Obx(() => _tts.audioReady.value
                                  ? const SizedBox.shrink()
                                  : const Padding(
                                      padding: EdgeInsets.only(right: 6),
                                      child: Icon(
                                        Icons.volume_off_rounded,
                                        size: 14,
                                        color: AppColors.warningYellow,
                                      ),
                                    )),
                              Text(
                                _isOffline ? 'অফলাইন মোড' : 'আশামিত্র AI',
                                style: AppTextStyles.caption.copyWith(
                                  color: _isOffline ? AppColors.warningYellow : AppColors.safeGreen,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Risk indicator
                    if (_riskLevel != 'low')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _riskColor.withValues(alpha: 0.12),
                          borderRadius: AppRadius.pillR,
                          border: Border.all(color: _riskColor.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          switch (_riskLevel) {
                            'emergency' => 'জরুরি',
                            'high'      => 'উচ্চ ঝুঁকি',
                            'medium'    => 'মাঝারি',
                            _           => '',
                          },
                          style: AppTextStyles.label.copyWith(color: _riskColor),
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
                    // Hold-to-talk: press the orb to listen, release to send
                    // (same gesture as the assistant). Listener captures the
                    // raw press/release regardless of hold duration.
                    Listener(
                      onPointerDown: (_) => _onHoldStart(),
                      onPointerUp: (_) => _onHoldEnd(),
                      onPointerCancel: (_) => _onHoldEnd(),
                      child: VoiceOrb(size: orbSize, state: _orbState),
                    ),
                    const SizedBox(height: 8),
                    if (_transcript.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: AppRadius.mdR,
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.20)),
                        ),
                        // STT confidence number used to render here next
                        // to the live transcript. Hidden per pilot
                        // feedback — the spoken text alone is enough.
                        child: Text(
                          '"$_transcript"',
                          style: AppTextStyles.bodySm.copyWith(color: AppColors.onBackground),
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
                    // Mic control is the orb itself now (hold-to-talk), so the
                    // separate toggle button is gone — just the status line.
                    Text(
                      _isProcessing
                          ? _statusText
                          : _isListening
                              ? 'শুনছি — ছেড়ে দিলে পাঠাবে'
                              : 'ধরে রেখে বলুন · ছেড়ে দিলে পাঠাবে',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption.copyWith(
                        color: _isListening
                            ? AppColors.safeGreen
                            : _isProcessing
                                ? AppColors.primary
                                : AppColors.textSecondary,
                        fontWeight: (_isListening || _isProcessing) ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_history.length >= 2)
                      TextButton(
                        onPressed: _submitAnswers,
                        child: Text(
                          'ফলাফল দেখুন →',
                          style: AppTextStyles.label.copyWith(color: AppColors.primary),
                        ),
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

  // Triage reply is voice-only via the orb (hold-to-talk). Graded answers are
  // captured from speech by AnswerCodes.fromSpeech — no on-screen option chips.

  // ── Chat bubble ───────────────────────────────────────────────
  Widget _buildChatBubble(ConversationTurn turn) {
    final isAsha = turn.role == 'asha';
    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: isAsha ? AppColors.primary.withValues(alpha: 0.10) : AppColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(AppRadius.lg),
          topRight: const Radius.circular(AppRadius.lg),
          bottomLeft: Radius.circular(isAsha ? AppRadius.lg : 4),
          bottomRight: Radius.circular(isAsha ? 4 : AppRadius.lg),
        ),
        boxShadow: AppShadows.low,
      ),
      child: Text(
        turn.text,
        style: AppTextStyles.body.copyWith(
          color: isAsha ? AppColors.primary : AppColors.onBackground,
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isAsha ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isAsha) ...[
            // AshaMitra logo as the assistant avatar — matches the
            // chat bubble in the AshaMitra Voice Assistant tab so the
            // worker sees the same brand mark in both surfaces.
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.6),
                  width: 1.5,
                ),
                boxShadow: AppShadows.tinted(AppColors.primary),
              ),
              padding: const EdgeInsets.all(3),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/ashalogo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            // Assistant bubbles get a "listen again" chip beneath them so the
            // worker can re-hear safety-critical guidance in a noisy setting.
            child: isAsha
                ? bubble
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      bubble,
                      _TriageReplayChip(
                        onTap: () => _replayAssistantTurn(turn.text),
                      ),
                    ],
                  ),
          ),
          if (isAsha) ...[
            const SizedBox(width: 8),
            // The worker's own profile photo (base64 from Atlas or local
            // file) with an initial-letter fallback — makes the conversation
            // feel personal and clearly shows who is speaking.
            UserAvatar(
              user: Get.isRegistered<AuthController>()
                  ? Get.find<AuthController>().user.value
                  : null,
              size: 32,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              textColor: AppColors.primary,
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
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.6),
                width: 1.5,
              ),
              boxShadow: AppShadows.tinted(AppColors.primary),
            ),
            padding: const EdgeInsets.all(3),
            child: ClipOval(
              child: Image.asset(
                'assets/images/ashalogo.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.lg),
                  topRight: Radius.circular(AppRadius.lg),
                  bottomRight: Radius.circular(AppRadius.lg),
                  bottomLeft: Radius.circular(4),
                ),
                boxShadow: AppShadows.low,
              ),
              child: _streamingPartial.isNotEmpty
                  ? Text(_streamingPartial, style: AppTextStyles.body)
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        3,
                        (i) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.40),
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

/// "Listen again" affordance under each assistant bubble in triage. A speaker
/// icon + Bengali label; tapping re-plays the spoken audio from cache (no
/// network / LLM) so the worker can re-hear safety-critical guidance.
class _TriageReplayChip extends StatelessWidget {
  final VoidCallback onTap;
  const _TriageReplayChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.pillR,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.volume_up_rounded,
                  size: 15,
                  color: AppColors.primary.withValues(alpha: 0.85),
                ),
                const SizedBox(width: 4),
                Text(
                  'আবার শুনুন',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

