import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../admin/controller/admin_controller.dart';
import '../../../../features/auth/data/models/user_model.dart';

class AdminAshaListScreen extends StatelessWidget {
  const AdminAshaListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<AdminController>();

    // Always reload fresh data from Atlas when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.loadAshaWorkers());
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: Get.back,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.all(12),
                        elevation: 2,
                        shadowColor: Colors.black.withValues(alpha: 0.1),
                      ),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 16, color: AppColors.onBackground),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'admin_asha_list'.tr,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: AppColors.onBackground,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Get.toNamed(AppRoutes.adminAddAsha),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        padding: const EdgeInsets.all(10),
                      ),
                      icon: const Icon(Icons.person_add_alt_1_rounded,
                          color: AppColors.primary, size: 22),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Obx(() {
                  if (ctrl.isLoading.value) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary, strokeWidth: 3));
                  }
                  if (ctrl.ashaWorkers.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline_rounded,
                              size: 64,
                              color: AppColors.textSecondary.withValues(alpha: 0.4)),
                          const SizedBox(height: 16),
                          Text('admin_no_asha'.tr,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    );
                  }
                  return RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: ctrl.loadAshaWorkers,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      itemCount: ctrl.ashaWorkers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) =>
                          _AshaCard(worker: ctrl.ashaWorkers[i], ctrl: ctrl),
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

class _AshaCard extends StatelessWidget {
  final UserModel worker;
  final AdminController ctrl;

  const _AshaCard({required this.worker, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final statusColor =
        worker.isActive ? AppColors.safeGreen : AppColors.textSecondary;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 14,
              offset: const Offset(0, 4))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(
                    worker.name.isNotEmpty ? worker.name[0].toUpperCase() : 'A',
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 16),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(worker.name,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onBackground,
                              letterSpacing: -0.1)),
                      const SizedBox(height: 3),
                      Row(children: [
                        Icon(Icons.phone_android_rounded,
                            size: 13,
                            color: AppColors.textSecondary.withValues(alpha: 0.7)),
                        const SizedBox(width: 4),
                        Text(worker.phone,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary)),
                      ]),
                      if (worker.block.isNotEmpty || worker.district.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(children: [
                          Icon(Icons.location_on_outlined,
                              size: 13,
                              color: AppColors.textSecondary.withValues(alpha: 0.5)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text('${worker.block}, ${worker.district}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w400,
                                    color: AppColors.textSecondary)),
                          ),
                        ]),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10)),
                      child: Text(
                        worker.isActive ? 'admin_active'.tr : 'admin_inactive'.tr,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: statusColor),
                      ),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () => _confirmToggle(context),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                            color: (worker.isActive
                                    ? AppColors.emergencyRed
                                    : AppColors.safeGreen)
                                .withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(
                          worker.isActive ? 'admin_remove'.tr : 'admin_reactivate'.tr,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: worker.isActive
                                  ? AppColors.emergencyRed
                                  : AppColors.safeGreen),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmToggle(BuildContext context) {
    final bool isRemove = worker.isActive;
    final String titleText =
        isRemove ? 'admin_remove_title'.tr : 'admin_reactivate_title'.tr;
    final String actionText =
        isRemove ? 'admin_remove'.tr : 'admin_reactivate'.tr;
    final Color actionColor =
        isRemove ? AppColors.emergencyRed : AppColors.safeGreen;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: actionColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle),
                child: Icon(
                    isRemove
                        ? Icons.person_remove_rounded
                        : Icons.person_add_alt_1_rounded,
                    color: actionColor,
                    size: 32),
              ),
              const SizedBox(height: 20),
              Text(titleText,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onBackground)),
              const SizedBox(height: 10),
              Text(
                'admin_confirm_action'.tr
                    .replaceAll('@name', worker.name)
                    .replaceAll('@action', actionText),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Get.back(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      child: Text('cancel'.tr,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Get.back();
                        if (isRemove) {
                          await ctrl.removeAshaWorker(worker.id);
                        } else {
                          await ctrl.reactivateAshaWorker(worker.id);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: actionColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(actionText,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }
}
