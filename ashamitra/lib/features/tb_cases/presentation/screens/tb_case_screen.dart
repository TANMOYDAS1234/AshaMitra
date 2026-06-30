import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/components/app_header.dart';
import '../../../../shared/widgets/app_input.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../eligible_couples/presentation/screens/eligible_couple_screen.dart'
    show DatePickField;
import '../../controller/tb_case_controller.dart';

// Presumptive-TB symptom checklist. Any "yes" → refer for sputum/CBNAAT.
const _tbSymptoms = [
  'tb_sym_cough2w', 'tb_sym_fever2w', 'tb_sym_weight_loss',
  'tb_sym_night_sweats', 'tb_sym_blood_sputum', 'tb_sym_contact',
];

const _stages = <String, String>{
  'presumptive': 'tb_stage_presumptive',
  'on_treatment': 'tb_stage_on_treatment',
  'completed': 'tb_stage_completed',
};
const _testResults = <String, String>{
  '': 'tb_result_none', 'pending': 'tb_result_pending',
  'positive': 'tb_result_positive', 'negative': 'tb_result_negative',
};
const _outcomes = <String, String>{
  '': 'tb_outcome_none', 'cured': 'tb_outcome_cured', 'completed': 'tb_outcome_completed',
  'lost': 'tb_outcome_lost', 'died': 'tb_outcome_died', 'failed': 'tb_outcome_failed',
};

TbCaseController _tbCtrl() => Get.isRegistered<TbCaseController>()
    ? Get.find<TbCaseController>()
    : Get.put(TbCaseController(), permanent: true);

