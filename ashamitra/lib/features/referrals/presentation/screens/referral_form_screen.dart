import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/services/api_service.dart';
import '../../../../shared/components/app_header.dart';
import '../../../../shared/widgets/app_input.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../controller/referral_controller.dart';
import '../../data/models/referral_model.dart';

/// Create / edit an ASHA referral slip (Form 3). Opened either blank, pre-filled
/// from a RED/YELLOW triage outcome (Get.arguments = Map), or in edit mode
/// (Get.arguments = ReferralModel).
class ReferralFormScreen extends StatefulWidget {
  const ReferralFormScreen({super.key});

  @override
  State<ReferralFormScreen> createState() => _ReferralFormScreenState();
}

class _ReferralFormScreenState extends State<ReferralFormScreen> {
  late final ReferralController _ctrl;
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _guardianCtrl = TextEditingController();
  final _villageCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _symptomsCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _imnciCtrl = TextEditingController();
  final _medsCtrl = TextEditingController();
  final _referredToCtrl = TextEditingController();

  String _caseType = 'Pregnancy';
  String _gender = 'Female';
  String _band = 'RED';
  String _patientId = '';
  String _reason = '';
  bool _saving = false;
  ReferralModel? _editing;

  bool get _isChild => _caseType == 'Newborn' || _caseType == 'Child';

  @override
  void initState() {
    super.initState();
    _ctrl = Get.isRegistered<ReferralController>()
        ? Get.find<ReferralController>()
        : Get.put(ReferralController(), permanent: true);

    final args = Get.arguments;
    if (args is ReferralModel) {
      _editing = args;
      _patientId = args.patientId;
      _nameCtrl.text = args.patientName;
      _ageCtrl.text = args.age;
      _guardianCtrl.text = args.guardianName;
      _villageCtrl.text = args.village;
      _mobileCtrl.text = args.mobile;
      _symptomsCtrl.text = args.symptoms;
      _weightCtrl.text = args.currentWeight;
      _imnciCtrl.text = args.imnci;
      _medsCtrl.text = args.medicinesGiven;
      _referredToCtrl.text = args.referredTo;
      _reason = args.reason;
      _caseType = _normCase(args.caseType);
      _gender = args.gender.isNotEmpty ? args.gender : 'Female';
      _band = args.band.isNotEmpty ? args.band : 'RED';
    } else if (args is Map) {
      _patientId = (args['patientId'] ?? '').toString();
      _nameCtrl.text = (args['patientName'] ?? '').toString();
      _ageCtrl.text = (args['age'] ?? '').toString();
      _guardianCtrl.text = (args['guardianName'] ?? '').toString();
      _villageCtrl.text = (args['village'] ?? '').toString();
      _mobileCtrl.text = (args['mobile'] ?? '').toString();
      _symptomsCtrl.text = (args['symptoms'] ?? '').toString();
      _medsCtrl.text = (args['medicinesGiven'] ?? '').toString();
      _referredToCtrl.text = (args['referredTo'] ?? '').toString();
      _reason = (args['reason'] ?? '').toString();
      final c = (args['caseType'] ?? '').toString();
      if (c.isNotEmpty) _caseType = _normCase(c);
      final g = (args['gender'] ?? '').toString();
      if (g == 'Female' || g == 'Male') _gender = g;
      final b = (args['band'] ?? '').toString();
      if (b == 'RED' || b == 'YELLOW') _band = b;
    }
  }

