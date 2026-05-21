import 'package:flutter_tts/flutter_tts.dart';

/// Shared TTS service — single tuned instance used across all screens.
/// Splits text on Bengali/English punctuation for natural human-like pauses.
class TtsService {
  static final TtsService _instance = TtsService._();
  factory TtsService() => _instance;
  TtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  Function()? onStart;
  Function()? onComplete;
  Function()? onError;

  Future<void> init() async {
    if (_initialized) {
      // Re-attach handlers (new screen may have set new callbacks)
      _attachHandlers();
      return;
    }
    await _tts.setEngine('com.google.android.tts');
    await _tts.setLanguage('bn-IN');
    await _tts.setSpeechRate(0.42);   // slower = more natural for Bengali
    await _tts.setPitch(1.0);         // neutral pitch sounds most human
    await _tts.setVolume(1.0);
    await _tts.awaitSpeakCompletion(true);
    _attachHandlers();
    _initialized = true;
  }

  void _attachHandlers() {
    _tts.setStartHandler(() => onStart?.call());
    _tts.setCompletionHandler(() => onComplete?.call());
    _tts.setErrorHandler((_) => onError?.call());
  }

  /// Speaks text with natural pauses between sentences.
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;

    // Split on Bengali danda (।), !, ?, . — keep natural sentence rhythm
    final sentences = text
        .split(RegExp(r'(?<=[।!?\.])\s*'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (sentences.length <= 1) {
      await _tts.speak(text);
      return;
    }

    for (int i = 0; i < sentences.length; i++) {
      await _tts.speak(sentences[i]);
      if (i < sentences.length - 1) {
        await Future.delayed(const Duration(milliseconds: 180));
      }
    }
  }

  Future<void> stop() async => _tts.stop();
}
