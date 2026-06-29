import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/components/app_header.dart';
import '../../controller/referral_controller.dart';
import '../../data/models/referral_model.dart';
import 'referral_detail_screen.dart';

/// Worker's referrals with outcome tracking — the list that answers
/// "who did I refer, and did they reach the facility?".
class ReferralListScreen extends StatelessWidget {
  const ReferralListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.isRegistered<ReferralController>()
        ? Get.find<ReferralController>()
        : Get.put(ReferralController(), permanent: true);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text('ref_new_referral'.tr),
        onPressed: () => Get.toNamed(AppRoutes.referralForm),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          child: Column(
            children: [
              AppHeader(
                title: 'ref_title'.tr,
                actions: [
                  HeaderActionCircle(
                    icon: Icons.refresh_rounded,
                    tooltip: 'ref_refresh'.tr,
                    onTap: ctrl.syncFromServer,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Obx(() {
                  final items = ctrl.referrals.toList();
                  if (items.isEmpty) {
                    return _empty(ctrl);
                  }
                  final open = items.where((r) => r.isOpen).length;
                  return RefreshIndicator(
                    onRefresh: ctrl.syncFromServer,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                      children: [
                        if (open > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10, left: 4),
                            child: Text(
                              'ref_open_banner'
                                  .trParams({'count': '$open'}),
                              style: AppTextStyles.label
                                  .copyWith(color: AppColors.emergencyRed),
                            ),
                          ),
                        ...items.map((r) => _ReferralCard(referral: r)),
                      ],
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _empty(ReferralController ctrl) => RefreshIndicator(
        onRefresh: ctrl.syncFromServer,
        child: ListView(
          children: [
            const SizedBox(height: 120),
            Icon(Icons.assignment_turned_in_outlined,
                size: 64, color: AppColors.primary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Center(
              child: Text('ref_empty_title'.tr,
                  style: AppTextStyles.h3
                      .copyWith(color: AppColors.textSecondary)),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text('ref_empty_subtitle'.tr,
                  style: AppTextStyles.label
                      .copyWith(color: AppColors.textSecondary)),
            ),
          ],
        ),
      );
}

class _ReferralCard extends StatelessWidget {
  const _ReferralCard({required this.referral});
  final ReferralModel referral;

  @override
  Widget build(BuildContext context) {
    final band = referral.band;
    final bandColor = band == 'RED'
        ? AppColors.emergencyRed
        : (band == 'YELLOW' ? AppColors.warningYellow : AppColors.textSecondary);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.surface,
        borderRadius: AppRadius.lgR,
        child: InkWell(
          borderRadius: AppRadius.lgR,
          onTap: () => Get.to(() => ReferralDetailScreen(referralId: referral.id)),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: AppRadius.lgR,
              boxShadow: AppShadows.low,
              border: Border(left: BorderSide(color: bandColor, width: 4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(referral.patientName,
                          style: AppTextStyles.h3,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    _StatusChip(status: referral.status),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    if (referral.village.isNotEmpty) referral.village,
                    if (referral.referredTo.isNotEmpty)
                      'ref_referred_to'.trParams({'facility': referral.referredTo}),
                  ].join('  '),
                  style: AppTextStyles.label.copyWith(color: AppColors.textSecondary),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                if (referral.symptoms.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(referral.symptoms,
                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'reached' => ('ref_status_reached'.tr, AppColors.primary),
      'completed' => ('ref_status_completed'.tr, AppColors.safeGreen),
      'cancelled' => ('ref_status_cancelled'.tr, AppColors.textSecondary),
      _ => ('ref_status_pending'.tr, AppColors.warningYellow),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: AppTextStyles.caption
              .copyWith(color: color, fontWeight: FontWeight.w700)),
    );
  }
}
