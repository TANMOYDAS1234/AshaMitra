import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/services/local_storage_service.dart';
import '../../../../shared/components/app_header.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../controller/patient_controller.dart';
import '../../data/models/patient_model.dart';
import '../../services/mcp_report_pdf.dart';

/// A mother's pregnancy episodes, newest first — every pregnancy of the SAME
/// woman (grouped via motherPersonId / Aadhaar / name+phone), each with its own
/// LMP/EDD/outcome + a one-tap report. Reached from a pregnant patient's
/// profile. A new MCP card is issued each pregnancy, so this shows the full arc.
class PregnancyTimelineScreen extends StatelessWidget {
  const PregnancyTimelineScreen({super.key, required this.patientId});
  final String patientId;

  Map<String, String> _header() {
    final u = LocalStorageService.loadUser() ?? const {};
    String s(List<String> keys) {
      for (final k in keys) {
        final v = (u[k] ?? '').toString().trim();
        if (v.isNotEmpty) return v;
      }
      return '';
    }
    return {
      'asha': s(['name', 'fullName']),
      'block': s(['block']),
      'district': s(['district']),
      'facility': s(['subCentre', 'subcentre', 'facilityName', 'facility']),
    };
  }

  String _fmt(DateTime? d) {
    if (d == null) return '—';
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(d.day)}/${p(d.month)}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<PatientController>();
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          child: Column(
            children: [
              AppHeader(title: 'গর্ভ-ইতিহাস (সব গর্ভ)'),
              const SizedBox(height: 8),
              Expanded(
                child: Obx(() {
                  final idx =
                      ctrl.patients.indexWhere((p) => p.id == patientId);
                  if (idx == -1) {
                    return Center(
                      child: Text('রোগীর তথ্য পাওয়া যায়নি',
                          style: AppTextStyles.body
                              .copyWith(color: AppColors.textSecondary)),
                    );
                  }
                  final mother = ctrl.patients[idx];
                  final episodes = ctrl.pregnancyEpisodesFor(mother);
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10, left: 4),
                        child: Text(
                          '${mother.name} — ${episodes.length} টি গর্ভ',
                          style: AppTextStyles.label
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                      for (var i = 0; i < episodes.length; i++)
                        _episodeCard(
                          context,
                          episodes[i],
                          // Newest first → highest number is the latest pregnancy.
                          number: episodes.length - i,
                          isCurrent: episodes[i].id == patientId,
                        ),
                    ],
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _episodeCard(BuildContext context, PatientModel e,
      {required int number, required bool isCurrent}) {
    final md = e.mcpDetails;
    final highRisk = md['highRisk'] == true;
    final outcome = (md['pregnancyOutcome'] ?? '').toString();
    final accent = highRisk ? AppColors.emergencyRed : AppColors.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgR,
        boxShadow: AppShadows.low,
        border: Border(left: BorderSide(color: accent, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('গর্ভ #$number', style: AppTextStyles.h3),
              const SizedBox(width: 8),
              if (isCurrent)
                _pill('বর্তমান', AppColors.primary),
              const Spacer(),
              if (highRisk) _pill('উচ্চ ঝুঁকি', AppColors.emergencyRed),
            ],
          ),
          const SizedBox(height: 8),
          _row('LMP', _fmt(e.lmp)),
          _row('সম্ভাব্য প্রসব (EDD)', _fmt(e.edd)),
          if ((md['gravida'] ?? '').toString().isNotEmpty)
            _row('গর্ভ (G/P/L)',
                '${md['gravida']}/${md['para'] ?? ''}/${md['prevLiveBirths'] ?? ''}'),
          _row('ফলাফল', outcome.isNotEmpty ? outcome : 'চলমান'),
          if (highRisk && (md['highRiskReason'] ?? '').toString().isNotEmpty)
            _row('ঝুঁকি', md['highRiskReason'].toString()),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'প্রোফাইল',
                  outlined: true,
                  icon: Icons.person_outline,
                  width: double.infinity,
                  onPressed: () => Get.toNamed(AppRoutes.patientProfile,
                      arguments: e.toJson()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label: 'রিপোর্ট',
                  icon: Icons.picture_as_pdf_outlined,
                  width: double.infinity,
                  onPressed: () => McpReportPdf.generate(e, header: _header()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: AppTextStyles.label.copyWith(
                color: color, fontWeight: FontWeight.w800, fontSize: 11)),
      );

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Text(label,
                  style: AppTextStyles.label
                      .copyWith(color: AppColors.textSecondary)),
            ),
            Expanded(child: Text(value, style: AppTextStyles.body)),
          ],
        ),
      );
}
