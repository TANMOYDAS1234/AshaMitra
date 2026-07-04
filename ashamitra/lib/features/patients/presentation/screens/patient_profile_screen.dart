import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/components/app_header.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/risk_badge.dart';
import '../../../../shared/widgets/patient_photo.dart';
import '../../controller/patient_controller.dart';
import '../../data/models/patient_model.dart';
import '../../services/mcp_report_pdf.dart';
import '../../../../core/services/local_storage_service.dart';
import '../../../../core/services/api_service.dart';
import '../../../schedule/services/checkup_launcher.dart';
import '../../../referrals/controller/referral_controller.dart';
import '../../../referrals/data/models/referral_model.dart';
import '../../../referrals/presentation/screens/referral_detail_screen.dart';
import '../../../referrals/presentation/screens/referral_form_screen.dart';
import 'pregnancy_timeline_screen.dart';

class PatientProfileScreen extends StatelessWidget {
  const PatientProfileScreen({super.key});

  // Case icon — handles both English (manual patients) and Bengali
  // (triage-created patients) type strings.
  IconData _caseIconData(String type) {
    final t = type.toLowerCase();
    if (t.contains('pregnan') || type.contains('গর্ভ')) {
      return Icons.pregnant_woman_rounded;
    }
    if (t.contains('postpartum') || type.contains('প্রসব')) {
      return Icons.volunteer_activism_rounded;
    }
    if (t.contains('newborn') || type.contains('নবজাতক')) {
      return Icons.child_care_rounded;
    }
    if (t.contains('infant') || type.contains('শিশু')) {
      return Icons.child_friendly_rounded;
    }
    if (t.contains('child')) return Icons.face_rounded;
    if (t.contains('immun') || type.contains('টিকা')) {
      return Icons.vaccines_rounded;
    }
    if (t.contains('emergency') || type.contains('জরুরি')) {
      return Icons.emergency_rounded;
    }
    return Icons.assignment_ind_rounded;
  }

