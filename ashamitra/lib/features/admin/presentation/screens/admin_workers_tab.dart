import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../features/auth/data/models/user_model.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../admin/controller/admin_controller.dart';

class AdminWorkersTab extends StatefulWidget {
  const AdminWorkersTab({super.key});

  @override
  State<AdminWorkersTab> createState() => _AdminWorkersTabState();
}

class _AdminWorkersTabState extends State<AdminWorkersTab> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<AdminController>();

    return Container(
      decoration: const BoxDecoration(gradient: AppGradients.background),
      child: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('ASHA Workers',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.onBackground)),
                  ),
                  IconButton(
                    onPressed: () => _showAddSheet(context, ctrl),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.all(10),
                    ),
                    icon: const Icon(Icons.person_add_alt_1_rounded,
                        color: Colors.white, size: 20),
                    tooltip: 'Add ASHA Worker',
                  ),
                ],
              ),
            ),

            // ── List ────────────────────────────────────────────
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
                            color: AppColors.textSecondary
                                .withValues(alpha: 0.4)),
                        const SizedBox(height: 16),
                        Text('admin_no_asha'.tr,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary)),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () => _showAddSheet(context, ctrl),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: Text('admin_add_asha'.tr),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: ctrl.loadAshaWorkers,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    itemCount: ctrl.ashaWorkers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _WorkerCard(
                      worker: ctrl.ashaWorkers[i],
                      ctrl: ctrl,
                      onTap: () =>
                          _showWorkerDetail(context, ctrl.ashaWorkers[i], ctrl),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  // ── Add ASHA bottom sheet ──────────────────────────────────────────
  void _showAddSheet(BuildContext context, AdminController ctrl) {
    final formKey = GlobalKey<FormState>();
    final phone = TextEditingController();
    final name = TextEditingController();
    final block = TextEditingController();
    final district = TextEditingController();
    final saving = false.obs;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Text('admin_add_asha'.tr,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onBackground)),
                const SizedBox(height: 20),
                _formField(name, 'admin_full_name'.tr, Icons.person_rounded,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'admin_name_required'.tr
                        : null),
                const SizedBox(height: 14),
                _formField(
                    phone, 'admin_phone'.tr, Icons.phone_android_rounded,
                    keyboardType: TextInputType.phone,
                    validator: (v) => (v == null || v.trim().length < 10)
                        ? 'admin_phone_required'.tr
                        : null),
                const SizedBox(height: 14),
                _formField(block, 'admin_block'.tr, Icons.location_on_rounded),
                const SizedBox(height: 14),
                _formField(district, 'admin_district'.tr, Icons.map_rounded),
                const SizedBox(height: 24),
                Obx(() => SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: saving.value
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                saving.value = true;
                                final ok = await ctrl.addAshaWorker(
                                  phone: phone.text.trim(),
                                  name: name.text.trim(),
                                  block: block.text.trim(),
                                  district: district.text.trim(),
                                );
                                saving.value = false;
                                if (ok) {
                                  Navigator.of(context).pop();
                                  Get.snackbar(
                                    'admin_success'.tr,
                                    'admin_add_success'.tr,
                                    backgroundColor: AppColors.safeGreen,
                                    colorText: Colors.white,
                                    snackPosition: SnackPosition.BOTTOM,
                                    margin: const EdgeInsets.all(16),
                                    borderRadius: 12,
                                  );
                                } else {
                                  Get.snackbar(
                                    'Error',
                                    ctrl.errorMsg.value,
                                    backgroundColor: AppColors.emergencyRed,
                                    colorText: Colors.white,
                                    snackPosition: SnackPosition.BOTTOM,
                                    margin: const EdgeInsets.all(16),
                                    borderRadius: 12,
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: saving.value
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : Text('admin_save'.tr,
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700)),
                      ),
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Worker detail bottom sheet ─────────────────────────────────────
  void _showWorkerDetail(
      BuildContext context, UserModel worker, AdminController ctrl) async {
    final patients = await ctrl.getWorkerPatients(worker.id);
    final reports = await ctrl.getWorkerReports(worker.id);

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              // Worker header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle),
                      child: UserAvatar(
                        user: worker,
                        size: 52,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        textColor: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(worker.name,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.onBackground)),
                          Text(worker.phone,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary)),
                          if (worker.block.isNotEmpty)
                            Text('${worker.block}, ${worker.district}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                          color: (worker.isActive
                                  ? AppColors.safeGreen
                                  : AppColors.textSecondary)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10)),
                      child: Text(
                        worker.isActive
                            ? 'admin_active'.tr
                            : 'admin_inactive'.tr,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: worker.isActive
                                ? AppColors.safeGreen
                                : AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              // Stats row
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Row(
                  children: [
                    _StatChip(Icons.people_rounded, '${patients.length}',
                        'Patients', AppColors.primary),
                    const SizedBox(width: 10),
                    _StatChip(Icons.analytics_rounded, '${reports.length}',
                        'Reports', AppColors.purple),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Patients list
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  children: [
                    if (patients.isNotEmpty) ...[
                      const Text('Patients',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onBackground)),
                      const SizedBox(height: 8),
                      ...patients.map((p) => _PatientRow(p)),
                      const SizedBox(height: 16),
                    ],
                    if (reports.isNotEmpty) ...[
                      const Text('Reports',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onBackground)),
                      const SizedBox(height: 8),
                      ...reports.map((r) => _ReportRow(r)),
                    ],
                    if (patients.isEmpty && reports.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.only(top: 32),
                          child: Text('No activity yet',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 14)),
                        ),
                      ),
                  ],
                ),
              ),
              // Activate / Deactivate button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      if (worker.isActive) {
                        await ctrl.removeAshaWorker(worker.id);
                      } else {
                        await ctrl.reactivateAshaWorker(worker.id);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: worker.isActive
                          ? AppColors.emergencyRed
                          : AppColors.safeGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      worker.isActive
                          ? 'admin_remove'.tr
                          : 'admin_reactivate'.tr,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _formField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.onBackground),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5)),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.emergencyRed)),
          focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.emergencyRed, width: 1.5)),
        ),
      );
}

