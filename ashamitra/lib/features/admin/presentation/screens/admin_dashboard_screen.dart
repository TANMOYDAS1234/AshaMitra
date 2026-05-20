import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../features/auth/controller/auth_controller.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../admin/controller/admin_controller.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<AdminController>();
    final auth = Get.find<AuthController>();

    // Reload fresh data every time dashboard opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ctrl.loadStats();
      ctrl.loadAshaWorkers();
    });
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          child: Column(
            children: [
              // ── Header Section ───────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
                child: Row(
                  children: [
                    // ── Profile photo / avatar ───────────────────────────
                    Obx(() {
                      final u = auth.user.value;
                      return GestureDetector(
                        onTap: () => Get.toNamed(AppRoutes.adminProfile),
                        child: Hero(
                          tag: 'admin_photo',
                          child: Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.25),
                                width: 2,
                              ),
                            ),
                            child: UserAvatar(
                              user: u,
                              size: 48,
                              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                              textColor: AppColors.primary,
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'admin_panel'.tr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              color: AppColors.onBackground,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Obx(() => Text(
                                auth.user.value?.name ?? 'Admin',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary,
                                ),
                              )),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: auth.logout,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.6),
                        padding: const EdgeInsets.all(10),
                      ),
                      icon: const Icon(
                        Icons.logout_rounded,
                        color: AppColors.emergencyRed,
                        size: 22,
                      ),
                      tooltip: 'Logout',
                    ),
                  ],
                ),
              ),

              // ── Main Content Section ─────────────────────────────
              Expanded(
                child: Obx(() {
                  if (ctrl.isLoading.value) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 3,
                      ),
                    );
                  }
                  
                  return RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () async {
                      await ctrl.loadStats();
                      await ctrl.loadAshaWorkers();
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Grid Layout for Stats ────────────────────────
                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.55,
                            children: [
                              _StatTile(
                                label: 'admin_total_asha'.tr,
                                value: '${ctrl.totalWorkers}',
                                icon: Icons.people_alt_rounded,
                                color: AppColors.primary,
                              ),
                              _StatTile(
                                label: 'admin_total_reports'.tr,
                                value: '${ctrl.totalReports}',
                                icon: Icons.analytics_rounded,
                                color: AppColors.purple,
                              ),
                              _StatTile(
                                label: 'admin_emergency_red'.tr,
                                value: '${ctrl.redReports}',
                                icon: Icons.gpp_bad_rounded,
                                color: AppColors.emergencyRed,
                              ),
                              _StatTile(
                                label: 'admin_warning_yellow'.tr,
                                value: '${ctrl.yellowReports}',
                                icon: Icons.thunderstorm_rounded,
                                color: AppColors.warningYellow,
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),

                          // ── Management Actions Header ────────────────────
                          Row(
                            children: [
                              Container(
                                width: 4,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'admin_management'.tr,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                  color: AppColors.onBackground,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // ── Action Management List ───────────────────────
                          _ActionCard(
                            icon: Icons.assignment_ind_rounded,
                            title: 'admin_profile_mgmt'.tr,
                            subtitle: 'admin_profile_mgmt_sub'.tr,
                            color: AppColors.sky,
                            onTap: () => Get.toNamed(AppRoutes.adminProfile),
                          ),
                          const SizedBox(height: 12),
                          _ActionCard(
                            icon: Icons.manage_accounts_rounded,
                            title: 'admin_asha_mgmt'.tr,
                            subtitle: 'admin_asha_mgmt_sub'.tr.replaceAll('@count', '${ctrl.totalWorkers}'),
                            color: AppColors.primary,
                            onTap: () => Get.toNamed(AppRoutes.adminAshaList),
                          ),
                          const SizedBox(height: 12),
                          _ActionCard(
                            icon: Icons.insert_chart_rounded,
                            title: 'admin_reports'.tr,
                            subtitle: 'admin_reports_sub'.tr,
                            color: AppColors.purple,
                            onTap: () => Get.toNamed(AppRoutes.adminReports),
                          ),
                          const SizedBox(height: 12),
                          _ActionCard(
                            icon: Icons.person_add_alt_1_rounded,
                            title: 'admin_add_asha'.tr,
                            subtitle: 'admin_add_asha_sub'.tr,
                            color: AppColors.safeGreen,
                            onTap: () => Get.toNamed(AppRoutes.adminAddAsha),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
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
}

// ── Optimized Grid Stat Tiles ───────────────────────────────────────
class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

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
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Decorative background accent
            Positioned(
              right: -15,
              bottom: -15,
              child: Icon(
                icon,
                size: 80,
                color: color.withValues(alpha: 0.03),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 18),
                  ),
                  const Spacer(),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: color,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Optimized Action Cards ──────────────────────────────────────────
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          splashColor: color.withValues(alpha: 0.05),
          highlightColor: color.withValues(alpha: 0.01),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onBackground,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withValues(alpha: 0.06),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 11,
                    color: AppColors.textSecondary.withValues(alpha: 0.7),
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