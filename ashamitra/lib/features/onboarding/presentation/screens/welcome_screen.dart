import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../shared/widgets/app_button.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const _cases = [
    (icon: Icons.pregnant_woman_rounded,       label: '🤰 গর্ভবতী মায়ের চেকআপ',    color: AppColors.primary),
    (icon: Icons.health_and_safety_rounded,    label: '🤱 প্রসব-পরবর্তী চেকআপ',    color: AppColors.purple),
    (icon: Icons.child_care_rounded,           label: '👶 নবজাতক (০-২৮ দিন)',       color: Color(0xFF0891B2)),
    (icon: Icons.baby_changing_station_rounded,label: '🍼 শিশু (১-১২ মাস)',          color: AppColors.safeGreen),
    (icon: Icons.child_friendly_rounded,       label: '🧒 শিশু স্বাস্থ্য (১-৫ বছর)', color: Color(0xFFF59E0B)),
    (icon: Icons.vaccines_rounded,             label: '💉 টিকা / ইমিউনাইজেশন',     color: Color(0xFF8B5CF6)),
    (icon: Icons.emergency_rounded,            label: '🚨 জরুরি অবস্থা',            color: AppColors.emergencyRed),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 28),
                Text('welcome_didi'.tr,
                    style: const TextStyle(fontSize: 26,
                        fontWeight: FontWeight.bold, color: AppColors.onBackground)),
                const SizedBox(height: 4),
                Text('welcome_subtitle'.tr,
                    style: const TextStyle(fontSize: 15, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                // Subtitle explaining the 7 cases
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'এই অ্যাপ দিয়ে ৭টি কেস পরিচালনা করুন — ভয়েস দিয়ে, বাংলায়।',
                    style: TextStyle(fontSize: 12, color: AppColors.primary,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 16),

                // ── 7 case list ──────────────────────────────
                Expanded(
                  child: ListView.separated(
                    itemCount: _cases.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final c = _cases[i];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: c.color.withOpacity(0.2)),
                          boxShadow: [
                            BoxShadow(color: c.color.withOpacity(0.07),
                                blurRadius: 10, offset: const Offset(0, 3)),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: c.color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(c.icon, color: c.color, size: 20),
                            ),
                            const SizedBox(width: 14),
                            Text(c.label,
                                style: const TextStyle(fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.onBackground)),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),
                AppButton(
                  label: 'get_started'.tr,
                  onPressed: () => Get.toNamed(AppRoutes.login),
                  icon: Icons.play_arrow_rounded,
                  width: double.infinity,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