// ── Worker card ────────────────────────────────────────────────────────────────
class _WorkerCard extends StatelessWidget {
  final UserModel worker;
  final AdminController ctrl;
  final VoidCallback onTap;

  const _WorkerCard(
      {required this.worker, required this.ctrl, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColor =
        worker.isActive ? AppColors.safeGreen : AppColors.textSecondary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
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
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle),
              child: UserAvatar(
                user: worker,
                size: 46,
                backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                textColor: AppColors.primary,
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
                          color: AppColors.onBackground)),
                  const SizedBox(height: 2),
                  Text(worker.phone,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                  if (worker.block.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text('${worker.block}, ${worker.district}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    worker.isActive
                        ? 'admin_active'.tr
                        : 'admin_inactive'.tr,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor),
                  ),
                ),
                const SizedBox(height: 6),
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: AppColors.textSecondary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stat chip ──────────────────────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatChip(this.icon, this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: color)),
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Patient row ────────────────────────────────────────────────────────────────
class _PatientRow extends StatelessWidget {
  final Map<String, dynamic> p;
  const _PatientRow(this.p);

  @override
  Widget build(BuildContext context) {
    final risk = p['risk']?.toString() ?? 'safe';
    final color = risk == 'emergency'
        ? AppColors.emergencyRed
        : risk == 'high'
            ? AppColors.warningYellow
            : AppColors.safeGreen;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Row(
        children: [
          Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(p['name']?.toString() ?? '',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onBackground)),
          ),
          Text(p['type']?.toString() ?? '',
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

// ── Report row ─────────────────────────────────────────────────────────────────
class _ReportRow extends StatelessWidget {
  final Map<String, dynamic> r;
  const _ReportRow(this.r);

  @override
  Widget build(BuildContext context) {
    final band = r['finalBand']?.toString().toUpperCase() ?? '';
    final color = band == 'RED'
        ? AppColors.emergencyRed
        : band == 'YELLOW'
            ? AppColors.warningYellow
            : AppColors.safeGreen;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Row(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6)),
            child: Text(band,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: color)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(r['caseLabel']?.toString() ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.onBackground)),
          ),
        ],
      ),
    );
  }
}
