import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../admin/controller/admin_controller.dart';
import 'admin_report_detail.dart';

/// Admin audit view of every soft-deleted report. The list is loaded on
/// open via [AdminController.loadDeletedReports] from
/// GET /api/admin/reports/deleted and refreshed on pull-down.
///
/// Each row shows who deleted what and when. Tapping opens the same
/// report-detail bottom sheet used by the live reports tab.
class AdminDeletedReportsScreen extends StatefulWidget {
  const AdminDeletedReportsScreen({super.key});

  @override
  State<AdminDeletedReportsScreen> createState() =>
      _AdminDeletedReportsScreenState();
}

class _AdminDeletedReportsScreenState extends State<AdminDeletedReportsScreen> {
  late final AdminController ctrl = Get.find<AdminController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => ctrl.loadDeletedReports());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deleted reports'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.onBackground,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          child: Obx(() {
            if (ctrl.isLoadingDeleted.value) {
              return const Center(
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 3),
              );
            }
            if (ctrl.deletedReports.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.delete_outline_rounded,
                        size: 64,
                        color: AppColors.textSecondary.withValues(alpha: 0.4)),
                    const SizedBox(height: 12),
                    Text('No deleted reports', style: AppTextStyles.bodySm),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: ctrl.loadDeletedReports,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                itemCount: ctrl.deletedReports.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final r = ctrl.deletedReports[i];
                  return _DeletedReportCard(
                    r: r,
                    onTap: () => showAdminReportDetail(context, r),
                  );
                },
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _DeletedReportCard extends StatelessWidget {
  final Map<String, dynamic> r;
  final VoidCallback onTap;

  const _DeletedReportCard({required this.r, required this.onTap});

  String _fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    try {
      return DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }

  Color _bandColor(String? band) => switch ((band ?? '').toUpperCase()) {
        'RED'    => AppColors.emergencyRed,
        'YELLOW' => AppColors.warningYellow,
        'GREEN'  => AppColors.safeGreen,
        _        => AppColors.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    final patientName  = r['patientName']?.toString().trim();
    final caseLabel    = r['caseLabel']?.toString().trim();
    final band         = r['finalBand']?.toString();
    final ashaName     = r['ashaName']?.toString() ?? '—';
    final ashaDistrict = r['ashaDistrict']?.toString() ?? '';
    final ashaBlock    = r['ashaBlock']?.toString() ?? '';
    final deletedAt    = _fmtDate(r['deletedAt']?.toString());
    final createdAt    = _fmtDate(r['createdAt']?.toString());
    final bandColor    = _bandColor(band);

    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.lgR,
      child: InkWell(
        borderRadius: AppRadius.lgR,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: AppRadius.lgR,
            boxShadow: AppShadows.tinted(AppColors.textSecondary),
            border: Border.all(
              color: bandColor.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: bandColor.withValues(alpha: 0.12),
                      borderRadius: AppRadius.smR,
                    ),
                    child: Icon(Icons.delete_sweep_rounded,
                        color: bandColor, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patientName?.isNotEmpty == true
                              ? patientName!
                              : 'Anonymous report',
                          style: AppTextStyles.body
                              .copyWith(fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (caseLabel != null && caseLabel.isNotEmpty)
                          Text(caseLabel,
                              style: AppTextStyles.caption,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  if (band != null && band.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: bandColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        band,
                        style: AppTextStyles.caption.copyWith(
                          color: bandColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              _MetaRow(
                icon: Icons.person_outline_rounded,
                label: 'Worker',
                value: [
                  ashaName,
                  if (ashaDistrict.isNotEmpty || ashaBlock.isNotEmpty)
                    '· ${[ashaDistrict, ashaBlock].where((s) => s.isNotEmpty).join(', ')}',
                ].join(' '),
              ),
              const SizedBox(height: 6),
              _MetaRow(
                icon: Icons.schedule_rounded,
                label: 'Created',
                value: createdAt,
              ),
              const SizedBox(height: 6),
              _MetaRow(
                icon: Icons.delete_outline_rounded,
                label: 'Deleted',
                value: deletedAt,
                valueColor: AppColors.emergencyRed,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _MetaRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        SizedBox(
          width: 64,
          child: Text(label,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              )),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.caption.copyWith(
              color: valueColor ?? AppColors.onBackground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
