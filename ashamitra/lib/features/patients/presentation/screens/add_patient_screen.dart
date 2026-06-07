import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/permissions.dart';
import '../../../../shared/components/app_header.dart';
import '../../../../shared/widgets/app_input.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../core/utils/validators.dart';
import '../../controller/patient_controller.dart';
import '../../data/models/patient_model.dart';

class AddPatientScreen extends StatefulWidget {
  const AddPatientScreen({super.key});

  @override
  State<AddPatientScreen> createState() => _AddPatientScreenState();
}

class _AddPatientScreenState extends State<AddPatientScreen> {
  late final PatientController _ctrl;
  final _formKey = GlobalKey<FormState>();
  String _caseType = 'Pregnancy';
  String _gender = 'Female';
  // Age unit: 'days' | 'months' | 'years'. Drives how the engine reads age
  // (newborn 0–28 d vs child 2 mo–5 y vs mother's age in years). Defaults
  // smartly from the case type so a newborn's "6" is never read as 6 years.
  String _ageUnit = 'years';
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _villageCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();

  // ── Speak-to-fill (voice dictation for free-text fields) ────────────────
  // Many ASHA workers type slowly; letting them speak the name/village in
  // Bengali fills the field in Bengali script via on-device STT. Lazily
  // initialised on first mic tap so we never prompt for the mic on open.
  final _stt = SpeechToText();
  bool _sttReady = false;
  String? _dictating; // 'name' | 'village' | null — which field is active

  /// If non-null, this screen is in EDIT mode for an existing patient.
  /// Pre-fills the form fields and the Save button calls updatePatient
  /// instead of addPatient. Triage-derived fields (outcome, reason,
  /// nextStep, qaHistory, risk, lastVisit) are preserved unchanged.
  PatientModel? _editing;

  @override
  void initState() {
    super.initState();
    _ctrl = Get.isRegistered<PatientController>()
        ? Get.find<PatientController>()
        : Get.put(PatientController(), permanent: true);

    // Edit-mode detection: pass the existing PatientModel as Get.arguments.
    final args = Get.arguments;
    if (args is PatientModel) {
      _editing = args;
      _nameCtrl.text    = args.name;
      _ageCtrl.text     = args.age;
      _villageCtrl.text = args.village == 'Unknown' || args.village == '—' ? '' : args.village;
      _mobileCtrl.text  = args.mobile;
      _caseType = args.type;
      _gender   = args.gender.isNotEmpty ? args.gender : 'Female';
      _ageUnit  = args.ageUnit.isNotEmpty ? args.ageUnit : _defaultAgeUnit(args.type);
    } else if (args is Map<String, dynamic>) {
      // 1b fix: when the worker reaches Add Patient from a case tile on the
      // dashboard, the case ID is passed in as 'caseType'. Pre-select that
      // chip so they don't have to manually pick the case again — they
      // already told us which case they're filing a patient for.
      final preselected = args['caseType']?.toString();
      if (preselected != null && preselected.isNotEmpty &&
          ['Pregnancy', 'Newborn', 'Child', 'Other'].contains(preselected)) {
        _caseType = preselected;
      }
      // Assistant pre-fill: name spoken via an "add <name>" voice command.
      final prefName = args['name']?.toString();
      if (prefName != null && prefName.trim().isNotEmpty) {
        _nameCtrl.text = prefName.trim();
      }
      _ageUnit = _defaultAgeUnit(_caseType);
    } else {
      _ageUnit = _defaultAgeUnit(_caseType);
    }
  }

  @override
  void dispose() {
    try { _stt.stop(); } catch (_) {}
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _villageCtrl.dispose();
    _mobileCtrl.dispose();
    super.dispose();
  }

  bool get _isEditing => _editing != null;

  // Smart default age unit per case: newborn → days, child → months,
  // pregnancy/other → years (the mother's / person's age).
  static String _defaultAgeUnit(String caseType) => switch (caseType) {
        'Newborn' => 'days',
        'Child'   => 'months',
        _         => 'years',
      };

  String _ageUnitLabel(String u) => switch (u) {
        'days'   => 'age_unit_days'.tr,
        'months' => 'age_unit_months'.tr,
        _        => 'age_unit_years'.tr,
      };

