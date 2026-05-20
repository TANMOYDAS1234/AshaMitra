import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../admin/controller/admin_controller.dart';

class AdminAddAshaScreen extends StatefulWidget {
  const AdminAddAshaScreen({super.key});

  @override
  State<AdminAddAshaScreen> createState() => _AdminAddAshaScreenState();
}

class _AdminAddAshaScreenState extends State<AdminAddAshaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _name = TextEditingController();
  final _block = TextEditingController();
  final _district = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _phone.dispose();
    _name.dispose();
    _block.dispose();
    _district.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _saving = true);
    final ctrl = Get.find<AdminController>();
    
    final ok = await ctrl.addAshaWorker(
      phone: _phone.text.trim(),
      name: _name.text.trim(),
      block: _block.text.trim(),
      district: _district.text.trim(),
    );
    
    setState(() => _saving = false);
    
    if (ok) {
      Get.back();
      Get.snackbar(
        'admin_success'.tr,
        'admin_add_success'.tr,
        backgroundColor: AppColors.safeGreen,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
      );
    } else {
      Get.snackbar(
        'admin_add_error'.tr,
        ctrl.errorMsg.value,
        backgroundColor: AppColors.emergencyRed,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        icon: const Icon(Icons.error_outline_rounded, color: Colors.white),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          child: Column(
            children: [
              // ── Header Section ───────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: Get.back,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.all(12),
                        elevation: 2,
                        shadowColor: Colors.black.withValues(alpha: 0.1),
                      ),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 16,
                        color: AppColors.onBackground,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'admin_add_asha'.tr,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: AppColors.onBackground,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Form Area ────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Container Card grouping form elements elegantly
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              _field(
                                ctrl: _name,
                                label: 'admin_full_name'.tr,
                                icon: Icons.person_outline_rounded,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'admin_name_required'.tr;
                                  return null;
                                },
                              ),
                              const SizedBox(height: 18),
                              _field(
                                ctrl: _phone,
                                label: 'admin_phone'.tr,
                                icon: Icons.phone_android_rounded,
                                keyboardType: TextInputType.phone,
                                validator: (v) {
                                  if (v == null || v.trim().length < 10) return 'admin_phone_required'.tr;
                                  return null;
                                },
                              ),
                              const SizedBox(height: 18),
                              _field(ctrl: _block, label: 'admin_block'.tr, icon: Icons.location_on_outlined),
                              const SizedBox(height: 18),
                              _field(ctrl: _district, label: 'admin_district'.tr, icon: Icons.map_outlined),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // ── Submit Button ──────────────────────────────────
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _saving ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
                              elevation: 0,
                              shadowColor: AppColors.primary.withValues(alpha: 0.3),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _saving
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Text(
                                    'admin_save'.tr,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                          ),
                        ),
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

  // ── Modularized Form Field Method ─────────────────────────────────
  Widget _field({
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: AppColors.onBackground,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
        floatingLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
        prefixIcon: Icon(
          icon, 
          color: AppColors.primary.withValues(alpha: 0.8), 
          size: 22,
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC), // Ultra-light grey for form depth
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.emergencyRed, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.emergencyRed, width: 1.8),
        ),
        errorStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.emergencyRed,
        ),
      ),
    );
  }
}