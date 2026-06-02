// ─────────────────────────────────────────────────────────────────────────────
// GroqSttService — server-routed speech-to-text using Groq Whisper.
//
// Why this exists:
//   The Android-native speech_to_text plugin became unreliable on the
//   target hardware (Infinix HiOS). After one successful turn, the
//   audio session was lingering long enough that the next listen()
//   silently no-op'd — orb stuck on "listening", no audio captured.
//   We tried explicit cancel + delay + permission re-request + plugin
//   re-initialization between turns and still hit the failure mode.
//
//   Groq Whisper is a different audio path: we record the worker's
//   utterance as a raw audio file using the `record` plugin, upload
//   it to backend /api/transcribe, and get text back. The recording
//   uses MediaRecorder under the hood — a separate Android API from
//   SpeechRecognizer, not subject to the same session-conflict bug.
//   Whisper has excellent Bengali support and Groq is fast (~500 ms
//   - 2 s typical for a short utterance).
//
// Trade-offs vs the device plugin:
//   + Capture works reliably on Infinix HiOS (different audio path)
//   + Bengali ASR quality is better than the device's Bengali model
//     on most cheap Android phones
//   + Same path on every phone — consistent UX
//   − Network-required. Offline → device-STT fallback (caller handles)
//   − One round-trip per utterance (~500 ms - 2 s) instead of streaming
//   − Costs a tiny bit of Groq quota (free tier covers pilot easily)
//
// Auto-stop heuristic (no plugin pauseFor here, we control timing):
//   1. Start recording.
//   2. Poll amplitude every 100 ms.
//   3. Treat amplitude > [_speechAmplitude] dBFS as "voice present".
//   4. Once voice was detected at least once AND we've then had
//      [_silenceTimeout] of below-threshold readings, stop the
//      recording and upload.
//   5. Hard ceiling at [_maxRecordingDuration] regardless.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../constants/api_constants.dart';

/// Live audio-level reading exposed to the UI so the orb can pulse
/// proportionally to the worker's voice. Same units the speech_to_text
/// plugin used — clipped to 0.0 - 1.0.
typedef AudioLevelCallback = void Function(double level);

/// Fires the moment the recorder stops (after auto-stop OR manual stop)
/// but BEFORE the audio bytes upload to backend /api/transcribe. Used
/// by the UI to transition the orb from "listening" (green) to
/// "processing" (cyan) the moment silence is detected — so the
/// worker isn't staring at a green orb wondering if it's still
/// recording while the upload is in flight (~500 ms - 2 s typical).
typedef ProcessingStartCallback = void Function();

class GroqSttService {
  final AudioRecorder _recorder = AudioRecorder();
  Timer? _ampPoller;
  Timer? _hardCeiling;
  Completer<String?>? _activeCompleter;
  /// Latest path the recorder was writing to — used for upload and
  /// cleanup. Set by [_startRecording] just before the recorder begins.
  String? _activeFilePath;

  /// dBFS threshold above which we consider the worker to be speaking.
  /// Below this is "silence" — used both to suppress false-start uploads
  /// (if the worker tapped the orb and immediately tapped pause) and to
  /// trigger the auto-stop after speech.
  static const double _speechAmplitudeDb = -40.0;

  /// How long of below-threshold amplitude after speech triggers the
  /// auto-stop. Mirrors the speech_to_text plugin's pauseFor concept
  /// but enforced here in client code rather than the native plugin.
  static const Duration _silenceTimeout = Duration(milliseconds: 1800);

  /// Hard ceiling — even if the worker keeps talking, we stop the
  /// recording at this duration to keep the backend round-trip
  /// bounded and avoid uploading multi-megabyte files.
  static const Duration _maxRecordingDuration = Duration(seconds: 45);

  /// Returns true if the underlying recorder is currently running.
  Future<bool> get isRecording => _recorder.isRecording();

