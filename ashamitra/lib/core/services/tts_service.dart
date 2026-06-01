import 'package:get/get.dart';
import 'vapi_tts_service.dart';

/// TTS tone profiles — each maps to a different emotional register.
/// The backend (server.js) maps these to Google Cloud speaking-rate values
/// when synthesizing Bengali audio through Chirp3-HD-Kore. The Flutter side
/// just passes the tone name through to /api/tts.
enum TtsTone {
  normal,    // routine questions — calm, clear
  empathy,   // acknowledging patient situation — warm, slightly slower
  urgent,    // YELLOW band — alert but not panic
  emergency, // RED band — fast, high pitch, commanding
  positive,  // GREEN band / reassurance — warm, slightly upbeat
  question,  // asking a clinical question — clear, slightly slower
}

/// Thin facade over [VapiTtsService] that exposes tone-aware speak methods.
///
/// One voice everywhere: Google Cloud Chirp3-HD-Kore (mature authoritative
/// female). The previous device-TTS fallback path was removed because it
/// used Android's system Bengali voice — also female, but clearly different
/// from Kore. Pilot testers reported it as "two different voices" and
/// found the inconsistency confusing.
///
/// Sources VapiTtsService tries in order for every speak call:
///   1. On-disk cache (instant after first play)
///   2. APK-bundled asset (instant for ~105 critical phrases shipped with
///      the app — emergency callouts, common questions, ack fillers)
///   3. Backend /api/tts → Google Cloud (~1-2 sec network round-trip)
///
/// If all three fail (offline + uncached + not bundled), the call returns
/// silently — no fallback voice. The on-screen text is always rendered
/// regardless, so workers never miss the question itself, just the audio
/// reinforcement of it in rare offline cases.
class TtsService {
  static final TtsService _instance = TtsService._();
  factory TtsService() => _instance;
  TtsService._();

  final VapiTtsService _vapiTts = VapiTtsService();

  Function()? onStart;
  Function()? onComplete;
  Function()? onError;

  /// `true` when the last [speak] attempt produced audio (cache / bundle /
  /// network all worked). `false` when audio could not be played at all
  /// (offline + uncached + not bundled).
  ///
  /// Screens can listen with `Obx(() => Icon(_tts.audioReady.value ? ... ))`
  /// to show a small "audio offline" indicator next to the rendered text so
  /// the worker isn't surprised by silence when they expected to hear Kore.
  final RxBool audioReady = true.obs;

  /// Wires the VapiTtsService callbacks. Safe to call multiple times; only
  /// the first call performs the wiring, subsequent calls re-attach the
  /// handlers (useful when the parent widget rebuilds).
  Future<void> init() async {
    _vapiTts.onStart    = () => onStart?.call();
    _vapiTts.onComplete = () => onComplete?.call();
    _vapiTts.onError    = () => onError?.call();
  }

  /// Speaks [text] in the given [tone]. Returns `true` if audio actually
  /// played (cache hit, bundled asset, or successful network fetch), `false`
  /// if all three sources failed (offline + uncached + not bundled).
  ///
  /// Callers can use the return value to show a small "audio offline" icon
  /// next to the rendered text so the worker isn't surprised by silence.
  Future<bool> speak(String text, {TtsTone tone = TtsTone.normal}) async {
    if (text.trim().isEmpty) return false;
    final played = await _vapiTts.speak(_humanize(text), tone: tone.name);
    audioReady.value = played;
    return played;
  }

  /// Strip commas before TTS. The voice engine (both Google Cloud and
  /// device TTS) inserts a noticeable beat at every comma, which turns
  /// short phrases like "নমস্কার দিদি, আমি আশামিত্র" into a phone-tree
  /// cadence instead of a conversational one. Removing commas (but
  /// keeping periods / Bengali daanda as natural sentence boundaries)
  /// lets the engine derive prosody from sentence structure alone.
  ///
  /// Applied to every speech path that goes through this service —
  /// triage prompts, assistant replies, emergency callouts, all of it —
  /// so the "robotic didi pause" is fixed app-wide, not just in the
  /// assistant screen. The backend's ttsToSsml() does the same strip
  /// server-side; doing it here too means device-TTS paths and any
  /// future direct-device fallback also stay humanized.
  ///
  /// Bundled-MP3 implication: existing assets/voices/*.mp3 were
  /// generated with comma-containing keys (md5 of original text +
  /// voice + tone). After this change, lookups use the comma-less
  /// text so the bundled-asset cache may miss until the bundle is
  /// regenerated. The disk cache rebuilds automatically on first
  /// online use; pure-offline first-launch may briefly fall back to
  /// "audio offline" for a few phrases until that happens.
  String _humanize(String text) {
    if (text.isEmpty) return text;
    return text
        .replaceAll(',', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Convenience: speak with tone auto-derived from a clinical risk level.
  Future<bool> speakWithRisk(String text, String riskLevel) =>
      speak(text, tone: _toneFromRisk(riskLevel));

  /// Emergency callout — same Kore voice, just the 'emergency' tone profile
  /// (faster speaking rate). 5-second timeout so a network hang doesn't
  /// keep a worker waiting at the most stressful moment. Returns whether
  /// audio actually played.
  Future<bool> speakEmergency(String text) async {
    if (text.trim().isEmpty) return false;
    final played = await _vapiTts.speak(_humanize(text), tone: TtsTone.emergency.name)
        .timeout(const Duration(seconds: 5), onTimeout: () => false);
    audioReady.value = played;
    return played;
  }

  Future<bool> speakQuestion(String text) => speak(text, tone: TtsTone.question);
  Future<bool> speakPositive(String text) => speak(text, tone: TtsTone.positive);
  Future<bool> speakEmpathy(String text)  => speak(text, tone: TtsTone.empathy);

  /// Plays [audioBytes] (an MP3 the combined /chat-with-voice endpoint
  /// returned alongside the text) instead of issuing a fresh /tts call.
  /// The bytes are also written to the on-device cache under the same key
  /// as [speak] would use, so the next time the same phrase is needed it's
  /// a pure cache hit. Returns whether audio actually played.
  Future<bool> speakBytes(
    List<int> audioBytes, {
    required String text,
    TtsTone tone = TtsTone.normal,
  }) async {
    if (audioBytes.isEmpty || text.trim().isEmpty) return false;
    // Bytes are already humanized server-side (server.js strips commas
    // in ttsToSsml). But the cache key here is hashed from [text], so
    // pass the humanized variant so the cached MP3 lookup in subsequent
    // speak() calls — which also humanize — hits the same key.
    final played = await _vapiTts.speakBytes(
      audioBytes,
      text: _humanize(text),
      tone: tone.name,
    );
    audioReady.value = played;
    return played;
  }

  static TtsTone _toneFromRisk(String risk) => switch (risk.toLowerCase()) {
        'emergency' => TtsTone.emergency,
        'high'      => TtsTone.emergency,
        'medium'    => TtsTone.urgent,
        'low'       => TtsTone.normal,
        'safe'      => TtsTone.positive,
        _           => TtsTone.normal,
      };

  Future<void> stop() => _vapiTts.stop();

  /// True while the underlying AudioPlayer is actively rendering audio.
  /// Use this to gate STT auto-restart — opening the mic while TTS is
  /// still coming out of the speaker causes the AI's own voice to be
  /// captured as "worker input" (a feedback loop).
  bool get isPlaying => _vapiTts.isPlaying;
}
