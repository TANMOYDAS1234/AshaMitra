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
import '../features/emergency/presentation/screens/emergency_screen.dart';
import '../features/reports/presentation/screens/reports_screen.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../features/admin/presentation/screens/admin_shell.dart';
import '../features/admin/presentation/screens/admin_asha_list_screen.dart';
import '../features/admin/presentation/screens/admin_add_asha_screen.dart';
import '../features/admin/presentation/screens/admin_reports_screen.dart';
import '../features/admin/presentation/screens/admin_profile_screen.dart';

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
  static const reports         = '/reports';
  static const profile         = '/profile';
  // Admin
  static const adminDashboard  = '/admin';
  static const adminAshaList   = '/admin/asha';
  static const adminAddAsha    = '/admin/asha/add';
  static const adminReports    = '/admin/reports';
  static const adminProfile    = '/admin/profile';

  static final pages = [
    GetPage(name: splash,         page: () => const SplashScreen()),
    GetPage(name: welcome,        page: () => const WelcomeScreen()),
    GetPage(name: language,       page: () => const LanguageScreen()),
    GetPage(name: login,          page: () => const LoginScreen()),
    GetPage(name: otp,            page: () => const OtpScreen()),
    GetPage(name: home,           page: () => const HomeScreen()),
    GetPage(name: selectCase,     page: () => const SelectCaseScreen()),
    GetPage(name: caseConfirm,    page: () => const CaseConfirmScreen()),
    GetPage(name: voiceTriage,    page: () => const VoiceTriageScreen()),
    GetPage(name: dynamicTriage,  page: () => const DynamicTriageScreen()),
    GetPage(name: triageResult,   page: () => const TriageResultScreen()),
    GetPage(name: patientList,    page: () => const PatientListScreen()),
    GetPage(name: addPatient,     page: () => const AddPatientScreen()),
    GetPage(name: patientProfile, page: () => const PatientProfileScreen()),
    GetPage(name: emergency,      page: () => const EmergencyScreen()),
    GetPage(name: reports,        page: () => const ReportsScreen()),
    GetPage(name: profile,        page: () => const ProfileScreen()),
    // Admin
    GetPage(name: adminDashboard, page: () => const AdminShell()),
    GetPage(name: adminAshaList,  page: () => const AdminAshaListScreen()),
    GetPage(name: adminAddAsha,   page: () => const AdminAddAshaScreen()),
    GetPage(name: adminReports,   page: () => const AdminReportsScreen()),
    GetPage(name: adminProfile,   page: () => const AdminProfileScreen()),
  ];
}
