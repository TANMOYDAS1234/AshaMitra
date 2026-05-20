import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/services/case_detection_service.dart';
import '../../data/models/triage_case_model.dart';

class CaseConfirmScreen extends StatefulWidget {
  const CaseConfirmScreen({super.key});

  @override
  State<CaseConfirmScreen> createState() => _CaseConfirmScreenState();
}

class _CaseConfirmScreenState extends State<CaseConfirmScreen> {
  final _service = CaseDetectionService();

  late List<TriageCaseModel> _allCases;
  TriageCaseModel? _detected;
  double _confidence = 0;
  String _method = '';
  bool _loading = true;
  int _countdown = 3;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>;
    _detected = args['case'] as TriageCaseModel;
    _confidence = (args['confidence'] as num).toDouble();
    _method = args['method'] as String;
    _loading = false;
    _loadAllCases();
    if (_confidence >= 0.95) _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadAllCases() async {
    _allCases = await _service.loadCases();
    if (mounted) setState(() {});
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_countdown <= 1) {
        t.cancel();
        _proceed(_detected!);
      } else {
        setState(() => _countdown--);
      }
    });
  }

  void _proceed(TriageCaseModel c) {
    _timer?.cancel();
    final situation = (Get.arguments as Map<String, dynamic>)['situation'] as String? ?? '';
    Get.toNamed(AppRoutes.voiceTriage, arguments: {
      'caseId': c.id,
      'caseTitle': c.title,
      'situation': situation,
    });
  }

  Color get _confidenceColor {
    if (_confidence >= 0.85) return AppColors.safeGreen;
    if (_confidence >= 0.60) return AppColors.warningYellow;
    return AppColors.emergencyRed;
  }

  String get _confidenceLabel {
    if (_confidence >= 0.85) return 'উচ্চ নিশ্চিততা';
    if (_confidence >= 0.60) return 'মাঝারি নিশ্চিততা';
    return 'কম নিশ্চিততা';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          child: _loading ? _buildLoading() : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildLoading() => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text('পরিস্থিতি বিশ্লেষণ হচ্ছে...',
                style: TextStyle(fontSize: 15, color: AppColors.textSecondary)),
          ],
        ),
      );

  Widget _buildContent() {
    final c = _detected!;
    final isAutoProceeding = _confidence >= 0.95 && _timer != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 32),

          // ── Header ──────────────────────────────────────────
          const Text('পরিস্থিতি শনাক্ত হয়েছে',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onBackground)),
          const SizedBox(height: 6),
          Text('ASHA-র বক্তব্য বিশ্লেষণ করা হয়েছে',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),

          const SizedBox(height: 32),

          // ── Detected case card ───────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _confidenceColor.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                    color: _confidenceColor.withValues(alpha: 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 6))
              ],
            ),
            child: Column(
              children: [
                Text(c.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onBackground)),
                const SizedBox(height: 16),

                // Confidence bar
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _confidence,
                          backgroundColor: const Color(0xFFE0E7FF),
                          color: _confidenceColor,
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('${(_confidence * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _confidenceColor)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _badge(_confidenceLabel, _confidenceColor),
                    _badge(
                        _method == 'ai' ? '🤖 AI শনাক্ত' : '📋 নিয়ম-ভিত্তিক',
                        AppColors.primary),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          const Spacer(),

          // ── Auto-proceed countdown ───────────────────────────
          if (isAutoProceeding) ...[
            Text('$_countdown সেকেন্ডে স্বয়ংক্রিয়ভাবে শুরু হবে...',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.safeGreen,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
          ],

          // ── Confirm button ───────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _proceed(c),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text('হ্যাঁ, সঠিক — শুরু করুন',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 12),

          // ── Change case button ───────────────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                _timer?.cancel();
                _showCasePicker();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('পরিবর্তন করুন',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      );

  void _showCasePicker() {
    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('সঠিক পরিস্থিতি বেছে নিন',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onBackground)),
            const SizedBox(height: 16),
            ..._allCases.map((c) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(c.title,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: c.id == _detected?.id
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: c.id == _detected?.id
                              ? AppColors.primary
                              : AppColors.onBackground)),
                  trailing: c.id == _detected?.id
                      ? const Icon(Icons.check_circle_rounded,
                          color: AppColors.primary)
                      : null,
                  onTap: () {
                    Get.back();
                    _proceed(c);
                  },
                )),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }
}
