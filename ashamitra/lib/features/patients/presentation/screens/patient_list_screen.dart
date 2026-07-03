import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/pdf_helper.dart';
import '../../../../shared/components/app_header.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../../../shared/widgets/risk_badge.dart' show RiskLevel;
import '../../../../shared/components/bottom_nav.dart';
import '../../../schedule/services/reminder_service.dart';
import '../../../registers/services/due_register_service.dart';
import '../../controller/patient_controller.dart';
import '../../data/models/patient_model.dart';

class PatientListScreen extends StatefulWidget {
  const PatientListScreen({super.key});

  @override
  State<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends State<PatientListScreen> {
  late final PatientController _ctrl;
  int _filterIndex = 0;
  String _searchQuery = '';

  // patientId → most-urgent pending schedule event (overdue first). Drives each
  // card's status colour / badge / actions. Loaded once (cache-first, offline).
  final Map<String, Map<String, dynamic>> _dueByPatient = {};

  @override
  void initState() {
    super.initState();
    _ctrl = Get.isRegistered<PatientController>()
        ? Get.find<PatientController>()
        : Get.put(PatientController(), permanent: true);
    _loadDue();
  }

  Future<void> _loadDue() async {
    final r = await DueRegisterService.fetchDue(withinDays: 60);
    final evs = [...r.events]..sort((a, b) {
        final ao = a['overdue'] == true ? 0 : 1;
        final bo = b['overdue'] == true ? 0 : 1;
        if (ao != bo) return ao - bo;
        return (a['dueDate'] ?? '')
            .toString()
            .compareTo((b['dueDate'] ?? '').toString());
      });
    final map = <String, Map<String, dynamic>>{};
    for (final e in evs) {
      final pid = (e['patientId'] ?? '').toString();
      if (pid.isEmpty) continue;
      map.putIfAbsent(pid, () => e);
    }
    if (mounted) setState(() => _dueByPatient..clear()..addAll(map));
  }

  static const _filters = ['All', 'Pregnancy', 'Newborn', 'Child', 'High Risk'];

  String _filterLabel(String f) => switch (f) {
        'All' => 'filter_all'.tr,
        'Pregnancy' => 'case_pregnancy'.tr,
        'Newborn' => 'case_newborn'.tr,
        'Child' => 'case_child'.tr,
        'High Risk' => 'filter_high_risk'.tr,
        _ => f,
      };

  List<PatientModel> get _filtered => _ctrl.patients.where((p) {
        final name = p.name;
        final type = p.type;
        final village = p.village;
        final risk = p.riskFromOutcome;

        final matchSearch =
            name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                village.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                p.rchId.contains(_searchQuery);
        final matchFilter = _filterIndex == 0 ||
            (_filterIndex == 4
                ? risk == RiskLevel.high || risk == RiskLevel.emergency
                : _typeMatchesFilter(type, _filters[_filterIndex]));
        return matchSearch && matchFilter;
      }).toList();

  static bool _typeMatchesFilter(String type, String filter) {
    final t = type.toLowerCase();
    return switch (filter) {
      'Pregnancy' => t.contains('pregnan') || type.contains('গর্ভ'),
      'Newborn' => t.contains('newborn') || type.contains('নবজাতক'),
      'Child' =>
        t.contains('child') || t.contains('infant') || type.contains('শিশু'),
      _ => true,
    };
  }

  Future<void> _downloadPdf() async {
    final list = _filtered;
    final theme = await PdfHelper.bengaliTheme();
    final doc = pw.Document(theme: theme);
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [
          pw.Text('plist_pdf_title'.tr,
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(
              'plist_pdf_generated'.trParams(
                  {'date': DateTime.now().toString().substring(0, 16)}),
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
          pw.Text('plist_pdf_total'.trParams({'count': '${list.length}'}),
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
          pw.Divider(height: 24),
          pw.Table.fromTextArray(
            headers: [
              'plist_pdf_col_name'.tr,
              'plist_pdf_col_type'.tr,
              'plist_pdf_col_village'.tr,
              'plist_pdf_col_last_visit'.tr,
              'plist_pdf_col_risk'.tr,
            ],
            data: list
                .map((p) => [
                      p.name,
                      p.type,
                      p.village,
                      p.lastVisit,
                      p.riskFromOutcome.name.toUpperCase(),
                    ])
                .toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo100),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        ],
      ),
    );
    final bytes = await doc.save();
    await PdfHelper.saveAndOpen(
        bytes, 'asha_mitra_patients_${DateTime.now().millisecondsSinceEpoch}.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          child: Column(
            children: [
              AppHeader(
                title: 'patients'.tr,
                actions: [
                  HeaderActionPill(
                    icon: Icons.download_rounded,
                    label: 'plist_pdf_button'.tr,
                    onTap: _downloadPdf,
                  ),
                  HeaderActionCircle(
                    icon: Icons.person_add_rounded,
                    onTap: () => Get.toNamed(AppRoutes.addPatient),
                    tooltip: 'add_patient'.tr,
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: AppTextStyles.body,
                  decoration: InputDecoration(
                    hintText: 'search_patient_hint'.tr,
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: AppColors.primary, size: 22),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _filters.length,
                  itemBuilder: (_, i) {
                    final sel = i == _filterIndex;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Material(
                        color: sel ? AppColors.primary : AppColors.surface,
                        borderRadius: AppRadius.pillR,
                        child: InkWell(
                          onTap: () => setState(() => _filterIndex = i),
                          borderRadius: AppRadius.pillR,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: sel ? AppColors.primary : AppColors.surface,
                              borderRadius: AppRadius.pillR,
                              boxShadow: sel
                                  ? AppShadows.tinted(AppColors.primary,
                                      strength: 2)
                                  : AppShadows.low,
                            ),
                            child: Text(
                              _filterLabel(_filters[i]),
                              style: AppTextStyles.label.copyWith(
                                color: sel
                                    ? AppColors.onPrimary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              // "রোগী তালিকা" heading + live count chip.
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Obx(() {
                  final n = _filtered.length;
                  return Row(
                    children: [
                      Text('plist_heading'.tr,
                          style: AppTextStyles.h2
                              .copyWith(fontWeight: FontWeight.w800)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: AppShadows.low,
                        ),
                        child: Text('plist_count'.trParams({'count': '$n'}),
                            style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  );
                }),
              ),
              Expanded(
                child: Obx(() {
                  if (_ctrl.isLoading.value && _ctrl.patients.isEmpty) {
                    return SkeletonList(
                      count: 5,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      builder: (_) => const SkeletonPatientCard(),
                    );
                  }
                  final list = _filtered;
                  if (list.isEmpty) {
                    return EmptyState(
                      icon: Icons.people_outline_rounded,
                      title: 'patient_empty'.tr,
                      subtitle: 'patient_list_subtitle_empty'.tr,
                      action: FilledButton.icon(
                        onPressed: () => Get.toNamed(AppRoutes.addPatient),
                        icon: const Icon(Icons.person_add_rounded, size: 18),
                        label: Text('add_patient'.tr),
                      ),
                    );
                  }
                  return RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () async {
                      await _ctrl.syncFromServer();
                      await _loadDue();
                    },
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      itemCount: list.length,
                      itemBuilder: (_, i) => _buildCard(list[i]),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 1),
    );
  }

  // Builds one status-driven patient card + its dismiss-to-delete wrapper.
  Widget _buildCard(PatientModel p) {
    final risk = p.riskFromOutcome;
    final highRisk = risk == RiskLevel.high || risk == RiskLevel.emergency;
    final due = _dueByPatient[p.id];
    final overdue = due?['overdue'] == true;

    // Left-border colour: high-risk red → overdue red → due amber → done green.
    final Color accent = highRisk
        ? AppColors.emergencyRed
        : (overdue
            ? AppColors.emergencyRed
            : (due != null ? AppColors.warningYellow : AppColors.safeGreen));

    // Badge (top-right).
    final String badge;
    final Color badgeColor;
    if (highRisk) {
      badge = 'plist_badge_highrisk'.tr;
      badgeColor = AppColors.emergencyRed;
    } else if (due != null) {
      badge = _dueBadge(due);
      badgeColor = overdue ? AppColors.emergencyRed : AppColors.accentDeep;
    } else {
      badge = 'plist_badge_done'.tr;
      badgeColor = AppColors.safeGreen;
    }

    // Actions: a due visit → start-checkup + remind; otherwise view-record + call.
    final actions = <_CardAction>[];
    if (due != null) {
      actions.add(_CardAction(
        label: 'plist_start_checkup'.tr,
        icon: Icons.medical_services_rounded,
        filled: true,
        color: highRisk ? AppColors.emergencyRed : AppColors.primary,
        onTap: () => Get.toNamed(AppRoutes.visit, arguments: due),
      ));
      actions.add(_CardAction(
        label: 'plist_remind'.tr,
        icon: Icons.notifications_active_outlined,
        filled: false,
        color: AppColors.purple,
        onTap: () => ReminderService.remind(context, due),
      ));
    } else {
      actions.add(_CardAction(
        label: 'plist_view_record'.tr,
        icon: Icons.visibility_outlined,
        filled: false,
        color: AppColors.primary,
        onTap: () =>
            Get.toNamed(AppRoutes.patientProfile, arguments: p.toJson()),
      ));
      if (p.mobile.isNotEmpty) {
        actions.add(_CardAction(
          label: 'plist_call'.tr,
          icon: Icons.call_rounded,
          filled: true,
          color: AppColors.purple,
          onTap: () => launchUrl(Uri.parse('tel:${p.mobile}')),
        ));
      }
    }

    return Dismissible(
      key: ValueKey(p.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.emergencyRed,
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 24),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: Text('delete_patient'.tr),
                content:
                    Text('delete_patient_confirm'.trParams({'name': p.name})),
                actions: [
                  TextButton(
                      onPressed: () => Get.back(result: false),
                      child: Text('cancel'.tr)),
                  TextButton(
                    onPressed: () => Get.back(result: true),
                    child: Text('delete_patient_short'.tr,
                        style: const TextStyle(color: AppColors.emergencyRed)),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) => _ctrl.deletePatient(p.id),
      child: _PatientCardV2(
        name: p.name,
        subtitle: _subtitle(p),
        type: p.type,
        photoB64: p.mcpDetails['photo']?.toString(),
        accent: accent,
        highRisk: highRisk,
        badge: badge,
        badgeColor: badgeColor,
        riskSubtext: highRisk ? _riskReason(p) : null,
        actions: actions,
        onTap: () =>
            Get.toNamed(AppRoutes.patientProfile, arguments: p.toJson()),
      ),
    );
  }

  String _subtitle(PatientModel p) {
    final rch = p.rchId.isEmpty ? '' : 'RCH: ${p.rchId}';
    final unit = switch (p.ageUnit) {
      'days' => 'plist_age_days'.tr,
      'months' => 'plist_age_months'.tr,
      _ => 'plist_age_years'.tr,
    };
    final age = p.age.isEmpty ? '' : '${p.age} $unit';
    return [rch, age].where((s) => s.isNotEmpty).join('  •  ');
  }

  String? _riskReason(PatientModel p) {
    final r = (p.reason ?? '').trim();
    if (r.isNotEmpty) return r;
    final s = (p.situation ?? '').trim();
    return s.isNotEmpty ? s : null;
  }

  // "বকেয়া ANC ৩" / "বকেয়া টিকা" etc. from the due event.
  String _dueBadge(Map<String, dynamic> e) {
    final kind = (e['kind'] ?? '').toString();
    final code = (e['code'] ?? '').toString();
    final due = 'plist_badge_due_prefix'.tr;
    if (kind == 'anc') {
      final n = RegExp(r'(\d+)').firstMatch(code)?.group(1) ?? '';
      return '$due ANC ${_bn(n)}'.trim();
    }
    final k = switch (kind) {
      'vaccine' => 'plist_kind_vaccine'.tr,
      'pnc' => 'PNC',
      'hbnc' => 'plist_kind_hbnc'.tr,
      'hbyc' => 'plist_kind_hbyc'.tr,
      _ => 'plist_kind_visit'.tr,
    };
    return '$due $k';
  }

  static String _bn(String ascii) {
    const d = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    return ascii.split('').map((c) {
      final i = int.tryParse(c);
      return i == null ? c : d[i];
    }).join();
  }
}

/// One card action button (filled primary or outlined secondary).
class _CardAction {
  final String label;
  final IconData icon;
  final bool filled;
  final Color color;
  final VoidCallback onTap;
  const _CardAction({
    required this.label,
    required this.icon,
    required this.filled,
    required this.color,
    required this.onTap,
  });
}

/// Reference-style patient card: colour-coded left border, avatar, name +
/// RCH/age, a status badge, and up to two action buttons. High-risk gets a soft
/// red wash + red border.
class _PatientCardV2 extends StatelessWidget {
  final String name;
  final String subtitle;
  final String type;
  final String? photoB64;
  final Color accent;
  final bool highRisk;
  final String badge;
  final Color badgeColor;
  final String? riskSubtext;
  final List<_CardAction> actions;
  final VoidCallback onTap;

  const _PatientCardV2({
    required this.name,
    required this.subtitle,
    required this.type,
    required this.photoB64,
    required this.accent,
    required this.highRisk,
    required this.badge,
    required this.badgeColor,
    required this.riskSubtext,
    required this.actions,
    required this.onTap,
  });

  IconData get _typeIcon {
    final t = type.toLowerCase();
    if (t.contains('pregnan') || type.contains('গর্ভ')) {
      return Icons.pregnant_woman_rounded;
    }
    if (t.contains('newborn') || type.contains('নবজাতক')) {
      return Icons.child_care_rounded;
    }
    if (t.contains('child') || t.contains('infant') || type.contains('শিশু')) {
      return Icons.child_friendly_rounded;
    }
    return Icons.person_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: highRisk ? const Color(0xFFFEF2F2) : AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: AppShadows.low,
              border: highRisk
                  ? Border.all(color: AppColors.emergencyRed, width: 1.4)
                  : null,
              // Coloured status rail on the left.
              gradient: LinearGradient(
                colors: [accent, accent.withValues(alpha: 0)],
                stops: const [0.012, 0.012],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _avatar(),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.h3.copyWith(
                                    color: highRisk
                                        ? AppColors.emergencyRed
                                        : AppColors.onBackground)),
                            const SizedBox(height: 2),
                            Text(subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodySm.copyWith(
                                    color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _badge(),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i > 0) const SizedBox(width: 10),
                        Expanded(
                          flex: actions[i].filled ? 3 : 2,
                          child: _actionButton(actions[i]),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _avatar() {
    final tint = highRisk
        ? AppColors.emergencyRed
        : (type.toLowerCase().contains('pregnan') || type.contains('গর্ভ')
            ? AppColors.purple
            : AppColors.primary);
    Widget inner;
    final b64 = photoB64 ?? '';
    if (b64.isNotEmpty) {
      try {
        inner = ClipOval(
          child: Image.memory(base64Decode(b64),
              width: 52, height: 52, fit: BoxFit.cover),
        );
      } catch (_) {
        inner = Icon(highRisk ? Icons.error_outline_rounded : _typeIcon,
            color: tint, size: 26);
      }
    } else {
      inner = Icon(highRisk ? Icons.error_outline_rounded : _typeIcon,
          color: tint, size: 26);
    }
    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: inner,
    );
  }

  Widget _badge() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(badge,
              style: AppTextStyles.caption
                  .copyWith(color: badgeColor, fontWeight: FontWeight.w700)),
        ),
        if (riskSubtext != null) ...[
          const SizedBox(height: 3),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(riskSubtext!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: AppTextStyles.caption.copyWith(
                    color: AppColors.emergencyRed,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ],
    );
  }

  Widget _actionButton(_CardAction a) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(a.icon, size: 16, color: a.filled ? Colors.white : a.color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(a.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.label.copyWith(
                  color: a.filled ? Colors.white : a.color,
                  fontWeight: FontWeight.w700)),
        ),
      ],
    );
    return Material(
      color: a.filled ? a.color : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: a.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: a.filled
                ? null
                : Border.all(color: a.color.withValues(alpha: 0.5), width: 1.3),
          ),
          child: child,
        ),
      ),
    );
  }
}
