import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../features/onboarding/presentation/screens/splash_screen.dart';
import '../features/onboarding/presentation/screens/welcome_screen.dart';
import '../features/onboarding/presentation/screens/language_screen.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/otp_screen.dart';
import '../features/home/presentation/screens/home_screen.dart';
import '../features/triage/presentation/screens/select_case_screen.dart';
import '../features/triage/presentation/screens/case_confirm_screen.dart';
import '../features/triage/presentation/screens/voice_triage_screen.dart';
import '../features/triage/presentation/screens/dynamic_triage_screen.dart';
import '../features/triage/presentation/screens/triage_result_screen.dart';
import '../features/patients/presentation/screens/patient_list_screen.dart';
import '../features/patients/presentation/screens/add_patient_screen.dart';
import '../features/patients/presentation/screens/patient_profile_screen.dart';
import '../features/registers/presentation/screens/registers_screen.dart';
import '../features/referrals/presentation/screens/referral_list_screen.dart';
import '../features/referrals/presentation/screens/referral_form_screen.dart';
import '../features/vital_events/presentation/screens/vital_event_screen.dart';
import '../features/ncd_cbac/presentation/screens/ncd_cbac_screen.dart';
import '../features/tb_cases/presentation/screens/tb_case_screen.dart';
import '../features/medicine_stock/presentation/screens/medicine_stock_screen.dart';
import '../features/emergency/presentation/screens/emergency_screen.dart';
import '../features/emergency/presentation/screens/nearby_facilities_screen.dart';
import '../features/reports/presentation/screens/checkup_log_screen.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../features/admin/presentation/screens/admin_shell.dart';
import '../features/admin/presentation/screens/admin_asha_list_screen.dart';
import '../features/admin/presentation/screens/admin_add_asha_screen.dart';
import '../features/admin/presentation/screens/admin_reports_screen.dart';
import '../features/admin/presentation/screens/admin_profile_screen.dart';
import '../features/assistant/presentation/screens/assistant_screen.dart';
import '../features/schedule/presentation/screens/due_list_screen.dart';
import '../features/schedule/presentation/screens/visit_screen.dart';
import '../features/development/presentation/screens/development_screen.dart';

/// Route-typed transition vocabulary.
///
/// - `fadeIn`         (180ms) — peer-level swaps (bottom-nav siblings)
/// - `rightToLeftWithFade` (260ms) — forward step in a guided flow
/// - `downToUp`       (320ms) — modal/emergency sheets (gravity feel)
/// - `zoom`           (280ms) — entering the voice/triage flow (mic-centric)
/// - `fade`           (240ms) — splash → next (calm reveal)
class AppRoutes {
  static const splash          = '/';
  static const welcome         = '/welcome';
  static const language        = '/language';
  static const login           = '/login';
  static const otp             = '/otp';
  static const home            = '/home';
  static const selectCase      = '/triage/select';
  static const caseConfirm     = '/triage/confirm';
  static const voiceTriage     = '/triage/voice';
  static const dynamicTriage   = '/triage/dynamic';
  static const triageResult    = '/triage/result';
  static const patientList     = '/patients';
  static const addPatient      = '/patients/add';
  static const patientProfile  = '/patients/profile';
  static const emergency       = '/emergency';
  static const nearestFacilities = '/nearest-facilities';
  static const reports         = '/reports';
  static const profile         = '/profile';
  static const assistant       = '/assistant';
  static const dueList         = '/schedule/due';
  static const visit           = '/schedule/visit';
  static const registers       = '/registers';
  static const referralList    = '/referrals';
  static const referralForm    = '/referrals/form';
  static const vitalEvents     = '/vital-events';
  static const ncdCbac         = '/ncd-cbac';
  static const tbCases         = '/tb-cases';
  static const medicineStock   = '/medicine-stock';
  static const development      = '/development';
  // Admin
  static const adminDashboard  = '/admin';
  static const adminAshaList   = '/admin/asha';
  static const adminAddAsha    = '/admin/asha/add';
  static const adminReports    = '/admin/reports';
  static const adminProfile    = '/admin/profile';

