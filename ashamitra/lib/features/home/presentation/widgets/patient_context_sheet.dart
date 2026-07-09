import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/services/api_service.dart';
import '../../../../shared/widgets/patient_photo.dart';
import '../../../patients/controller/patient_controller.dart';
import '../../../patients/data/models/patient_model.dart';
import '../../../schedule/services/checkup_launcher.dart';
import '../../../schedule/services/reminder_service.dart';

/// Bottom sheet shown when an ASHA taps a case card on Home.
///
/// Pushes the worker toward the **patient-first** workflow:
///   1. Pick an existing patient → triage links to that patient
///   2. Add a new patient → form opens with the case pre-selected
///   3. Continue without a patient → anonymous triage (still works,
///      but the resulting report is labelled "অনামী").
///
/// `caseId` and `caseTitle` are forwarded so the next screen knows which
/// clinical module to load.
class PatientContextSheet extends StatelessWidget {
  final String caseId;
  final String caseTitle;
  final IconData caseIcon;
  final Color caseColor;

  const PatientContextSheet({
    super.key,
    required this.caseId,
    required this.caseTitle,
    required this.caseIcon,
    required this.caseColor,
  });

  static Future<void> show(
    BuildContext context, {
    required String caseId,
    required String caseTitle,
    required IconData caseIcon,
    required Color caseColor,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PatientContextSheet(
        caseId: caseId,
        caseTitle: caseTitle,
        caseIcon: caseIcon,
        caseColor: caseColor,
      ),
    );
  }

