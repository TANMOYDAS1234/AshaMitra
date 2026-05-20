import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../app/routes.dart';
import '../../../../core/services/language_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../shared/widgets/app_button.dart';

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  static const _languages = [
    ('বাংলা', 'Bengali'),
    ('हिन्दी', 'Hindi'),
    ('English', 'English'),
  ];

  static const _langColors = [
    Color(0xFF4F46E5), // indigo — Bengali
    Color(0xFFE85D04), // saffron — Hindi
    Color(0xFF0891B2), // teal — English
  ];

  static const _langAbbr = ['বা', 'हि', 'En'];

  @override
  Widget build(BuildContext context) {
    final lang = Get.find<LanguageController>();
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 60),
                Text(
                  'select_language_subtitle'.tr,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Text(
                  'select_language'.tr,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onBackground,
                  ),
                ),
                const SizedBox(height: 40),
                Obx(() => Column(
                      children: List.generate(_languages.length, (i) {
                        final (name, subName) = _languages[i];
                        final isSelected = i == lang.selectedIndex.value;
                        final accent = _langColors[i];
                        final abbr = _langAbbr[i];
                        return GestureDetector(
                          onTap: () => lang.setLanguage(i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                            decoration: BoxDecoration(
                              color: isSelected ? accent : Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isSelected ? accent : const Color(0xFFE0E7FF),
                                width: isSelected ? 2 : 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isSelected
                                      ? accent.withOpacity(0.28)
                                      : Colors.black.withOpacity(0.04),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white.withOpacity(0.2)
                                        : accent.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Center(
                                    child: Text(
                                      abbr,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected ? Colors.white : accent,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected ? Colors.white : AppColors.onBackground,
                                      ),
                                    ),
                                    Text(
                                      subName,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isSelected
                                            ? Colors.white.withOpacity(0.75)
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                if (isSelected)
                                  const Icon(Icons.check_circle_rounded,
                                      color: Colors.white, size: 24),
                              ],
                            ),
                          ),
                        );
                      }),
                    )),
                const Spacer(),
                AppButton(
                  label: 'continue'.tr,
                  onPressed: () => Get.offNamed(AppRoutes.welcome),
                  icon: Icons.arrow_forward_rounded,
                  width: double.infinity,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
