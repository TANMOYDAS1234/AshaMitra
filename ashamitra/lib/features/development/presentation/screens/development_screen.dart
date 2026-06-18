import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/components/app_header.dart';
import '../../../../shared/widgets/app_button.dart';

/// Child development screening (2 months–3 years), driven by the engine's
/// `development` module (MCP card pg 13–25). The worker picks the child's age
/// band, ticks any milestone danger-signs listed for that age; if any are
/// present the screen surfaces the YELLOW refer guidance (DEIC / health worker).
class DevelopmentScreen extends StatefulWidget {
  const DevelopmentScreen({super.key});

  @override
  State<DevelopmentScreen> createState() => _DevelopmentScreenState();
}

class _DevelopmentScreenState extends State<DevelopmentScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _bands = [];
  String _referBn = 'বিকাশে বিলম্বের লক্ষণ — DEIC বা স্বাস্থ্যকর্মীর কাছে রেফার করুন।';

  int _bandIdx = -1;
  final Set<int> _checked = {};
  bool _showResult = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await rootBundle.loadString('assets/data/asha_engine.json');
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final modules = (j['modules'] as List).cast<Map<String, dynamic>>();
      final dev = modules.firstWhere((m) => m['module_id'] == 'development');
      _bands = (dev['milestones_by_age'] as List).cast<Map<String, dynamic>>();
      final yellow = (dev['yellow_rules'] as List?) ?? [];
      if (yellow.isNotEmpty) {
        _referBn = (yellow.first['action_bn'] ?? _referBn).toString();
      }
    } catch (_) {
      _bands = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  List<String> get _signs => _bandIdx < 0
      ? const []
      : ((_bands[_bandIdx]['danger_signs_bn'] as List?) ?? [])
          .map((e) => e.toString())
          .toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          child: Column(
            children: [
              const AppHeader(title: 'শিশু বিকাশ যাচাই'),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _hero(),
                            const SizedBox(height: 18),
                            Text('শিশুর বয়স কোন ধাপে?', style: AppTextStyles.label),
                            const SizedBox(height: 8),
                            _bandChips(),
                            if (_bandIdx >= 0) ...[
                              const SizedBox(height: 18),
                              Text('এই বয়সের বিপদচিহ্ন (যা দেখা যাচ্ছে টিক দিন)',
                                  style: AppTextStyles.label),
                              const SizedBox(height: 4),
                              ..._signs.asMap().entries.map((e) => CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                    activeColor: AppColors.emergencyRed,
                                    controlAffinity: ListTileControlAffinity.leading,
                                    value: _checked.contains(e.key),
                                    title: Text(e.value, style: AppTextStyles.body),
                                    onChanged: (on) => setState(() => on == true
                                        ? _checked.add(e.key)
                                        : _checked.remove(e.key)),
                                  )),
                              const SizedBox(height: 18),
                              AppButton(
                                label: 'ফলাফল দেখুন',
                                width: double.infinity,
                                onPressed: () => setState(() => _showResult = true),
                              ),
                            ],
                            if (_showResult) ...[
                              const SizedBox(height: 18),
                              _resultCard(),
                            ],
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.emoji_people_rounded, color: Colors.white, size: 44),
          ),
          const SizedBox(height: 10),
          Text('২ মাস – ৩ বছর',
              style: AppTextStyles.label.copyWith(color: Colors.white70)),
          Text('বিকাশের মাইলস্টোন যাচাই',
              style: AppTextStyles.h3.copyWith(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _bandChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _bands.asMap().entries.map((e) {
        final sel = _bandIdx == e.key;
        return ChoiceChip(
          label: Text(e.value['age_bn']?.toString() ?? ''),
          selected: sel,
          selectedColor: AppColors.primary,
          labelStyle: AppTextStyles.label.copyWith(
            color: sel ? AppColors.onPrimary : AppColors.textSecondary,
          ),
          onSelected: (_) => setState(() {
            _bandIdx = e.key;
            _checked.clear();
            _showResult = false;
          }),
        );
      }).toList(),
    );
  }

  Widget _resultCard() {
    final flagged = _checked.isNotEmpty;
    final color = flagged ? AppColors.warningYellow : AppColors.safeGreen;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(flagged ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
              color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              flagged ? _referBn : 'এই বয়সের জন্য বিকাশ স্বাভাবিক। রুটিন ফলো-আপ চালিয়ে যান।',
              style: AppTextStyles.body,
            ),
          ),
        ],
      ),
    );
  }
}
