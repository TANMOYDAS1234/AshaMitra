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
              const SizedBox(height: 24),

              // ── Hero photo ───────────────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/images/hero_asha.png',
                  height: 196,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 20),
              const Text('ASHA Mitra',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold,
                      color: AppColors.onBackground)),
              const SizedBox(height: 6),
              Text('auth_login_subtitle'.tr,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),

              const SizedBox(height: 28),

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
