// ─────────────────────────────────────────────────────────────────────────────
// AssistantScreen — voice-first Gemini-Live-style AI assistant for ASHA workers
//
// Behaviour:
//   1. Opens with a warm greeting in the app's selected language (Bengali by
//      default; Hindi or English if the worker set it).
//   2. Voice orb auto-starts listening after the greeting plays.
//   3. Worker speaks freely — clinical questions, general knowledge, casual
//      chat. Whatever.
//   4. Assistant detects the language of the worker's reply and continues in
//      THAT language for the rest of the session — even if it differs from
//      the app setting. Code-switching is tolerated.
//   5. When the conversation contains clinical content (2+ symptoms, a clear
//      patient situation, or a danger sign), the assistant suggests:
//      "Should I save this as a report?" Inline action chips appear.
//   6. If yes → patient picker → save report. If no → conversation continues.
//   7. Tap orb = TRUE PAUSE. Stops listening, stops speaking, stays
//      quiet until worker taps again. Mic-off orb (grey) makes it
//      visually obvious that nothing is being captured. Critical for
//      privacy (patient home visits), background-noise rejection, and
//      as an escape hatch when the state machine gets confused.
//
// Offline-first action layer:
//   Before sending any user utterance to the LLM, a rule-based intent
//   classifier checks for common app actions ("call ambulance", "open
//   patients", "start triage" etc.) in Bengali/Hindi/English. Matches
//   are dispatched instantly with no network round-trip. Anything that
//   doesn't match (clinical questions, free chat) falls through to
//   Gemini as before. See intent_classifier.dart + intent_dispatcher.dart.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../../app/routes.dart';
import '../../../../core/services/language_controller.dart';
import '../../../../core/services/tts_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/voice_orb.dart';
import '../../services/assistant_chat_service.dart';
import '../../services/intent_classifier.dart';
import '../../services/intent_dispatcher.dart';

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  // ── Services ───────────────────────────────────────────────────────────
  final _chat = AssistantChatService();
  final _stt = SpeechToText();
  final _tts = TtsService();
  // Rule-based intent classifier runs BEFORE the LLM on every user
  // utterance. Common app actions ("open patients", "call ambulance",
  // "start triage") match here and execute instantly — no network
  // round-trip. Anything that doesn't match falls through to Gemini.
  // This is the offline-emergency layer: actions work without signal.
  final _intentClassifier = RuleBasedIntentClassifier();

  // ── State ──────────────────────────────────────────────────────────────
  final List<AssistantTurn> _history = [];
  AssistantLang _activeLang = AssistantLang.bn;
  OrbState _orbState = OrbState.idle;

  String _liveTranscript = '';
  String _statusLine = '';
  bool _sttReady = false;
  bool _isListening = false;
  bool _isThinking = false;
  bool _showSaveChip = false;
  // True while the screen wants to stay listening between turns and even
  // through silent pauses. Flipped off when the worker taps the orb to
  // pause, and on dispose so background STT events can't accidentally
  // restart the mic after teardown.
  bool _autoListen = true;
  // True when the worker has explicitly paused the assistant by tapping
  // the orb. While paused: no auto-restart, TTS stays stopped, orb shows
  // grey/mic-off so worker can see at a glance that nothing is captured.
  // Tap again to resume.
  bool _isPaused = false;

  // STT self-recovery: track consecutive error/status-failure events.
  // The native SpeechRecognizer can get into a stuck state after several
  // back-to-back errors where listen() returns immediately with no audio
  // session. When we hit the threshold, we cancel + re-initialize the
  // plugin rather than ignore the error and silently leave the mic dead.
  int _consecutiveSttErrors = 0;
  static const _sttErrorThreshold = 3;

  // Escalates the status line from "thinking" to "waking server" after
  // 5s of waiting so the worker knows the cold-start is happening rather
  // than the app being frozen. Cancelled when the reply lands.
  Timer? _coldStartHintTimer;

  @override
  void initState() {
    super.initState();
    _activeLang = AssistantLangX.fromIndex(
      Get.find<LanguageController>().selectedIndex.value,
    );
    _statusLine = _bootStatus(_activeLang);
    _initAll();
  }

  Future<void> _initAll() async {
    await _tts.init();
    _wireTtsCallbacks();
    _sttReady = await _initStt();
    if (!mounted) return;
    // Voice-first: greet immediately, then auto-listen when TTS done.
    await _speakGreeting();
  }

  /// Initialize the STT plugin. Used both at boot and from the self-
  /// recovery path when consecutive errors signal the native recognizer
  /// is in a stuck state.
  Future<bool> _initStt() async {
    return await _stt.initialize(
      onError: (err) {
        if (!mounted) return;
        // Track consecutive errors so a runaway error storm triggers a
        // hard reset instead of silently leaving the mic dead. The native
        // SpeechRecognizer occasionally enters a state where listen()
        // returns immediately with no audio session; only cancel + init
        // recovers from it.
        _consecutiveSttErrors++;
        if (_consecutiveSttErrors >= _sttErrorThreshold) {
          _recoverStt();
        } else {
          _resetToIdle();
        }
      },
      onStatus: (status) {
        if (!mounted) return;
        if ((status == SpeechToText.doneStatus ||
                status == SpeechToText.notListeningStatus) &&
            _isListening) {
          _onListenComplete();
        }
      },
    );
  }

  /// Hard-reset the STT plugin after [_sttErrorThreshold] consecutive
  /// errors. Cancels any in-flight listen session, re-initializes the
  /// plugin, and restores the orb to a clean idle state. Worker can
  /// then tap to talk again without restarting the app.
  Future<void> _recoverStt() async {
    _consecutiveSttErrors = 0;
    try {
      await _stt.cancel();
    } catch (_) {}
    _sttReady = await _initStt();
    if (!mounted) return;
    _resetToIdle();
  }

  void _wireTtsCallbacks() {
    _tts.onStart = () {
      if (mounted && !_isPaused) {
        setState(() => _orbState = OrbState.processing);
      }
    };
    _tts.onComplete = () {
      if (!mounted) return;
      setState(() => _orbState = _isPaused ? OrbState.paused : OrbState.idle);
      // Auto-listen after every TTS chunk — but ONLY if the worker hasn't
      // tapped to pause. _isPaused is the worker-controlled hard switch;
      // _autoListen is the screen-lifecycle switch. Both must allow it.
      //
      // Drain wait extended to 800 ms (was 600 ms) AFTER _tts.isPlaying
      // reports false. The plugin's isPlaying flag flips off slightly
      // before the audio actually leaves the speaker on cheaper phones;
      // the extra buffer kills the "TTS bleeds into next STT" bug where
      // the assistant's own voice was being captured as the worker's
      // next utterance.
      if (_autoListen && !_isPaused && !_isThinking && !_showSaveChip) {
        () async {
          final deadline = DateTime.now().add(const Duration(seconds: 2));
          while (_tts.isPlaying && DateTime.now().isBefore(deadline)) {
            await Future.delayed(const Duration(milliseconds: 80));
          }
          await Future.delayed(const Duration(milliseconds: 800));
          if (mounted &&
              _autoListen &&
              !_isPaused &&
              !_isThinking &&
              !_showSaveChip &&
              !_isListening) {
            _startListening();
          }
        }();
      }
    };
    _tts.onError = () {
      if (mounted) _resetToIdle();
    };
  }

  // ── Greeting ───────────────────────────────────────────────────────────
  Future<void> _speakGreeting() async {
    final greeting = _greetingFor(_activeLang);
    setState(() => _statusLine = _greetingStatus(_activeLang));
    await _tts.speak(greeting, tone: TtsTone.empathy);
  }

  // ── STT control ────────────────────────────────────────────────────────
  Future<void> _startListening() async {
    if (!_sttReady || _isListening || _isPaused) return;
    setState(() {
      _isListening = true;
      _liveTranscript = '';
      _orbState = OrbState.listening;
      _statusLine = _listeningStatus(_activeLang);
    });
    // listenFor extended 30s → 45s and pauseFor 4s → 6s so ASHA workers
    // get more thinking-time between phrases. They often pause mid-
    // sentence to recall a number or look up a register; 4 sec was
    // committing too early and cutting them off.
    //
    // cancelOnError: true (was false) — let errors propagate through the
    // onError callback to the self-recovery counter rather than silently
    // swallow them. Silent swallowing was the root cause of the "mic
    // stuck on listening forever, no audio captured" state.
    await _stt.listen(
      localeId: _activeLang.sttLocale,
      listenFor: const Duration(seconds: 45),
      pauseFor: const Duration(seconds: 6),
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: true,
      ),
      onResult: (r) {
        if (!mounted) return;
        setState(() => _liveTranscript = r.recognizedWords);
        if (r.finalResult && _liveTranscript.trim().isNotEmpty) {
          // Successful capture — reset the error counter.
          _consecutiveSttErrors = 0;
          _stt.stop();
        }
      },
    );
  }

  void _onListenComplete() {
    setState(() {
      _isListening = false;
      _orbState = _isPaused ? OrbState.paused : OrbState.idle;
    });
    final input = _liveTranscript.trim();
    if (input.isEmpty) {
      _statusLine = _isPaused
          ? _pausedStatus(_activeLang)
          : _idleStatus(_activeLang);
      // Silent timeout (pauseFor or listenFor with no speech) — re-arm
      // the mic so the screen stays truly always-listening while open.
      // Skip the re-arm if worker has paused, or if TTS is mid-playback
      // (the AI's own voice would bleed into the next STT session — the
      // "TTS taken as input" bug). Drain wait extended to 800 ms after
      // isPlaying clears.
      if (_autoListen && !_isPaused && !_isThinking && !_showSaveChip) {
        () async {
          final deadline = DateTime.now().add(const Duration(seconds: 2));
          while (_tts.isPlaying && DateTime.now().isBefore(deadline)) {
            await Future.delayed(const Duration(milliseconds: 80));
          }
          await Future.delayed(const Duration(milliseconds: 800));
          if (mounted &&
              _autoListen &&
              !_isPaused &&
              !_isListening &&
              !_isThinking) {
            _startListening();
          }
        }();
      }
      return;
    }
    // Send straight to LLM — no ack filler. The filler used to play a
    // 1-sec "got it" through TTS before the real reply, but that meant
    // 3 audio focus transitions per turn (STT-stop → ack-TTS → response-
    // TTS → STT-restart). On Android, each transition risks the system
    // beep and a state-machine race where one of them never fully
    // releases audio focus, leaving the mic stuck. Dropping the filler
    // eliminates one of the three transitions and the stuck-mic bug
    // we were seeing after ~5-10 turns.
    _handleUserInput(input);
  }

  // ── Main loop: rule-match → action OR LLM, then speak reply ────────────
  Future<void> _handleUserInput(String input) async {
    HapticFeedback.lightImpact();
    setState(() {
      _history.add(AssistantTurn(role: 'user', text: input));
      _isThinking = true;
      _orbState = OrbState.processing;
      _statusLine = _thinkingStatus(_activeLang);
      _liveTranscript = '';
    });

    // ── Step 1: try rule-based intent classifier first ──
    // Common app actions (call ambulance, open patients, etc.) bypass
    // the LLM entirely — instant response, works offline. If the
    // classifier finds a confident match, we dispatch the action and
    // speak a short confirmation; conversation history records the
    // confirmation so the LLM has context if the worker keeps talking.
    final classified = _intentClassifier.classify(input, _activeLang);
    if (classified.isHandled && classified.confidence >= 0.45) {
      final dispatcher = IntentDispatcher(lang: _activeLang);
      final result = await dispatcher.dispatch(classified);
      if (result.handled) {
        setState(() {
          _isThinking = false;
          _history.add(
            AssistantTurn(role: 'assistant', text: result.spokenConfirmation),
          );
          _statusLine = '';
        });
        if (result.spokenConfirmation.isNotEmpty) {
          try {
            await _tts.stop();
          } catch (_) {}
          await _tts.speak(result.spokenConfirmation, tone: TtsTone.normal);
        }
        return;
      }
    }

    // ── Step 2: fall through to LLM for free-form / clinical chat ──
    // Arm cold-start hint — after 5s of waiting, switch the status line
    // to "waking the server" so the worker knows the app isn't frozen.
    _coldStartHintTimer?.cancel();
    _coldStartHintTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _isThinking) {
        setState(() => _statusLine = _wakingServerStatus(_activeLang));
      }
    });

    final response = await _chat.ask(
      userInput: input,
      history: _history,
      appLanguage: _activeLang,
    );

    _coldStartHintTimer?.cancel();

    // Switch active language to whatever the worker just spoke
    _activeLang = response.detectedLanguage;

    setState(() {
      _isThinking = false;
      _history.add(AssistantTurn(role: 'assistant', text: response.text));
      _statusLine = '';
      _showSaveChip = response.shouldOfferSave;
    });

    if (response.text.isNotEmpty) {
      try {
        await _tts.stop(); // ensure no overlap with auto-listen restart
      } catch (_) {}
      // Prefer pre-synthesized bytes from /chat-with-voice — one fewer
      // network round-trip, voice arrives with the text instead of a
      // beat behind. Falls back to /tts via _tts.speak otherwise.
      if (response.prefetchedAudio != null &&
          response.prefetchedAudio!.isNotEmpty) {
        await _tts.speakBytes(
          response.prefetchedAudio!,
          text: response.text,
          tone: TtsTone.normal,
        );
      } else {
        await _tts.speak(response.text, tone: TtsTone.normal);
      }
    }
  }

  // ── Orb tap: TRUE pause toggle ─────────────────────────────────────────
  // Worker-controlled hard switch. Every state has one clear behaviour
  // and the worker always knows what tapping will do:
  //   Paused      → resume (start listening)
  //   Listening   → pause  (stop, stay quiet, NO auto-restart)
  //   Speaking    → pause  (stop TTS, stay quiet)
  //   Thinking    → pause  (cancel pending re-arm, stay quiet — the
  //                         in-flight Gemini reply is allowed to land
  //                         but won't be spoken because TTS is paused)
  //   Idle        → start listening
  //
  // Critical: when we enter the paused state, _autoListen stays true
  // (it's the screen-lifecycle flag) but _isPaused is the gate every
  // re-arm path checks. This is the "escape hatch" that lets the worker
  // recover from any stuck-state without leaving the screen.
  Future<void> _onOrbTap() async {
    // Resume from a paused session.
    if (_isPaused) {
      setState(() {
        _isPaused = false;
        _orbState = OrbState.idle;
        _statusLine = _idleStatus(_activeLang);
      });
      _startListening();
      return;
    }
    // Pause from anywhere else — stop everything, stay quiet.
    await _pauseAssistant();
  }

  Future<void> _pauseAssistant() async {
    try {
      if (_isListening) await _stt.cancel();
    } catch (_) {}
    try {
      await _tts.stop();
    } catch (_) {}
    _coldStartHintTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _isPaused = true;
      _isListening = false;
      _liveTranscript = '';
      _orbState = OrbState.paused;
      _statusLine = _pausedStatus(_activeLang);
    });
  }

  void _resetToIdle() {
    setState(() {
      _isListening = false;
      _isThinking = false;
      _orbState = _isPaused ? OrbState.paused : OrbState.idle;
      _statusLine = _isPaused
          ? _pausedStatus(_activeLang)
          : _idleStatus(_activeLang);
    });
  }

  // ── Save as report ─────────────────────────────────────────────────────
  void _confirmSave() {
    setState(() => _showSaveChip = false);
    // Hand off to existing patient context sheet flow — assistant content
    // becomes the situation seed.
    final lastUserMessage = _history.lastWhere(
      (t) => t.role == 'user',
      orElse: () => const AssistantTurn(role: 'user', text: ''),
    );
    Get.toNamed(AppRoutes.selectCase, arguments: {
      'situation': lastUserMessage.text,
    });
  }

  void _dismissSave() => setState(() => _showSaveChip = false);

  @override
  void dispose() {
    // Flip auto-listen off first so the delayed restart callback can't
    // re-open the mic on a disposed state.
    _autoListen = false;
    _coldStartHintTimer?.cancel();
    _tts.stop();
    _stt.stop();
    super.dispose();
  }

  // ── UI ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          child: Column(
            children: [
              _AssistantHeader(
                lang: _activeLang,
                onClose: () => Get.back(),
              ),
              Expanded(
                child: Column(
                  children: [
                    Expanded(child: _ConversationView(history: _history)),
                    if (_showSaveChip)
                      _SaveAsReportChips(
                        lang: _activeLang,
                        onYes: _confirmSave,
                        onNo: _dismissSave,
                      ),
                    if (_liveTranscript.isNotEmpty && _isListening)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 8),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: AppRadius.lgR,
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Text(
                            _liveTranscript,
                            style: AppTextStyles.body
                                .copyWith(color: AppColors.primary),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              _OrbDock(
                state: _orbState,
                statusLine: _statusLine.isEmpty
                    ? _idleStatus(_activeLang)
                    : _statusLine,
                isThinking: _isThinking,
                onTap: _onOrbTap,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── i18n strings (no .tr dependency — these need to track _activeLang) ──
  String _bootStatus(AssistantLang l) => switch (l) {
        AssistantLang.bn => 'প্রস্তুতি চলছে...',
        AssistantLang.hi => 'तैयार हो रही हूँ...',
        AssistantLang.en => 'Getting ready...',
      };
  String _greetingFor(AssistantLang l) => switch (l) {
        AssistantLang.bn =>
          'নমস্কার দিদি, আমি আশামিত্র। আপনি কী জানতে চান বা কোনো রোগীর কথা বলতে চান?',
        AssistantLang.hi =>
          'नमस्ते दीदी, मैं आशामित्र हूँ। आप क्या जानना चाहती हैं, या किसी मरीज़ के बारे में बताइए?',
        AssistantLang.en =>
          'Hello, I\'m Asha Mitra. What would you like to know, or tell me about a patient?',
      };
  String _greetingStatus(AssistantLang l) => switch (l) {
        AssistantLang.bn => 'বলছি...',
        AssistantLang.hi => 'बात कर रही हूँ...',
        AssistantLang.en => 'Speaking...',
      };
  String _listeningStatus(AssistantLang l) => switch (l) {
        AssistantLang.bn => 'শুনছি — বলুন',
        AssistantLang.hi => 'सुन रही हूँ — बोलिए',
        AssistantLang.en => 'Listening...',
      };
  String _thinkingStatus(AssistantLang l) => switch (l) {
        AssistantLang.bn => 'ভাবছি...',
        AssistantLang.hi => 'सोच रही हूँ...',
        AssistantLang.en => 'Thinking...',
      };
  String _wakingServerStatus(AssistantLang l) => switch (l) {
        AssistantLang.bn => 'সার্ভার জাগাচ্ছি, একটু অপেক্ষা করুন...',
        AssistantLang.hi => 'सर्वर जगा रहे हैं, थोड़ा रुकें...',
        AssistantLang.en => 'Waking the server, please wait...',
      };
  String _idleStatus(AssistantLang l) => switch (l) {
        AssistantLang.bn => 'অর্বে ট্যাপ করুন কথা বলতে',
        AssistantLang.hi => 'बोलने के लिए ओर्ब पर टैप करें',
        AssistantLang.en => 'Tap the orb to talk',
      };
  String _pausedStatus(AssistantLang l) => switch (l) {
        AssistantLang.bn => 'মাইক বন্ধ — চালু করতে ট্যাপ করুন',
        AssistantLang.hi => 'माइक बंद — चालू करने के लिए टैप करें',
        AssistantLang.en => 'Mic off — tap to start',
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _AssistantHeader extends StatelessWidget {
  final AssistantLang lang;
  final VoidCallback onClose;
  const _AssistantHeader({required this.lang, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final title = switch (lang) {
      AssistantLang.bn => 'আশামিত্র',
      AssistantLang.hi => 'आशामित्र',
      AssistantLang.en => 'Asha Mitra',
    };
    final subtitle = switch (lang) {
      AssistantLang.bn => 'ভয়েস সহায়ক',
      AssistantLang.hi => 'वॉइस सहायक',
      AssistantLang.en => 'Voice Assistant',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          Material(
            color: AppColors.surface,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onClose,
              customBorder: const CircleBorder(),
              child: Ink(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  boxShadow: AppShadows.low,
                ),
                child: const Icon(Icons.close_rounded,
                    size: 20, color: AppColors.onBackground),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.h2),
                Text(subtitle, style: AppTextStyles.bodySm),
              ],
            ),
          ),
          // Subtle language pill — shows active conversation language
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.accent],
              ),
              borderRadius: AppRadius.pillR,
              boxShadow: AppShadows.tinted(AppColors.primary),
            ),
            child: Text(
              lang.code.toUpperCase(),
              style: AppTextStyles.caption.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationView extends StatelessWidget {
  final List<AssistantTurn> history;
  const _ConversationView({required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // App's own logo instead of the generic AI sparkle —
              // pilot listeners associated the star with Gemini.
              Opacity(
                opacity: 0.65,
                child: Image.asset(
                  'assets/images/ashalogo.png',
                  width: 56, height: 56,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'যা ইচ্ছা জিজ্ঞেস করুন',
                textAlign: TextAlign.center,
                style: AppTextStyles.h3
                    .copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              Text(
                'ক্লিনিক্যাল প্রশ্ন · সাধারণ জ্ঞান · রোগীর কথা',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySm,
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      itemCount: history.length,
      itemBuilder: (_, i) {
        final turn = history[history.length - 1 - i];
        return _MessageBubble(turn: turn);
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final AssistantTurn turn;
  const _MessageBubble({required this.turn});

  @override
  Widget build(BuildContext context) {
    final isUser = turn.role == 'user';
    return Padding(
      padding: EdgeInsets.only(
        top: 4,
        bottom: 4,
        left: isUser ? 60 : 0,
        right: isUser ? 0 : 60,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            // AshaMitra logo as the assistant avatar. White circle so the
            // logo's natural colors read cleanly regardless of what's
            // inside the PNG (a tint mask was breaking on logos with
            // non-trivial alpha). Subtle indigo ring keeps it on-brand.
            Container(
              width: 32,
              height: 32,
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
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppRadius.md),
                  topRight: const Radius.circular(AppRadius.md),
                  bottomLeft: Radius.circular(isUser ? AppRadius.md : 4),
                  bottomRight: Radius.circular(isUser ? 4 : AppRadius.md),
                ),
                boxShadow: AppShadows.low,
              ),
              child: Text(
                turn.text,
                style: AppTextStyles.body.copyWith(
                  color: isUser ? Colors.white : AppColors.onBackground,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SaveAsReportChips extends StatelessWidget {
  final AssistantLang lang;
  final VoidCallback onYes;
  final VoidCallback onNo;
  const _SaveAsReportChips({
    required this.lang,
    required this.onYes,
    required this.onNo,
  });

  @override
  Widget build(BuildContext context) {
    final prompt = switch (lang) {
      AssistantLang.bn => 'এটি কি রিপোর্ট হিসেবে সংরক্ষণ করব?',
      AssistantLang.hi => 'इसे रिपोर्ट के रूप में सहेजना है?',
      AssistantLang.en => 'Save this as a report?',
    };
    final yes = switch (lang) {
      AssistantLang.bn => 'হ্যাঁ, সংরক্ষণ করুন',
      AssistantLang.hi => 'हाँ, सहेजें',
      AssistantLang.en => 'Yes, save',
    };
    final no = switch (lang) {
      AssistantLang.bn => 'না, শুধু জ্ঞানের জন্য',
      AssistantLang.hi => 'नहीं, सिर्फ़ जानने के लिए',
      AssistantLang.en => 'No, just info',
    };
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accent.withValues(alpha: 0.10),
            AppColors.primary.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: AppRadius.lgR,
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bookmark_add_rounded,
                  size: 18, color: AppColors.accent),
              const SizedBox(width: 8),
              Expanded(child: Text(prompt, style: AppTextStyles.labelLg)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onYes,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: Text(yes),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(onPressed: onNo, child: Text(no)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrbDock extends StatelessWidget {
  final OrbState state;
  final String statusLine;
  final bool isThinking;
  final VoidCallback onTap;
  const _OrbDock({
    required this.state,
    required this.statusLine,
    required this.isThinking,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onTap,
            child: VoiceOrb(state: state, size: 130),
          ),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Text(
              statusLine,
              key: ValueKey(statusLine),
              style: AppTextStyles.label.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
