import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/pdf_helper.dart';
import '../../../admin/controller/admin_controller.dart';
import 'admin_deleted_reports_screen.dart';
import 'admin_report_detail.dart';

class AdminReportsTab extends StatefulWidget {
  const AdminReportsTab({super.key});

  @override
  State<AdminReportsTab> createState() => _AdminReportsTabState();
}

class _AdminReportsTabState extends State<AdminReportsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => Get.find<AdminController>().loadReports());
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
                  Expanded(
                    child: Text('Reports', style: AppTextStyles.h2),
                  ),
                  Obx(() {
                    final activeCount = [
                      ctrl.selectedWorkerId.value,
                      ctrl.selectedDistrict.value,
                      ctrl.selectedBlock.value,
                    ].where((e) => e != null).length;
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton(
                          onPressed: () => _openFilterSheet(context, ctrl),
                          style: IconButton.styleFrom(
                            backgroundColor: activeCount > 0
                                ? AppColors.primary.withValues(alpha: 0.12)
                                : Colors.grey.shade100,
                            padding: const EdgeInsets.all(10),
                          ),
                          icon: const Icon(Icons.filter_alt_rounded,
                              color: AppColors.primary, size: 20),
                          tooltip: 'Filter by worker / location',
                        ),
                        if (activeCount > 0)
                          Positioned(
                            top: 4, right: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: const BoxDecoration(
                                color: AppColors.accent,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                              child: Text(
                                '$activeCount',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  }),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Get.to(() => const AdminDeletedReportsScreen()),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey.shade100,
                      padding: const EdgeInsets.all(10),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: AppColors.emergencyRed, size: 20),
                    tooltip: 'Deleted reports',
                  ),
                  const SizedBox(width: 8),
                  Obx(() => IconButton(
                        onPressed: ctrl.filteredReports.isEmpty
                            ? null
                            : () => _downloadPdf(ctrl.filteredReports.toList()),
                        style: IconButton.styleFrom(
                          backgroundColor: ctrl.filteredReports.isEmpty
                              ? Colors.grey.shade200
                              : AppColors.primary,
                          padding: const EdgeInsets.all(10),
                        ),
                        icon: Icon(Icons.download_rounded,
                            color: ctrl.filteredReports.isEmpty
                                ? AppColors.textSecondary
                                : AppColors.onPrimary,
                            size: 20),
                        tooltip: 'Download PDF',
                      )),
                ],
              ),
            ),

            // ── Filter chips ─────────────────────────────────────
            Obx(() => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Row(
                    children: [
                      _FilterChip(
                          label: 'admin_filter_all'.tr,
                          selected: ctrl.filterMode.value == 'all',
                          onTap: () => ctrl.setFilter('all')),
                      const SizedBox(width: 8),
                      _FilterChip(
                          label: '🔴 Red',
                          selected: ctrl.filterMode.value == 'red',
                          color: AppColors.emergencyRed,
                          onTap: () => ctrl.setFilter('red')),
                      const SizedBox(width: 8),
                      _FilterChip(
                          label: '🟡 Yellow',
                          selected: ctrl.filterMode.value == 'yellow',
                          color: AppColors.warningYellow,
                          onTap: () => ctrl.setFilter('yellow')),
                      const SizedBox(width: 8),
                      _FilterChip(
                          label: '🟢 Green',
                          selected: ctrl.filterMode.value == 'green',
                          color: AppColors.safeGreen,
                          onTap: () => ctrl.setFilter('green')),
                      const SizedBox(width: 8),
                      _FilterChip(
                          label: '📅 Day',
                          selected: ctrl.filterMode.value == 'day',
                          onTap: () => _pickDate(context, ctrl, 'day')),
                      const SizedBox(width: 8),
                      _FilterChip(
                          label: '📆 Month',
                          selected: ctrl.filterMode.value == 'month',
                          onTap: () => _pickDate(context, ctrl, 'month')),
                      const SizedBox(width: 8),
                      _FilterChip(
                          label: '🗓 Year',
                          selected: ctrl.filterMode.value == 'year',
                          onTap: () => _pickDate(context, ctrl, 'year')),
                    ],
                  ),
                )),

            // ── Summary row ──────────────────────────────────────
            Obx(() => Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Row(
                    children: [
                      _SummaryChip('Total ${ctrl.totalReports}',
                          AppColors.primary),
                      const SizedBox(width: 8),
                      _SummaryChip('🔴 ${ctrl.redReports}',
                          AppColors.emergencyRed),
                      const SizedBox(width: 8),
                      _SummaryChip('🟡 ${ctrl.yellowReports}',
                          AppColors.warningYellow),
                      const SizedBox(width: 8),
                      _SummaryChip('🟢 ${ctrl.greenReports}',
                          AppColors.safeGreen),
                    ],
                  ),
                )),

            // ── Report list ──────────────────────────────────────
            Expanded(
              child: Obx(() {
                if (ctrl.isLoading.value) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 3));
                }
                if (ctrl.filteredReports.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bar_chart_outlined,
                            size: 64,
                            color: AppColors.textSecondary
                                .withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        Text('admin_no_reports'.tr, style: AppTextStyles.bodySm),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: ctrl.loadReports,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    itemCount: ctrl.filteredReports.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final r = ctrl.filteredReports[i];
                      return _ReportCard(
                        r: r,
                        onTap: () => showAdminReportDetail(context, r),
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

  Future<void> _pickDate(BuildContext context, AdminController ctrl, String mode) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: ctrl.filterDate.value ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDatePickerMode:
          mode == 'year' ? DatePickerMode.year : DatePickerMode.day,
      helpText: mode == 'day'
          ? 'Select Day'
          : mode == 'month'
              ? 'Select Month'
              : 'Select Year',
    );
    if (picked != null) ctrl.setFilter(mode, date: picked);
  }

  Future<void> _downloadPdf(List<dynamic> reports) async {
    if (reports.isEmpty) {
      Get.snackbar('No reports', 'Nothing to export', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    // Cap at 100 so the file stays openable on low-RAM admin tablets.
    final wasCapped = reports.length > 100;
    if (wasCapped) reports = reports.take(100).toList();

    try {
      final theme = await PdfHelper.bengaliTheme();
      final doc = pw.Document(theme: theme);
      final maps = reports.map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}).toList();

      // Stats
      final total = maps.length;
      final red = maps.where((r) => (r['finalBand']?.toString() ?? '').toUpperCase() == 'RED').length;
      final yellow = maps.where((r) => (r['finalBand']?.toString() ?? '').toUpperCase() == 'YELLOW').length;
      final green = maps.where((r) => (r['finalBand']?.toString() ?? '').toUpperCase() == 'GREEN').length;

      // Per-worker breakdown
      final byWorker = <String, int>{};
      for (final r in maps) {
        final w = (r['ashaName']?.toString().trim().isNotEmpty == true)
            ? r['ashaName'].toString()
            : (r['ashaId']?.toString() ?? '—');
        byWorker[w] = (byWorker[w] ?? 0) + 1;
      }
      final workerList = byWorker.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // Per-case-type breakdown
      final byCase = <String, int>{};
      for (final r in maps) {
        final c = r['caseLabel']?.toString() ?? r['caseType']?.toString() ?? '—';
        byCase[c] = (byCase[c] ?? 0) + 1;
      }

      PdfColor bandColor(String b) => switch (b.toUpperCase()) {
            'RED'    => const PdfColor.fromInt(0xFFDC2626),
            'YELLOW' => const PdfColor.fromInt(0xFFD97706),
            'GREEN'  => const PdfColor.fromInt(0xFF16A34A),
            _        => PdfColors.grey500,
          };

      pw.Widget statBox(String label, String value, PdfColor color) =>
          pw.Expanded(
            child: pw.Container(
              margin: const pw.EdgeInsets.symmetric(horizontal: 4),
              padding: const pw.EdgeInsets.symmetric(vertical: 10),
              decoration: pw.BoxDecoration(
                color: color,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Column(children: [
                pw.Text(value,
                    style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white)),
                pw.SizedBox(height: 2),
                pw.Text(label,
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.white)),
              ]),
            ),
          );

      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        maxPages: 200,
        header: (ctx) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 6),
          decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColor.fromInt(0xFF4F46E5), width: 1.5))),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('ASHA Mitra — Admin Reports',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF4F46E5))),
              pw.Text('Page ${ctx.pageNumber}/${ctx.pagesCount}',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
            ],
          ),
        ),
        footer: (ctx) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 6),
          decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
          child: pw.Text(
              'Confidential clinical record  ·  Generated ${DateTime.now().toString().substring(0, 16)}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
              textAlign: pw.TextAlign.center),
        ),
        build: (ctx) => [
          // ── Cover summary ─────────────────────────────────────
          pw.SizedBox(height: 8),
          pw.Text('ADMIN SUMMARY',
              style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey600,
                  letterSpacing: 1.5)),
          pw.SizedBox(height: 10),
          pw.Row(children: [
            statBox('Total', '$total', const PdfColor.fromInt(0xFF4F46E5)),
            statBox('RED', '$red', const PdfColor.fromInt(0xFFDC2626)),
            statBox('YELLOW', '$yellow', const PdfColor.fromInt(0xFFD97706)),
            statBox('GREEN', '$green', const PdfColor.fromInt(0xFF16A34A)),
          ]),
          if (wasCapped) ...[
            pw.SizedBox(height: 6),
            pw.Text(
                'Showing newest 100 of ${reports.length}. Use date / band filters to scope older sessions.',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.orange700)),
          ],
          pw.SizedBox(height: 18),

          // ── Per-worker breakdown ──────────────────────────────
          pw.Text('BY WORKER',
              style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey600,
                  letterSpacing: 1.5)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: ['ASHA worker', 'Reports', '% of total'],
            data: workerList
                .map((e) => [e.key, '${e.value}', '${(e.value / total * 100).toStringAsFixed(1)}%'])
                .toList(),
            headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.white),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColor.fromInt(0xFF4F46E5)),
            cellStyle: const pw.TextStyle(fontSize: 10),
            cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.center, 2: pw.Alignment.center},
            oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF0F0FF)),
          ),
          pw.SizedBox(height: 18),

          // ── Per-case-type breakdown ───────────────────────────
          pw.Text('BY CASE TYPE',
              style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey600,
                  letterSpacing: 1.5)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: ['Case type', 'Count', '% of total'],
            data: byCase.entries
                .map((e) => [e.key, '${e.value}', '${(e.value / total * 100).toStringAsFixed(1)}%'])
                .toList(),
            headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.white),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColor.fromInt(0xFF6366F1)),
            cellStyle: const pw.TextStyle(fontSize: 10),
            cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.center, 2: pw.Alignment.center},
            oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF5F5FF)),
          ),
          pw.SizedBox(height: 20),

          // ── Per-report detail table ───────────────────────────
          pw.Text('SESSION DETAILS  ($total records)',
              style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey600,
                  letterSpacing: 1.5)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Worker', 'Patient', 'Case', 'Band', 'Risk', 'Facility'],
            data: maps.map((r) => [
              _fmtDate(r['createdAt']?.toString() ?? ''),
              r['ashaName']?.toString() ?? '—',
              r['patientName']?.toString().isNotEmpty == true
                  ? r['patientName'].toString()
                  : 'Anonymous',
              r['caseLabel']?.toString() ?? r['caseType']?.toString() ?? '—',
              r['finalBand']?.toString() ?? '—',
              '${r['riskScore'] ?? 0}',
              r['facilityType']?.toString() ?? '—',
            ]).toList(),
            headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColor.fromInt(0xFF4F46E5)),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.centerLeft,
              4: pw.Alignment.center,
              5: pw.Alignment.center,
              6: pw.Alignment.centerLeft,
            },
            cellDecoration: (i, data, j) => i == 0
                ? const pw.BoxDecoration()
                : (j == 4 && data is String && data.isNotEmpty)
                    ? pw.BoxDecoration(color: bandColor(data).shade(0.85))
                    : const pw.BoxDecoration(),
            oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFFAFAFF)),
          ),
        ],
      ));

      final bytes = await doc.save().timeout(const Duration(seconds: 60));
      final fileName =
          'asha_mitra_admin_reports_${DateTime.now().millisecondsSinceEpoch}.pdf';
      await PdfHelper.saveAndOpen(bytes, fileName)
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      Get.snackbar('PDF generation failed', 'Could not generate PDF: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.emergencyRed,
          colorText: AppColors.onPrimary,
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 5));
    }
  }

  String _fmtDate(String iso) {
    try {
      return DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }

  void _openFilterSheet(BuildContext context, AdminController ctrl) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Obx(() {
            final workers = ctrl.ashaWorkers;
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(child: Text('Filter reports', style: AppTextStyles.h2)),
                      if (ctrl.selectedWorkerId.value != null ||
                          ctrl.selectedDistrict.value != null ||
                          ctrl.selectedBlock.value   != null)
                        TextButton.icon(
                          onPressed: () { ctrl.clearLocationFilters(); Get.back(); },
                          icon: const Icon(Icons.clear_rounded, size: 16),
                          label: const Text('Clear'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Worker ─────────────────────────────────────────────
                  Text('ASHA WORKER', style: AppTextStyles.overline),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String?>(
                    initialValue: ctrl.selectedWorkerId.value,
                    isExpanded: true,
                    decoration: const InputDecoration(),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('সব ASHA — All workers')),
                      for (final w in workers)
                        DropdownMenuItem<String?>(
                          value: w.id,
                          child: Text('${w.name} · ${w.phone}', overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) => ctrl.selectedWorkerId.value = v,
                  ),
                  const SizedBox(height: 16),

                  // ── District ──────────────────────────────────────────
                  Text('DISTRICT', style: AppTextStyles.overline),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String?>(
                    initialValue: ctrl.selectedDistrict.value,
                    isExpanded: true,
                    decoration: const InputDecoration(),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('সব জেলা — All districts')),
                      for (final d in ctrl.districts)
                        DropdownMenuItem<String?>(value: d, child: Text(d)),
                    ],
                    onChanged: (v) => ctrl.selectedDistrict.value = v,
                  ),
                  const SizedBox(height: 16),

                  // ── Block ─────────────────────────────────────────────
                  Text('BLOCK', style: AppTextStyles.overline),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String?>(
                    initialValue: ctrl.selectedBlock.value,
                    isExpanded: true,
                    decoration: const InputDecoration(),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('সব ব্লক — All blocks')),
                      for (final b in ctrl.blocks)
                        DropdownMenuItem<String?>(value: b, child: Text(b)),
                    ],
                    onChanged: (v) => ctrl.selectedBlock.value = v,
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () { ctrl.applyLocationFilters(); Get.back(); },
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Apply filters'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ── Filter chip ────────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  const _FilterChip(
      {required this.label,
      required this.selected,
      required this.onTap,
      this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return Material(
      color: selected ? c : AppColors.surface,
      borderRadius: AppRadius.pillR,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.pillR,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? c : AppColors.surface,
            borderRadius: AppRadius.pillR,
            border: Border.all(
                color: selected ? c : AppColors.cardBorder),
          ),
          child: Text(label,
              style: AppTextStyles.label.copyWith(
                color: selected ? AppColors.onPrimary : AppColors.textSecondary,
              )),
        ),
      ),
    );
  }
}