  // ── Duration tokens for transitions ────────────────────────────────────
  static const _fast   = Duration(milliseconds: 180);
  static const _medium = Duration(milliseconds: 260);
  static const _calm   = Duration(milliseconds: 320);

  static final pages = [
    // Splash — calm reveal
    GetPage(
      name: splash,
      page: () => const SplashScreen(),
      transition: Transition.fade,
      transitionDuration: Duration(milliseconds: 240),
      curve: Curves.easeOut,
    ),

    // Onboarding flow — forward step
    GetPage(
      name: language,
      page: () => const LanguageScreen(),
      transition: Transition.rightToLeftWithFade,
      transitionDuration: _medium,
      curve: Curves.easeOutCubic,
    ),
    GetPage(
      name: welcome,
      page: () => const WelcomeScreen(),
      transition: Transition.rightToLeftWithFade,
      transitionDuration: _medium,
      curve: Curves.easeOutCubic,
    ),
    GetPage(
      name: login,
      page: () => const LoginScreen(),
      transition: Transition.rightToLeftWithFade,
      transitionDuration: _medium,
      curve: Curves.easeOutCubic,
    ),
    GetPage(
      name: otp,
      page: () => const OtpScreen(),
      transition: Transition.rightToLeftWithFade,
      transitionDuration: _medium,
      curve: Curves.easeOutCubic,
    ),

    // Bottom-nav peers — instant fade (these swap via offAllNamed)
    GetPage(
      name: home,
      page: () => const HomeScreen(),
      transition: Transition.fadeIn,
      transitionDuration: _fast,
    ),
    GetPage(
      name: patientList,
      page: () => const PatientListScreen(),
      transition: Transition.fadeIn,
      transitionDuration: _fast,
    ),
    GetPage(
      name: reports,
      page: () => const CheckupLogScreen(),
      transition: Transition.fadeIn,
      transitionDuration: _fast,
    ),
    GetPage(
      name: profile,
      page: () => const ProfileScreen(),
      transition: Transition.fadeIn,
      transitionDuration: _fast,
    ),

    // AI Assistant — Gemini-Live-style voice-first chat. zoom transition
    // reinforces "you are entering a conversation".
    GetPage(
      name: assistant,
      page: () => const AssistantScreen(),
      transition: Transition.zoom,
      transitionDuration: Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    ),

    // Due / overdue reminder shortlist — forward step
    GetPage(
      name: dueList,
      page: () => const DueListScreen(),
      transition: Transition.rightToLeftWithFade,
      transitionDuration: _medium,
      curve: Curves.easeOutCubic,
    ),
    GetPage(
      name: visit,
      page: () => const VisitScreen(),
      transition: Transition.rightToLeftWithFade,
      transitionDuration: _medium,
      curve: Curves.easeOutCubic,
    ),
    GetPage(
      name: registers,
      page: () => const RegistersScreen(),
      transition: Transition.rightToLeftWithFade,
      transitionDuration: _medium,
      curve: Curves.easeOutCubic,
    ),
    GetPage(
      name: development,
      page: () => const DevelopmentScreen(),
      transition: Transition.rightToLeftWithFade,
      transitionDuration: _medium,
      curve: Curves.easeOutCubic,
    ),
    GetPage(
      name: referralList,
      page: () => const ReferralListScreen(),
      transition: Transition.rightToLeftWithFade,
      transitionDuration: _medium,
      curve: Curves.easeOutCubic,
    ),
    GetPage(
      name: referralForm,
      page: () => const ReferralFormScreen(),
      transition: Transition.rightToLeftWithFade,
      transitionDuration: _medium,
      curve: Curves.easeOutCubic,
    ),
    GetPage(
      name: vitalEvents,
      page: () => const VitalEventListScreen(),
      transition: Transition.rightToLeftWithFade,
      transitionDuration: _medium,
      curve: Curves.easeOutCubic,
    ),
    GetPage(
      name: ncdCbac,
      page: () => const NcdCbacListScreen(),
      transition: Transition.rightToLeftWithFade,
      transitionDuration: _medium,
      curve: Curves.easeOutCubic,
    ),
    GetPage(
      name: tbCases,
      page: () => const TbCaseListScreen(),
      transition: Transition.rightToLeftWithFade,
      transitionDuration: _medium,
      curve: Curves.easeOutCubic,
    ),
    GetPage(
      name: medicineStock,
      page: () => const MedicineStockListScreen(),
      transition: Transition.rightToLeftWithFade,
      transitionDuration: _medium,
      curve: Curves.easeOutCubic,
    ),

    // Triage entry — zoom (mic-centric, "enter the conversation")
    GetPage(
      name: selectCase,
      page: () => const SelectCaseScreen(),
      transition: Transition.zoom,
      transitionDuration: Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    ),

    // Triage continuation — forward step
    GetPage(
      name: caseConfirm,
      page: () => const CaseConfirmScreen(),
      transition: Transition.rightToLeftWithFade,
      transitionDuration: _medium,
    ),
    GetPage(
      name: voiceTriage,
      page: () => const VoiceTriageScreen(),
      transition: Transition.rightToLeftWithFade,
      transitionDuration: _medium,
    ),
    GetPage(
      name: dynamicTriage,
      page: () => const DynamicTriageScreen(),
      transition: Transition.rightToLeftWithFade,
      transitionDuration: _medium,
    ),
    GetPage(
      name: triageResult,
      page: () => const TriageResultScreen(),
      transition: Transition.fadeIn,
      transitionDuration: _medium,
    ),

    // Patient detail screens — forward step
    GetPage(
      name: addPatient,
      page: () => const AddPatientScreen(),
      transition: Transition.rightToLeftWithFade,
      transitionDuration: _medium,
    ),
    GetPage(
      name: patientProfile,
      // Opaque slide (not ...WithFade): a fade keeps the incoming page
      // translucent mid-transition, so the previous screen's card shows
      // through as a "ghost" behind the header. rightToLeft covers cleanly.
      page: () => const PatientProfileScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: _medium,
      curve: Curves.easeOutCubic,
    ),

    // Emergency — slides up like a sheet (gravity / urgency feel)
    GetPage(
      name: emergency,
      page: () => const EmergencyScreen(),
      transition: Transition.downToUp,
      transitionDuration: _calm,
      curve: Curves.easeOutCubic,
    ),

    // Nearby facilities map — opened by the assistant for "nearest hospital /
    // how far / how long" queries (real GPS + OSRM distances).
    GetPage(
      name: nearestFacilities,
      page: () => const NearbyFacilitiesScreen(),
      transition: Transition.rightToLeftWithFade,
      transitionDuration: _medium,
      curve: Curves.easeOutCubic,
    ),

    // Admin — forward step
    GetPage(name: adminDashboard, page: () => const AdminShell(),
        transition: Transition.fadeIn, transitionDuration: _fast),
    GetPage(name: adminAshaList,  page: () => const AdminAshaListScreen(),
        transition: Transition.rightToLeftWithFade, transitionDuration: _medium),
    GetPage(name: adminAddAsha,   page: () => const AdminAddAshaScreen(),
        transition: Transition.rightToLeftWithFade, transitionDuration: _medium),
    GetPage(name: adminReports,   page: () => const AdminReportsScreen(),
        transition: Transition.rightToLeftWithFade, transitionDuration: _medium),
    GetPage(name: adminProfile,   page: () => const AdminProfileScreen(),
        transition: Transition.rightToLeftWithFade, transitionDuration: _medium),
  ];
}
