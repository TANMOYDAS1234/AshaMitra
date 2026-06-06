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
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../../app/routes.dart';
import '../../../../core/services/language_controller.dart';
import '../../../../core/services/tts_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/services/groq_stt_service.dart';
import '../../../../shared/widgets/voice_orb.dart';
import '../../services/assistant_chat_service.dart';
import '../../services/intent_classifier.dart';
import '../../services/intent_dispatcher.dart';
import '../../services/voice_triage_engine.dart';

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  // ── Services ───────────────────────────────────────────────────────────
  final _chat = AssistantChatService();
  // Device STT — the PRIMARY capture path. On-device Bengali/Hindi
  // recognition is noticeably more accurate for our workers than Groq
  // Whisper was, so we drive this directly. The historical "stuck on
  // listening" failures on Infinix HiOS were NOT an audio-session race —
  // they were (1) a missing android.speech.RecognitionService <queries>
  // entry that left the recognizer invisible under Android 11+ package
  // visibility, and (2) an over-eager error handler that tore the plugin
  // down on every benign error_no_match. Both are fixed now (see
  // AndroidManifest.xml + _initStt onError below).
  final _stt = SpeechToText();
  // Server-routed STT via Groq Whisper. Kept only as a LAST-RESORT
  // fallback for the rare device with no on-device recognizer at all
  // (no Google app / unsupported OEM). Whisper's accuracy was worse for
  // our workers, so we never prefer it when device STT is available.
  final _groqStt = GroqSttService();
  // True only when the device recognizer failed to initialise (no
  // RecognitionService on this phone). Set in _initAll from _sttReady.
  // Default false → prefer device STT; flip to Groq only when the
  // device recognizer is genuinely unavailable.
  bool _useGroqStt = false;
  final _tts = TtsService();
  // Rule-based intent classifier runs BEFORE the LLM on every user
  // utterance. Common app actions ("open patients", "call ambulance",
  // "start triage") match here and execute instantly — no network
  // round-trip. Anything that doesn't match falls through to Gemini.
  // This is the offline-emergency layer: actions work without signal.
  final _intentClassifier = RuleBasedIntentClassifier();

  // Voice-driven triage engine — Tier 2. When the worker says "start
  // checkup" (or similar) the assistant takes over the triage
  // conversation itself instead of dropping the worker on the visual
  // triage screen. Same RuleExecutor + same questions as that screen;
  // the only thing this engine adds is iteration state + a spoken-
  // answer → option mapping. The visual triage screen is still
  // available as a separate entry point (home tile, bottom nav).
  final _triageEngine = VoiceTriageEngine();
  // True while we've asked "which case?" and are waiting for the worker
  // to reply with newborn / child / pregnancy. One-turn state — flipped
  // off as soon as we either start a session or give up.
  bool _awaitingCaseChoice = false;

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

  // ── Interaction model ─────────────────────────────────────────────────
  // Hold-to-talk (WhatsApp voice-note style): the mic is ON only while the
  // worker is physically pressing the orb, and the captured speech is sent
  // the moment they release. This removes the always-listening churn —
  // no surprise mic on/off, no premature cut-off mid-sentence, no AI-voice
  // bleeding back into the mic — because the worker, not a silence timer,
  // owns when listening starts and stops. The legacy always-listening
  // auto-restart paths are kept but gated behind `!_holdToTalk` so this is
  // a one-flag switch (and reversible).
  static const bool _holdToTalk = true;
  // When the current press began — used to ignore accidental quick taps
  // (a <300ms press sends nothing) so a stray touch never fires an empty turn.
  DateTime? _holdStartedAt;
  // Monotonic turn counter. Each user turn bumps it; an in-flight reply
  // checks its captured value after the network await and bails if a newer
  // turn has started (i.e. the worker barged in) — so a stale reply never
  // speaks over the new one.
  int _turnSeq = 0;

  // STT self-recovery: track consecutive GENUINE-fault events. Benign
  // events (error_no_match / error_speech_timeout) never count here —
  // they're handled inline in _initStt's onError and reset this to 0.
  // Threshold is 2: a single transient fault (e.g. a one-off recognizer
  // busy) just re-arms via onStatus; only two faults back-to-back mean
  // the plugin is genuinely wedged and warrants a full reinit. The old
  // value of 1 fired a teardown on every benign no-match, which was the
  // bug, not a feature.
  int _consecutiveSttErrors = 0;
  static const _sttErrorThreshold = 2;

  // ── Stuck-listening watchdog ──────────────────────────────────────────
  // OS-level mic revocation (Infinix HiOS / Android privacy manager) can
  // leave STT in `listening` state with zero audio reaching the plugin.
  // The standard onError callback may not fire — the mic just goes dark.
  // We poll: if N seconds elapse while listening with no partial words
  // AND no detectable audio level, we treat the session as stuck and
  // self-recover the plugin.
  Timer? _sttWatchdogTimer;
  DateTime? _lastAudioActivity; // updated on partial transcript OR voice
  bool _showSilentMicBanner = false; // "মাইক চালু আছে কিন্তু কিছু শুনতে পাচ্ছি না"
  // Continuously-updated audio amplitude from speech_to_text's
  // onSoundLevelChange. 0.0 = silent, ~1.0 = loud speech. Drives the
  // pulsing ring around the orb so worker can see voice is landing.
  double _audioLevel = 0.0;

  // Adaptive pauseFor — on Android this maps to the recognizer's
  // "complete silence length": how long it waits in trailing silence
  // before finalizing and returning the result. It's the single biggest
  // knob on "how fast does she reply after I stop talking", so we keep
  // it tight; tap-to-commit covers anyone who wants instant.
  //   - First open with no history → 3000 ms (still room to compose)
  //   - Mid-conversation → 1500 ms (snappy follow-ups / commands)
  // Lowered from 4500/2500 — pilot wanted a quicker turnaround, and the
  // recognizer's own end-of-speech VAD usually fires before this anyway.
  Duration get _adaptivePauseFor =>
      _history.isEmpty ? const Duration(milliseconds: 3000) : const Duration(milliseconds: 1500);

  // ── Conversation self-heal watchdog ───────────────────────────────────
  // The always-listening loop re-arms the mic from a single TTS-onComplete
  // callback (and the empty-result path). If that callback ever fails to
  // fire — a missed audioplayers completion event, an audio-focus hiccup
  // after many TTS↔STT cycles, or a stalled turn — the conversation
  // silently dies: orb idle, mic not listening, worker must tap. This is
  // the safety net: if we SHOULD be listening (auto-listen on; not paused,
  // thinking, or showing the save chip; TTS not playing) but aren't, for
  // ~8s, restart listening. It only ever fires when the normal re-arm
  // didn't, so it can't fight the happy path (which re-arms within ~3.5s).
  Timer? _selfHealTimer;
  int _idleTicks = 0;
  // (No server keep-warm timer needed — the backend runs on an always-on VPS,
  // so there's no cold-start nap to pre-empt.)

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
    // Fire-and-forget cold-start prevention. Renders free-tier sleeps
    // after 15 min idle; the wake-up alone is 15-30 sec. Pinging
    // /health on screen open kicks off the wake before the worker
    // tries to talk. Result: when they say something 5 sec later, the
    // server is usually warm. Negligible bandwidth cost.
    _warmBackend();
    _startSelfHealWatchdog();
  }

  Future<void> _warmBackend() async {
    try {
      await _chat.warmupBackend();
    } catch (_) { /* best-effort, ignore failures */ }
  }

  /// Safety net for the always-listening loop. Polls every 4s: if the
  /// assistant should be listening (auto-listen on; not paused, thinking,
  /// or showing the save chip; TTS silent) but isn't, for two ticks (~8s),
  /// the normal TTS-onComplete re-arm must have been missed — so restart
  /// listening. Guarded by the same conditions as the happy-path re-arm,
  /// so it only fires when the loop genuinely stalled, never during the
  /// normal ~3.5s re-arm window or an intentional pause.
  void _startSelfHealWatchdog() {
    // Only relevant to the always-listening loop. In hold-to-talk the mic
    // is driven entirely by the worker's press, so there's no stalled loop
    // to recover — skip it.
    if (_holdToTalk) return;
    _selfHealTimer?.cancel();
    _idleTicks = 0;
    _selfHealTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) {
        _selfHealTimer?.cancel();
        return;
      }
      final shouldBeListening = _autoListen &&
          !_isPaused &&
          !_isThinking &&
          !_showSaveChip &&
          !_isListening &&
          !_tts.isPlaying;
      if (shouldBeListening) {
        _idleTicks++;
        if (_idleTicks >= 2) {
          _idleTicks = 0;
          _startListening();
        }
      } else {
        _idleTicks = 0;
      }
    });
  }

  Future<void> _initAll() async {
    await _tts.init();
    _wireTtsCallbacks();
    _sttReady = await _initStt();
    // Device STT is the preferred path. Only fall back to Groq Whisper
    // when the on-device recognizer failed to initialise (no Google app
    // / OEM without a RecognitionService). On every normal phone
    // _sttReady is true, so _useGroqStt stays false.
    _useGroqStt = !_sttReady;
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
        final msg = err.errorMsg;
        // `error_no_match` and `error_speech_timeout` are NORMAL in an
        // always-listening loop — the worker simply paused or the
        // recognizer caught nothing this turn. They are NOT failures.
        // The old code treated every error the same and (with threshold
        // 1) tore the whole plugin down on each one; re-initialising
        // mid-loop left the recognizer in a no-op state on the NEXT
        // turn. That self-inflicted churn — not an audio-session race —
        // was the real "mic on but capturing nothing" bug. Here we just
        // reset the fault counter and let the onStatus(done) that always
        // follows (cancelOnError: true) re-arm the mic via
        // _onListenComplete().
        if (msg == 'error_no_match' || msg == 'error_speech_timeout') {
          _consecutiveSttErrors = 0;
          return;
        }
        // Genuine fault (audio / client / busy / network). Only
        // hard-recover after two back-to-back faults, so a single
        // transient hiccup doesn't reinitialise the plugin and stall the
        // next turn. The onStatus(done) re-arms the mic in between.
        _consecutiveSttErrors++;
        if (_consecutiveSttErrors >= _sttErrorThreshold) {
          _recoverStt();
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

  // ── Stuck-listening watchdog ──────────────────────────────────────────
  // Started when STT begins listening, cancelled when audio is detected
  // or the session ends. If the elapsed silent time exceeds the limits,
  // we either show the "can't hear you" banner OR force-recover the
  // plugin. This catches the OS-level mic-revocation case where
  // SpeechRecognizer doesn't fire onError but the mic is denied.
  void _startSttWatchdog() {
    _sttWatchdogTimer?.cancel();
    _lastAudioActivity = DateTime.now();
    _showSilentMicBanner = false;
    // Poll twice per second — cheap, plenty granular for human-visible
    // banner timing.
    _sttWatchdogTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted || !_isListening) {
        _sttWatchdogTimer?.cancel();
        return;
      }
      final silentFor = DateTime.now().difference(_lastAudioActivity ?? DateTime.now());
      // After 4 sec of pure silence, show the "I can't hear you" banner.
      if (!_showSilentMicBanner && silentFor.inSeconds >= 4) {
        setState(() => _showSilentMicBanner = true);
      }
      // After 7 sec of pure silence, assume the OS denied mic access
      // (or the plugin is stuck) and self-recover. Cut from 10 → 7
      // so the worker doesn't sit through nearly a full minute when
      // multiple turns are stuck back-to-back.
      if (silentFor.inSeconds >= 7) {
        _sttWatchdogTimer?.cancel();
        _recoverStt();
      }
    });
  }

  void _stopSttWatchdog() {
    _sttWatchdogTimer?.cancel();
    _sttWatchdogTimer = null;
    if (mounted && _showSilentMicBanner) {
      setState(() => _showSilentMicBanner = false);
    }
  }

  /// Check + re-request microphone permission before starting STT.
  /// Returns true if permission is granted (worker can proceed),
  /// false if denied — in which case we show a dialog that either
  /// (a) re-prompts or (b) deep-links to system Settings if the
  /// worker tapped "Don't ask again" previously.
  ///
  /// HiOS / Android 14 sometimes silently downgrade a granted
  /// permission to "denied" when the user hasn't interacted for a
  /// while or the OS's privacy manager kicks in. Re-checking every
  /// time before listen() catches that.
  Future<bool> _ensureMicPermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) {
      if (!mounted) return false;
      // Worker chose "Don't ask again" at some point. Only way to
      // recover is the system settings screen.
      final go = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(_micDeniedTitle(_activeLang)),
          content: Text(_micDeniedBody(_activeLang)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(_micDeniedCancel(_activeLang)),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(_micDeniedSettings(_activeLang)),
            ),
          ],
        ),
      );
      if (go == true) {
        await openAppSettings();
      }
      return false;
    }
    // status is denied or restricted — fire the runtime prompt.
    final result = await Permission.microphone.request();
    return result.isGranted;
  }

  // Permission-denied dialog copy. Bilingual so the worker who has
  // already switched languages sees their language even at this
  // edge-case prompt.
  String _micDeniedTitle(AssistantLang l) => switch (l) {
        AssistantLang.bn => 'মাইক অনুমতি দরকার',
        AssistantLang.hi => 'माइक की अनुमति चाहिए',
        AssistantLang.en => 'Microphone permission needed',
      };
  String _micDeniedBody(AssistantLang l) => switch (l) {
        AssistantLang.bn =>
          'আপনার কথা শোনার জন্য মাইক অনুমতি দরকার। সেটিংস থেকে চালু করুন।',
        AssistantLang.hi =>
          'आपकी आवाज़ सुनने के लिए माइक की अनुमति चाहिए। सेटिंग्स से चालू करें।',
        AssistantLang.en =>
          'I need microphone access to hear you. Please enable it in Settings.',
      };
  String _micDeniedCancel(AssistantLang l) => switch (l) {
        AssistantLang.bn => 'বাতিল',
        AssistantLang.hi => 'रद्द',
        AssistantLang.en => 'Cancel',
      };
  String _micDeniedSettings(AssistantLang l) => switch (l) {
        AssistantLang.bn => 'সেটিংস খুলুন',
        AssistantLang.hi => 'सेटिंग्स खोलें',
        AssistantLang.en => 'Open Settings',
      };

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
      setState(() {
        _orbState = _isPaused ? OrbState.paused : OrbState.idle;
        // Hold-to-talk: after the reply finishes, just sit idle showing the
        // "hold to talk" hint. The mic stays OFF until the worker presses —
        // no auto-restart, so nothing toggles on its own.
        if (_holdToTalk && !_isPaused) _statusLine = _holdHintStatus(_activeLang);
      });
      // Legacy always-listening auto-restart — gated off in hold-to-talk.
      // Re-arms the mic after every TTS chunk unless the worker paused.
      // The drain wait (isPlaying + 1500ms) kept the AI's own voice from
      // bleeding into the next STT session.
      if (!_holdToTalk && _autoListen && !_isPaused && !_isThinking && !_showSaveChip) {
        () async {
          final deadline = DateTime.now().add(const Duration(seconds: 2));
          while (_tts.isPlaying && DateTime.now().isBefore(deadline)) {
            await Future.delayed(const Duration(milliseconds: 80));
          }
          await Future.delayed(const Duration(milliseconds: 1500));
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
    // TtsService.speak() now strips commas universally, so we no longer
    // need a local _humanize() here. Triage and every other consumer
    // gets the same humanization for free.
    await _tts.speak(greeting, tone: TtsTone.empathy);
  }

  // ── STT control ────────────────────────────────────────────────────────
  Future<void> _startListening() async {
    if (_isListening || _isPaused) return;
    final permResult = await _ensureMicPermission();
    if (!permResult) return;

    setState(() {
      _isListening = true;
      _liveTranscript = '';
      _audioLevel = 0.0;
      _showSilentMicBanner = false;
      _orbState = OrbState.listening;
      _statusLine = _listeningStatus(_activeLang);
    });
    _startSttWatchdog();

    // Groq Whisper fallback — reached ONLY when the device recognizer
    // failed to initialise (_useGroqStt was set from !_sttReady in
    // _initAll). On every normal phone this branch is skipped and we use
    // the more-accurate device STT path below. The service auto-stops on
    // silence and uploads the recording for transcription.
    if (_useGroqStt) {
      final text = await _groqStt.startCapture(
        onAudioLevel: (level) {
          if (!mounted) return;
          if (level > 0.15) {
            _lastAudioActivity = DateTime.now();
            if (_showSilentMicBanner) {
              setState(() => _showSilentMicBanner = false);
            }
          }
          if ((level - _audioLevel).abs() > 0.04) {
            setState(() => _audioLevel = level);
          }
        },
        // Fires the instant silence is detected — gives the orb a
        // visible state change (green → cyan + "শুনলাম, ভাবছি...")
        // so the worker doesn't stare at a still-green orb during
        // the upload + LLM round-trip and assume the system is dead.
        onProcessingStart: () {
          if (!mounted) return;
          _stopSttWatchdog();
          setState(() {
            _isListening = false;
            _audioLevel = 0.0;
            _orbState = OrbState.processing;
            _statusLine = _heardYouStatus(_activeLang);
          });
        },
        languageCode: _activeLang.code,
      );
      if (!mounted) return;
      _stopSttWatchdog();
      setState(() {
        _isListening = false;
        _audioLevel = 0.0;
      });
      if (text != null && text.trim().isNotEmpty) {
        setState(() => _liveTranscript = text.trim());
        _handleUserInput(text.trim());
        return;
      }
      // Empty result from Groq → either silence-only utterance OR
      // network/Groq failure. Re-arm (the empty-input recovery path
      // mirrors the previous device-STT behaviour).
      _onListenComplete();
      return;
    }

    // ── Primary: device speech_to_text plugin ──
    if (!_sttReady) return;
    // Only tear down a prior session if one is genuinely still open. The
    // old code ran an unconditional cancel + 400 ms wait on EVERY turn —
    // that added latency to every utterance and, worse, cancelling an
    // already-idle recognizer could leave it transiently unavailable for
    // the listen() that immediately followed. Now that the real bug (the
    // missing RecognitionService <queries> + the no-match teardown) is
    // fixed, we only guard the genuine "previous session not yet closed"
    // case, with a full reinit as a last resort if cancel doesn't take.
    if (_stt.isListening) {
      try { await _stt.cancel(); } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 300));
      if (_stt.isListening) {
        _sttReady = await _initStt();
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }
    // listenFor 30s — covers long clinical descriptions; the worker can
    // tap-pause if they need more.
    // pauseFor 2.5s — short, command-style replies ("রিপোর্ট দেখাও",
    // "অ্যাম্বুলেন্স ডাকো") otherwise made the worker wait 6 sec of
    // silence before the plugin even finalized. Pilot reported the
    // delay as the worst part of the experience. 2.5s still gives
    // breathing room mid-sentence for the clinical-question path but
    // makes single-command actions feel near-instant.
    //
    // cancelOnError: true — let errors propagate through the onError
    // callback to the self-recovery counter rather than silently
    // swallow them. Silent swallowing was the root cause of the "mic
    // stuck on listening forever, no audio captured" state.
    await _stt.listen(
      listenOptions: SpeechListenOptions(
        localeId: _activeLang.sttLocale,
        // Hold-to-talk: the worker's release ends the turn, so use long
        // windows that effectively disable the silence auto-stop — a pause
        // to think mid-sentence must NOT cut them off. Always-listening
        // mode keeps the adaptive silence threshold for snappy turns.
        listenFor: _holdToTalk
            ? const Duration(seconds: 120)
            : const Duration(seconds: 30),
        pauseFor: _holdToTalk
            ? const Duration(seconds: 120)
            : _adaptivePauseFor,
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: true,
      ),
      onSoundLevelChange: (level) {
        if (!mounted) return;
        // speech_to_text emits dB-ish values in roughly -2 .. 12 range
        // on Android. Normalize to 0..1 for the orb's pulse animation.
        final n = ((level + 2) / 12).clamp(0.0, 1.0);
        // Treat any non-trivial input as audio activity for the
        // watchdog. The 0.15 threshold filters silence-floor noise.
        if (n > 0.15) {
          _lastAudioActivity = DateTime.now();
          if (_showSilentMicBanner) {
            setState(() => _showSilentMicBanner = false);
          }
        }
        if ((n - _audioLevel).abs() > 0.04) {
          setState(() => _audioLevel = n);
        }
      },
      onResult: (r) {
        if (!mounted) return;
        // Any partial result confirms the mic is working — refresh the
        // watchdog and hide the silent-mic banner.
        _lastAudioActivity = DateTime.now();
        setState(() {
          _liveTranscript = r.recognizedWords;
          if (_showSilentMicBanner) _showSilentMicBanner = false;
        });
        if (r.finalResult && _liveTranscript.trim().isNotEmpty) {
          // Successful capture — reset the error counter + stop watchdog.
          _consecutiveSttErrors = 0;
          _stopSttWatchdog();
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
          : (_holdToTalk ? _holdHintStatus(_activeLang) : _idleStatus(_activeLang));
      // Legacy always-listening re-arm on a silent turn — gated off in
      // hold-to-talk (the worker decides when to talk; nothing auto-restarts).
      if (!_holdToTalk && _autoListen && !_isPaused && !_isThinking && !_showSaveChip) {
        () async {
          final deadline = DateTime.now().add(const Duration(seconds: 2));
          while (_tts.isPlaying && DateTime.now().isBefore(deadline)) {
            await Future.delayed(const Duration(milliseconds: 80));
          }
          await Future.delayed(const Duration(milliseconds: 1500));
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

  // ── Main loop: triage flow → rule-match → LLM, then speak reply ────────
  Future<void> _handleUserInput(String input) async {
    HapticFeedback.lightImpact();
    // Stamp this turn. If the worker barges in (holds the orb again) while
    // the reply is being fetched, _turnSeq advances and this turn's reply is
    // dropped after the network await instead of speaking over the new one.
    final myTurn = ++_turnSeq;
    setState(() {
      _history.add(AssistantTurn(role: 'user', text: input));
      _isThinking = true;
      _orbState = OrbState.processing;
      // Worker has seen "শুনলাম, ভাবছি..." from the onProcessingStart
      // hook during the Whisper upload. Now the text has arrived and
      // we're actually calling the LLM — shift to the plain "ভাবছি..."
      // so the worker can see we moved from "got your audio" to
      // "working on a reply". Without this, both stages look the
      // same and a 3 sec total wait reads as one undifferentiated stall.
      _statusLine = _thinkingStatus(_activeLang);
      _liveTranscript = '';
    });

    // ── Step 0a: in-flight voice triage takes priority ──
    // If the engine is mid-session, route every user utterance into it
    // until it finishes. Worker's "cancel" or "stop" exits cleanly.
    if (_triageEngine.isActive) {
      await _continueTriage(input);
      return;
    }

    // ── Step 0b: case selection after worker triggered startTriage ──
    if (_awaitingCaseChoice) {
      await _resolveCaseChoice(input);
      return;
    }

    // ── Step 1: try rule-based intent classifier first ──
    // Common app actions (call ambulance, open patients, etc.) bypass
    // the LLM entirely — instant response, works offline. If the
    // classifier finds a confident match, we dispatch the action and
    // speak a short confirmation; conversation history records the
    // confirmation so the LLM has context if the worker keeps talking.
    final classified = _intentClassifier.classify(input, _activeLang);
    if (classified.isHandled && classified.confidence >= 0.45) {
      // Special-case startTriage: don't dispatch to the visual screen.
      // Begin the inline voice-driven triage flow here instead.
      if (classified.intent == AssistantIntent.startTriage) {
        await _beginTriagePrompt();
        return;
      }
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
          await _tts.speak(
            result.spokenConfirmation,
            tone: TtsTone.normal,
          );
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

    // Barge-in guard: the worker started a new turn while this reply was in
    // flight — drop it silently so it can't speak over the newer turn.
    if (!mounted || myTurn != _turnSeq) return;

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
      // beat behind. The backend already de-commas the spoken-text
      // path (see server.js), so prefetchedAudio is humanized at
      // source. Device TTS path goes through _humanize() locally.
      if (response.prefetchedAudio != null &&
          response.prefetchedAudio!.isNotEmpty) {
        await _tts.speakBytes(
          response.prefetchedAudio!,
          text: response.text,
          tone: TtsTone.normal,
        );
      } else {
        // Stream: speak the first sentence as soon as the response
        // arrives, queue the remaining sentences. For multi-sentence
        // replies this cuts perceived latency by ~60% — worker hears
        // "ঠিক আছে।" within ~1s of finishing speaking, instead of
        // waiting for the whole 2-3 sentence reply to render then
        // play. Single-sentence replies behave identically to before.
        await _streamSpeak(response.text);
      }
    }
  }

  /// Split [text] on sentence boundaries (। / . / ? / !) and speak
  /// each chunk back-to-back. The first call returns as soon as the
  /// first chunk starts playing — but we still await the chain so the
  /// caller's TTS-onComplete logic fires after the LAST chunk, which
  /// is what the auto-listen restart needs.
  Future<void> _streamSpeak(String text) async {
    final chunks = _splitSentences(text);
    if (chunks.isEmpty) return;
    for (final chunk in chunks) {
      if (!mounted) return;
      if (_isPaused) return; // worker hit pause mid-stream
      await _tts.speak(chunk, tone: TtsTone.normal);
    }
  }

  /// Sentence splitter that preserves the terminator on each chunk so
  /// prosody is correct (the engine pauses appropriately after `?`).
  /// Falls back to the whole string if no sentence boundary is found.
  static List<String> _splitSentences(String text) {
    final s = text.trim();
    if (s.isEmpty) return const [];
    // Match runs of non-terminator chars + an optional terminator.
    final re = RegExp(r'[^।.!?]+[।.!?]?', multiLine: true, dotAll: true);
    final out = <String>[];
    for (final m in re.allMatches(s)) {
      final piece = m.group(0)?.trim();
      if (piece != null && piece.isNotEmpty) out.add(piece);
    }
    return out.isEmpty ? [s] : out;
  }

  // ── Voice-driven triage (Tier 2) ───────────────────────────────────────
  //
  // Flow:
  //   1. Worker says "start checkup" / "শুরু করো ট্রিয়াজ" → intent
  //      classifier returns startTriage → _beginTriagePrompt() asks
  //      "which case?".
  //   2. Worker says "newborn" / "শিশু" / "pregnancy" → _resolveCaseChoice
  //      starts the engine on that case and speaks Q1.
  //   3. Each subsequent utterance → _continueTriage() → engine
  //      submitAnswer() → next question OR outcome.
  //   4. Engine finishes (all questions or hard-stop) → speak the
  //      band-specific summary, surface "save as report?" chips.
  //
  // The visual triage screen is still untouched — it's a separate
  // entry point for workers who prefer the structured Q&A view.

  /// Step 1: prompt the worker for case type.
  Future<void> _beginTriagePrompt() async {
    const ask = 'কোন কেস? নবজাতক, শিশু, নাকি গর্ভাবস্থা?';
    setState(() {
      _awaitingCaseChoice = true;
      _isThinking = false;
      _history.add(const AssistantTurn(role: 'assistant', text: ask));
      _statusLine = '';
    });
    try {
      await _tts.stop();
    } catch (_) {}
    await _tts.speak(ask, tone: TtsTone.empathy);
  }

  /// Step 2: map the worker's case-choice utterance to a caseId and
  /// start the engine. Falls back to repeating the prompt if we can't
  /// confidently identify which case they meant.
  Future<void> _resolveCaseChoice(String input) async {
    final lower = input.toLowerCase();
    String? caseId;
    if (lower.contains('নবজাতক') ||
        lower.contains('newborn') ||
        lower.contains('জন্ম') ||
        lower.contains('সদ্যজাত')) {
      caseId = 'newborn';
    } else if (lower.contains('শিশু') ||
        lower.contains('child') ||
        lower.contains('বাচ্চা')) {
      caseId = 'child';
    } else if (lower.contains('গর্ভ') ||
        lower.contains('pregnan') ||
        lower.contains('প্রেগন') ||
        lower.contains('মা')) {
      caseId = 'pregnancy';
    }

    if (caseId == null) {
      const retry =
          'বুঝতে পারলাম না। নবজাতক, শিশু, অথবা গর্ভাবস্থা — কোনটি বলুন।';
      setState(() {
        _isThinking = false;
        _history.add(const AssistantTurn(role: 'assistant', text: retry));
      });
      await _tts.speak(retry, tone: TtsTone.normal);
      return;
    }

    final firstQ = await _triageEngine.start(caseId);
    setState(() {
      _awaitingCaseChoice = false;
      _isThinking = false;
    });
    if (firstQ == null) {
      const err =
          'এই কেসের প্রশ্ন লোড করা গেল না। দয়া করে ট্রিয়াজ স্ক্রিন ব্যবহার করুন।';
      setState(() =>
          _history.add(const AssistantTurn(role: 'assistant', text: err)));
      await _tts.speak(err, tone: TtsTone.normal);
      return;
    }
    await _speakQuestion(firstQ.text);
  }

  /// Step 3: route worker's answer into the engine and either ask the
  /// next question or speak the final outcome.
  Future<void> _continueTriage(String input) async {
    // "Cancel" / "stop" exits the flow cleanly without producing an
    // outcome — worker may want to escape if they triggered triage by
    // mistake. (Tap-to-pause works too but voice exit is faster.)
    final lower = input.toLowerCase();
    if (lower.contains('বাতিল') ||
        lower.contains('cancel') ||
        lower.contains('থামাও') ||
        lower.contains('stop')) {
      _triageEngine.cancel();
      const msg = 'ট্রিয়াজ বাতিল করা হল।';
      setState(() {
        _isThinking = false;
        _history.add(const AssistantTurn(role: 'assistant', text: msg));
      });
      await _tts.speak(msg, tone: TtsTone.normal);
      return;
    }

    final priorQ = _triageEngine.currentQuestion();
    final next = await _triageEngine.submitAnswer(input);

    // Same question returned = answer couldn't be mapped, re-ask.
    if (next != null && priorQ != null && next.id == priorQ.id) {
      const retry = 'ক্ষমা করবেন, "হ্যাঁ" বা "না" বলুন।';
      setState(() {
        _isThinking = false;
        _history.add(const AssistantTurn(role: 'assistant', text: retry));
      });
      await _tts.speak(retry, tone: TtsTone.normal);
      return;
    }

    if (next != null) {
      setState(() => _isThinking = false);
      await _speakQuestion(next.text);
      return;
    }

    // No next question → outcome is ready.
    final outcome = _triageEngine.outcome;
    if (outcome == null) {
      _triageEngine.cancel();
      setState(() => _isThinking = false);
      return;
    }
    setState(() {
      _isThinking = false;
      _history.add(AssistantTurn(
        role: 'assistant',
        text: outcome.spokenSummary +
            (outcome.action.isNotEmpty ? '\n\n${outcome.action}' : ''),
      ));
      // Offer save — same chip the LLM-driven save flow uses.
      _showSaveChip = true;
    });
    await _tts.speak(
      outcome.spokenSummary,
      tone: outcome.band == 'RED' ? TtsTone.urgent : TtsTone.normal,
    );
  }

  /// Shared: add the question to history + speak it. Centralized so
  /// the same code runs for the first question and every follow-up.
  /// Prefixes a small "n of N" cue in the displayed text (NOT spoken)
  /// so the worker can see progress through the triage without it
  /// cluttering the audio.
  Future<void> _speakQuestion(String questionText) async {
    final n = _triageEngine.currentQuestionNumber;
    final total = _triageEngine.totalQuestions;
    final displayed = total > 0 ? '[$n / $total]  $questionText' : questionText;
    setState(() {
      _history.add(AssistantTurn(role: 'assistant', text: displayed));
    });
    try {
      await _tts.stop();
    } catch (_) {}
    // Spoken text excludes the progress bracket — workers don't want
    // to hear "one of eight" before every question, just see it.
    await _tts.speak(questionText, tone: TtsTone.question);
  }

  // ── Orb tap behaviour ───────────────────────────────────────────────────
  // Paused      → resume (start listening)
  // Listening   → COMMIT current recording immediately (don't wait for
  //               silence detection — worker is signalling "I'm done,
  //               send it now"). Single tap = faster turn.
  // Speaking    → pause (stop TTS, stay quiet)
  // Thinking    → pause (cancel pending re-arm)
  // Idle        → start listening
  //
  // Tap-to-commit is the biggest perceived-speed win for chat-style
  // dialogue: instead of waiting 1.2 sec of silence to confirm a turn,
  // the worker just taps and the upload starts. Long-press still
  // pauses if the worker wants the older "tap = pause" behaviour.
  Future<void> _onOrbTap() async {
    if (_isPaused) {
      setState(() {
        _isPaused = false;
        _orbState = OrbState.idle;
        _statusLine = _idleStatus(_activeLang);
      });
      _startListening();
      return;
    }
    if (_isListening && _useGroqStt) {
      // Force-commit the in-flight recording.
      await _groqStt.commit(
        languageCode: _activeLang.code,
        onProcessingStart: () {
          if (!mounted) return;
          _stopSttWatchdog();
          setState(() {
            _isListening = false;
            _audioLevel = 0.0;
            _orbState = OrbState.processing;
            _statusLine = _heardYouStatus(_activeLang);
          });
        },
      );
      return;
    }
    if (_isListening && _sttReady) {
      // Tap-to-commit on the device STT path: stop capturing now and let
      // the recognizer finalise the current partial instead of waiting
      // out the pauseFor silence window. The resulting final onResult /
      // onStatus(done) flows into _onListenComplete() as usual. Flip the
      // orb to processing immediately so the tap feels responsive.
      _stopSttWatchdog();
      setState(() {
        _audioLevel = 0.0;
        _orbState = OrbState.processing;
        _statusLine = _heardYouStatus(_activeLang);
      });
      try { await _stt.stop(); } catch (_) {}
      return;
    }
    await _pauseAssistant();
  }

  Future<void> _onOrbLongPress() async {
    // Long-press = explicit pause from any state. Worker uses this
    // when they want the privacy / mic-off mode rather than a fast
    // commit. Avoids accidentally pausing when they meant to commit.
    await _pauseAssistant();
  }

  Future<void> _pauseAssistant() async {
    try {
      if (_isListening) {
        await _groqStt.cancel();
        await _stt.cancel();
      }
    } catch (_) {}
    try {
      await _tts.stop();
    } catch (_) {}
    _coldStartHintTimer?.cancel();
    _stopSttWatchdog();
    if (!mounted) return;
    setState(() {
      _isPaused = true;
      _isListening = false;
      _liveTranscript = '';
      _audioLevel = 0.0;
      _orbState = OrbState.paused;
      _statusLine = _pausedStatus(_activeLang);
    });
  }

  // ── Hold-to-talk handlers ─────────────────────────────────────────────
  // Press the orb → mic on; release → send. The worker owns the mic, so
  // nothing toggles on its own. Pressing also barges in: it stops any reply
  // in flight (TTS + pending LLM) and grabs the mic immediately, so the
  // worker is never stuck waiting for the assistant to finish.
  Future<void> _onHoldStart() async {
    if (!_holdToTalk || _isListening) return;
    _coldStartHintTimer?.cancel();
    try {
      await _tts.stop();
    } catch (_) {}
    // Supersede any in-flight reply so it can't speak over the new turn
    // (the stale reply is dropped by the _turnSeq guard in _handleUserInput).
    if (mounted && (_isThinking || _showSaveChip)) {
      setState(() {
        _isThinking = false;
        _showSaveChip = false;
      });
    }
    _holdStartedAt = DateTime.now();
    await _startListening();
  }

  Future<void> _onHoldEnd() async {
    if (!_holdToTalk) return;
    final start = _holdStartedAt;
    _holdStartedAt = null;
    if (!_isListening) return;
    final heldMs =
        start == null ? 0 : DateTime.now().difference(start).inMilliseconds;
    _stopSttWatchdog();
    // Ignore an accidental quick tap — never fire an empty turn.
    if (heldMs < 300) {
      try {
        await _groqStt.cancel();
      } catch (_) {}
      try {
        await _stt.cancel();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _isListening = false;
        _audioLevel = 0.0;
        _orbState = OrbState.idle;
        _statusLine = _holdHintStatus(_activeLang);
      });
      return;
    }
    // Commit what was captured → process → reply.
    if (mounted) {
      setState(() {
        _audioLevel = 0.0;
        _orbState = OrbState.processing;
        _statusLine = _heardYouStatus(_activeLang);
      });
    }
    if (_useGroqStt) {
      await _groqStt.commit(
        languageCode: _activeLang.code,
        onProcessingStart: () {
          if (!mounted) return;
          setState(() {
            _isListening = false;
            _audioLevel = 0.0;
            _orbState = OrbState.processing;
            _statusLine = _heardYouStatus(_activeLang);
          });
        },
      );
    } else {
      // Device STT: drive the result DIRECTLY instead of relying solely on the
      // recognizer's onStatus(done) callback — on some Android builds that
      // event doesn't fire after stop(), which left the orb stuck on
      // "ভাবছি…" forever (the captured answer was never processed). Set
      // _isListening=false FIRST so the onStatus handler (guarded on
      // _isListening) can't ALSO complete the turn (no double-processing),
      // then finalize and complete here. A short settle lets the final
      // partial land into _liveTranscript before we read it.
      if (mounted) setState(() => _isListening = false);
      try {
        await _stt.stop();
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      _onListenComplete();
    }
  }

  void _resetToIdle() {
    _stopSttWatchdog();
    setState(() {
      _isListening = false;
      _isThinking = false;
      _audioLevel = 0.0;
      _orbState = _isPaused ? OrbState.paused : OrbState.idle;
      _statusLine = _isPaused
          ? _pausedStatus(_activeLang)
          : _idleStatus(_activeLang);
    });
  }

  /// Cancel an in-flight LLM call. The HTTP request itself can't be
  /// aborted cleanly (the response will arrive eventually) but flipping
  /// _isThinking off + clearing the cold-start timer + stopping any
  /// queued TTS means the worker gets the orb back immediately. The
  /// late reply, if any, gets swallowed by the mounted-check in
  /// _handleUserInput.
  void _cancelThinking() {
    _coldStartHintTimer?.cancel();
    try {
      _tts.stop();
    } catch (_) {}
    setState(() {
      _isThinking = false;
      _orbState = OrbState.idle;
      _statusLine = _idleStatus(_activeLang);
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
    _sttWatchdogTimer?.cancel();
    _selfHealTimer?.cancel();
    _tts.stop();
    _stt.stop();
    _groqStt.dispose();
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
              // ── Silent-mic banner ───────────────────────────────────
              // Surfaces after 6 sec of no audio while listening — tells
              // the worker the assistant is on but isn't hearing them
              // (commonly an OS-level mic revocation on Infinix HiOS).
              if (_showSilentMicBanner) _SilentMicBanner(lang: _activeLang),
              // ── Cancel button during processing ─────────────────────
              // Visible only while the LLM call is in flight. Gives the
              // worker an escape hatch when the network is slow and
              // they don't want to wait another 5-10 sec for whatever
              // Gemini might say. Tap cancels timer + resets the orb.
              if (_isThinking) _CancelProcessingButton(
                lang: _activeLang,
                onCancel: _cancelThinking,
              ),
              _OrbDock(
                state: _orbState,
                statusLine: _statusLine.isEmpty
                    ? (_holdToTalk
                        ? _holdHintStatus(_activeLang)
                        : _idleStatus(_activeLang))
                    : _statusLine,
                isThinking: _isThinking,
                holdToTalk: _holdToTalk,
                onHoldStart: _onHoldStart,
                onHoldEnd: _onHoldEnd,
                onLongPress: _onOrbLongPress,
                audioLevel: _audioLevel,
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
        AssistantLang.bn => 'শুনছি — বলুন · ট্যাপ করে পাঠান',
        AssistantLang.hi => 'सुन रही हूँ — बोलें · टैप करके भेजें',
        AssistantLang.en => 'Listening — tap to send',
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
  /// Hold-to-talk idle hint: press and hold to speak, release to send.
  String _holdHintStatus(AssistantLang l) => switch (l) {
        AssistantLang.bn => 'ধরে রেখে বলুন · ছেড়ে দিলে পাঠাবে',
        AssistantLang.hi => 'दबाकर बोलें · छोड़ने पर भेजेगा',
        AssistantLang.en => 'Hold to talk · release to send',
      };
  String _pausedStatus(AssistantLang l) => switch (l) {
        AssistantLang.bn => 'মাইক বন্ধ — চালু করতে ট্যাপ করুন',
        AssistantLang.hi => 'माइक बंद — चालू करने के लिए टैप करें',
        AssistantLang.en => 'Mic off — tap to start',
      };
  /// Shown the instant Whisper auto-stop fires — between "worker
  /// stopped speaking" and "transcription text returns". Without this
  /// status the worker would see a still-green orb during the upload
  /// + LLM round-trip and think the system was dead.
  String _heardYouStatus(AssistantLang l) => switch (l) {
        AssistantLang.bn => 'শুনলাম, ভাবছি...',
        AssistantLang.hi => 'सुन लिया, सोच रही हूँ...',
        AssistantLang.en => 'Got it, thinking...',
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
  /// 0..1 normalised audio level from speech_to_text. Drives the
  /// pulsing ring around the orb so the worker sees their voice
  /// is landing in real time — a quiet ring means the mic is dead
  /// even if the orb says "listening".
  final double audioLevel;
  final VoidCallback onTap;
  /// Long-press = explicit pause. Kept separate from [onTap] because
  /// tap during listening force-commits the recording (speed win) —
  /// workers who want the pause behaviour signal it with a long-press
  /// instead, so they don't accidentally pause mid-thought.
  final VoidCallback onLongPress;
  /// When true, the orb is a press-and-hold control (mic on while pressed,
  /// send on release) instead of tap/long-press. [onTap]/[onLongPress] are
  /// then unused but kept so the always-listening mode is a one-flag flip.
  final bool holdToTalk;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;
  const _OrbDock({
    required this.state,
    required this.statusLine,
    required this.isThinking,
    required this.audioLevel,
    required this.onTap,
    required this.onLongPress,
    required this.holdToTalk,
    required this.onHoldStart,
    required this.onHoldEnd,
  });

  /// Hold-to-talk → raw pointer Listener (press = mic on, release = send),
  /// with no long-press delay. Always-listening → the old tap/long-press
  /// GestureDetector. behavior:opaque so the whole orb area is pressable.
  Widget _gestureWrap(Widget child) {
    if (holdToTalk) {
      return Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => onHoldStart(),
        onPointerUp: (_) => onHoldEnd(),
        onPointerCancel: (_) => onHoldEnd(),
        child: child,
      );
    }
    return GestureDetector(onTap: onTap, onLongPress: onLongPress, child: child);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _gestureWrap(
            Stack(
              alignment: Alignment.center,
              children: [
                // Audio-level halo — pulses outward in proportion to
                // current voice loudness. Only visible while listening
                // (state == listening). Scale: 1.0 at silence → ~1.45
                // at full speech. Subtle so it complements the orb's
                // existing breathing animation rather than fighting it.
                if (state == OrbState.listening)
                  AnimatedScale(
                    duration: const Duration(milliseconds: 90),
                    scale: 1.0 + audioLevel * 0.45,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF22C55E).withValues(
                          alpha: 0.10 + audioLevel * 0.30,
                        ),
                      ),
                    ),
                  ),
                VoiceOrb(state: state, size: 130),
              ],
            ),
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

/// Cancel-during-processing pill. Visible only when the LLM call is
/// in flight. Gives the worker a clear escape hatch when Gemini /
/// Render is slow — instead of staring at "ভাবছি..." for 15 seconds,
/// they tap once and the orb is back to listening/idle. The actual
/// HTTP request keeps going in the background but its result is
/// ignored on arrival.
class _CancelProcessingButton extends StatelessWidget {
  final AssistantLang lang;
  final VoidCallback onCancel;
  const _CancelProcessingButton({required this.lang, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final label = switch (lang) {
      AssistantLang.bn => 'বাতিল করুন',
      AssistantLang.hi => 'रद्द करें',
      AssistantLang.en => 'Cancel',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Align(
        alignment: Alignment.center,
        child: Material(
          color: AppColors.surface,
          borderRadius: AppRadius.pillR,
          child: InkWell(
            onTap: onCancel,
            borderRadius: AppRadius.pillR,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: AppRadius.pillR,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "I can't hear you" banner — surfaces 6 sec into a listening session
/// with no detectable audio. Tells the worker the assistant is on but
/// not capturing, and points them at the tap-to-restart escape hatch.
/// On Infinix HiOS this often means the OS has revoked mic access mid-
/// session even though our app-level permission says granted.
class _SilentMicBanner extends StatelessWidget {
  final AssistantLang lang;
  const _SilentMicBanner({required this.lang});

  @override
  Widget build(BuildContext context) {
    final text = switch (lang) {
      AssistantLang.bn =>
        'মাইক চালু আছে কিন্তু কিছু শুনতে পাচ্ছি না। অর্বে আবার ট্যাপ করুন।',
      AssistantLang.hi =>
        'माइक चालू है पर कुछ सुनाई नहीं दे रहा। ओर्ब पर फिर से टैप करें।',
      AssistantLang.en =>
        "Mic is on but I'm not hearing you. Tap the orb to retry.",
    };
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: AppRadius.mdR,
        border: Border.all(color: const Color(0xFFD97706)),
      ),
      child: Row(
        children: [
          const Icon(Icons.mic_off_rounded, size: 18, color: Color(0xFFD97706)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodySm.copyWith(
                color: const Color(0xFF92400E),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
