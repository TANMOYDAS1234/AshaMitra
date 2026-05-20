import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'routes.dart';
import 'app_binding.dart';
import '../core/theme/app_colors.dart';
import '../core/services/language_controller.dart';
import '../localization/app_translations.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    // Use the already-saved locale — LanguageController is registered in main()
    final lang = Get.find<LanguageController>();
    return GetMaterialApp(
      title: 'ASHA Mitra',
      debugShowCheckedModeBanner: false,
      translations: AppTranslations(),
      locale: LanguageController.locales[lang.selectedIndex.value],
      fallbackLocale: const Locale('en', 'US'),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.purple,
          surface: AppColors.surface,
        ),
        scaffoldBackgroundColor: AppColors.background,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: AppColors.onBackground,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          iconTheme: IconThemeData(color: AppColors.onBackground),
        ),
      ),
      initialBinding: AppBinding(),
      initialRoute: AppRoutes.splash,
      getPages: AppRoutes.pages,
    );
  }
}
