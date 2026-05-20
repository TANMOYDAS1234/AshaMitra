import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/services/case_detection_service.dart';
import '../../data/models/triage_case_model.dart';

class SelectCaseScreen extends StatefulWidget {
  const SelectCaseScreen({super.key});

  @override
  State<SelectCaseScreen> createState() => _SelectCaseScreenState();
}

class _SelectCaseScreenState extends State<SelectCaseScreen> {
  final _detectionService = CaseDetectionService();
  final _stt = SpeechToText();
  final _tts = FlutterTts();
  List<TriageCaseModel> _cases = [];
  bool _loading = true;
  bool _listening = false;
  String _transcript = '';

  @override
  void initState() {
    super.initState();
    _loadCases();
    _initSttTts();
  }

  Future<void> _initSttTts() async {
    await _stt.initialize();
    await _tts.setLanguage('bn-IN');
    await _tts.setSpeechRate(0.42);
    await _tts.setPitch(1.1);
    await _tts.setVolume(1.0);
    // Greet the worker
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) _tts.speak('পরিস্থিতি বলুন। মাইক বোতাম চাপুন।');
  }

  Future<void> _loadCases() async {
    final cases = await _detectionService.loadCases();
    if (mounted) setState(() { _cases = cases; _loading = false; });
  }

  // Single-tap toggle
  Future<void> _toggleMic() async {
    if (_listening) {
      await _stt.stop();
      setState(() => _listening = false);
      if (_transcript.isNotEmpty) _detectCase(_transcript);
    } else {
      await _tts.stop();
      setState(() { _listening = true; _transcript = ''; });
      await _stt.listen(
        localeId: 'bn_IN',
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 60),
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          partialResults: true,
          cancelOnError: false,
        ),
        onResult: (result) {
          if (!mounted) return;
          setState(() => _transcript = result.recognizedWords);
          // Auto-stop on final result
          if (result.finalResult && _transcript.isNotEmpty) {
            _stt.stop();
            setState(() => _listening = false);
            _detectCase(_transcript);
          }
        },
      );
    }
  }

  Future<void> _detectCase(String transcript) async {
    Get.dialog(
      const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      barrierDismissible: false,
    );
    final result = await _detectionService.detect(transcript);
    Get.back();

    // Gap 2 fix: zero confidence means nothing was recognised —
    // go straight to manual selection instead of showing a wrong case.
    if (result.confidence == 0.0) {
      Get.snackbar(
        'বোঝা যায়নি',
        'পরিস্থিতি শনাক্ত হয়নি। নিচে থেকে ম্যানুয়ালি বেছে নিন।',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.warningYellow,
        colorText: AppColors.onBackground,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    final detectedCase = _cases.firstWhere((c) => c.id == result.caseId,
        orElse: () => _cases.first);
    Get.toNamed(AppRoutes.caseConfirm, arguments: {
      'case': detectedCase,
      'confidence': result.confidence,
      'method': result.method,
      'situation': transcript,
    });
  }

  void _selectCase(TriageCaseModel caseModel) {
    Get.toNamed(AppRoutes.voiceTriage, arguments: {
      'caseId': caseModel.id,
      'caseTitle': caseModel.title,
    });
  }

  @override
  void dispose() {
    _tts.stop();
    _stt.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final caseIcons = {
      'pregnancy': (Icons.pregnant_woman_rounded, AppColors.primary),
      'postpartum': (Icons.health_and_safety_rounded, AppColors.purple),
      'newborn': (Icons.child_care_rounded, AppColors.sky),
      'infant': (Icons.baby_changing_station_rounded, AppColors.safeGreen),
      'child': (Icons.child_friendly_rounded, AppColors.warningYellow),
      'immunization': (Icons.vaccines_rounded, AppColors.primary),
      'emergency': (Icons.emergency_rounded, AppColors.emergencyRed),
    };

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Get.back(),
                      child: Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)],
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('select_case'.tr,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.onBackground)),
                        Text('select_case_subtitle'.tr,
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Mic toggle card ──────────────────────────
                GestureDetector(
                  onTap: _toggleMic,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _listening
                            ? [AppColors.safeGreen, const Color(0xFF16A34A)]
                            : [AppColors.primary, AppColors.purple],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: (_listening ? AppColors.safeGreen : AppColors.primary).withOpacity(0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52, height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _listening ? Icons.stop_rounded : Icons.mic_rounded,
                            color: Colors.white, size: 26,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _listening ? '🔴 শুনছি — থামাতে আবার চাপুন' : '🎤 পরিস্থিতি বলুন',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _transcript.isNotEmpty
                                    ? _transcript
                                    : _listening
                                        ? 'বলুন...'
                                        : 'মাইক চাপুন, তারপর পরিস্থিতি বলুন',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.88)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                const Text(
                  'অথবা ম্যানুয়ালি নির্বাচন করুন:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 0.9,
                    ),
                    itemCount: _cases.length,
                    itemBuilder: (_, i) {
                      final caseModel = _cases[i];
                      final (icon, color) = caseIcons[caseModel.id] ?? (Icons.help_outline, AppColors.primary);
                      return GestureDetector(
                        onTap: () => _selectCase(caseModel),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: color.withOpacity(0.15)),
                            boxShadow: [BoxShadow(color: color.withOpacity(0.10), blurRadius: 16, offset: const Offset(0, 4))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 48, height: 48,
                                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                                child: Icon(icon, color: color, size: 24),
                              ),
                              const SizedBox(height: 10),
                              Text(caseModel.title,
                                  maxLines: 2, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E1B4B), height: 1.3)),
                            ],
                          ),
                        ),
                      );
                    },
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