  /// One meta line (village / mobile) — white icon + text on the purple hero.
  Widget _metaRow(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Icon(icon, size: 15, color: Colors.white.withValues(alpha: 0.9)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySm
                      .copyWith(color: Colors.white.withValues(alpha: 0.95))),
            ),
          ],
        ),
      );

  /// Crisp white risk pill that reads cleanly on the purple hero.
  Widget _heroRiskPill(RiskLevel risk) {
    final (label, color, icon) = switch (risk) {
      RiskLevel.safe =>
        ('risk_safe'.tr, AppColors.safeGreen, Icons.check_circle_rounded),
      RiskLevel.moderate => (
          'risk_moderate'.tr,
          AppColors.warningYellow,
          Icons.warning_amber_rounded
        ),
      RiskLevel.high =>
        ('risk_high'.tr, const Color(0xFFF97316), Icons.error_rounded),
      RiskLevel.emergency =>
        ('risk_emergency'.tr, AppColors.emergencyRed, Icons.emergency_rounded),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 5),
        Text(label,
            style: AppTextStyles.caption
                .copyWith(color: color, fontWeight: FontWeight.w800)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final args = (Get.arguments as Map<String, dynamic>?) ?? {};
    final patientId = (args['id'] as String?)?.trim() ?? '';
    final name = (args['name'] as String?)?.trim().isNotEmpty == true
        ? args['name'] as String
        : 'Unknown';
    final type = args['type'] as String? ?? 'Other';
    final village = (args['village'] as String?)?.trim() ?? '';
    final mobile = (args['mobile'] as String?)?.trim() ?? '';
    final lastVisit = (args['lastVisit'] as String?)?.trim();

    // ── Real triage assessment data carried by PatientModel ───────────────
    final outcome = args['outcome'] as String?;
    final reason = (args['reason'] as String?)?.trim() ?? '';
    final nextStep = (args['nextStep'] as String?)?.trim() ?? '';
    final situation = (args['situation'] as String?)?.trim() ?? '';

    final qaHistory = <({String q, String a})>[];
    final qaRaw = args['qaHistory'];
    if (qaRaw is List) {
      for (final e in qaRaw) {
        if (e is Map) {
          final q = (e['question'] ?? '').toString().trim();
          final a = (e['answer'] ?? '').toString().trim();
          if (q.isNotEmpty || a.isNotEmpty) qaHistory.add((q: q, a: a));
        }
      }
    }

    // Risk — derive from outcome so the badge matches the patient list card.
    final riskRaw = args['risk'];
    final risk = switch (outcome) {
      'emergency' => RiskLevel.emergency,
      'attention' => RiskLevel.high,
      'safe'      => RiskLevel.safe,
      _ => riskRaw is RiskLevel
          ? riskRaw
          : switch (riskRaw?.toString() ?? '') {
              'emergency' => RiskLevel.emergency,
              'high'      => RiskLevel.high,
              'moderate'  => RiskLevel.moderate,
              _           => RiskLevel.safe,
            },
    };

    final hasAssessment = (outcome != null && outcome.isNotEmpty) ||
        reason.isNotEmpty ||
        nextStep.isNotEmpty ||
        situation.isNotEmpty ||
        qaHistory.isNotEmpty;

    // Past triage reports linked to this patient (by id, name as fallback).
    final history = <Map<String, dynamic>>[];
    if (Get.isRegistered<PatientController>()) {
      for (final r in Get.find<PatientController>().reports) {
        final rid = (r['patientId'] ?? '').toString();
        final rname = (r['patientName'] ?? '').toString();
        final byId = patientId.isNotEmpty && rid == patientId;
        final byName = name != 'Unknown' && rname.isNotEmpty && rname == name;
        if (byId || (rid.isEmpty && byName)) {
          history.add(Map<String, dynamic>.from(r));
        }
      }
      history.sort((a, b) => (b['createdAt'] ?? '')
          .toString()
          .compareTo((a['createdAt'] ?? '').toString()));
    }

    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final argPhotoB64 = (args['mcpDetails'] is Map)
        ? (args['mcpDetails'] as Map)['photo']?.toString()
        : null;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          child: Column(
            children: [
              AppHeader(
                title: 'prof_patient_profile'.tr,
                actions: [
                  HeaderActionPill(
                    icon: Icons.edit_outlined,
                    label: 'prof_edit'.tr,
                    onTap: () {
                      // Resolve the live PatientModel from the controller so we
                      // get the current syncState + version, not a snapshot from
                      // navigation args. Falls back to a synthesized model if
                      // the patient is somehow missing (shouldn't happen).
                      PatientModel? model;
                      if (Get.isRegistered<PatientController>()) {
                        final ctrl = Get.find<PatientController>();
                        final idx = ctrl.patients.indexWhere((p) => p.id == patientId);
                        if (idx != -1) model = ctrl.patients[idx];
                      }
                      if (model == null) return; // patient gone — defensive no-op
                      Get.toNamed(AppRoutes.addPatient, arguments: model);
                    },
                  ),
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: Column(
                    children: [
                      // ── Patient header — purple hero (neutral shadow, no halo) ──
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.primaryDeep,
                              AppColors.primary,
                              AppColors.purple,
                            ],
                            stops: [0.0, 0.55, 1.0],
                          ),
                          boxShadow: AppShadows.mid,
                        ),
                        child: Row(
                          children: [
                            // Live photo: prefer the controller's current model
                            // (so an edit reflects immediately) and fall back to
                            // the navigation snapshot. Obx rebuilds on update.
                            Obx(() {
                              var pb = argPhotoB64;
                              if (Get.isRegistered<PatientController>()) {
                                final ctrl = Get.find<PatientController>();
                                final i = ctrl.patients.indexWhere((p) => p.id == patientId);
                                if (i != -1) {
                                  pb = ctrl.patients[i].mcpDetails['photo']?.toString();
                                }
                              }
                              final ph = patientPhotoProvider(pb);
                              return GestureDetector(
                                // Hold (long-press) to view the photo full-screen.
                                onLongPress: ph == null
                                    ? null
                                    : () => showPatientPhotoDialog(context, pb, name: name),
                                child: Hero(
                                  tag: 'patient_avatar_$patientId',
                                  child: Container(
                                    width: 70, height: 70,
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withValues(alpha: 0.30),
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: ph == null
                                            ? Colors.white.withValues(alpha: 0.18)
                                            : null,
                                        image: ph != null
                                            ? DecorationImage(
                                                image: ph, fit: BoxFit.cover)
                                            : null,
                                      ),
                                      child: ph != null
                                          ? null
                                          : Center(
                                              child: Text(
                                                initial,
                                                style: AppTextStyles.display
                                                    .copyWith(
                                                  fontSize: 26,
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.h2.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 5),
                                  if (village.isNotEmpty && village != '—')
                                    _metaRow(Icons.location_on_rounded, village),
                                  if (mobile.isNotEmpty)
                                    _metaRow(Icons.phone_rounded, mobile),
                                  const SizedBox(height: 10),
                                  _heroRiskPill(risk),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      // ── Info cards ───────────────────────────────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _InfoCard('prof_case'.tr, type,
                              _caseIconData(type), AppColors.primary),
                          const SizedBox(width: 10),
                          _InfoCard('prof_last_visit'.tr,
                              lastVisit?.isNotEmpty == true ? lastVisit! : '—',
                              Icons.event_available_rounded, AppColors.sky),
                          const SizedBox(width: 10),
                          _InfoCard('prof_status'.tr, risk.label,
                              Icons.health_and_safety_rounded,
                              risk == RiskLevel.emergency
                                  ? AppColors.emergencyRed
                                  : risk == RiskLevel.high
                                      ? AppColors.warningYellow
                                      : AppColors.safeGreen),
                        ],
                      ),
                      const SizedBox(height: 20),
                      AppButton(
                        // The checkup IS the structured MCP-card visit form
                        // (next due visit, dynamic per case) — not voice triage.
                        label: 'prof_start_checkup'.tr,
                        onPressed: () => CheckupLauncher.start(
                            patientId: patientId, patientName: name),
                        icon: Icons.assignment_turned_in_outlined,
                        width: double.infinity,
                      ),
                      const SizedBox(height: 10),
                      // One-tap "মা ও শিশুর কার্ড" — compiles registration +
                      // captured visit records into a printable MCP-card report.
                      AppButton(
                        label: 'prof_mch_report_pdf'.tr,
                        outlined: true,
                        icon: Icons.picture_as_pdf_outlined,
                        width: double.infinity,
                        onPressed: () async {
                          if (!Get.isRegistered<PatientController>()) return;
                          final ctrl = Get.find<PatientController>();
                          final i = ctrl.patients
                              .indexWhere((p) => p.id == patientId);
                          if (i == -1) {
                            Get.snackbar('prof_report'.tr,
                                'prof_patient_not_found'.tr,
                                snackPosition: SnackPosition.BOTTOM,
                                backgroundColor: AppColors.warningYellow,
                                colorText: Colors.white,
                                margin: const EdgeInsets.all(16),
                                borderRadius: 12);
                            return;
                          }
                          final u = LocalStorageService.loadUser() ?? const {};
                          String s(List<String> keys) {
                            for (final k in keys) {
                              final v = (u[k] ?? '').toString().trim();
                              if (v.isNotEmpty) return v;
                            }
                            return '';
                          }
                          await McpReportPdf.generate(ctrl.patients[i], header: {
                            'asha': s(['name', 'fullName']),
                            'block': s(['block']),
                            'district': s(['district']),
                            'facility':
                                s(['subCentre', 'subcentre', 'facilityName', 'facility']),
                          });
                        },
                      ),
                      // Pregnancy patients: see every pregnancy of this woman.
                      if (type.toLowerCase().contains('pregnan') ||
                          type.contains('গর্ভ')) ...[
                        const SizedBox(height: 10),
                        AppButton(
                          label: 'prof_pregnancy_history'.tr,
                          outlined: true,
                          icon: Icons.timeline_rounded,
                          width: double.infinity,
                          onPressed: () => Get.to(
                              () => PregnancyTimelineScreen(patientId: patientId)),
                        ),
                      ],
                      const SizedBox(height: 24),
                      // ── Checkup timeline (schedule events, done + upcoming) ──
                      if (patientId.isNotEmpty) ...[
                        _SectionTitle('prof_checkup_timeline'.tr,
                            icon: Icons.timeline_rounded),
                        const SizedBox(height: 12),
                        _CheckupTimeline(patientId: patientId),
                        const SizedBox(height: 24),
                      ],
                      // ── Referrals for this patient (Form 3 + outcome) ──
                      if (patientId.isNotEmpty) ...[
                        _SectionTitle('prof_referral'.tr,
                            icon: Icons.local_hospital_rounded),
                        const SizedBox(height: 12),
                        _ProfileReferrals(patientId: patientId),
                        const SizedBox(height: 24),
                      ],
                      // ── Last assessment ──────────────────────────────
                      _SectionTitle('prof_last_assessment'.tr,
                          icon: Icons.fact_check_rounded),
                      const SizedBox(height: 12),
                      if (hasAssessment) ...[
                        if (outcome != null && outcome.isNotEmpty)
                          _AssessmentCard(
                              outcome: outcome,
                              reason: reason,
                              nextStep: nextStep),
                        if (situation.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _TextCard(
                              title: 'prof_reported_situation'.tr, body: situation),
                        ],
                        if (qaHistory.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _QaCard(qaHistory: qaHistory),
                        ],
                      ] else if (patientId.isNotEmpty)
                        // No triage yet → derive from the latest checkup's flags.
                        _CheckupAssessment(patientId: patientId)
                      else
                        const _EmptyAssessment(),
                      if (history.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _SectionTitle('prof_report_history'.tr,
                            icon: Icons.history_rounded),
                        const SizedBox(height: 12),
                        _ReportHistory(reports: history),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Section title ─────────────────────────────────────────────────────────
extension on RiskLevel {
  String get label => switch (this) {
        RiskLevel.safe => 'prof_risk_safe'.tr,
        RiskLevel.moderate => 'prof_risk_moderate'.tr,
        RiskLevel.high => 'prof_risk_high'.tr,
        RiskLevel.emergency => 'prof_risk_emergency'.tr,
      };
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final IconData? icon;
  const _SectionTitle(this.text, {this.icon});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.accent],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          if (icon != null) ...[
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.h3),
          ),
        ],
      );
}

// ── Assessment card — color-coded by triage outcome ───────────────────────
class _AssessmentCard extends StatelessWidget {
  final String outcome;
  final String reason;
  final String nextStep;

  const _AssessmentCard({
    required this.outcome,
    required this.reason,
    required this.nextStep,
  });

  @override
  Widget build(BuildContext context) {
    final (bg, border, textColor, label, icon) = switch (outcome) {
      'emergency' => (
          const Color(0xFFFFEBEB),
          AppColors.emergencyRed,
          const Color(0xFF7F1D1D),
          'prof_outcome_emergency'.tr,
          Icons.emergency_rounded,
        ),
      'attention' => (
          const Color(0xFFFFFBEB),
          AppColors.warningYellow,
          const Color(0xFF78350F),
          'prof_outcome_attention'.tr,
          Icons.warning_amber_rounded,
        ),
      _ => (
          const Color(0xFFECFDF5),
          AppColors.safeGreen,
          const Color(0xFF064E3B),
          'prof_outcome_safe'.tr,
          Icons.check_circle_outline_rounded,
        ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: border, size: 18),
              const SizedBox(width: 8),
              Text(label.toUpperCase(),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                      color: border, letterSpacing: 0.4)),
            ],
          ),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(reason,
                style: TextStyle(fontSize: 14, color: textColor, height: 1.6)),
          ],
          if (nextStep.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.arrow_forward_rounded, size: 13, color: border),
                      const SizedBox(width: 5),
                      Text('next_step'.tr,
                          style: TextStyle(fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: border, letterSpacing: 0.5)),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(nextStep,
                      style: TextStyle(fontSize: 13, color: textColor,
                          height: 1.5)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Plain text card (reported situation) ──────────────────────────────────
class _TextCard extends StatelessWidget {
  final String title;
  final String body;

  const _TextCard({required this.title, required this.body});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE0E7FF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title.toUpperCase(),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                    color: AppColors.primary, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            Text(body,
                style: const TextStyle(fontSize: 14,
                    color: AppColors.onBackground, height: 1.5)),
          ],
        ),
      );
}

// ── Q&A history from the actual triage ────────────────────────────────────
class _QaCard extends StatelessWidget {
  final List<({String q, String a})> qaHistory;

  const _QaCard({required this.qaHistory});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE0E7FF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('assessment_qa'.tr,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                    color: AppColors.primary, letterSpacing: 0.5)),
            const SizedBox(height: 12),
            for (var i = 0; i < qaHistory.length; i++) ...[
              if (qaHistory[i].q.isNotEmpty) ...[
                Text(qaHistory[i].q,
                    style: const TextStyle(fontSize: 12,
                        color: AppColors.textSecondary, height: 1.4)),
                const SizedBox(height: 3),
              ],
              Text(qaHistory[i].a.isNotEmpty ? qaHistory[i].a : '—',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                      color: AppColors.onBackground)),
              if (i != qaHistory.length - 1)
                const Divider(height: 16, color: Color(0xFFE0E7FF)),
            ],
          ],
        ),
      );
}