// ── Summary chip ───────────────────────────────────────────────────────────────
class _SummaryChip extends StatelessWidget {
  final String label;
  final Color color;
  const _SummaryChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: AppRadius.smR),
      child: Text(label,
          style: AppTextStyles.overline.copyWith(color: color)),
    );
  }
}

// ── Report card ────────────────────────────────────────────────────────────────
class _ReportCard extends StatelessWidget {
  final Map<String, dynamic> r;
  final VoidCallback onTap;
  const _ReportCard({required this.r, required this.onTap});

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

    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.lgR,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lgR,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.lgR,
            border: Border.all(color: color.withValues(alpha: 0.25)),
            boxShadow: AppShadows.low,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle),
                child: Center(
                  child: Text(
                    band.isNotEmpty ? band[0] : '?',
                    style: AppTextStyles.label.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (caseLabel.isNotEmpty)
                      Text(caseLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.label),
                    if (patientName.isNotEmpty)
                      Text(patientName, style: AppTextStyles.caption),
                    if ((r['ashaName']?.toString() ?? '').isNotEmpty)
                      Text('ASHA: ${r['ashaName']}',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          )),
                    Text(fmtDate, style: AppTextStyles.caption),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: AppRadius.smR),
                child: Text(band,
                    style: AppTextStyles.overline.copyWith(color: color)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── (report detail moved to admin_report_detail.dart) ───────────────────────
