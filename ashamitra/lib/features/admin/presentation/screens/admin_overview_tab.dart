import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../features/auth/controller/auth_controller.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../admin/controller/admin_controller.dart';

class AdminOverviewTab extends StatelessWidget {
  const AdminOverviewTab({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<AdminController>();
    final auth = Get.find<AuthController>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ctrl.loadStats();
      ctrl.loadReports();
    });

    return Container(
      decoration: const BoxDecoration(gradient: AppGradients.background),
      child: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            await ctrl.loadStats();
            await ctrl.loadReports();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────────
                Row(
                  children: [
                    Obx(() => UserAvatar(
                          user: auth.user.value,
                          size: 44,
                          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                          textColor: AppColors.primary,
                        )),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('admin_panel'.tr,
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.onBackground)),
                          Obx(() => Text(auth.user.value?.name ?? 'Admin',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textSecondary))),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Stats grid ───────────────────────────────────
                Obx(() => GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.55,
                      children: [
                        _StatTile('admin_total_asha'.tr, '${ctrl.totalWorkers}',
                            Icons.people_alt_rounded, AppColors.primary),
                        _StatTile('admin_total_reports'.tr, '${ctrl.totalReports}',
                            Icons.analytics_rounded, AppColors.purple),
                        _StatTile('admin_emergency_red'.tr, '${ctrl.redReports}',
                            Icons.gpp_bad_rounded, AppColors.emergencyRed),
                        _StatTile('admin_warning_yellow'.tr, '${ctrl.yellowReports}',
                            Icons.warning_amber_rounded, AppColors.warningYellow),
                      ],
                    )),
                const SizedBox(height: 28),

                // ── Recent reports ───────────────────────────────
                const Text('Recent Reports',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onBackground)),
                const SizedBox(height: 12),
                Obx(() {
                  if (ctrl.isLoading.value) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary, strokeWidth: 2));
                  }
                  if (ctrl.reports.isEmpty) {
                    return Center(
                      child: Text('admin_no_reports'.tr,
                          style: const TextStyle(color: AppColors.textSecondary)),
                    );
                  }
                  final recent = ctrl.reports.take(5).toList();
                  return Column(
                    children: recent
                        .map((r) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _RecentReportCard(r: r),
                            ))
                        .toList(),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatTile(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 8))
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: color,
                  height: 1.1)),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  height: 1.3)),
        ],
      ),
    );
  }
}

class _RecentReportCard extends StatelessWidget {
  final Map<String, dynamic> r;
  const _RecentReportCard({required this.r});

  Color get _bandColor {
    final band = r['finalBand']?.toString().toUpperCase() ?? '';
    if (band == 'RED') return AppColors.emergencyRed;
    if (band == 'YELLOW') return AppColors.warningYellow;
    return AppColors.safeGreen;
  }

  @override
  Widget build(BuildContext context) {
    final color = _bandColor;
    final band = r['finalBand']?.toString().toUpperCase() ?? '-';
    final caseLabel = r['caseLabel']?.toString() ?? '';
    final patientName = r['patientName']?.toString() ?? '';
    String fmtDate = '';
    try {
      fmtDate = DateFormat('dd MMM, HH:mm')
          .format(DateTime.parse(r['createdAt']?.toString() ?? ''));
    } catch (_) {}

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Center(
              child: Text(band.isNotEmpty ? band[0] : '?',
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (caseLabel.isNotEmpty)
                  Text(caseLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onBackground)),
                if (patientName.isNotEmpty)
                  Text(patientName,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Text(fmtDate,
              style: const TextStyle(
                  fontSize: 10, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