  /// Start recording. Returns a Future that completes with the
  /// transcribed text once the auto-stop fires (or null if the
  /// recording or upload failed). [onAudioLevel] is invoked at ~10 Hz
  /// while recording so the UI can show a level meter.
  /// [onProcessingStart] fires once when silence is detected (or the
  /// hard ceiling hits) but BEFORE the audio uploads — so the UI can
  /// flip the orb from "listening" to "processing" immediately.
  Future<String?> startCapture({
    required AudioLevelCallback onAudioLevel,
    ProcessingStartCallback? onProcessingStart,
    String languageCode = 'bn',
  }) async {
    // If a previous capture is still running, cancel it cleanly first.
    await stop();

    if (!await _recorder.hasPermission()) {
      return null;
    }
    final path = await _composeTempPath();
    _activeFilePath = path;
    _activeCompleter = Completer<String?>();

    try {
      // Opus-in-OGG gives us excellent compression (~64 kbps) and
      // Groq Whisper accepts it natively. AAC-in-M4A as fallback for
      // older Android versions that don't expose Opus encoder.
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.opus,
          sampleRate: 16000, // Whisper's native rate
          numChannels: 1,
          bitRate: 64000,
        ),
        path: path,
      );
    } catch (_) {
      // Encoder unsupported on this device — retry with AAC.
      try {
        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            sampleRate: 16000,
            numChannels: 1,
            bitRate: 64000,
          ),
          path: path,
        );
      } catch (e) {
        _activeCompleter?.complete(null);
        return _activeCompleter!.future;
      }
    }

    // Auto-stop machinery.
    DateTime? speechStartedAt;
    DateTime? lastVoiceTick;
    final completer = _activeCompleter!;
    _ampPoller?.cancel();
    _ampPoller = Timer.periodic(const Duration(milliseconds: 100), (t) async {
      if (!await _recorder.isRecording()) {
        t.cancel();
        return;
      }
      final amp = await _recorder.getAmplitude();
      // Normalise to 0..1 for the UI. The plugin's dBFS scale is
      // 0 = full scale, more negative = quieter. Map [-60, 0] → [0, 1].
      final norm = ((amp.current + 60.0) / 60.0).clamp(0.0, 1.0);
      onAudioLevel(norm);
      final voicePresent = amp.current > _speechAmplitudeDb;
      if (voicePresent) {
        speechStartedAt ??= DateTime.now();
        lastVoiceTick = DateTime.now();
      } else if (speechStartedAt != null && lastVoiceTick != null) {
        // We've had speech before. Check if the silence has gone on
        // long enough to trigger auto-stop.
        final silentFor = DateTime.now().difference(lastVoiceTick!);
        if (silentFor >= _silenceTimeout) {
          t.cancel();
          onProcessingStart?.call();
          await _stopAndTranscribe(completer, languageCode);
        }
      }
    });

    // Hard ceiling regardless of speech state.
    _hardCeiling?.cancel();
    _hardCeiling = Timer(_maxRecordingDuration, () async {
      if (!completer.isCompleted) {
        _ampPoller?.cancel();
        onProcessingStart?.call();
        await _stopAndTranscribe(completer, languageCode);
      }
    });

    return completer.future;
  }

  /// Manually stop the recording (worker tapped the orb to commit).
  /// Triggers the upload + completes the active capture's Future.
  Future<void> stop() async {
    _ampPoller?.cancel();
    _hardCeiling?.cancel();
    final c = _activeCompleter;
    if (c != null && !c.isCompleted) {
      await _stopAndTranscribe(c, 'bn');
    }
  }

  /// Cancel without uploading — worker hit pause/cancel during the
  /// capture and doesn't want anything sent. Cleans the temp file.
  Future<void> cancel() async {
    _ampPoller?.cancel();
    _hardCeiling?.cancel();
    try { await _recorder.stop(); } catch (_) {}
    final p = _activeFilePath;
    if (p != null) {
      try { await File(p).delete(); } catch (_) {}
    }
    final c = _activeCompleter;
    if (c != null && !c.isCompleted) c.complete(null);
    _activeCompleter = null;
    _activeFilePath = null;
  }

  Future<void> _stopAndTranscribe(
    Completer<String?> completer,
    String languageCode,
  ) async {
    String? path;
    try {
      path = await _recorder.stop();
    } catch (e) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }
    if (path == null) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }
    String? text;
    try {
      text = await _uploadAndTranscribe(path, languageCode);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[GroqSttService] upload failed: $e');
      }
    }
    // Clean up the temp file either way.
    try { await File(path).delete(); } catch (_) {}
    _activeFilePath = null;
    if (!completer.isCompleted) completer.complete(text);
    _activeCompleter = null;
  }

  Future<String?> _uploadAndTranscribe(String path, String languageCode) async {
    final bytes = await File(path).readAsBytes();
    if (bytes.isEmpty) return null;
    final ext = path.toLowerCase().endsWith('.ogg') ? 'ogg' : 'm4a';
    final mime = ext == 'ogg' ? 'audio/ogg' : 'audio/m4a';
    final url = Uri.parse(
      '${ApiConstants.baseUrl}/transcribe?lang=$languageCode&ext=$ext',
    );
    final resp = await http
        .post(url, headers: {'Content-Type': mime}, body: bytes)
        .timeout(const Duration(seconds: 25));
    if (resp.statusCode != 200) return null;
    final body = resp.body;
    // Backend wraps the text in { success, text } — we extract it.
    // Minimal hand-parse to avoid an extra json dependency here.
    final match = RegExp(r'"text"\s*:\s*"([^"]*)"').firstMatch(body);
    final extracted = match?.group(1)?.trim();
    if (extracted == null || extracted.isEmpty) return null;
    // Unescape the most common JSON-escaped chars Whisper might emit.
    return extracted
        .replaceAll(r'\"', '"')
        .replaceAll(r'\\', r'\')
        .replaceAll(r'\n', '\n');
  }

  Future<String> _composeTempPath() async {
    final dir = await getTemporaryDirectory();
    final name = 'asha_utterance_${DateTime.now().millisecondsSinceEpoch}';
    // Default extension — actual encoder may produce ogg or m4a.
    return '${dir.path}/$name.m4a';
  }

  Future<void> dispose() async {
    await cancel();
    await _recorder.dispose();
  }
}
