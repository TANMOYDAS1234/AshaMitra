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
        'Pregnancy' || 'pregnancy' => 'গর্ভবতী',
        'Newborn' || 'newborn' => 'নবজাতক',
        'Child' || 'child' => 'শিশু',
        _ => 'অন্যান্য',
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
              AppHeader(title: 'রেফারেল বিবরণ'),
              const SizedBox(height: 8),
              Expanded(
                child: Obx(() {
                  final r = _ctrl.referrals
                      .firstWhereOrNull((x) => x.id == referralId);
                  if (r == null) {
                    return Center(
                      child: Text('রেফারেলটি পাওয়া যায়নি',
                          style: AppTextStyles.body
                              .copyWith(color: AppColors.textSecondary)),
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    children: [
                      _bandBanner(r),
                      const SizedBox(height: 14),
                      _card('রোগীর তথ্য', [
                        _row('নাম', r.patientName),
                        _row('বয়স', r.age),
                        _row('লিঙ্গ', _genderLabel(r.gender)),
                        if (r.guardianName.isNotEmpty) _row('অভিভাবক', r.guardianName),
                        _row('গ্রাম', r.village),
                        if (r.mobile.isNotEmpty) _row('মোবাইল', r.mobile),
                        _row('কেস', _caseLabel(r.caseType)),
                      ]),
                      const SizedBox(height: 12),
                      _card('চিকিৎসা তথ্য', [
                        if (r.symptoms.isNotEmpty) _row('লক্ষণ', r.symptoms),
                        if (r.currentWeight.isNotEmpty) _row('ওজন', '${r.currentWeight} কেজি'),
                        if (r.imnci.isNotEmpty) _row('IMNCI', r.imnci),
                        if (r.medicinesGiven.isNotEmpty) _row('ওষুধ', r.medicinesGiven),
                        _row('রেফার', r.referredTo),
                        _row('তারিখ', _fmtDate(r.createdAt)),
                      ]),
                      if (r.status != 'pending') ...[
                        const SizedBox(height: 12),
                        _card('ফলাফল', [
                          _row('অবস্থা', _statusLabel(r.status)),
                          if (r.reachedDate != null)
                            _row('পৌঁছেছেন', _fmtDate(r.reachedDate)),
                          if (r.admittedBy.isNotEmpty) _row('ভর্তি করেছেন', r.admittedBy),
                          if (r.relation.isNotEmpty) _row('সম্পর্ক', r.relation),
                          if (r.outcome.isNotEmpty) _row('ফলাফল', r.outcome),
                          if (r.facilityNotes.isNotEmpty) _row('মন্তব্য', r.facilityNotes),
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
          label: 'কেন্দ্রে পৌঁছেছেন',
          icon: Icons.check_circle_outline,
          width: double.infinity,
          onPressed: () => _ctrl.updateReferral(
            r.copyWith(status: 'reached', reachedDate: DateTime.now()),
          ),
        ),
      if (r.isOpen) ...[
        const SizedBox(height: 10),
        AppButton(
          label: 'ফলাফল নথিভুক্ত করুন',
          icon: Icons.assignment_turned_in_outlined,
          width: double.infinity,
          onPressed: () => _recordOutcome(context, r),
        ),
      ],
      const SizedBox(height: 10),
      AppButton(
        label: 'স্লিপ প্রিন্ট / PDF',
        icon: Icons.picture_as_pdf_outlined,
        width: double.infinity,
        outlined: true,
        onPressed: () => ReferralPdf.generate(r, header: _header()),
      ),
      const SizedBox(height: 10),
      AppButton(
        label: 'স্লিপ সম্পাদনা',
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
                label: 'বাতিল',
                width: double.infinity,
                outlined: true,
                color: AppColors.textSecondary,
                onPressed: () => _ctrl.updateReferral(r.copyWith(status: 'cancelled')),
              ),
            ),
          if (r.isOpen) const SizedBox(width: 10),
          Expanded(
            child: AppButton(
              label: 'মুছুন',
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
              Text('ফলাফল নথিভুক্ত করুন', style: AppTextStyles.h3),
              const SizedBox(height: 14),
              Text('ফলাফল', style: AppTextStyles.label),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: outcome,
                isExpanded: true,
                style: AppTextStyles.body,
                decoration: const InputDecoration(),
                onChanged: (v) => setSheet(() => outcome = v ?? outcome),
                items: options
                    .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                    .toList(),
              ),
              const SizedBox(height: 12),
              AppInput(hint: 'কে ভর্তি করেছেন', label: 'ভর্তি করেছেন', controller: admittedBy),
              const SizedBox(height: 12),
              AppInput(hint: 'সম্পর্ক', label: 'সম্পর্ক', controller: relation),
              const SizedBox(height: 12),
              AppInput(hint: 'কেন্দ্রের মন্তব্য', label: 'মন্তব্য', controller: notes, maxLines: 2),
              const SizedBox(height: 18),
              AppButton(
                label: 'সম্পন্ন হিসেবে সংরক্ষণ',
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
        title: const Text('রেফারেল মুছবেন?'),
        content: Text('${r.patientName}-এর রেফারেলটি মুছে ফেলা হবে।'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('না')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('মুছুন', style: TextStyle(color: AppColors.emergencyRed)),
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
        'Female' => 'মহিলা',
        'Male' => 'পুরুষ',
        _ => g,
      };

  String _statusLabel(String s) => switch (s) {
        'reached' => 'কেন্দ্রে পৌঁছেছেন',
        'completed' => 'সম্পন্ন',
        'cancelled' => 'বাতিল',
        _ => 'অপেক্ষমাণ',
      };

  Widget _bandBanner(ReferralModel r) {
    final isRed = r.band == 'RED';
    final color = isRed
        ? AppColors.emergencyRed
        : (r.band == 'YELLOW' ? AppColors.warningYellow : AppColors.textSecondary);
    final text = isRed
        ? 'জরুরি রেফার (RED) — ৩০ মিনিটের মধ্যে'
        : (r.band == 'YELLOW' ? 'রেফার (YELLOW) — ২৪ ঘণ্টার মধ্যে' : 'রেফার');
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
