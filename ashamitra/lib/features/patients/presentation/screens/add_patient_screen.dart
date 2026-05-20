import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../shared/widgets/app_input.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../core/utils/validators.dart';
import '../../controller/patient_controller.dart';

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
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _villageCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ctrl = Get.isRegistered<PatientController>()
        ? Get.find<PatientController>()
        : Get.put(PatientController(), permanent: true);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _villageCtrl.dispose();
    _mobileCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    _ctrl.addPatient(
      name: _nameCtrl.text.trim(),
      type: _caseType,
      village: _villageCtrl.text.trim().isEmpty ? 'Unknown' : _villageCtrl.text.trim(),
      mobile: _mobileCtrl.text.trim(),
    );
    Get.back();
    Get.snackbar(
      'Patient Added',
      '${_nameCtrl.text.trim()} has been added successfully.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.safeGreen,
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 2),
    );
  }

  void _saveAndCheckup() {
    if (!_formKey.currentState!.validate()) return;
    _ctrl.addPatient(
      name: _nameCtrl.text.trim(),
      type: _caseType,
      village: _villageCtrl.text.trim().isEmpty ? 'Unknown' : _villageCtrl.text.trim(),
      mobile: _mobileCtrl.text.trim(),
    );
    Get.toNamed(AppRoutes.selectCase);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Get.back(),
                      child: Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)]),
                        child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Add Patient',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.onBackground)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        AppInput(
                          hint: 'Full name',
                          label: 'Patient Name',
                          controller: _nameCtrl,
                          prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.primary, size: 20),
                          validator: (v) => v == null || v.isEmpty ? 'Name is required' : null,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: AppInput(
                                hint: 'Age',
                                label: 'Age',
                                controller: _ageCtrl,
                                keyboardType: TextInputType.number,
                                prefixIcon: const Icon(Icons.cake_outlined, color: AppColors.primary, size: 20),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Gender',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String>(
                                    value: _gender,
                                    onChanged: (v) => setState(() => _gender = v!),
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: Colors.white.withOpacity(0.9),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE0E7FF))),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE0E7FF))),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                    ),
                                    items: ['Female', 'Male', 'Other']
                                        .map((g) => DropdownMenuItem(value: g, child: Text(g, style: const TextStyle(fontSize: 14))))
                                        .toList(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        AppInput(
                          hint: 'Village / Area name',
                          label: 'Village',
                          controller: _villageCtrl,
                          prefixIcon: const Icon(Icons.location_on_outlined, color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(height: 16),
                        AppInput(
                          hint: '10-digit mobile number',
                          label: 'Mobile Number',
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
                            const Text('Case Type',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              children: ['Pregnancy', 'Newborn', 'Child', 'Other'].map((c) {
                                final sel = c == _caseType;
                                return GestureDetector(
                                  onTap: () => setState(() => _caseType = c),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: sel ? AppColors.primary : Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: sel ? AppColors.primary : const Color(0xFFE0E7FF)),
                                      boxShadow: [if (sel) BoxShadow(color: AppColors.primary.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 2))],
                                    ),
                                    child: Text(c,
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: sel ? Colors.white : AppColors.textSecondary)),
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
                              label: 'Save Patient',
                              onPressed: _save,
                              outlined: true,
                              width: double.infinity,
                            ),
                            const SizedBox(height: 10),
                            AppButton(
                              label: 'Save & Start Checkup',
                              onPressed: _saveAndCheckup,
                              icon: Icons.mic_rounded,
                              width: double.infinity,
                            ),
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
