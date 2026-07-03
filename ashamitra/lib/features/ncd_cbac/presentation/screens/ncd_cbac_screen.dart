import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/components/app_header.dart';
import '../../../../shared/widgets/app_input.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/date_pick_field.dart';
import '../../../../shared/widgets/module_list_card.dart';
import '../../controller/ncd_cbac_controller.dart';
import '../../../patients/controller/patient_controller.dart';
import '../../../patients/data/models/patient_model.dart';

// ── CBAC Part A: the 6 risk-score items. The map value is the per-option score.
const _ageBands = <String, int>{'30-39': 0, '40-49': 1, '50-59': 2, '60+': 3};
const _tobaccoOpts = <String, int>{'never': 0, 'past': 1, 'current': 2};
const _waistOpts = <String, int>{'normal': 0, 'medium': 1, 'high': 2};

// ── CBAC Part B: early-detection symptoms, grouped. Breast/cervical groups are
// shown for women only. Any ticked symptom → refer for confirmation.
const _symGroups = <String, List<String>>{
  'nc_grp_general': ['nc_sym_breathless', 'nc_sym_vision', 'nc_sym_numbness'],
  'nc_grp_tb': [
    'nc_sym_cough2w', 'nc_sym_blood_sputum', 'nc_sym_fever2w',
    'nc_sym_weight_loss', 'nc_sym_night_sweats'
  ],
  'nc_grp_oral': [
    'nc_sym_mouth_ulcer', 'nc_sym_mouth_patch', 'nc_sym_mouth_open', 'nc_sym_lump_mouth'
  ],
  'nc_grp_breast': ['nc_sym_breast_lump', 'nc_sym_nipple_discharge', 'nc_sym_breast_change'],
  'nc_grp_cervical': [
    'nc_sym_bleed_between', 'nc_sym_bleed_postmeno', 'nc_sym_bleed_postcoital',
    'nc_sym_foul_discharge'
  ],
};
const _femaleOnlyGroups = {'nc_grp_breast', 'nc_grp_cervical'};

int riskScoreOf(Map data) {
  final age = (_ageBands[(data['ageBand'] ?? '').toString()] ?? 0);
  final tob = (_tobaccoOpts[(data['tobacco'] ?? 'never').toString()] ?? 0);
  final waist = (_waistOpts[(data['waist'] ?? 'normal').toString()] ?? 0);
  final alcohol = data['alcohol'] == true ? 1 : 0;
  final inactive = data['inactive'] == true ? 1 : 0;
  final family = data['familyHistory'] == true ? 2 : 0;
  return age + tob + waist + alcohol + inactive + family;
}

String _bandFromAge(String age) {
  final y = int.tryParse(age.trim());
  if (y == null) return '';
  if (y >= 60) return '60+';
  if (y >= 50) return '50-59';
  if (y >= 40) return '40-49';
  if (y >= 30) return '30-39';
  return '';
}

NcdCbacController _ncdCtrl() => Get.isRegistered<NcdCbacController>()
    ? Get.find<NcdCbacController>()
    : Get.put(NcdCbacController(), permanent: true);

PatientController _patientCtrl() => Get.isRegistered<PatientController>()
    ? Get.find<PatientController>()
    : Get.put(PatientController(), permanent: true);

/// Adults (30+) the registry already knows but who haven't been screened.
List<Map<String, dynamic>> _ncdCandidates(List<PatientModel> patients) {
  final out = <Map<String, dynamic>>[];
  for (final p in patients) {
    if (p.ageUnit != 'years') continue;
    final years = int.tryParse(p.age);
    if (years == null || years < 30) continue;
    out.add({
      'personName': p.name,
      'sex': p.gender,
      'age': p.age,
      'aadhaar': (p.mcpDetails['motherAadhaar'] ?? '').toString(),
      'village': p.village,
      'mobile': p.mobile,
      'ageBand': _bandFromAge(p.age),
      'status': 'active',
      'patientId': p.id,
    });
  }
  return out;
}

