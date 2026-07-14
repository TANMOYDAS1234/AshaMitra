import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/components/app_header.dart';
import '../../controller/readiness_controller.dart';

/// The 30-second check-in.
///
/// This is the screen that decides whether the whole feature works. An ASHA who
/// finds it tedious will tick everything green on her doorstep without opening
/// the box, and then the district dashboard becomes a confident lie. So:
/// three taps per row, no typing, no scroll traps, and the critical items sit at
/// the top where fatigue hasn't set in yet.
class ReadinessCheckScreen extends StatefulWidget {
  const ReadinessCheckScreen({super.key});

  @override
  State<ReadinessCheckScreen> createState() => _ReadinessCheckScreenState();
}

class _ReadinessCheckScreenState extends State<ReadinessCheckScreen> {
  final c = Get.put(ReadinessController(), tag: 'readiness');

  @override
  void initState() {
    super.initState();
    c.loadForm();
  }

  static const _statusLabel = {
    'ok': 'আছে',
    'low': 'কম',
    'out': 'নেই',
  };
  static const _statusColor = {
    'ok': AppColors.safeGreen,
    'low': AppColors.warning,
    'out': AppColors.emergencyRed,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          child: Column(
            children: [
              AppHeader(
                title: 'ওষুধ ও যন্ত্রপাতি',
                subtitle: 'যা নেই, সেটা সঙ্গে সঙ্গে উপরে জানানো হবে',
              ),
              Expanded(
                child: Obx(() {
                  if (c.loadingForm.value) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (c.items.isEmpty) {
                    return Center(
                      child: Text('কোনও তালিকা পাওয়া যায়নি',
                          style: AppTextStyles.body
                              .copyWith(color: AppColors.textSecondary)),
                    );
                  }
                  final critical = c.items.where((i) => i.critical).toList();
                  final rest = c.items.where((i) => !i.critical).toList();
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                    children: [
                      if (c.lastSubmittedAt.value != null) _lastCheck(),
                      if (critical.isNotEmpty) ...[
                        _sectionTitle(
                          'প্রাণরক্ষাকারী — এগুলো না থাকলে জীবন ঝুঁকিতে',
                          AppColors.emergencyRed,
                        ),
                        ...critical.map(_row),
                        const SizedBox(height: 8),
                      ],
                      if (rest.isNotEmpty) ...[
                        _sectionTitle('বাকি সরঞ্জাম', AppColors.textSecondary),
                        ...rest.map(_row),
                      ],
                    ],
                  );
                }),
              ),
            ],
          ),
        ),
      ),
      bottomSheet: _submitBar(),
    );
  }

  Widget _lastCheck() {
    final d = c.lastSubmittedAt.value!;
    final days = DateTime.now().difference(d).inDays;
    final txt = days == 0
        ? 'আজ জানানো হয়েছে'
        : days == 1
            ? 'গতকাল জানানো হয়েছে'
            : '$days দিন আগে জানানো হয়েছে';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: AppRadius.lgR,
      ),
      child: Row(
        children: [
          const Icon(Icons.history_rounded, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text('$txt — শুধু যেটা বদলেছে, সেটা ঠিক করুন',
                style: AppTextStyles.bodySm.copyWith(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t, Color col) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
        child: Text(t,
            style: AppTextStyles.label
                .copyWith(color: col, fontWeight: FontWeight.w800)),
      );

  Widget _row(ReadinessItem item) {
    return Obx(() {
      final val = c.answers[item.code] ?? 'ok';
      final isBad = val == 'out';
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.lgR,
          boxShadow: AppShadows.low,
          border: isBad && item.critical
              ? Border.all(color: AppColors.emergencyRed.withValues(alpha: 0.5), width: 1.5)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_iconFor(item.cat), size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(item.label,
                      style: AppTextStyles.body
                          .copyWith(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: ['ok', 'low', 'out'].map((s) {
                final sel = val == s;
                final col = _statusColor[s]!;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Material(
                      color: sel ? col : col.withValues(alpha: 0.08),
                      borderRadius: AppRadius.mdR,
                      child: InkWell(
                        borderRadius: AppRadius.mdR,
                        onTap: () => c.setAnswer(item.code, s),
                        child: Container(
                          height: 42,
                          alignment: Alignment.center,
                          child: Text(
                            _statusLabel[s]!,
                            style: AppTextStyles.label.copyWith(
                              color: sel ? Colors.white : col,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      );
    });
  }

  IconData _iconFor(String cat) => switch (cat) {
        'drug' => Icons.medication_rounded,
        'equipment' => Icons.medical_services_rounded,
        'transport' => Icons.local_shipping_rounded,
        'facility' => Icons.local_hospital_rounded,
        _ => Icons.inventory_2_rounded,
      };

  Widget _submitBar() => Obx(() {
        // Count what will escalate, and SAY so before she taps. A worker who
        // knows her BMHO is about to be paged answers more carefully — and is
        // never ambushed by an alert she didn't realise she'd raised.
        final outCritical = c.items
            .where((i) => i.critical && (c.answers[i.code] ?? 'ok') == 'out')
            .length;
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            boxShadow: AppShadows.low,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (outCritical > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.campaign_rounded,
                          size: 18, color: AppColors.emergencyRed),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$outCritical টি জরুরি জিনিস নেই — পাঠালে সঙ্গে সঙ্গে '
                          'আপনার উপরের অফিসারের ফোনে খবর যাবে।',
                          style: AppTextStyles.bodySm
                              .copyWith(color: AppColors.emergencyRed),
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: c.submitting.value ? null : _submit,
                  icon: c.submitting.value
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(c.submitting.value ? 'পাঠানো হচ্ছে…' : 'পাঠিয়ে দিন'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.lgR),
                    textStyle: AppTextStyles.labelLg,
                  ),
                ),
              ),
            ],
          ),
        );
      });

  Future<void> _submit() async {
    final escalated = await c.submit();
    if (!mounted) return;
    if (escalated < 0) {
      Get.snackbar('পাঠানো যায়নি', 'ইন্টারনেট দেখে আবার চেষ্টা করুন।',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.emergencyRed,
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
          borderRadius: 12);
      return;
    }
    Get.back();
    Get.snackbar(
      'ধন্যবাদ',
      escalated > 0
          ? '$escalated টি জরুরি ঘাটতির খবর উপরে পাঠানো হয়েছে।'
          : 'আপনার রিপোর্ট জমা হয়েছে।',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor:
          (escalated > 0 ? AppColors.emergencyRed : AppColors.safeGreen)
              .withValues(alpha: 0.95),
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 4),
    );
  }
}
