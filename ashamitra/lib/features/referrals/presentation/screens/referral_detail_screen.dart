import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/services/local_storage_service.dart';
import '../../../../shared/components/app_header.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_input.dart';
import '../../controller/referral_controller.dart';
import '../../data/models/referral_model.dart';
import '../../services/referral_pdf.dart';
import 'referral_form_screen.dart';

/// One referral with its outcome timeline + the actions that move it forward:
/// mark reached → record outcome (admitted/treated/…) → done. Also prints the
/// Form 3 slip PDF (three copies: one for the ASHA, two travel with the patient).
class ReferralDetailScreen extends StatelessWidget {
  const ReferralDetailScreen({super.key, required this.referralId});
  final String referralId;

  ReferralController get _ctrl => Get.find<ReferralController>();

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

  String _caseLabel(String c) => switch (c) {
        'Pregnancy' || 'pregnancy' => 'refd_case_pregnancy'.tr,
        'Newborn' || 'newborn' => 'refd_case_newborn'.tr,
        'Child' || 'child' => 'refd_case_child'.tr,
        _ => 'refd_case_other'.tr,
      };

  String _fmtDate(DateTime? d) {
    if (d == null) return '';
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(d.day)}/${p(d.month)}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          child: Column(
            children: [
              AppHeader(title: 'refd_title'.tr),
              const SizedBox(height: 8),
              Expanded(
                child: Obx(() {
                  final r = _ctrl.referrals
                      .firstWhereOrNull((x) => x.id == referralId);
                  if (r == null) {
                    return Center(
                      child: Text('refd_not_found'.tr,
                          style: AppTextStyles.body
                              .copyWith(color: AppColors.textSecondary)),
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    children: [
                      _bandBanner(r),
                      const SizedBox(height: 14),
                      _card('refd_patient_info'.tr, [
                        _row('refd_name'.tr, r.patientName),
                        _row('refd_age'.tr, r.age),
                        _row('refd_gender'.tr, _genderLabel(r.gender)),
                        if (r.guardianName.isNotEmpty) _row('refd_guardian'.tr, r.guardianName),
                        _row('refd_village'.tr, r.village),
                        if (r.mobile.isNotEmpty) _row('refd_mobile'.tr, r.mobile),
                        _row('refd_case'.tr, _caseLabel(r.caseType)),
                      ]),
                      const SizedBox(height: 12),
                      _card('refd_medical_info'.tr, [
                        if (r.symptoms.isNotEmpty) _row('refd_symptoms'.tr, r.symptoms),
                        if (r.currentWeight.isNotEmpty)
                          _row('refd_weight'.tr, 'refd_weight_kg'.trParams({'w': r.currentWeight})),
                        if (r.imnci.isNotEmpty) _row('IMNCI', r.imnci),
                        if (r.medicinesGiven.isNotEmpty) _row('refd_medicines'.tr, r.medicinesGiven),
                        _row('refd_referred_to'.tr, r.referredTo),
                        _row('refd_date'.tr, _fmtDate(r.createdAt)),
                      ]),
                      if (r.status != 'pending') ...[
                        const SizedBox(height: 12),
                        _card('refd_outcome'.tr, [
                          _row('refd_status'.tr, _statusLabel(r.status)),
                          if (r.reachedDate != null)
                            _row('refd_reached'.tr, _fmtDate(r.reachedDate)),
                          if (r.admittedBy.isNotEmpty) _row('refd_admitted_by'.tr, r.admittedBy),
                          if (r.relation.isNotEmpty) _row('refd_relation'.tr, r.relation),
                          if (r.outcome.isNotEmpty) _row('refd_outcome'.tr, _outcomeLabel(r.outcome)),
                          if (r.facilityNotes.isNotEmpty) _row('refd_facility_notes'.tr, r.facilityNotes),
                        ]),
                      ],
                      const SizedBox(height: 20),
                      ..._actions(context, r),
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

  List<Widget> _actions(BuildContext context, ReferralModel r) {
    return [
      if (r.status == 'pending')
        AppButton(
          label: 'refd_btn_reached'.tr,
          icon: Icons.check_circle_outline,
          width: double.infinity,
          onPressed: () => _ctrl.updateReferral(
            r.copyWith(status: 'reached', reachedDate: DateTime.now()),
          ),
        ),
      if (r.isOpen) ...[
        const SizedBox(height: 10),
        AppButton(
          label: 'refd_btn_record_outcome'.tr,
          icon: Icons.assignment_turned_in_outlined,
          width: double.infinity,
          onPressed: () => _recordOutcome(context, r),
        ),
      ],
      const SizedBox(height: 10),
      AppButton(
        label: 'refd_btn_print_slip'.tr,
        icon: Icons.picture_as_pdf_outlined,
        width: double.infinity,
        outlined: true,
        onPressed: () => ReferralPdf.generate(r, header: _header()),
      ),
      const SizedBox(height: 10),
      AppButton(
        label: 'refd_btn_edit_slip'.tr,
        icon: Icons.edit_outlined,
        width: double.infinity,
        outlined: true,
        onPressed: () => Get.to(() => const ReferralFormScreen(), arguments: r),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          if (r.isOpen)
            Expanded(
              child: AppButton(
                label: 'refd_btn_cancel'.tr,
                width: double.infinity,
                outlined: true,
                color: AppColors.textSecondary,
                onPressed: () => _ctrl.updateReferral(r.copyWith(status: 'cancelled')),
              ),
            ),
          if (r.isOpen) const SizedBox(width: 10),
          Expanded(
            child: AppButton(
              label: 'refd_btn_delete'.tr,
              width: double.infinity,
              outlined: true,
              color: AppColors.emergencyRed,
              onPressed: () => _confirmDelete(context, r),
            ),
          ),
        ],
      ),
    ];
  }

  Future<void> _recordOutcome(BuildContext context, ReferralModel r) async {
    final admittedBy = TextEditingController(text: r.admittedBy);
    final relation = TextEditingController(text: r.relation);
    final notes = TextEditingController(text: r.facilityNotes);
    // Stored values stay canonical (persisted in r.outcome); only labels are localized.
    String outcome = r.outcome.isNotEmpty ? r.outcome : 'ভর্তি করা হয়েছে';
    const options = [
      'ভর্তি করা হয়েছে',
      'চিকিৎসা করে বাড়ি পাঠানো হয়েছে',
      'উপরের কেন্দ্রে রেফার',
      'মৃত্যু',
      'অন্যান্য',
    ];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 18,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: StatefulBuilder(
          builder: (ctx, setSheet) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('refd_btn_record_outcome'.tr, style: AppTextStyles.h3),
              const SizedBox(height: 14),
              Text('refd_outcome'.tr, style: AppTextStyles.label),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: outcome,
                isExpanded: true,
                style: AppTextStyles.body,
                decoration: const InputDecoration(),
                onChanged: (v) => setSheet(() => outcome = v ?? outcome),
                items: options
                    .map((o) => DropdownMenuItem(value: o, child: Text(_outcomeLabel(o))))
                    .toList(),
              ),
              const SizedBox(height: 12),
              AppInput(
                  hint: 'refd_admitted_by_hint'.tr,
                  label: 'refd_admitted_by'.tr,
                  controller: admittedBy),
              const SizedBox(height: 12),
              AppInput(
                  hint: 'refd_relation'.tr, label: 'refd_relation'.tr, controller: relation),
              const SizedBox(height: 12),
              AppInput(
                  hint: 'refd_facility_notes_hint'.tr,
                  label: 'refd_facility_notes'.tr,
                  controller: notes,
                  maxLines: 2),
              const SizedBox(height: 18),
              AppButton(
                label: 'refd_btn_save_completed'.tr,
                width: double.infinity,
                onPressed: () {
                  _ctrl.updateReferral(r.copyWith(
                    status: 'completed',
                    reachedDate: r.reachedDate ?? DateTime.now(),
                    admittedBy: admittedBy.text.trim(),
                    relation: relation.text.trim(),
                    outcome: outcome,
                    facilityNotes: notes.text.trim(),
                  ));
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, ReferralModel r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('refd_delete_title'.tr),
        content: Text('refd_delete_confirm'.trParams({'name': r.patientName})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('refd_no'.tr)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('refd_btn_delete'.tr,
                style: const TextStyle(color: AppColors.emergencyRed)),
          ),
        ],
      ),
    );
    if (ok == true) {
      _ctrl.deleteReferral(r.id);
      Get.back();
    }
  }

  // ── small UI helpers ──────────────────────────────────────────────────────
  String _genderLabel(String g) => switch (g) {
        'Female' => 'refd_gender_female'.tr,
        'Male' => 'refd_gender_male'.tr,
        _ => g,
      };

  String _statusLabel(String s) => switch (s) {
        'reached' => 'refd_status_reached'.tr,
        'completed' => 'refd_status_completed'.tr,
        'cancelled' => 'refd_status_cancelled'.tr,
        _ => 'refd_status_pending'.tr,
      };

  // Maps the canonical stored outcome value to its localized display label.
  String _outcomeLabel(String o) => switch (o) {
        'ভর্তি করা হয়েছে' => 'refd_outcome_admitted'.tr,
        'চিকিৎসা করে বাড়ি পাঠানো হয়েছে' => 'refd_outcome_treated_sent_home'.tr,
        'উপরের কেন্দ্রে রেফার' => 'refd_outcome_referred_higher'.tr,
        'মৃত্যু' => 'refd_outcome_death'.tr,
        'অন্যান্য' => 'refd_outcome_other'.tr,
        _ => o,
      };

  Widget _bandBanner(ReferralModel r) {
    final isRed = r.band == 'RED';
    final color = isRed
        ? AppColors.emergencyRed
        : (r.band == 'YELLOW' ? AppColors.warningYellow : AppColors.textSecondary);
    final text = isRed
        ? 'refd_band_red'.tr
        : (r.band == 'YELLOW' ? 'refd_band_yellow'.tr : 'refd_band_default'.tr);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: color, borderRadius: AppRadius.lgR),
      child: Row(
        children: [
          const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: AppTextStyles.label
                    .copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _card(String title, List<Widget> rows) {
    final visible = rows.whereType<Widget>().toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgR,
        boxShadow: AppShadows.low,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: AppTextStyles.label.copyWith(color: AppColors.primary)),
          const SizedBox(height: 8),
          ...visible,
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(label,
                style: AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
          ),
          Expanded(child: Text(value, style: AppTextStyles.body)),
        ],
      ),
    );
  }
}