/// The NCD register: every adult 30+ screened with the CBAC, their risk score
/// and whether they were referred. Answers "who is high-risk / needs testing?".
class NcdCbacListScreen extends StatelessWidget {
  const NcdCbacListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = _ncdCtrl();
    final pc = _patientCtrl();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text('nc_new'.tr),
        onPressed: () => Get.to(() => const NcdCbacFormScreen()),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          child: Column(
            children: [
              AppHeader(
                title: 'nc_list_title'.tr,
                actions: [
                  HeaderActionCircle(
                    icon: Icons.refresh_rounded,
                    tooltip: 'nc_refresh'.tr,
                    onTap: ctrl.syncFromServer,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Obx(() {
                  final saved = ctrl.items.toList();
                  final savedPids = saved
                      .map((e) => (e['patientId'] ?? '').toString())
                      .where((s) => s.isNotEmpty)
                      .toSet();
                  final suggestions = _ncdCandidates(pc.patients.toList())
                      .where((c) => !savedPids.contains(c['patientId']))
                      .toList()
                    ..sort((a, b) => (a['personName'] ?? '')
                        .toString()
                        .compareTo((b['personName'] ?? '').toString()));
                  if (saved.isEmpty && suggestions.isEmpty) return _empty(ctrl);
                  return RefreshIndicator(
                    onRefresh: ctrl.syncFromServer,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                      children: [
                        ...saved.map((c) => _NcdCard(data: c)),
                        if (suggestions.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8, left: 4),
                            child: Text(
                                'nc_suggested'.trParams(
                                    {'count': '${suggestions.length}'}),
                                style: AppTextStyles.label.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700)),
                          ),
                          ...suggestions.map((c) => _NcdCard(data: c, suggested: true)),
                        ],
                      ],
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

  Widget _empty(NcdCbacController ctrl) => RefreshIndicator(
        onRefresh: ctrl.syncFromServer,
        child: ListView(
          children: [
            const SizedBox(height: 120),
            Icon(Icons.health_and_safety_outlined,
                size: 64, color: AppColors.primary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Center(
              child: Text('nc_empty_title'.tr,
                  style: AppTextStyles.h3.copyWith(color: AppColors.textSecondary)),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text('nc_empty_subtitle'.tr,
                  style: AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
            ),
          ],
        ),
      );
}

class _NcdCard extends StatelessWidget {
  const _NcdCard({required this.data, this.suggested = false});
  final Map<String, dynamic> data;
  final bool suggested;

  @override
  Widget build(BuildContext context) {
    final score = (data['riskScore'] as num?)?.toInt() ?? riskScoreOf(data);
    final symCount = (data['symptoms'] as List?)?.length ?? 0;
    final highRisk = score >= 4 || symCount > 0;
    final closed = (data['status'] ?? 'active').toString() == 'closed';
    final accent = suggested
        ? AppColors.primary
        : (closed
            ? AppColors.textSecondary
            : (highRisk ? AppColors.emergencyRed : AppColors.safeGreen));
    final chip = suggested
        ? 'nc_chip_suggested'.tr
        : (closed
            ? 'nc_chip_closed'.tr
            : (highRisk ? 'nc_chip_high'.tr : 'nc_chip_low'.tr));
    final subtitle = [
      if ((data['age'] ?? '').toString().isNotEmpty)
        'nc_age_short'.trParams({'age': '${data['age']}'}),
      if ((data['village'] ?? '').toString().isNotEmpty) data['village'],
      if (!suggested) 'nc_score_short'.trParams({'score': '$score'}),
      if (symCount > 0) 'nc_symptoms_short'.trParams({'count': '$symCount'}),
    ].where((e) => e.toString().isNotEmpty).join('  ·  ');
    return ModuleListCard(
      icon: suggested
          ? Icons.person_add_alt_1_rounded
          : Icons.health_and_safety_rounded,
      title: (data['personName'] ?? '').toString(),
      subtitle: subtitle,
      accent: accent,
      badge: chip,
      danger: highRisk && !closed && !suggested,
      onTap: () => Get.to(() => const NcdCbacFormScreen(), arguments: data),
    );
  }
}

/// Add / edit a CBAC screening. Get.arguments = existing record Map (edit) or null.
class NcdCbacFormScreen extends StatefulWidget {
  const NcdCbacFormScreen({super.key});
  @override
  State<NcdCbacFormScreen> createState() => _NcdCbacFormScreenState();
}

class _NcdCbacFormScreenState extends State<NcdCbacFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _aadhaar = TextEditingController();
  final _village = TextEditingController();
  final _mobile = TextEditingController();
  final _bp = TextEditingController();
  final _sugar = TextEditingController();
  final _referredTo = TextEditingController();
  final _notes = TextEditingController();

  String _sex = 'Female';
  String _ageBand = '';
  String _tobacco = 'never';
  String _waist = 'normal';
  bool _alcohol = false;
  bool _inactive = false;
  bool _familyHistory = false;
  bool _knownHtn = false;
  bool _knownDiabetes = false;
  bool _knownHeart = false;
  bool _knownCopd = false;
  bool _referred = false;
  bool _closed = false;
  final _symptoms = <String>{};
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
      _aadhaar.text = (a['aadhaar'] ?? '').toString();
      _village.text = (a['village'] ?? '').toString();
      _mobile.text = (a['mobile'] ?? '').toString();
      _bp.text = (a['bp'] ?? '').toString();
      _sugar.text = (a['bloodSugar'] ?? '').toString();
      _referredTo.text = (a['referredTo'] ?? '').toString();
      _notes.text = (a['notes'] ?? '').toString();
      _sex = (a['sex'] ?? 'Female').toString().isEmpty ? 'Female' : (a['sex']).toString();
      _ageBand = (a['ageBand'] ?? '').toString();
      _tobacco = (a['tobacco'] ?? 'never').toString();
      _waist = (a['waist'] ?? 'normal').toString();
      _alcohol = a['alcohol'] == true;
      _inactive = a['inactive'] == true;
      _familyHistory = a['familyHistory'] == true;
      _knownHtn = a['knownHtn'] == true;
      _knownDiabetes = a['knownDiabetes'] == true;
      _knownHeart = a['knownHeart'] == true;
      _knownCopd = a['knownCopd'] == true;
      _referred = a['referred'] == true;
      _closed = (a['status'] ?? 'active').toString() == 'closed';
      _symptoms.addAll(((a['symptoms'] as List?) ?? []).map((e) => e.toString()));
      _followUp = DateTime.tryParse((a['followUpDate'] ?? '').toString());
    }
    if (_ageBand.isEmpty) _ageBand = _bandFromAge(_age.text);
  }

  @override
  void dispose() {
    for (final c in [
      _name, _age, _aadhaar, _village, _mobile, _bp, _sugar, _referredTo, _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  int get _score => riskScoreOf({
        'ageBand': _ageBand,
        'tobacco': _tobacco,
        'waist': _waist,
        'alcohol': _alcohol,
        'inactive': _inactive,
        'familyHistory': _familyHistory,
      });

  bool get _highRisk => _score >= 4 || _symptoms.isNotEmpty;

  String? _aadhaarV(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return null;
    return RegExp(r'^\d{12}$').hasMatch(s) ? null : 'nc_aadhaar_invalid'.tr;
  }

  Future<void> _pickFollowUp() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _followUp ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (d != null) setState(() => _followUp = d);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final ctrl = _ncdCtrl();
    final rec = <String, dynamic>{
      if (_editingId.isNotEmpty) 'id': _editingId,
      'patientId': _patientId,
      'personName': _name.text.trim(),
      'sex': _sex,
      'age': _age.text.trim(),
      'aadhaar': _aadhaar.text.trim(),
      'village': _village.text.trim(),
      'mobile': _mobile.text.trim(),
      'ageBand': _ageBand,
      'tobacco': _tobacco,
      'alcohol': _alcohol,
      'waist': _waist,
      'inactive': _inactive,
      'familyHistory': _familyHistory,
      'riskScore': _score,
      'symptoms': _symptoms.toList(),
      'knownHtn': _knownHtn,
      'knownDiabetes': _knownDiabetes,
      'knownHeart': _knownHeart,
      'knownCopd': _knownCopd,
      'bp': _bp.text.trim(),
      'bloodSugar': _sugar.text.trim(),
      'referred': _referred,
      'referredTo': _referredTo.text.trim(),
      'followUpDate': _followUp?.toIso8601String() ?? '',
      'notes': _notes.text.trim(),
      'status': _closed ? 'closed' : 'active',
    };
    await ctrl.upsert(rec);
    Get.back();
    Get.snackbar('nc_snack_title'.tr, 'nc_snack_saved'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.safeGreen,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        duration: const Duration(seconds: 2));
  }

  @override
  Widget build(BuildContext context) {
    final female = _sex == 'Female';
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          child: Column(
            children: [
              AppHeader(title: _editingId.isEmpty ? 'nc_new'.tr : 'nc_edit'.tr),
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
                          hint: 'nc_name'.tr,
                          label: 'nc_name'.tr,
                          controller: _name,
                          prefixIcon: const Icon(Icons.person_outline_rounded,
                              color: AppColors.primary, size: 20),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'nc_name_required'.tr : null,
                        ),
                        const SizedBox(height: 14),
                        Row(children: [
                          Expanded(child: _sexDropdown()),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppInput(
                              hint: 'nc_age'.tr,
                              label: 'nc_age'.tr,
                              controller: _age,
                              keyboardType: TextInputType.number,
                              onChanged: (v) {
                                final b = _bandFromAge(v);
                                if (b.isNotEmpty && b != _ageBand) {
                                  setState(() => _ageBand = b);
                                }
                              },
                            ),
                          ),
                        ]),
                        const SizedBox(height: 14),
                        AppInput(
                          hint: 'nc_aadhaar_hint'.tr,
                          label: 'nc_aadhaar'.tr,
                          controller: _aadhaar,
                          keyboardType: TextInputType.number,
                          maxLength: 12,
                          prefixIcon: const Icon(Icons.badge_outlined,
                              color: AppColors.primary, size: 20),
                          validator: _aadhaarV,
                        ),
                        const SizedBox(height: 14),
                        Row(children: [
                          Expanded(
                            child: AppInput(
                              hint: 'nc_village'.tr,
                              label: 'nc_village'.tr,
                              controller: _village,
                              prefixIcon: const Icon(Icons.location_on_outlined,
                                  color: AppColors.primary, size: 20),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppInput(
                              hint: 'nc_mobile'.tr,
                              label: 'nc_mobile'.tr,
                              controller: _mobile,
                              keyboardType: TextInputType.phone,
                              maxLength: 10,
                            ),
                          ),
                        ]),

                        // ── Part A: risk score ──
                        _sectionTitle('nc_part_a'.tr),
                        _enumDropdown('nc_age_band'.tr, _ageBand.isEmpty ? '30-39' : _ageBand,
                            _ageBands.keys, (v) => setState(() => _ageBand = v),
                            labelFor: (k) => 'nc_band_$k'.tr),
                        const SizedBox(height: 12),
                        _enumDropdown('nc_tobacco'.tr, _tobacco, _tobaccoOpts.keys,
                            (v) => setState(() => _tobacco = v),
                            labelFor: (k) => 'nc_tobacco_$k'.tr),
                        const SizedBox(height: 12),
                        _enumDropdown(
                            female ? 'nc_waist_f'.tr : 'nc_waist_m'.tr,
                            _waist, _waistOpts.keys, (v) => setState(() => _waist = v),
                            labelFor: (k) =>
                                '${'nc_waist_$k'.tr} (${(female ? 'nc_waist_f_$k' : 'nc_waist_m_$k').tr})'),
                        _switch('nc_alcohol'.tr, _alcohol, (v) => setState(() => _alcohol = v)),
                        _switch('nc_inactive'.tr, _inactive, (v) => setState(() => _inactive = v)),
                        _switch('nc_family_history'.tr, _familyHistory,
                            (v) => setState(() => _familyHistory = v)),
                        const SizedBox(height: 12),
                        _scoreBanner(),

                        // ── Part B: symptoms ──
                        _sectionTitle('nc_part_b'.tr),
                        ..._symGroups.entries
                            .where((g) => female || !_femaleOnlyGroups.contains(g.key))
                            .expand((g) => [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8, bottom: 2),
                                    child: Text(g.key.tr,
                                        style: AppTextStyles.caption.copyWith(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w700)),
                                  ),
                                  ...g.value.map(_symptomTile),
                                ]),

                        // ── Known conditions + measurements ──
                        _sectionTitle('nc_known'.tr),
                        _switch('nc_known_htn'.tr, _knownHtn, (v) => setState(() => _knownHtn = v)),
                        _switch('nc_known_diabetes'.tr, _knownDiabetes,
                            (v) => setState(() => _knownDiabetes = v)),
                        _switch('nc_known_heart'.tr, _knownHeart,
                            (v) => setState(() => _knownHeart = v)),
                        _switch('nc_known_copd'.tr, _knownCopd,
                            (v) => setState(() => _knownCopd = v)),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(
                            child: AppInput(
                              hint: 'nc_bp_hint'.tr,
                              label: 'nc_bp'.tr,
                              controller: _bp,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppInput(
                              hint: 'nc_sugar_hint'.tr,
                              label: 'nc_sugar'.tr,
                              controller: _sugar,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ]),

                        // ── Outcome ──
                        _sectionTitle('nc_outcome'.tr),
                        _switch('nc_referred'.tr, _referred, (v) => setState(() => _referred = v),
                            danger: true),
                        if (_referred) ...[
                          const SizedBox(height: 8),
                          AppInput(
                            hint: 'nc_referred_to_hint'.tr,
                            label: 'nc_referred_to'.tr,
                            controller: _referredTo,
                          ),
                        ],
                        const SizedBox(height: 14),
                        DatePickField(
                          label: 'nc_followup'.tr,
                          value: _followUp,
                          onTap: _pickFollowUp,
                          onClear: () => setState(() => _followUp = null),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('nc_closed'.tr, style: AppTextStyles.label),
                          subtitle: Text('nc_closed_reason'.tr,
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.textSecondary)),
                          value: _closed,
                          onChanged: (v) => setState(() => _closed = v),
                        ),
                        const SizedBox(height: 8),
                        AppInput(
                          hint: 'nc_notes'.tr,
                          label: 'nc_notes'.tr,
                          controller: _notes,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 24),
                        AppButton(
                          label: 'nc_save'.tr,
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
        child: Row(children: [
          Container(
            width: 4, height: 16,
            decoration: BoxDecoration(
                color: AppColors.purple, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 8),
          Text(t,
              style: AppTextStyles.h3.copyWith(color: AppColors.purple, fontSize: 16)),
        ]),
      );

  Widget _sexDropdown() {
    const opts = {'Female': 'nc_sex_female', 'Male': 'nc_sex_male', 'Other': 'nc_sex_other'};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('nc_sex'.tr, style: AppTextStyles.label),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _sex,
          isExpanded: true,
          style: AppTextStyles.body,
          onChanged: (v) => setState(() => _sex = v ?? 'Female'),
          items: opts.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value.tr)))
              .toList(),
        ),
      ],
    );
  }

  Widget _enumDropdown(String label, String value, Iterable<String> keys,
      void Function(String) onChanged,
      {required String Function(String) labelFor}) {
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
          items: keys
              .map((k) => DropdownMenuItem(value: k, child: Text(labelFor(k))))
              .toList(),
        ),
      ],
    );
  }

  Widget _switch(String title, bool value, void Function(bool) onChanged,
          {bool danger = false}) =>
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        activeThumbColor: danger ? AppColors.emergencyRed : AppColors.primary,
        title: Text(title, style: AppTextStyles.label),
        value: value,
        onChanged: onChanged,
      );

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

  Widget _scoreBanner() {
    final color = _highRisk ? AppColors.emergencyRed : AppColors.safeGreen;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(_highRisk ? Icons.warning_amber_rounded : Icons.check_circle_outline,
              color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _highRisk
                  ? 'nc_score_high'.trParams({'score': '$_score'})
                  : 'nc_score_low'.trParams({'score': '$_score'}),
              style: AppTextStyles.label.copyWith(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
