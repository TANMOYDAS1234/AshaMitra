import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_input.dart';

class AuthForm extends StatelessWidget {
  final void Function(String phone) onSubmit;
  final RxBool isLoading;
  final RxString? errorMsg;

  const AuthForm({super.key, required this.onSubmit, required this.isLoading, this.errorMsg});

  static const _cases = [
    (icon: Icons.pregnant_woman_rounded,  labelKey: 'auth_case_pregnant',  color: AppColors.primary),
    (icon: Icons.health_and_safety_rounded, labelKey: 'auth_case_postnatal', color: AppColors.purple),
    (icon: Icons.child_care_rounded,      labelKey: 'auth_case_newborn',   color: Color(0xFF0891B2)),
    (icon: Icons.baby_changing_station_rounded, labelKey: 'auth_case_infant', color: AppColors.safeGreen),
    (icon: Icons.child_friendly_rounded,  labelKey: 'auth_case_child',     color: Color(0xFFF59E0B)),
    (icon: Icons.vaccines_rounded,        labelKey: 'auth_case_vaccine',   color: Color(0xFF8B5CF6)),
    (icon: Icons.emergency_rounded,       labelKey: 'auth_case_emergency', color: AppColors.emergencyRed),
  ];

  @override
  Widget build(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final phoneCtrl = TextEditingController();

    return Container(
      decoration: const BoxDecoration(gradient: AppGradients.background),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 52),

              // ── Logo ─────────────────────────────────────────
              Container(
                width: 74, height: 74,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.purple],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 20, offset: const Offset(0, 6)),
                  ],
                ),
                child: const Icon(Icons.health_and_safety_rounded,
                    color: Colors.white, size: 38),
              ),
              const SizedBox(height: 20),
              const Text('ASHA Mitra',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold,
                      color: AppColors.onBackground)),
              const SizedBox(height: 6),
              Text('auth_login_subtitle'.tr,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),

              const SizedBox(height: 24),

              // ── 7 case chips ─────────────────────────────────
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _cases.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final c = _cases[i];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: c.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: c.color.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(c.icon, size: 14, color: c.color),
                          const SizedBox(width: 5),
                          Text(c.labelKey.tr,
                              style: TextStyle(fontSize: 11,
                                  fontWeight: FontWeight.w600, color: c.color)),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 32),

              // ── Login form ───────────────────────────────────
              GlassCard(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: formKey,
                  child: Column(
                    children: [
                      AppInput(
                        hint: 'auth_phone_hint'.tr,
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        label: 'auth_phone_label'.tr,
                        prefixIcon: const Icon(Icons.phone_rounded,
                            color: AppColors.primary, size: 20),
                        validator: Validators.phone,
                      ),
                      const SizedBox(height: 24),
                      Obx(() {
                        final err = errorMsg?.value ?? '';
                        return Column(
                          children: [
                            if (err.isNotEmpty)
                              Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFEDED),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFFFCDD2)),
                                ),
                                child: Text(err,
                                    style: const TextStyle(color: Color(0xFFB71C1C), fontSize: 13)),
                              ),
                            AppButton(
                              label: 'auth_send_otp'.tr,
                              onPressed: () {
                                if (formKey.currentState!.validate()) {
                                  onSubmit(phoneCtrl.text);
                                }
                              },
                              isLoading: isLoading.value,
                              icon: Icons.send_rounded,
                              width: double.infinity,
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
              Text(
                'auth_privacy_note'.tr,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