// ── Empty state — manually added patient with no triage yet ───────────────
class _EmptyAssessment extends StatelessWidget {
  const _EmptyAssessment();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE0E7FF)),
        ),
        child: Column(
          children: [
            Icon(Icons.assignment_outlined, size: 40,
                color: AppColors.primary.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text('no_assessment_yet'.tr,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                    color: AppColors.onBackground)),
            const SizedBox(height: 4),
            Text(
                'no_assessment_hint'.tr,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary,
                    height: 1.5)),
          ],
        ),
      );
}

// ── Checkup-derived assessment (when no triage has been run) ───────────────
// A patient may only ever get structured checkups (ANC/HBNC/…), never a separate
// triage. The visit form still captures danger signs, so summarise the LATEST
// completed checkup here: red if it flagged danger signs, green if it was clear.
class _CheckupAssessment extends StatefulWidget {
  final String patientId;
  const _CheckupAssessment({required this.patientId});
  @override
  State<_CheckupAssessment> createState() => _CheckupAssessmentState();
}

class _CheckupAssessmentState extends State<_CheckupAssessment> {
  bool _loading = true;
  Map<String, dynamic>? _latest;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    List<dynamic> evs;
    try {
      evs = await ApiService.getScheduleForPatient(widget.patientId);
    } catch (_) {
      evs = const [];
    }
    final done = evs
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((e) => (e['status'] ?? '') == 'done')
        .toList()
      ..sort((a, b) {
        final ra = (a['record'] is Map ? a['record']['completedAt'] : null) ??
            a['doneDate'] ?? a['dueDate'] ?? '';
        final rb = (b['record'] is Map ? b['record']['completedAt'] : null) ??
            b['doneDate'] ?? b['dueDate'] ?? '';
        return rb.toString().compareTo(ra.toString());
      });
    if (!mounted) return;
    setState(() {
      _latest = done.isNotEmpty ? done.first : null;
      _loading = false;
    });
  }

  List<String> _flags(Map rec) {
    final out = <String>[];
    void add(dynamic v) {
      if (v is List) out.addAll(v.map((e) => e.toString()).where((s) => s.isNotEmpty));
    }
    add(rec['dangerFlags']);
    add(rec['tbSymptoms']);
    add(rec['pncFlags']);
    if (rec['motherPnc'] is Map) add((rec['motherPnc'] as Map)['dangerFlags']);
    return out;
  }

  String _fmt(dynamic iso) {
    final d = DateTime.tryParse((iso ?? '').toString());
    if (d == null) return '';
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(d.day)}/${p(d.month)}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE0E7FF)),
        ),
        child: const Center(
            child: SizedBox(
                width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    final e = _latest;
    if (e == null) {
      // Never had a checkup or a triage.
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE0E7FF)),
        ),
        child: Column(
          children: [
            Icon(Icons.assignment_outlined,
                size: 40, color: AppColors.primary.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text('prof_no_assessment_yet'.tr,
                style: AppTextStyles.label
                    .copyWith(fontWeight: FontWeight.w700, color: AppColors.onBackground)),
            const SizedBox(height: 4),
            Text('prof_no_assessment_checkup_hint'.tr,
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
          ],
        ),
      );
    }
    final rec = e['record'] is Map ? (e['record'] as Map) : const {};
    final flags = _flags(rec);
    final label = (e['label'] ?? '').toString();
    final date = _fmt(rec['completedAt'] ?? e['doneDate'] ?? e['dueDate']);
    final ok = flags.isEmpty;
    final color = ok ? AppColors.safeGreen : AppColors.emergencyRed;
    final bg = ok
        ? AppColors.safeGreen.withValues(alpha: 0.08)
        : AppColors.emergencyRed.withValues(alpha: 0.08);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ok ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                  color: color, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ok
                      ? 'prof_last_checkup_ok'.tr
                      : 'prof_danger_signs_found'
                          .trParams({'count': '${flags.length}'}),
                  style: AppTextStyles.label
                      .copyWith(color: color, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            [if (label.isNotEmpty) label, if (date.isNotEmpty) date].join(' · '),
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
          if (!ok) ...[
            const SizedBox(height: 8),
            ...flags.map((f) => Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ',
                          style: TextStyle(color: AppColors.emergencyRed, height: 1.4)),
                      Expanded(
                        child: Text(f,
                            style: AppTextStyles.body.copyWith(
                                color: AppColors.onBackground, height: 1.4)),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 8),
            Text('prof_danger_advice'.tr,
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.emergencyRed, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}

// ── Past triage reports linked to this patient ────────────────────────────
class _ReportHistory extends StatelessWidget {
  final List<Map<String, dynamic>> reports;

  const _ReportHistory({required this.reports});

  static String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE0E7FF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('report_history'.trParams({'count': '${reports.length}'}),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                    color: AppColors.primary, letterSpacing: 0.5)),
            const SizedBox(height: 12),
            for (var i = 0; i < reports.length; i++) ...[
              _row(reports[i]),
              if (i != reports.length - 1)
                const Divider(height: 18, color: Color(0xFFE0E7FF)),
            ],
          ],
        ),
      );

  Widget _row(Map<String, dynamic> r) {
    final outcome = (r['outcome'] ?? 'safe').toString();
    final (color, label) = switch (outcome) {
      'emergency' => (AppColors.emergencyRed, 'prof_outcome_emergency'.tr),
      'attention' => (AppColors.warningYellow, 'prof_outcome_attention'.tr),
      _           => (AppColors.safeGreen, 'prof_outcome_safe'.tr),
    };
    final date = _formatDate((r['createdAt'] ?? '').toString());
    final caseLabel = (r['caseLabel'] ?? '').toString().trim();
    final reason = (r['reason'] ?? '').toString().trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 10, height: 10,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(label,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                          color: color)),
                  const Spacer(),
                  if (date.isNotEmpty)
                    Text(date,
                        style: const TextStyle(fontSize: 11,
                            color: AppColors.textSecondary)),
                ],
              ),
              if (caseLabel.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(caseLabel,
                    style: const TextStyle(fontSize: 11,
                        color: AppColors.textSecondary)),
              ],
              if (reason.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(reason,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12,
                        color: AppColors.onBackground, height: 1.4)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── Checkup timeline — the patient's schedule events (done + upcoming) ─────
class _CheckupTimeline extends StatefulWidget {
  final String patientId;
  const _CheckupTimeline({required this.patientId});
  @override
  State<_CheckupTimeline> createState() => _CheckupTimelineState();
}

class _CheckupTimelineState extends State<_CheckupTimeline> {
  bool _loading = true;
  List<Map<String, dynamic>> _events = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    List<dynamic> raw;
    try {
      raw = await ApiService.getScheduleForPatient(widget.patientId);
    } catch (_) {
      raw = const [];
    }
    if (!mounted) return;
    setState(() {
      _events =
          raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      _loading = false;
    });
  }

  static String _fmt(dynamic iso) {
    final d = DateTime.tryParse((iso ?? '').toString());
    if (d == null) return '';
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(d.day)}/${p(d.month)}/${d.year}';
  }

  static IconData _icon(String k) => switch (k) {
        'vaccine' => Icons.vaccines_rounded,
        'anc' => Icons.pregnant_woman_rounded,
        'pnc' => Icons.volunteer_activism_rounded,
        'hbnc' => Icons.child_care_rounded,
        'hbyc' => Icons.child_friendly_rounded,
        _ => Icons.event_note_rounded,
      };

  // Order by the SCHEDULED (guideline) date — the headline date for every visit.
  DateTime _date(Map<String, dynamic> e) =>
      DateTime.tryParse((e['dueDate'] ?? '').toString()) ?? DateTime(2100);

  // What was recorded at a completed visit — short summary line.
  String _summary(Map<String, dynamic> e) {
    final rec = e['record'] is Map ? (e['record'] as Map) : const {};
    final kind = (e['kind'] ?? '').toString();
    String r(String k) => (rec[k] ?? '').toString().trim();
    if (kind == 'anc') {
      final bits = <String>[
        if (r('bp').isNotEmpty) 'BP ${r('bp')}',
        if (r('hb').isNotEmpty) 'Hb ${r('hb')}',
        if (r('weight').isNotEmpty)
          'prof_weight_value'.trParams({'value': r('weight')}),
      ];
      return bits.isEmpty ? 'prof_done'.tr : bits.join(' · ');
    }
    if (kind == 'vaccine') {
      final g = (rec['givenVaccines'] as List?)?.length ?? 0;
      return g > 0
          ? 'prof_vaccines_given'.trParams({'count': '$g'})
          : 'prof_done'.tr;
    }
    if (kind == 'hbyc') {
      final ms = r('muacStatus');
      return ms.isNotEmpty ? 'MUAC: $ms' : 'prof_done'.tr;
    }
    final flags = (rec['dangerFlags'] as List?)?.length ?? 0;
    return flags > 0
        ? 'prof_danger_signs_count'.trParams({'count': '$flags'})
        : 'prof_ok'.tr;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(
            child: SizedBox(
                width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    final now = DateTime.now();
    final done = _events.where((e) => (e['status'] ?? '') == 'done').toList()
      ..sort((a, b) => _date(b).compareTo(_date(a))); // recent first
    final pending = _events
        .where((e) => (e['status'] ?? 'pending') == 'pending')
        .toList()
      ..sort((a, b) => _date(a).compareTo(_date(b))); // soonest first

    if (done.isEmpty && pending.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE0E7FF)),
        ),
        child: Column(children: [
          Icon(Icons.event_busy_rounded,
              size: 36, color: AppColors.primary.withValues(alpha: 0.4)),
          const SizedBox(height: 10),
          Text('prof_no_schedule_yet'.tr,
              style: AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text('prof_no_schedule_hint'.tr,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
        ]),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E7FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pending.isNotEmpty) ...[
            Text('prof_upcoming_overdue'.tr,
                style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
            const SizedBox(height: 8),
            ...pending.map((e) {
              // Overdue only once the clinical window has closed (windowEnd),
              // not the moment the due date passes.
              final we = DateTime.tryParse((e['windowEnd'] ?? '').toString());
              final isOverdue = (we ?? _date(e)).isBefore(now);
              return _row(e, done: false, overdue: isOverdue);
            }),
          ],
          if (pending.isNotEmpty && done.isNotEmpty)
            const Divider(height: 22, color: Color(0xFFE0E7FF)),
          if (done.isNotEmpty) ...[
            Text('prof_completed'.tr,
                style: AppTextStyles.caption.copyWith(
                    color: AppColors.safeGreen, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
            const SizedBox(height: 8),
            ...done.map((e) => _row(e, done: true, overdue: false)),
          ],
        ],
      ),
    );
  }

  Widget _row(Map<String, dynamic> e, {required bool done, required bool overdue}) {
    final kind = (e['kind'] ?? '').toString();
    // In-window = the due date has arrived but the window hasn't closed yet.
    final now = DateTime.now();
    final due = DateTime.tryParse((e['dueDate'] ?? '').toString());
    final we = DateTime.tryParse((e['windowEnd'] ?? '').toString());
    final inWindow = !done && !overdue && due != null && !due.isAfter(now) &&
        (we == null || !we.isBefore(now));
    final color = done
        ? AppColors.safeGreen
        : (overdue
            ? AppColors.emergencyRed
            : (inWindow ? AppColors.primary : AppColors.warningYellow));
    final rec = e['record'] is Map ? (e['record'] as Map) : const {};
    // Headline date = the scheduled (guideline) date for every visit.
    final date = _fmt(e['dueDate']);
    // For completed visits also show the day it was actually recorded.
    final recorded = done ? _fmt(e['doneDate'] ?? rec['completedAt']) : '';
    final summary = _summary(e);
    final sub = done
        ? (recorded.isNotEmpty
            ? 'prof_done_on'
                .trParams({'date': recorded, 'summary': summary})
            : summary)
        : (overdue
            ? 'prof_overdue'.tr
            : (inWindow ? 'prof_do_now'.tr : 'prof_upcoming'.tr));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
            child: Icon(done ? Icons.check_rounded : _icon(kind), size: 17, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text((e['label'] ?? '').toString(),
                          // Show the full checkup name (wrap up to 2 lines) — the
                          // names ("ANC ১ম পরীক্ষা (প্রথম ত্রৈমাসিক)") are long.
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700)),
                    ),
                    if (date.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(date,
                          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                    ],
                  ],
                ),
                Text(sub,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          // Per-checkup report download (any completed module — ANC/PNC/vaccine/HBNC/HBYC).
          if (done)
            IconButton(
              tooltip: 'prof_this_checkup_report'.tr,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
              onPressed: () => _downloadEvent(e),
              icon: const Icon(Icons.download_rounded, size: 20, color: AppColors.primary),
            ),
        ],
      ),
    );
  }

  /// Builds + opens a focused PDF for a single completed checkup. Resolves the
  /// live PatientModel from the controller and reuses the ASHA header.
  Future<void> _downloadEvent(Map<String, dynamic> e) async {
    try {
      final ctrl = Get.find<PatientController>();
      final i = ctrl.patients.indexWhere((p) => p.id == widget.patientId);
      if (i == -1) {
        Get.snackbar('prof_report'.tr, 'prof_patient_not_found'.tr,
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppColors.warningYellow,
            colorText: Colors.white,
            margin: const EdgeInsets.all(16), borderRadius: 12);
        return;
      }
      final u = LocalStorageService.loadUser() ?? const {};
      String s(List<String> keys) {
        for (final k in keys) {
          final v = (u[k] ?? '').toString().trim();
          if (v.isNotEmpty) return v;
        }
        return '';
      }
      await McpReportPdf.generateForEvent(ctrl.patients[i], e, header: {
        'asha': s(['name', 'fullName']),
        'block': s(['block']),
        'district': s(['district']),
        'facility': s(['subCentre', 'subcentre', 'facilityName', 'facility']),
      });
    } catch (_) {
      Get.snackbar('prof_report'.tr, 'prof_report_failed'.tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.emergencyRed,
          colorText: Colors.white,
          margin: const EdgeInsets.all(16), borderRadius: 12);
    }
  }
}