  void _pickExistingPatient(BuildContext context) {
    final ctrl = Get.find<PatientController>();
    Get.back(); // close this sheet first
    // 1a fix: only show patients whose case type matches the case the worker
    // just tapped. Worker tapping "নবজাতক (newborn)" should see only newborn
    // patients, not the whole list. _matchesCase is forgiving — both English
    // (Pregnancy, Newborn) and Bengali (নবজাতক, শিশু) type strings match.
    final filtered = ctrl.patients
        .where((p) => _matchesCase(p, caseId))
        .toList();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExistingPatientPicker(
        patients: filtered,
        caseTitle: caseTitle,
        onPick: (p) {
          Get.back();
          // Checkup = structured MCP-card visit form (next due visit).
          CheckupLauncher.start(patientId: p.id, patientName: p.name);
        },
      ),
    );
  }

  /// Matches a patient's type string against the case ID the worker tapped.
  /// Both English ("Pregnancy", "Newborn") and Bengali ("নবজাতক", "গর্ভবতী")
  /// type values are accepted because patients added via the form get
  /// English types while triage-created patients get Bengali case labels.
  static bool _matchesCase(PatientModel p, String caseId) {
    final t = p.type.toLowerCase();
    switch (caseId) {
      case 'pregnancy':
        return t.contains('pregnan') || p.type.contains('গর্ভ');
      case 'postpartum':
        return t.contains('postpartum') || p.type.contains('প্রসব');
      case 'newborn':
        return t.contains('newborn') || p.type.contains('নবজাত');
      case 'infant':
      case 'child':
        return t.contains('infant') || t.contains('child') ||
            p.type.contains('শিশু');
      default:
        return true; // unknown case → show all (fail-open)
    }
  }

  void _addNewPatient() {
    Get.back();
    // 1b fix: pass the case the worker tapped so Add Patient pre-selects
    // it. add_patient_screen reads the 'caseType' key from arguments and
    // initializes its case-type chip selection accordingly.
    Get.toNamed(AppRoutes.addPatient, arguments: {
      'caseType': _caseTypeForCaseId(caseId),
    });
    // After adding, the user can launch checkup via "Save & Start Checkup",
    // which already passes patientId/Name forward.
  }

  /// Maps a caseId to a case photo (assets/images/cases/<name>.png).
  static String _photoForCaseId(String caseId) {
    switch (caseId) {
      case 'pregnancy':
      case 'postpartum':
        return 'pregnancy';
      case 'newborn':
        return 'newborn';
      case 'infant':
      case 'child':
        return 'child';
      default:
        return 'other';
    }
  }

  /// Maps a dashboard caseId to the form's expected case-type label.
  /// add_patient_screen's case chips are ['Pregnancy', 'Newborn', 'Child', 'Other'].
  static String _caseTypeForCaseId(String caseId) {
    switch (caseId) {
      case 'pregnancy':
      case 'postpartum':
        return 'Pregnancy';
      case 'newborn':
        return 'Newborn';
      case 'infant':
      case 'child':
        return 'Child';
      default:
        return 'Other';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // ── Case summary — a real case photo (photo-forward) ──────
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    'assets/images/cases/${_photoForCaseId(caseId)}.png',
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: caseColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(caseIcon, color: caseColor, size: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(caseTitle,
                          style: AppTextStyles.h3,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      Text('checkup_for_whom'.tr, style: AppTextStyles.bodySm),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Option 1: existing patient ─────────────────────────────
            _ContextOption(
              icon: Icons.people_alt_rounded,
              title: 'pick_existing_patient'.tr,
              subtitle: 'pick_existing_patient_sub'.tr,
              color: AppColors.primary,
              onTap: () => _pickExistingPatient(context),
            ),
            const SizedBox(height: 10),

            // ── Option 2: add new patient ──────────────────────────────
            _ContextOption(
              icon: Icons.person_add_alt_1_rounded,
              title: 'add_new_patient_sheet'.tr,
              subtitle: 'add_new_patient_sheet_sub'.tr,
              color: AppColors.accent,
              onTap: _addNewPatient,
              recommended: true,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ContextOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool recommended;

  const _ContextOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.recommended = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.lgR,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lgR,
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.lgR,
            boxShadow: AppShadows.tinted(color),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: AppRadius.mdR,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(title, style: AppTextStyles.labelLg)),
                        if (recommended) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: AppRadius.pillR,
                            ),
                            child: Text(
                              'recommended'.tr,
                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppTextStyles.bodySm),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Searchable picker for existing patients. Shows when the worker chose
/// "চলমান রোগী নির্বাচন করুন" in the context sheet.
class _ExistingPatientPicker extends StatefulWidget {
  final List<PatientModel> patients;
  /// Case title for the header — e.g. 'নবজাতক (০–২৮ দিন)' — so the worker
  /// sees the picker is scoped to this case, not "all patients".
  final String caseTitle;
  final void Function(PatientModel) onPick;
  const _ExistingPatientPicker({
    required this.patients,
    required this.caseTitle,
    required this.onPick,
  });

  @override
  State<_ExistingPatientPicker> createState() => _ExistingPatientPickerState();
}

class _ExistingPatientPickerState extends State<_ExistingPatientPicker> {
  String _query = '';
  // patientId → soonest pending schedule event (for the due-status hint).
  final Map<String, Map<String, dynamic>> _due = {};
  bool _dueLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadDue();
  }

  /// Loads the full schedule once and keeps each patient's *soonest pending*
  /// event, so the picker can show who is actually due / overdue vs not.
  Future<void> _loadDue() async {
    try {
      final evs = await ApiService.getAllSchedule();
      final detail = <String, Map<String, dynamic>>{};
      final soonest = <String, DateTime>{};
      for (final e in evs) {
        if (e is! Map) continue;
        if ((e['status'] ?? 'pending').toString() == 'done') continue;
        final pid = (e['patientId'] ?? '').toString();
        if (pid.isEmpty) continue;
        final dd = DateTime.tryParse((e['dueDate'] ?? '').toString());
        if (dd == null) continue;
        if (!soonest.containsKey(pid) || dd.isBefore(soonest[pid]!)) {
          soonest[pid] = dd;
          detail[pid] = Map<String, dynamic>.from(e);
        }
      }
      if (mounted) {
        setState(() {
          _due
            ..clear()
            ..addAll(detail);
          _dueLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _dueLoaded = true);
    }
  }

  /// Due-status line + a "মনে করান" (remind) action for a patient row.
  Widget _dueHint(PatientModel p) {
    if (!_dueLoaded) return const SizedBox.shrink();
    final e = _due[p.id];
    if (e == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Text('কোনো বকেয়া চেকআপ নেই',
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
      );
    }
    final dd = DateTime.tryParse((e['dueDate'] ?? '').toString());
    if (dd == null) return const SizedBox.shrink();
    final today = DateTime.now();
    final d0 = DateTime(today.year, today.month, today.day);
    final due0 = DateTime(dd.year, dd.month, dd.day);
    final days = due0.difference(d0).inDays; // to window start (due)
    // Window end (overdue only after this); fall back to due date if absent.
    final weRaw = DateTime.tryParse((e['windowEnd'] ?? '').toString());
    final end0 = weRaw != null ? DateTime(weRaw.year, weRaw.month, weRaw.day) : due0;
    final toEnd = end0.difference(d0).inDays;
    String two(int n) => n.toString().padLeft(2, '0');
    final label = (e['label'] ?? '').toString();
    final (String text, Color color) = toEnd < 0
        ? ('${toEnd.abs()} দিন পার — বকেয়া', AppColors.emergencyRed) // window closed
        : days <= 0
            ? (toEnd == 0 ? 'আজ শেষ দিন' : 'এখন করুন · $toEnd দিন বাকি',
                AppColors.primary) // in window
            : ('পরের: ${two(dd.day)}/${two(dd.month)} ($days দিন বাকি)',
                AppColors.textSecondary); // upcoming
    final reminded = ReminderService.lastRemindedText(e);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(Icons.event_rounded, size: 13, color: color),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label.isEmpty ? text : '$label · $text',
                  // Show the full due status (checkup name + window) — wrap, don't clip.
                  maxLines: 3,
                  style: AppTextStyles.caption
                      .copyWith(color: color, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              _remindPill(p, e),
            ],
          ),
        ),
        if (reminded != null)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Row(
              children: [
                const Icon(Icons.check_circle, size: 12, color: AppColors.safeGreen),
                const SizedBox(width: 4),
                Text(reminded,
                    style: AppTextStyles.caption.copyWith(
                        color: AppColors.safeGreen, fontSize: 11)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _remindPill(PatientModel p, Map<String, dynamic> e) {
    return GestureDetector(
      onTap: () async {
        // Enrich with the patient's own name/mobile in case the event lacks them.
        final ev = {...e, 'patientName': p.name, 'patientMobile': p.mobile};
        final updated = await ReminderService.remind(context, ev);
        if (updated != null && mounted) {
          setState(() {
            _due[p.id] = {
              ...e,
              'lastRemindedAt': updated['lastRemindedAt'],
              'lastReminderChannel': updated['lastReminderChannel'],
            };
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notifications_active_outlined,
                size: 14, color: AppColors.primary),
            const SizedBox(width: 4),
            Text('মনে করান',
                style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase().trim();
    final filtered = q.isEmpty
        ? widget.patients
        : widget.patients.where((p) =>
            p.name.toLowerCase().contains(q) ||
            p.village.toLowerCase().contains(q) ||
            p.mobile.contains(q),
          ).toList();

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('pick_existing_patient'.tr, style: AppTextStyles.h2),
                  const SizedBox(height: 2),
                  Text(
                    widget.caseTitle,
                    style: AppTextStyles.bodySm.copyWith(color: AppColors.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              autofocus: false,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'search_patients_hint'.tr,
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 22),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Text(
                          widget.patients.isEmpty
                              ? 'no_patients_added_yet'.tr
                              : 'no_matches_found'.tr,
                          style: AppTextStyles.bodySm,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (_, i) {
                        final p = filtered[i];
                        return Material(
                          color: AppColors.primarySoft,
                          borderRadius: AppRadius.lgR,
                          child: InkWell(
                            onTap: () => widget.onPick(p),
                            borderRadius: AppRadius.lgR,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Builder(builder: (ctx) {
                                    final pb = p.mcpDetails['photo']?.toString();
                                    final photo = patientPhotoProvider(pb);
                                    return GestureDetector(
                                      onLongPress: photo == null
                                          ? null
                                          : () => showPatientPhotoDialog(ctx, pb, name: p.name),
                                      child: CircleAvatar(
                                        radius: 20,
                                        backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                                        backgroundImage: photo,
                                        child: photo == null
                                            ? Text(
                                                p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                                                style: AppTextStyles.labelLg
                                                    .copyWith(color: AppColors.primary),
                                              )
                                            : null,
                                      ),
                                    );
                                  }),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(p.name, style: AppTextStyles.labelLg),
                                        Text(
                                          '${p.type} · ${p.village.isEmpty ? "—" : p.village}',
                                          style: AppTextStyles.bodySm,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        _dueHint(p),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios_rounded,
                                      size: 14, color: AppColors.textSecondary),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
