import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'app/app.dart';
import 'core/services/local_storage_service.dart';
import 'core/services/language_controller.dart';
import 'core/services/rule_executor.dart';
import 'core/services/tts_prewarm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStorageService.init();

  // Register LanguageController before App builds so Obx can find it
  Get.put(LanguageController(), permanent: true);

  final executor = RuleExecutor();
  Get.put(executor, permanent: true);
  await executor.load();

  // Warm the TTS cache in the background so Leda's voice works offline.
  // Non-blocking — returns immediately. See TtsPrewarmService docs.
  unawaited(TtsPrewarmService.startInBackground());

  runApp(const App());
}