// ── Referrals for this patient (Form 3 + outcome tracking) ──────────────────
// Lists every referral linked to this patient (status pending→reached→completed)
// and lets the worker open the outcome screen or start a new referral pre-filled
// from the patient. Reactive to the shared ReferralController.
class _ProfileReferrals extends StatelessWidget {
  final String patientId;
  const _ProfileReferrals({required this.patientId});

  ReferralController get _ctrl => Get.isRegistered<ReferralController>()
      ? Get.find<ReferralController>()
      : Get.put(ReferralController(), permanent: true);

  static (String, Color) _statusBn(String s) => switch (s) {
        'reached' => ('prof_ref_reached'.tr, AppColors.primary),
        'completed' => ('prof_ref_completed'.tr, AppColors.safeGreen),
        'cancelled' => ('prof_ref_cancelled'.tr, AppColors.textSecondary),
        _ => ('prof_ref_pending'.tr, AppColors.warningYellow),
      };

  void _newReferral() {
    final pc = Get.find<PatientController>();
    final i = pc.patients.indexWhere((p) => p.id == patientId);
    final args = <String, dynamic>{'patientId': patientId};
    if (i != -1) {
      final p = pc.patients[i];
      final t = p.type.toLowerCase();
      args.addAll({
        'patientName': p.name,
        'age': p.age.toString(),
        'guardianName': p.guardianName,
        'village': p.village,
        'mobile': p.mobile,
        'gender': p.gender,
        'caseType': t.contains('pregn')
            ? 'pregnancy'
            : (t.contains('newborn') ? 'newborn' : (t.contains('child') ? 'child' : 'other')),
      });
    }
    Get.to(() => const ReferralFormScreen(), arguments: args);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final list = _ctrl.referrals.where((r) => r.patientId == patientId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE0E7FF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text('prof_no_referrals'.tr,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary)),
              )
            else
              ...list.map(_referralRow),
            const SizedBox(height: 10),
            AppButton(
              label: 'prof_new_referral'.tr,
              outlined: true,
              icon: Icons.add_circle_outline_rounded,
              width: double.infinity,
              onPressed: _newReferral,
            ),
          ],
        ),
      );
    });
  }

  Widget _referralRow(ReferralModel r) {
    final (statusLabel, statusColor) = _statusBn(r.status);
    final bandColor = r.band == 'YELLOW' ? AppColors.warningYellow : AppColors.emergencyRed;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Get.to(() => ReferralDetailScreen(referralId: r.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                  color: bandColor.withValues(alpha: 0.14), shape: BoxShape.circle),
              child: Icon(Icons.local_hospital_rounded, size: 17, color: bandColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.referredTo.isNotEmpty ? r.referredTo : 'prof_referral'.tr,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (r.reason.isNotEmpty || r.symptoms.isNotEmpty)
                    Text(
                      r.reason.isNotEmpty ? r.reason : r.symptoms,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(statusLabel,
                  style: AppTextStyles.caption
                      .copyWith(color: statusColor, fontWeight: FontWeight.w700)),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textSecondary, size: 22),
          ],
        ),
      ),
    );
  }
}

// ── Info card ─────────────────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _InfoCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.15),
              color.withValues(alpha: 0.05),
            ],
          ),
          border: Border.all(color: color.withValues(alpha: 0.14)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 7,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 19),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: AppTextStyles.label.copyWith(
                  fontWeight: FontWeight.w800, color: AppColors.onBackground),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
