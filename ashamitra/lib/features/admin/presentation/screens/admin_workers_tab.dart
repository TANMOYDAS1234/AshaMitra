import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/panel_palette.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../features/auth/data/models/user_model.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../admin/controller/admin_controller.dart';
import '../../../auth/controller/auth_controller.dart';
import '../../../../app/routes.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../../../shared/widgets/empty_state.dart';
import 'admin_report_detail.dart';

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
    // The level this supervisor manages (ASHA for an ANM, ANM for a BMHO, …).
    final child = Get.find<AuthController>().user.value?.manages ?? 'ASHA';

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
                  Expanded(
                    child: Text('আমার $child', style: AppTextStyles.h2),
                  ),
                  IconButton(
                    onPressed: () => _showAddSheet(context, ctrl),
                    style: IconButton.styleFrom(
                      backgroundColor: PanelPalette.primary,
                      padding: const EdgeInsets.all(10),
                    ),
                    icon: const Icon(Icons.person_add_alt_1_rounded,
                        color: AppColors.onPrimary, size: 20),
                    tooltip: 'নতুন $child',
                  ),
                ],
              ),
            ),

            // ── Search ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: TextField(
                onChanged: (v) => ctrl.workerQuery.value = v,
                style: AppTextStyles.body,
                decoration: InputDecoration(
                  hintText: '$child খুঁজুন — নাম, মোবাইল বা গ্রাম',
                  hintStyle: AppTextStyles.caption,
                  prefixIcon: Icon(Icons.search_rounded,
                      color: PanelPalette.primary, size: 20),
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                      borderRadius: AppRadius.mdR, borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: AppRadius.mdR,
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: AppRadius.mdR,
                      borderSide: BorderSide(
                          color: PanelPalette.primary, width: 1.5)),
                ),
              ),
            ),

            // ── Bulk action bar (appears once anything is selected) ──────
            Obx(() {
              final n = ctrl.selectedWorkers.length;
              if (n == 0) return const SizedBox.shrink();
              return Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                decoration: BoxDecoration(
                  color: PanelPalette.primary.withValues(alpha: 0.08),
                  borderRadius: AppRadius.mdR,
                  border: Border.all(
                      color: PanelPalette.primary.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('$n জন বাছাই করা হয়েছে',
                          style: AppTextStyles.label
                              .copyWith(color: PanelPalette.primary)),
                    ),
                    TextButton(
                      onPressed: () => _runBulk(context, ctrl, true),
                      child: Text('সক্রিয়',
                          style: AppTextStyles.label
                              .copyWith(color: AppColors.safeGreen)),
                    ),
                    TextButton(
                      onPressed: () => _runBulk(context, ctrl, false),
                      child: Text('নিষ্ক্রিয়',
                          style: AppTextStyles.label
                              .copyWith(color: AppColors.emergencyRed)),
                    ),
                    IconButton(
                      onPressed: ctrl.clearSelection,
                      icon: const Icon(Icons.close_rounded, size: 18),
                      color: PanelPalette.textSecondary,
                      tooltip: 'বাতিল',
                    ),
                  ],
                ),
              );
            }),

            // ── Unassigned members you can adopt ────────────────────────
            // The migration leaves the legacy ANM with no supervisor; this is
            // how a newly created BMHO pulls her into the tree.
            Obx(() {
              final free = ctrl.unassigned;
              if (free.isEmpty) return const SizedBox.shrink();
              return Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warningYellow.withValues(alpha: 0.10),
                  borderRadius: AppRadius.mdR,
                  border: Border.all(
                      color: AppColors.warningYellow.withValues(alpha: 0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person_search_rounded,
                            size: 16, color: AppColors.warningYellow),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text('${free.length} জন $child কোনো দলে নেই',
                              style: AppTextStyles.label),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...free.map((u) => Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text('${u.name} · ${u.phone}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.caption),
                              ),
                              TextButton(
                                onPressed: () => _adopt(ctrl, u),
                                style: TextButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 10),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text('দলে নিন',
                                    style: AppTextStyles.label
                                        .copyWith(color: PanelPalette.primary)),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              );
            }),

            // ── List ────────────────────────────────────────────
            Expanded(
              child: Obx(() {
                if (ctrl.isLoading.value) {
                  return SkeletonList(
                    count: 4,
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    builder: (_) => const SkeletonPatientCard(),
                  );
                }
                if (ctrl.ashaWorkers.isEmpty) {
                  return EmptyState(
                    icon: Icons.people_outline_rounded,
                    title: 'এখনও কোনো $child যোগ করা হয়নি',
                    subtitle: 'উপরের + বোতাম দিয়ে আপনার দল তৈরি করুন',
                    action: ElevatedButton.icon(
                      onPressed: () => _showAddSheet(context, ctrl),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text('নতুন $child যোগ করুন'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PanelPalette.primary,
                        foregroundColor: AppColors.onPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.mdR),
                      ),
                    ),
                  );
                }
                final list = ctrl.visibleWorkers;
                if (list.isEmpty) {
                  return EmptyState(
                    icon: Icons.search_off_rounded,
                    title: '"${ctrl.workerQuery.value}" — কিছু পাওয়া যায়নি',
                    subtitle: 'অন্য নাম, মোবাইল বা গ্রাম দিয়ে খুঁজুন',
                  );
                }
                return RefreshIndicator(
                  color: PanelPalette.primary,
                  onRefresh: ctrl.loadAshaWorkers,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final w = list[i];
                      final selecting = ctrl.selectedWorkers.isNotEmpty;
                      return _WorkerCard(
                        worker: w,
                        ctrl: ctrl,
                        selected: ctrl.selectedWorkers.contains(w.id),
                        onLongPress: () => ctrl.toggleSelect(w.id),
                        onTap: () {
                          // Once a selection is running, a tap toggles rather
                          // than navigating — standard multi-select behaviour.
                          if (selecting) {
                            ctrl.toggleSelect(w.id);
                          } else if (w.manages.isNotEmpty) {
                            // Sub-supervisor → drill into their team.
                            _showTeamSheet(context, w, ctrl);
                          } else {
                            // ASHA leaf → her patients & reports.
                            _showWorkerDetail(context, w, ctrl);
                          }
                        },
                      );
                    },
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
    final child = Get.find<AuthController>().user.value?.manages ?? 'ASHA';
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
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
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
                Text('নতুন $child যোগ করুন', style: AppTextStyles.h3),
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
                                    colorText: AppColors.onPrimary,
                                    snackPosition: SnackPosition.BOTTOM,
                                    margin: const EdgeInsets.all(16),
                                    borderRadius: 12,
                                  );
                                } else {
                                  Get.snackbar(
                                    'error'.tr,
                                    ctrl.errorMsg.value,
                                    backgroundColor: AppColors.emergencyRed,
                                    colorText: AppColors.onPrimary,
                                    snackPosition: SnackPosition.BOTTOM,
                                    margin: const EdgeInsets.all(16),
                                    borderRadius: 12,
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PanelPalette.primary,
                          foregroundColor: AppColors.onPrimary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.lgR),
                        ),
                        child: saving.value
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    color: AppColors.onPrimary, strokeWidth: 2))
                            : Text('admin_save'.tr, style: AppTextStyles.labelLg.copyWith(color: AppColors.onPrimary)),
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
        builder: (sheetCtx, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
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
                          color: PanelPalette.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle),
                      child: UserAvatar(
                        user: worker,
                        size: 52,
                        backgroundColor: PanelPalette.primary.withValues(alpha: 0.1),
                        textColor: PanelPalette.primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(worker.name, style: AppTextStyles.h3),
                          Text(worker.phone, style: AppTextStyles.bodySm),
                          if (worker.block.isNotEmpty)
                            Text('${worker.block}, ${worker.district}',
                                style: AppTextStyles.caption),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                          color: (worker.isActive
                                  ? AppColors.safeGreen
                                  : PanelPalette.textSecondary)
                              .withValues(alpha: 0.1),
                          borderRadius: AppRadius.smR),
                      child: Text(
                        worker.isActive
                            ? 'admin_active'.tr
                            : 'admin_inactive'.tr,
                        style: AppTextStyles.overline.copyWith(
                          color: worker.isActive
                              ? AppColors.safeGreen
                              : PanelPalette.textSecondary,
                        ),
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
                        'patients'.tr, PanelPalette.primary),
                    const SizedBox(width: 10),
                    _StatChip(Icons.analytics_rounded, '${reports.length}',
                        'reports'.tr, AppColors.purple),
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
                      Text('patients'.tr, style: AppTextStyles.label),
                      const SizedBox(height: 8),
                      ...patients.map((p) => _PatientRow(p,
                          onTap: () => Get.toNamed(
                              AppRoutes.patientProfile, arguments: p))),
                      const SizedBox(height: 16),
                    ],
                    if (reports.isNotEmpty) ...[
                      Text('reports'.tr, style: AppTextStyles.label),
                      const SizedBox(height: 8),
                      ...reports.map((r) => _ReportRow(r,
                          onTap: () => showAdminReportDetail(sheetCtx, r))),
                    ],
                    if (patients.isEmpty && reports.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 32),
                          child: Text('admin_no_activity'.tr, style: AppTextStyles.body.copyWith(color: PanelPalette.textSecondary)),
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
                      foregroundColor: AppColors.onPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.lgR),
                    ),
                    child: Text(
                      worker.isActive
                          ? 'admin_remove'.tr
                          : 'admin_reactivate'.tr,
                      style: AppTextStyles.labelLg.copyWith(color: AppColors.onPrimary),
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

  // ── Adopt an unattached member into my team ───────────────────────────────
  Future<void> _adopt(AdminController ctrl, UserModel u) async {
    final ok = await ctrl.adopt(u.id);
    Get.snackbar(
      ok ? 'দলে যোগ হয়েছে' : 'যোগ করা যায়নি',
      ok ? '${u.name} এখন আপনার দলে' : ctrl.errorMsg.value,
      backgroundColor: ok ? AppColors.safeGreen : AppColors.emergencyRed,
      colorText: AppColors.onPrimary,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
    );
  }

  // ── Bulk activate / deactivate the current selection ──────────────────────
  // Reports the honest count (ok/total) — a partial failure must not read as
  // a clean success when someone's account was left untouched.
  Future<void> _runBulk(
      BuildContext context, AdminController ctrl, bool active) async {
    final n = ctrl.selectedWorkers.length;
    final ok = await ctrl.bulkSetActive(active);
    if (!context.mounted) return;
    final allGood = ok == n;
    Get.snackbar(
      active ? 'সক্রিয় করা হয়েছে' : 'নিষ্ক্রিয় করা হয়েছে',
      allGood ? '$ok জন সম্পন্ন' : '$n জনের মধ্যে $ok জন সম্পন্ন',
      backgroundColor: allGood
          ? (active ? AppColors.safeGreen : AppColors.emergencyRed)
          : AppColors.warningYellow,
      colorText: AppColors.onPrimary,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
    );
  }

  // ── Team drill-down sheet (a sub-supervisor's direct reports) ──────────────
  // Recurses down the tree: tapping a member who is themselves a supervisor
  // opens their team; an ASHA leaf opens her patients & reports.
  void _showTeamSheet(
      BuildContext context, UserModel node, AdminController ctrl) async {
    final team = await ctrl.getWorkerTeam(node.id);
    if (!context.mounted) return;
    final childLabel = node.manages; // what THIS node manages, e.g. 'ASHA'

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (sheetCtx, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.xxl)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2))),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                          color: PanelPalette.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle),
                      child: UserAvatar(
                          user: node,
                          size: 46,
                          backgroundColor:
                              PanelPalette.primary.withValues(alpha: 0.1),
                          textColor: PanelPalette.primary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(node.name, style: AppTextStyles.h3),
                          Text('${node.roleShort} · ${team.length} $childLabel',
                              style: AppTextStyles.caption),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: team.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 32),
                          child: Text('এখনও কোনো $childLabel যোগ করা হয়নি',
                              style: AppTextStyles.body
                                  .copyWith(color: PanelPalette.textSecondary)),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                        itemCount: team.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _WorkerCard(
                          worker: team[i],
                          ctrl: ctrl,
                          onTap: () {
                            final m = team[i];
                            Navigator.of(sheetCtx).pop();
                            if (m.manages.isNotEmpty) {
                              _showTeamSheet(context, m, ctrl);
                            } else {
                              _showWorkerDetail(context, m, ctrl);
                            }
                          },
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
        style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: PanelPalette.primary, size: 20),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
              borderRadius: AppRadius.mdR,
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: AppRadius.mdR,
              borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          focusedBorder: OutlineInputBorder(
              borderRadius: AppRadius.mdR,
              borderSide:
                  BorderSide(color: PanelPalette.primary, width: 1.5)),
          errorBorder: OutlineInputBorder(
              borderRadius: AppRadius.mdR,
              borderSide:
                  const BorderSide(color: AppColors.emergencyRed)),
          focusedErrorBorder: OutlineInputBorder(
              borderRadius: AppRadius.mdR,
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
  final VoidCallback? onLongPress; // long-press starts multi-select
  final bool selected;

  const _WorkerCard({
    required this.worker,
    required this.ctrl,
    required this.onTap,
    this.onLongPress,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor =
        worker.isActive ? AppColors.safeGreen : PanelPalette.textSecondary;

    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.xlR,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: AppRadius.xlR,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected
                ? PanelPalette.primary.withValues(alpha: 0.06)
                : AppColors.surface,
            borderRadius: AppRadius.xlR,
            boxShadow: AppShadows.low,
            border: selected
                ? Border.all(color: PanelPalette.primary, width: 1.5)
                : null,
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                        color: PanelPalette.primary.withValues(alpha: 0.08),
                        shape: BoxShape.circle),
                    child: UserAvatar(
                      user: worker,
                      size: 46,
                      backgroundColor:
                          PanelPalette.primary.withValues(alpha: 0.08),
                      textColor: PanelPalette.primary,
                    ),
                  ),
                  if (selected)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                            color: PanelPalette.primary, shape: BoxShape.circle),
                        child: const Icon(Icons.check_rounded,
                            size: 12, color: AppColors.onPrimary),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(worker.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.labelLg),
                        ),
                        // Role tag — tells a CMHO at a glance whether this row
                        // is a BMHO, an ANM or an ASHA.
                        if (worker.manages.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color:
                                    PanelPalette.primary.withValues(alpha: 0.10),
                                borderRadius: AppRadius.smR),
                            child: Text(worker.roleShort,
                                style: AppTextStyles.overline
                                    .copyWith(color: PanelPalette.primary)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(worker.phone, style: AppTextStyles.caption),
                    if (worker.block.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text('${worker.block}, ${worker.district}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption),
                    ],
                    const SizedBox(height: 5),
                    // Aggregates from the server: a supervisor row summarises
                    // their WHOLE subtree; an ASHA row is her own numbers.
                    Row(
                      children: [
                        if (worker.teamSize > 0)
                          _MiniStat(Icons.groups_rounded, '${worker.teamSize} ASHA')
                        else
                          _MiniStat(
                              Icons.people_alt_rounded, '${worker.patientCount}'),
                        const SizedBox(width: 12),
                        _MiniStat(
                            Icons.analytics_rounded, '${worker.reportCount}'),
                        if (worker.redCount > 0) ...[
                          const SizedBox(width: 12),
                          _MiniStat(Icons.gpp_bad_rounded, '${worker.redCount}',
                              color: AppColors.emergencyRed),
                        ],
                      ],
                    ),
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
                        borderRadius: AppRadius.smR),
                    child: Text(
                      worker.isActive
                          ? 'admin_active'.tr
                          : 'admin_inactive'.tr,
                      style: AppTextStyles.overline.copyWith(color: statusColor),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Icon(Icons.chevron_right_rounded,
                      size: 18, color: PanelPalette.textSecondary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Mini stat (icon + number) used on the worker cards ────────────────────────
class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color? color;
  const _MiniStat(this.icon, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? PanelPalette.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: c.withValues(alpha: 0.85)),
        const SizedBox(width: 3),
        Text(value,
            style: AppTextStyles.overline
                .copyWith(color: c, fontWeight: FontWeight.w700)),
      ],
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
            borderRadius: AppRadius.mdR),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: AppTextStyles.h3.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                    )),
                Text(label, style: AppTextStyles.caption),
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
  final VoidCallback? onTap;
  const _PatientRow(this.p, {this.onTap});

  @override
  Widget build(BuildContext context) {
    final risk = p['risk']?.toString() ?? 'safe';
    final color = risk == 'emergency'
        ? AppColors.emergencyRed
        : risk == 'high'
            ? AppColors.warningYellow
            : AppColors.safeGreen;

    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: AppRadius.mdR,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdR,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: AppRadius.mdR,
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
                    style: AppTextStyles.label),
              ),
              Text(p['type']?.toString() ?? '', style: AppTextStyles.caption),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded,
                  size: 16, color: PanelPalette.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Report row ─────────────────────────────────────────────────────────────────
class _ReportRow extends StatelessWidget {
  final Map<String, dynamic> r;
  final VoidCallback? onTap;
  const _ReportRow(this.r, {this.onTap});

  @override
  Widget build(BuildContext context) {
    final band = r['finalBand']?.toString().toUpperCase() ?? '';
    final color = band == 'RED'
        ? AppColors.emergencyRed
        : band == 'YELLOW'
            ? AppColors.warningYellow
            : AppColors.safeGreen;

    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: AppRadius.mdR,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdR,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: AppRadius.mdR,
              border: Border.all(color: color.withValues(alpha: 0.2))),
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: AppRadius.smR),
                child: Text(band,
                    style: AppTextStyles.overline.copyWith(color: color)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(r['caseLabel']?.toString() ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded,
                  size: 16, color: PanelPalette.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