/// The TB register: presumptive cases (screened, referred for testing) and
/// confirmed cases on DOTS treatment the ASHA supports for adherence.
class TbCaseListScreen extends StatelessWidget {
  const TbCaseListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = _tbCtrl();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text('tb_new'.tr),
        onPressed: () => Get.to(() => const TbCaseFormScreen()),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          child: Column(
            children: [
              AppHeader(
                title: 'tb_list_title'.tr,
                actions: [
                  HeaderActionCircle(
                    icon: Icons.refresh_rounded,
                    tooltip: 'tb_refresh'.tr,
                    onTap: ctrl.syncFromServer,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Obx(() {
                  final saved = ctrl.items.toList();
                  if (saved.isEmpty) return _empty(ctrl);
                  return RefreshIndicator(
                    onRefresh: ctrl.syncFromServer,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                      children: saved.map((c) => _TbCard(data: c)).toList(),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _empty(TbCaseController ctrl) => RefreshIndicator(
        onRefresh: ctrl.syncFromServer,
        child: ListView(
          children: [
            const SizedBox(height: 120),
            Icon(Icons.coronavirus_outlined,
                size: 64, color: AppColors.primary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Center(
              child: Text('tb_empty_title'.tr,
                  style: AppTextStyles.h3.copyWith(color: AppColors.textSecondary)),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text('tb_empty_subtitle'.tr,
                  style: AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
            ),
          ],
        ),
      );
}

class _TbCard extends StatelessWidget {
  const _TbCard({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final stage = (data['stage'] ?? 'presumptive').toString();
    final symCount = (data['symptoms'] as List?)?.length ?? 0;
    final color = switch (stage) {
      'on_treatment' => AppColors.primary,
      'completed' => AppColors.safeGreen,
      _ => AppColors.emergencyRed,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.surface,
        borderRadius: AppRadius.lgR,
        child: InkWell(
          borderRadius: AppRadius.lgR,
          onTap: () => Get.to(() => const TbCaseFormScreen(), arguments: data),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: AppRadius.lgR,
              boxShadow: AppShadows.low,
              border: Border(left: BorderSide(color: color, width: 4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text((data['personName'] ?? '').toString(),
                          style: AppTextStyles.h3,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text((_stages[stage] ?? 'tb_stage_presumptive').tr,
                          style: AppTextStyles.caption
                              .copyWith(color: color, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    if ((data['village'] ?? '').toString().isNotEmpty) data['village'],
                    if (stage == 'presumptive' && symCount > 0)
                      'tb_symptoms_short'.trParams({'count': '$symCount'}),
                    if (stage == 'presumptive' &&
                        (data['testResult'] ?? '').toString().isNotEmpty)
                      (_testResults[(data['testResult']).toString()] ?? '').tr,
                    if (stage != 'presumptive' &&
                        (data['regimen'] ?? '').toString().isNotEmpty)
                      data['regimen'],
                  ].where((e) => e.toString().isNotEmpty).join('  ·  '),
                  style: AppTextStyles.label.copyWith(color: AppColors.textSecondary),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Add / edit a TB case. Get.arguments = existing record Map (edit) or null.
class TbCaseFormScreen extends StatefulWidget {
  const TbCaseFormScreen({super.key});
  @override
  State<TbCaseFormScreen> createState() => _TbCaseFormScreenState();
}

class _TbCaseFormScreenState extends State<TbCaseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _village = TextEditingController();
  final _mobile = TextEditingController();
  final _regimen = TextEditingController();
  final _dosesTaken = TextEditingController();
  final _dosesMissed = TextEditingController();
  final _nikshay = TextEditingController();
  final _notes = TextEditingController();

  String _sex = 'Male';
  String _stage = 'presumptive';
  String _testResult = '';
  String _tbType = 'pulmonary';
  String _followUpSputum = '';
  String _outcome = '';
  bool _referredForTest = false;
  final _symptoms = <String>{};
  DateTime? _treatmentStart;
  DateTime? _followUp;
  String _editingId = '';
  String _patientId = '';

  @override
  void initState() {
    super.initState();
    final a = Get.arguments;
    if (a is Map) {
      _editingId = (a['id'] ?? '').toString();
      _patientId = (a['patientId'] ?? '').toString();
      _name.text = (a['personName'] ?? '').toString();
      _age.text = (a['age'] ?? '').toString();
      _village.text = (a['village'] ?? '').toString();
      _mobile.text = (a['mobile'] ?? '').toString();
      _regimen.text = (a['regimen'] ?? '').toString();
      _dosesTaken.text = (a['dosesTaken'] ?? '').toString();
      _dosesMissed.text = (a['dosesMissed'] ?? '').toString();
      _nikshay.text = (a['nikshayId'] ?? '').toString();
      _notes.text = (a['notes'] ?? '').toString();
      _sex = (a['sex'] ?? 'Male').toString().isEmpty ? 'Male' : (a['sex']).toString();
      _stage = (a['stage'] ?? 'presumptive').toString();
      _testResult = (a['testResult'] ?? '').toString();
      _tbType = (a['tbType'] ?? 'pulmonary').toString().isEmpty
          ? 'pulmonary'
          : (a['tbType']).toString();
      _followUpSputum = (a['followUpSputum'] ?? '').toString();
      _outcome = (a['outcome'] ?? '').toString();
      _referredForTest = a['referredForTest'] == true;
      _symptoms.addAll(((a['symptoms'] as List?) ?? []).map((e) => e.toString()));
      _treatmentStart = DateTime.tryParse((a['treatmentStart'] ?? '').toString());
      _followUp = DateTime.tryParse((a['followUpDate'] ?? '').toString());
    }
  }

  @override
  void dispose() {
    for (final c in [
      _name, _age, _village, _mobile, _regimen, _dosesTaken, _dosesMissed,
      _nikshay, _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(DateTime? cur, void Function(DateTime) set) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: cur ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 3),
    );
    if (d != null) setState(() => set(d));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final ctrl = _tbCtrl();
    final rec = <String, dynamic>{
      if (_editingId.isNotEmpty) 'id': _editingId,
      'patientId': _patientId,
      'personName': _name.text.trim(),
      'sex': _sex,
      'age': _age.text.trim(),
      'village': _village.text.trim(),
      'mobile': _mobile.text.trim(),
      'stage': _stage,
      'symptoms': _symptoms.toList(),
      'referredForTest': _referredForTest,
      'testResult': _testResult,
      'tbType': _tbType,
      'treatmentStart': _treatmentStart?.toIso8601String() ?? '',
      'regimen': _regimen.text.trim(),
      'dosesTaken': _dosesTaken.text.trim(),
      'dosesMissed': _dosesMissed.text.trim(),
      'followUpSputum': _followUpSputum,
      'nikshayId': _nikshay.text.trim(),
      'outcome': _outcome,
      'followUpDate': _followUp?.toIso8601String() ?? '',
      'notes': _notes.text.trim(),
    };
    await ctrl.upsert(rec);
    Get.back();
    Get.snackbar('tb_snack_title'.tr, 'tb_snack_saved'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.safeGreen,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        duration: const Duration(seconds: 2));
  }

  @override
  Widget build(BuildContext context) {
    final presumptive = _stage == 'presumptive';
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          child: Column(
            children: [
              AppHeader(title: _editingId.isEmpty ? 'tb_new'.tr : 'tb_edit'.tr),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppInput(
                          hint: 'tb_name'.tr,
                          label: 'tb_name'.tr,
                          controller: _name,
                          prefixIcon: const Icon(Icons.person_outline_rounded,
                              color: AppColors.primary, size: 20),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'tb_name_required'.tr : null,
                        ),
                        const SizedBox(height: 14),
                        Row(children: [
                          Expanded(
                            child: _dropdown('tb_sex'.tr, _sex,
                                const {'Male': 'tb_sex_male', 'Female': 'tb_sex_female', 'Other': 'tb_sex_other'},
                                (v) => setState(() => _sex = v)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppInput(
                              hint: 'tb_age'.tr,
                              label: 'tb_age'.tr,
                              controller: _age,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ]),
                        const SizedBox(height: 14),
                        Row(children: [
                          Expanded(
                            child: AppInput(
                              hint: 'tb_village'.tr,
                              label: 'tb_village'.tr,
                              controller: _village,
                              prefixIcon: const Icon(Icons.location_on_outlined,
                                  color: AppColors.primary, size: 20),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppInput(
                              hint: 'tb_mobile'.tr,
                              label: 'tb_mobile'.tr,
                              controller: _mobile,
                              keyboardType: TextInputType.phone,
                              maxLength: 10,
                            ),
                          ),
                        ]),
                        const SizedBox(height: 14),
                        _dropdown('tb_stage'.tr, _stage, _stages,
                            (v) => setState(() => _stage = v)),

                        if (presumptive) ...[
                          _sectionTitle('tb_presumptive_section'.tr),
                          ..._tbSymptoms.map(_symptomTile),
                          const SizedBox(height: 8),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            activeThumbColor: AppColors.emergencyRed,
                            title: Text('tb_referred_for_test'.tr, style: AppTextStyles.label),
                            value: _referredForTest,
                            onChanged: (v) => setState(() => _referredForTest = v),
                          ),
                          if (_symptoms.isNotEmpty) _presumptiveBanner(),
                          const SizedBox(height: 8),
                          _dropdown('tb_test_result'.tr, _testResult, _testResults,
                              (v) => setState(() => _testResult = v)),
                        ] else ...[
                          _sectionTitle('tb_treatment_section'.tr),
                          _dropdown('tb_type'.tr, _tbType,
                              const {'pulmonary': 'tb_type_pulmonary', 'extra_pulmonary': 'tb_type_extra'},
                              (v) => setState(() => _tbType = v)),
                          const SizedBox(height: 12),
                          AppInput(
                            hint: 'tb_nikshay_hint'.tr,
                            label: 'tb_nikshay'.tr,
                            controller: _nikshay,
                          ),
                          const SizedBox(height: 14),
                          DatePickField(
                            label: 'tb_treatment_start'.tr,
                            value: _treatmentStart,
                            onTap: () => _pickDate(_treatmentStart, (d) => _treatmentStart = d),
                            onClear: () => setState(() => _treatmentStart = null),
                          ),
                          const SizedBox(height: 14),
                          AppInput(
                            hint: 'tb_regimen_hint'.tr,
                            label: 'tb_regimen'.tr,
                            controller: _regimen,
                          ),
                          const SizedBox(height: 14),
                          Row(children: [
                            Expanded(
                              child: AppInput(
                                hint: 'tb_doses_taken'.tr,
                                label: 'tb_doses_taken'.tr,
                                controller: _dosesTaken,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: AppInput(
                                hint: 'tb_doses_missed'.tr,
                                label: 'tb_doses_missed'.tr,
                                controller: _dosesMissed,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ]),
                          const SizedBox(height: 12),
                          _dropdown('tb_followup_sputum'.tr, _followUpSputum, _testResults,
                              (v) => setState(() => _followUpSputum = v)),
                          const SizedBox(height: 12),
                          _dropdown('tb_outcome'.tr, _outcome, _outcomes,
                              (v) => setState(() => _outcome = v)),
                        ],

                        const SizedBox(height: 14),
                        DatePickField(
                          label: 'tb_followup'.tr,
                          value: _followUp,
                          onTap: () => _pickDate(_followUp, (d) => _followUp = d),
                          onClear: () => setState(() => _followUp = null),
                        ),
                        const SizedBox(height: 14),
                        AppInput(
                          hint: 'tb_notes'.tr,
                          label: 'tb_notes'.tr,
                          controller: _notes,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 24),
                        AppButton(
                          label: 'tb_save'.tr,
                          icon: Icons.check_rounded,
                          width: double.infinity,
                          onPressed: _save,
                        ),
                        const SizedBox(height: 24),
                      ],
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

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 8),
        child: Text(t,
            style: AppTextStyles.h3.copyWith(color: AppColors.primary, fontSize: 16)),
      );

  Widget _dropdown(String label, String value, Map<String, String> opts,
      void Function(String) onChanged) {
    final keys = opts.keys.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: keys.contains(value) ? value : keys.first,
          isExpanded: true,
          style: AppTextStyles.body,
          onChanged: (v) => onChanged(v ?? keys.first),
          items: opts.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value.tr)))
              .toList(),
        ),
      ],
    );
  }

  Widget _symptomTile(String key) {
    final on = _symptoms.contains(key);
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: AppColors.emergencyRed,
      title: Text(key.tr, style: AppTextStyles.label),
      value: on,
      onChanged: (v) =>
          setState(() => v == true ? _symptoms.add(key) : _symptoms.remove(key)),
    );
  }

  Widget _presumptiveBanner() => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.emergencyRed.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.emergencyRed.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppColors.emergencyRed, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text('tb_presumptive_banner'.tr,
                  style: AppTextStyles.label.copyWith(
                      color: AppColors.emergencyRed, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
}
