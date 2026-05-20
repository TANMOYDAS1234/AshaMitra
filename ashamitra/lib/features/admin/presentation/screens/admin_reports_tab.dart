import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/utils/pdf_helper.dart';
import '../../../admin/controller/admin_controller.dart';

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
                  const Expanded(
                    child: Text('Reports',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.onBackground)),
                  ),
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
                                : Colors.white,
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
                        Text('admin_no_reports'.tr,
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14)),
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
                        onTap: () => _showDetail(context, r),
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

  void _showDetail(BuildContext context, Map<String, dynamic> r) {
    final band = r['finalBand']?.toString().toUpperCase() ?? '';
    final color = band == 'RED'
        ? AppColors.emergencyRed
        : band == 'YELLOW'
            ? AppColors.warningYellow
            : AppColors.safeGreen;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
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
              // Band badge + case label
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10)),
                    child: Text(band,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: color)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(r['caseLabel']?.toString() ?? '',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onBackground)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _DetailRow('Patient', r['patientName']?.toString() ?? '-'),
              _DetailRow('Risk Score', '${r['riskScore'] ?? 0}'),
              _DetailRow('Risk Level', r['riskLevel']?.toString() ?? '-'),
              _DetailRow('Facility', r['facilityType']?.toString() ?? '-'),
              _DetailRow('Recheck After',
                  '${r['recheckAfterHours'] ?? 0} hrs'),
              if ((r['reason']?.toString() ?? '').isNotEmpty)
                _DetailRow('Reason', r['reason'].toString()),
              if ((r['nextStep']?.toString() ?? '').isNotEmpty)
                _DetailRow('Next Step', r['nextStep'].toString()),
              if ((r['dangerSigns'] as List?)?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                const Text('Danger Signs',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: (r['dangerSigns'] as List)
                      .map((s) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                                color: AppColors.emergencyRed
                                    .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8)),
                            child: Text(s.toString(),
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.emergencyRed)),
                          ))
                      .toList(),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                _fmtDate(r['createdAt']?.toString() ?? ''),
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _downloadPdf(List<dynamic> reports) async {
    try {
      final doc = pw.Document();
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (ctx) => [
            pw.Text('ASHA Mitra — Admin Reports',
                style: pw.TextStyle(
                    fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text(
                'Generated: ${DateTime.now().toString().substring(0, 16)}',
                style: const pw.TextStyle(
                    fontSize: 10, color: PdfColors.grey600)),
            pw.Text('Total: ${reports.length}',
                style: const pw.TextStyle(
                    fontSize: 11, color: PdfColors.grey700)),
            pw.Divider(height: 20),
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Patient', 'Case', 'Band', 'Facility'],
              data: reports.map((item) {
                final Map<String, dynamic> r = item is Map
                    ? Map<String, dynamic>.from(item)
                    : {};
                return [
                  _fmtDate(r['createdAt']?.toString() ?? ''),
                  r['patientName']?.toString() ?? '',
                  r['caseLabel']?.toString() ?? '',
                  r['finalBand']?.toString() ?? '',
                  r['facilityType']?.toString() ?? '',
                ];
              }).toList(),
              headerStyle:
                  pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.indigo100),
              cellAlignment: pw.Alignment.centerLeft,
              cellStyle: const pw.TextStyle(fontSize: 9),
            ),
          ],
        ),
      );
      await PdfHelper.saveAndOpen(
          doc,
          'admin_reports_${DateTime.now().millisecondsSinceEpoch}.pdf');
    } catch (e) {
      Get.snackbar('Error', 'Could not generate PDF: $e',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  String _fmtDate(String iso) {
    try {
      return DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? c : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? c : const Color(0xFFE0E7FF)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textSecondary)),
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
          borderRadius: BorderRadius.circular(10)),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
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

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
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
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
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
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onBackground)),
                  if (patientName.isNotEmpty)
                    Text(patientName,
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary)),
                  Text(fmtDate,
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(band,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: color)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Detail row ─────────────────────────────────────────────────────────────────
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty || value == '-') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value,
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
