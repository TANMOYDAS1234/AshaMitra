import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'routes.dart';
import 'app_binding.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_radius.dart';
import '../core/services/language_controller.dart';
import '../features/auth/controller/auth_controller.dart';
import '../localization/app_translations.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      _maybeReplaySplash();
    }
  }

  /// Reopening the app while logged out should feel like a fresh launch — but a
  /// warm resume skips the initial (splash) route. So when the worker returns to
  /// the app after being away, and they're sitting logged-out on login/language,
  /// replay the splash. Guarded so it never interrupts an OTP entry, an active
  /// session, or a quick app-switch.
  void _maybeReplaySplash() {
    final paused = _pausedAt;
    _pausedAt = null;
    if (paused == null) return;
    if (DateTime.now().difference(paused) < const Duration(seconds: 12)) return;
    if (!Get.isRegistered<AuthController>()) return;
    if (Get.find<AuthController>().user.value != null) return; // logged in
    final route = Get.currentRoute;
    if (route == AppRoutes.login || route == AppRoutes.language) {
      Get.offAllNamed(AppRoutes.splash);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Global status-bar styling: dark icons on the app's light background.
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.surface,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));

    final lang = Get.find<LanguageController>();
    return GetMaterialApp(
      title: 'ASHA Mitra',
      debugShowCheckedModeBanner: false,
      translations: AppTranslations(),
      locale: LanguageController.locales[lang.selectedIndex.value],
      // Bengali is the primary language + the fallback: any key missing a
      // Hindi/English translation shows Bengali rather than going blank or
      // English. Keeps the worker experience safe while hi/en fill in.
      fallbackLocale: const Locale('bn', 'BD'),
      theme: _buildTheme(),
      initialBinding: AppBinding(),
      initialRoute: AppRoutes.splash,
      getPages: AppRoutes.pages,
    );
  }

  ThemeData _buildTheme() {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.purple,
        surface: AppColors.surface,
        error: AppColors.emergencyRed,
      ),
      scaffoldBackgroundColor: AppColors.background,
      useMaterial3: true,
      textTheme: AppTextStyles.textTheme,
      primaryTextTheme: AppTextStyles.textTheme,
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTextStyles.h2,
        iconTheme: const IconThemeData(color: AppColors.onBackground),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: AppTextStyles.body.copyWith(color: AppColors.textLight),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: AppRadius.mdR,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdR,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdR,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdR),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: AppTextStyles.labelLg,
          minimumSize: const Size(0, 48),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: AppTextStyles.labelLg,
          minimumSize: const Size(48, 48),
        ),
      ),
      splashFactory: InkRipple.splashFactory,
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdR),
        contentTextStyle: AppTextStyles.body.copyWith(color: AppColors.onPrimary),
      ),
    );
  }
}