  void _showSnack(String title, String body, Color color) {
    Get.snackbar(
      title, body,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: color,
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 2),
    );
  }

  // ── Speak-to-fill ───────────────────────────────────────────────────────
  Future<void> _initStt() async {
    final ok = await AppPermissions.requestMicrophone();
    if (!ok) {
      if (mounted) setState(() => _sttReady = false);
      return;
    }
    _sttReady = await _stt.initialize(
      onError: (_) {
        if (mounted) setState(() => _dictating = null);
      },
      onStatus: (s) {
        if ((s == SpeechToText.doneStatus ||
                s == SpeechToText.notListeningStatus) &&
            mounted) {
          setState(() => _dictating = null);
        }
      },
    );
    if (mounted) setState(() {});
  }

  /// Toggle dictation for [field], writing the recognised Bengali text into
  /// [ctrl]. Tapping the same field's mic again stops it.
  Future<void> _dictate(String field, TextEditingController ctrl) async {
    if (_dictating == field) {
      try { await _stt.stop(); } catch (_) {}
      if (mounted) setState(() => _dictating = null);
      return;
    }
    if (!_sttReady) {
      await _initStt();
      if (!_sttReady) {
        _showSnack('app_name'.tr, 'mic_permission_denied'.tr,
            AppColors.warningYellow);
        return;
      }
    }
    try { await _stt.stop(); } catch (_) {}
    if (mounted) setState(() => _dictating = field);
    await _stt.listen(
      listenOptions: SpeechListenOptions(
        localeId: 'bn_IN',
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: true,
      ),
      onResult: (r) {
        if (!mounted) return;
        ctrl.text = r.recognizedWords;
        ctrl.selection =
            TextSelection.collapsed(offset: ctrl.text.length);
        if (r.finalResult && mounted) setState(() => _dictating = null);
      },
    );
  }

  Widget _micSuffix(String field, TextEditingController ctrl) {
    final active = _dictating == field;
    return IconButton(
      tooltip: 'speak'.tr,
      icon: Icon(
        active ? Icons.mic_rounded : Icons.mic_none_rounded,
        color: active ? AppColors.emergencyRed : AppColors.primary,
        size: 20,
      ),
      onPressed: () => _dictate(field, ctrl),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isEditing) {
      final updated = _editing!.copyWith(
        name:    _nameCtrl.text.trim(),
        type:    _caseType,
        village: _villageCtrl.text.trim().isEmpty ? 'Unknown' : _villageCtrl.text.trim(),
        mobile:  _mobileCtrl.text.trim(),
        age:     _ageCtrl.text.trim(),
        ageUnit: _ageUnit,
        gender:  _gender,
      );
      final result = await _ctrl.updatePatient(updated);
      if (!mounted) return;
      if (result == 'duplicate') {
        _showSnack('cannot_save'.tr, 'duplicate_patient_msg'.tr, AppColors.warningYellow);
        return;
      }
      Get.back();
      _showSnack('patient_updated'.tr,
          'patient_updated_msg'.trParams({'name': updated.name}), AppColors.safeGreen);
      return;
    }

    // ADD mode
    _ctrl.addPatient(
      name: _nameCtrl.text.trim(),
      type: _caseType,
      village: _villageCtrl.text.trim().isEmpty ? 'Unknown' : _villageCtrl.text.trim(),
      mobile: _mobileCtrl.text.trim(),
      age: _ageCtrl.text.trim(),
      ageUnit: _ageUnit,
      gender: _gender,
    );
    Get.back();
    _showSnack('patient_added'.tr,
        'patient_added_msg'.trParams({'name': _nameCtrl.text.trim()}), AppColors.safeGreen);
  }

  void _saveAndCheckup() {
    if (!_formKey.currentState!.validate()) return;
    final patient = _ctrl.addPatient(
      name: _nameCtrl.text.trim(),
      type: _caseType,
      village: _villageCtrl.text.trim().isEmpty ? 'Unknown' : _villageCtrl.text.trim(),
      mobile: _mobileCtrl.text.trim(),
      age: _ageCtrl.text.trim(),
      ageUnit: _ageUnit,
      gender: _gender,
    );
    // The worker already chose the case type on this form, so jump straight
    // into that module's triage — carrying the patient so triage uses their
    // age/history (adaptive band) and can answer name/age questions. 'Other'
    // is ambiguous, so fall back to the case picker.
    final caseId = _caseIdForType(_caseType);
    if (caseId == null) {
      Get.toNamed(AppRoutes.selectCase, arguments: {
        'patientId': patient.id,
        'patientName': patient.name,
      });
    } else {
      Get.toNamed(AppRoutes.voiceTriage, arguments: {
        'caseId': caseId,
        'caseTitle': _caseTitleForId(caseId),
        'patientId': patient.id,
        'patientName': patient.name,
      });
    }
  }

  // Registration case-type chip → triage case id. null for 'Other' (ambiguous)
  // so the worker picks the case manually.
  static String? _caseIdForType(String caseType) => switch (caseType) {
        'Pregnancy' => 'pregnancy',
        'Newborn' => 'newborn',
        'Child' => 'child',
        _ => null,
      };

  static String _caseTitleForId(String caseId) => switch (caseId) {
        'pregnancy' => '🤰 গর্ভবতী মায়ের চেকআপ',
        'newborn' => '👶 নবজাতক চেকআপ (০-২৮ দিন)',
        'child' => '🧒 শিশু স্বাস্থ্য যাচাই (১-৫ বছর)',
        _ => 'স্বাস্থ্য যাচাই',
      };

  // Localized display labels for the English-valued gender / case options.
  // The stored value stays English (the patient model + reports rely on it);
  // only what the worker reads is translated.
  String _genderLabel(String g) => switch (g) {
        'Female' => 'gender_female'.tr,
        'Male' => 'gender_male'.tr,
        _ => 'gender_other'.tr,
      };
  String _caseLabel(String c) => switch (c) {
        'Pregnancy' => 'case_pregnancy'.tr,
        'Newborn' => 'case_newborn'.tr,
        'Child' => 'case_child'.tr,
        _ => 'case_other'.tr,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          child: Column(
            children: [
              AppHeader(title: (_isEditing ? 'edit_patient' : 'add_patient').tr),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        AppInput(
                          hint: 'full_name'.tr,
                          label: 'patient_name'.tr,
                          controller: _nameCtrl,
                          prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.primary, size: 20),
                          suffixIcon: _micSuffix('name', _nameCtrl),
                          validator: (v) => v == null || v.trim().isEmpty ? 'name_required'.tr : null,
                        ),
                        const SizedBox(height: 16),
                        // ── Age + unit ──────────────────────────────────────
                        Text('age'.tr, style: AppTextStyles.label),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: AppInput(
                                hint: 'age'.tr,
                                controller: _ageCtrl,
                                keyboardType: TextInputType.number,
                                prefixIcon: const Icon(Icons.cake_outlined, color: AppColors.primary, size: 20),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 5,
                              // ValueKey(_ageUnit) forces the field to rebuild when
                              // the case chip changes the unit programmatically —
                              // otherwise `initialValue` is init-only and the shown
                              // unit wouldn't follow the case type.
                              child: DropdownButtonFormField<String>(
                                key: ValueKey('ageUnit_$_ageUnit'),
                                initialValue: _ageUnit,
                                isExpanded: true,
                                onChanged: (v) => setState(() => _ageUnit = v ?? _ageUnit),
                                style: AppTextStyles.body,
                                decoration: const InputDecoration(),
                                items: ['days', 'months', 'years']
                                    .map((u) => DropdownMenuItem(value: u, child: Text(_ageUnitLabel(u))))
                                    .toList(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // ── Gender ──────────────────────────────────────────
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('gender'.tr, style: AppTextStyles.label),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: _gender,
                              isExpanded: true,
                              onChanged: (v) => setState(() => _gender = v!),
                              style: AppTextStyles.body,
                              decoration: const InputDecoration(),
                              // Value stays English (stored in the model);
                              // only the shown label is localized.
                              items: ['Female', 'Male', 'Other']
                                  .map((g) => DropdownMenuItem(value: g, child: Text(_genderLabel(g))))
                                  .toList(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        AppInput(
                          hint: 'village_hint'.tr,
                          label: 'village'.tr,
                          controller: _villageCtrl,
                          prefixIcon: const Icon(Icons.location_on_outlined, color: AppColors.primary, size: 20),
                          suffixIcon: _micSuffix('village', _villageCtrl),
                        ),
                        const SizedBox(height: 16),
                        AppInput(
                          hint: 'mobile_hint'.tr,
                          label: 'mobile_number'.tr,
                          controller: _mobileCtrl,
                          keyboardType: TextInputType.phone,
                          maxLength: 10,
                          prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.primary, size: 20),
                          validator: Validators.phone,
                        ),
                        const SizedBox(height: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('case_type'.tr, style: AppTextStyles.label),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              children: ['Pregnancy', 'Newborn', 'Child', 'Other'].map((c) {
                                final sel = c == _caseType;
                                return Material(
                                  color: sel ? AppColors.primary : AppColors.surface,
                                  borderRadius: AppRadius.pillR,
                                  child: InkWell(
                                    onTap: () => setState(() {
                                      _caseType = c;
                                      // Age unit follows the case type dynamically:
                                      // newborn→days, child→months, pregnancy/other→
                                      // years. Worker can still override the dropdown.
                                      _ageUnit = _defaultAgeUnit(c);
                                    }),
                                    borderRadius: AppRadius.pillR,
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 180),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                                      decoration: BoxDecoration(
                                        color: sel ? AppColors.primary : AppColors.surface,
                                        borderRadius: AppRadius.pillR,
                                        boxShadow: sel
                                            ? AppShadows.tinted(AppColors.primary, strength: 2)
                                            : AppShadows.low,
                                      ),
                                      child: Text(
                                        _caseLabel(c),
                                        style: AppTextStyles.label.copyWith(
                                          color: sel ? AppColors.onPrimary : AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        Column(
                          children: [
                            AppButton(
                              label: (_isEditing ? 'save_changes' : 'save_patient').tr,
                              onPressed: _save,
                              outlined: !_isEditing, // edit mode: primary; add mode: secondary (paired with checkup)
                              width: double.infinity,
                            ),
                            // "Save & Start Checkup" only makes sense for new patients —
                            // editing doesn't need a follow-up checkup step.
                            if (!_isEditing) ...[
                              const SizedBox(height: 10),
                              AppButton(
                                label: 'save_and_start_checkup'.tr,
                                onPressed: _saveAndCheckup,
                                icon: Icons.mic_rounded,
                                width: double.infinity,
                              ),
                            ],
                          ],
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
}
