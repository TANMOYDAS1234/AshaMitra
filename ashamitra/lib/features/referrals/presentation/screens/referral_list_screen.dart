import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/components/app_header.dart';
import '../../../../shared/widgets/module_list_card.dart';
import '../../controller/referral_controller.dart';
import 'referral_detail_screen.dart';

/// Clinical urgency band → rail / avatar colour.
Color _bandColor(String band) => switch (band) {
      'RED' => AppColors.emergencyRed,
      'YELLOW' => AppColors.warningYellow,
      _ => AppColors.primary,
    };

/// Tracking status → pill label + colour.
(String, Color) _statusInfo(String status) => switch (status) {
      'reached' => ('ref_status_reached'.tr, AppColors.primary),
      'completed' => ('ref_status_completed'.tr, AppColors.safeGreen),
      'cancelled' => ('ref_status_cancelled'.tr, AppColors.textSecondary),
      _ => ('ref_status_pending'.tr, AppColors.warningYellow),
    };

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
              const SizedBox(height: 6),
              Expanded(
                child: Obx(() {
                  final items = ctrl.referrals.toList();
                  if (items.isEmpty) return _empty(ctrl);
                  final open = items.where((r) => r.isOpen).length;
                  final done =
                      items.where((r) => r.status == 'completed').length;
                  return RefreshIndicator(
                    onRefresh: ctrl.syncFromServer,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                      children: [
                        _hero(total: items.length, open: open, done: done),
                        const SizedBox(height: 16),
                        _listHeader(items.length),
                        ...items.map((r) {
                          final (statusLabel, statusColor) =
                              _statusInfo(r.status);
                          final subtitle = [
                            if (r.referredTo.isNotEmpty)
                              'ref_referred_to'
                                  .trParams({'facility': r.referredTo}),
                            if (r.village.isNotEmpty) r.village,
                            if (r.symptoms.isNotEmpty) r.symptoms,
                          ].join('  ·  ');
                          return ModuleListCard(
                            icon: Icons.local_hospital_rounded,
                            title: r.patientName,
                            subtitle: subtitle,
                            accent: _bandColor(r.band),
                            badge: statusLabel,
                            badgeColor: statusColor,
                            danger: r.band == 'RED' && r.isOpen,
                            onTap: () => Get.to(
                                () => ReferralDetailScreen(referralId: r.id)),
                          );
                        }),
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

  // ── Gradient hero — referral summary at a glance ──────────────────────────
  Widget _hero({required int total, required int open, required int done}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDeep, AppColors.primary, AppColors.purple],
          stops: [0.0, 0.55, 1.0],
        ),
        boxShadow: AppShadows.tinted(AppColors.primary, strength: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('ref_hero_chip'.tr,
                      style: AppTextStyles.caption.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                ),
                const Spacer(),
                Icon(Icons.track_changes_rounded,
                    color: Colors.white.withValues(alpha: 0.85), size: 22),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                    child: _stat('$total', 'ref_stat_total'.tr,
                        emphasize: true)),
                const SizedBox(width: 10),
                Expanded(
                    child: _stat('$open', 'ref_stat_followup'.tr,
                        warn: open > 0)),
                const SizedBox(width: 10),
                Expanded(child: _stat('$done', 'ref_stat_done'.tr)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String value, String label,
      {bool emphasize = false, bool warn = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: emphasize ? 0.24 : 0.13),
        borderRadius: BorderRadius.circular(16),
        border: warn
            ? Border.all(color: Colors.white.withValues(alpha: 0.55), width: 1)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (warn) ...[
                const Icon(Icons.notifications_active_rounded,
                    color: Colors.white, size: 15),
                const SizedBox(width: 3),
              ],
              Text(value,
                  style: AppTextStyles.h2.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      height: 1.0)),
            ],
          ),
          const SizedBox(height: 3),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption
                  .copyWith(color: Colors.white.withValues(alpha: 0.85))),
        ],
      ),
    );
  }

  Widget _listHeader(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.accent],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text('ref_list_header'.tr,
              style: AppTextStyles.label.copyWith(
                  color: AppColors.onBackground,
                  fontWeight: FontWeight.w800,
                  fontSize: 14)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('$count',
                style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary, fontWeight: FontWeight.w800)),
          ),
        ],
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