  // Triage uses lowercase ids; registration uses capitalized. Normalize to the
  // capitalized chip values used here.
  String _normCase(String c) => switch (c.toLowerCase()) {
        'pregnancy' => 'Pregnancy',
        'newborn' => 'Newborn',
        'child' || 'infant' => 'Child',
        _ => 'Other',
      };

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _guardianCtrl.dispose();
    _villageCtrl.dispose();
    _mobileCtrl.dispose();
    _symptomsCtrl.dispose();
    _weightCtrl.dispose();
    _imnciCtrl.dispose();
    _medsCtrl.dispose();
    _referredToCtrl.dispose();
    super.dispose();
  }

  String _caseLabel(String c) => switch (c) {
        'Pregnancy' => 'reff_case_pregnancy'.tr,
        'Newborn' => 'reff_case_newborn'.tr,
        'Child' => 'reff_case_child'.tr,
        _ => 'reff_case_other'.tr,
      };

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final draft = (_editing ?? ReferralModel(id: '', patientName: '')).copyWith(
      patientId: _patientId,
      patientName: _nameCtrl.text.trim(),
      age: _ageCtrl.text.trim(),
      gender: _gender,
      guardianName: _guardianCtrl.text.trim(),
      village: _villageCtrl.text.trim(),
      mobile: _mobileCtrl.text.trim(),
      caseType: _caseType,
      symptoms: _symptomsCtrl.text.trim(),
      currentWeight: _isChild ? _weightCtrl.text.trim() : '',
      imnci: _isChild ? _imnciCtrl.text.trim() : '',
      medicinesGiven: _medsCtrl.text.trim(),
      referredTo: _referredToCtrl.text.trim(),
      reason: _reason,
      band: _band,
    );

    if (_editing != null) {
      await _ctrl.updateReferral(draft);
      if (!mounted) return;
      setState(() => _saving = false);
      Get.back();
      _snack('reff_snack_updated'.tr, AppColors.safeGreen);
      return;
    }

    final result = await _ctrl.addReferral(draft);
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.outcome == ReferralSaveOutcome.needsLogin ||
        ApiService.token == null) {
      return; // 401 hook navigates to login
    }
    Get.back();
    if (result.outcome == ReferralSaveOutcome.synced) {
      _snack('reff_snack_created_synced'.tr, AppColors.safeGreen);
    } else {
      _snack('reff_snack_created_offline'.tr, AppColors.warningYellow);
    }
  }

  void _snack(String msg, Color color) => Get.snackbar(
        'reff_snack_title'.tr, msg,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: color,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        duration: const Duration(seconds: 3),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          child: Column(
            children: [
              AppHeader(title: _editing != null ? 'reff_header_edit'.tr : 'reff_header_new'.tr),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Band selector
                        Text('reff_urgency'.tr, style: AppTextStyles.label),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _bandChip('RED', 'reff_band_red'.tr, AppColors.emergencyRed),
                            const SizedBox(width: 10),
                            _bandChip('YELLOW', 'reff_band_yellow'.tr, AppColors.warningYellow),
                          ],
                        ),
                        const SizedBox(height: 18),
                        AppInput(
                          hint: 'reff_patient_name'.tr,
                          label: 'reff_patient_name'.tr,
                          controller: _nameCtrl,
                          prefixIcon: const Icon(Icons.person_outline_rounded,
                              color: AppColors.primary, size: 20),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'reff_val_name'.tr : null,
                        ),
                        const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: AppInput(
                                hint: 'reff_age'.tr,
                                label: 'reff_age'.tr,
                                controller: _ageCtrl,
                                prefixIcon: const Icon(Icons.cake_outlined,
                                    color: AppColors.primary, size: 20),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('reff_gender'.tr, style: AppTextStyles.label),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String>(
                                    initialValue: _gender,
                                    isExpanded: true,
                                    style: AppTextStyles.body,
                                    decoration: const InputDecoration(),
                                    onChanged: (v) => setState(() => _gender = v!),
                                    items: [
                                      DropdownMenuItem(value: 'Female', child: Text('reff_gender_female'.tr)),
                                      DropdownMenuItem(value: 'Male', child: Text('reff_gender_male'.tr)),
                                      DropdownMenuItem(value: 'Other', child: Text('reff_gender_other'.tr)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        // Case type chips
                        Text('reff_case'.tr, style: AppTextStyles.label),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: ['Pregnancy', 'Newborn', 'Child', 'Other'].map((c) {
                            final sel = c == _caseType;
                            return ChoiceChip(
                              label: Text(_caseLabel(c)),
                              selected: sel,
                              selectedColor: AppColors.primary,
                              labelStyle: AppTextStyles.label.copyWith(
                                color: sel ? AppColors.onPrimary : AppColors.textSecondary,
                              ),
                              onSelected: (_) => setState(() => _caseType = c),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 14),
                        AppInput(
                          hint: 'reff_guardian_hint'.tr,
                          label: 'reff_guardian'.tr,
                          controller: _guardianCtrl,
                        ),
                        const SizedBox(height: 14),
                        AppInput(
                          hint: 'reff_village_hint'.tr,
                          label: 'reff_village'.tr,
                          controller: _villageCtrl,
                          prefixIcon: const Icon(Icons.location_on_outlined,
                              color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(height: 14),
                        AppInput(
                          hint: 'reff_mobile_hint'.tr,
                          label: 'reff_mobile'.tr,
                          controller: _mobileCtrl,
                          keyboardType: TextInputType.phone,
                          maxLength: 10,
                          prefixIcon: const Icon(Icons.phone_outlined,
                              color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(height: 14),
                        AppInput(
                          hint: 'reff_symptoms_hint'.tr,
                          label: 'reff_symptoms'.tr,
                          controller: _symptomsCtrl,
                          maxLines: 3,
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'reff_val_symptoms'.tr : null,
                        ),
                        if (_isChild) ...[
                          const SizedBox(height: 14),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: AppInput(
                                  hint: 'reff_weight_hint'.tr,
                                  label: 'reff_weight'.tr,
                                  controller: _weightCtrl,
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: AppInput(
                                  hint: 'reff_imnci_hint'.tr,
                                  label: 'reff_imnci'.tr,
                                  controller: _imnciCtrl,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 14),
                        AppInput(
                          hint: 'reff_meds_hint'.tr,
                          label: 'reff_meds'.tr,
                          controller: _medsCtrl,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 14),
                        AppInput(
                          hint: 'reff_referred_to_hint'.tr,
                          label: 'reff_referred_to'.tr,
                          controller: _referredToCtrl,
                          prefixIcon: const Icon(Icons.local_hospital_outlined,
                              color: AppColors.primary, size: 20),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'reff_val_referred_to'.tr : null,
                        ),
                        const SizedBox(height: 28),
                        AppButton(
                          label: _editing != null ? 'reff_btn_update'.tr : 'reff_btn_create'.tr,
                          onPressed: _saving ? null : _save,
                          isLoading: _saving,
                          width: double.infinity,
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

  Widget _bandChip(String value, String label, Color color) {
    final sel = _band == value;
    return Expanded(
      child: Material(
        color: sel ? color : AppColors.surface,
        borderRadius: AppRadius.pillR,
        child: InkWell(
          borderRadius: AppRadius.pillR,
          onTap: () => setState(() => _band = value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: sel ? color : AppColors.surface,
              borderRadius: AppRadius.pillR,
              boxShadow: sel ? AppShadows.tinted(color, strength: 2) : AppShadows.low,
            ),
            child: Text(label,
                style: AppTextStyles.label.copyWith(
                  color: sel ? Colors.white : AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                )),
          ),
        ),
      ),
    );
  }
}
