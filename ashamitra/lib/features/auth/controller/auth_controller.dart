import 'dart:convert';
import 'dart:io';
import 'package:get/get.dart';
import '../data/models/user_model.dart';
import '../../../app/routes.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/services/api_service.dart';
import '../../patients/controller/patient_controller.dart';

class AuthController extends GetxController {
  final isLoading = false.obs;
  final user      = Rxn<UserModel>();
  final errorMsg  = ''.obs;

  bool _sessionExpiring = false;

  /// True while the splash is on screen. A startup sync can 401 on an expired
  /// token before the splash finishes; this suppresses the login redirect so
  /// the splash always plays. Set by SplashScreen, reliable regardless of how
  /// GetX reports the current route mid-transition.
  static bool splashActive = false;

  @override
  void onInit() {
    super.onInit();
    ApiService.loadToken(); // non-blocking pre-warm; restoreSession also loads token
    // Force a clean re-login whenever the backend rejects our token (401).
    ApiService.onUnauthorized = handleSessionExpired;
  }

  /// Forced re-login when the backend rejects our session (401). SOFT logout:
  /// clears only token + user — local patient/report data stays on the phone
  /// and re-syncs automatically after the next login. Debounced so a burst of
  /// parallel 401s triggers exactly one redirect.
  void handleSessionExpired() {
    if (_sessionExpiring) return;
    if (ApiService.token == null && user.value == null) return; // already out
    _sessionExpiring = true;
    user.value = null;
    ApiService.clearToken();
    LocalStorageService.clearUser(); // keeps patients/reports on the device
    // If a startup sync 401s while the splash is still on screen, don't yank
    // the user to login mid-animation — the session is already cleared, so the
    // splash's own routing will send them on once it finishes.
    if (splashActive || Get.currentRoute == AppRoutes.splash) return;
    // Replay the splash on the way out so the animation shows on logout/expiry
    // too; the splash routes to login once it finishes.
    Get.offAllNamed(AppRoutes.splash);
  }

  bool restoreSession() {
    final json = LocalStorageService.loadUser();
    if (json == null) return false;
    user.value = UserModel.fromJson(json);
    // Synchronously restore token so all subsequent API calls are authenticated
    final token = LocalStorageService.get('jwt_token');
    if (token != null) ApiService.setTokenInMemory(token);
    _sessionExpiring = false; // a restored session re-arms the 401 handler
    return true;
  }

  /// Step 1 — send OTP via backend (works for admin and ASHA worker).
  Future<void> login(String phone) async {
    isLoading.value = true;
    errorMsg.value  = '';
    try {
      final res = await ApiService.sendOtp(phone.trim());
      if (res['success'] == true) {
        Get.toNamed(AppRoutes.otp, arguments: {
          'phone': phone.trim(),
          'pilotOtp': res['otp']?.toString(),
        });
      } else {
        errorMsg.value = res['message']?.toString() ?? 'লগইন ব্যর্থ।';
      }
    } catch (_) {
      errorMsg.value = 'সংযোগ ব্যর্থ। সার্ভার চালু আছে কিনা দেখুন।';
    } finally {
      isLoading.value = false;
    }
  }

  /// Resend OTP WITHOUT navigating — we're already on the OTP screen, so
  /// going through [login] is wrong: its `Get.toNamed(otp)` is a no-op here
  /// (GetX preventDuplicates blocks navigating to the route we're already on),
  /// which is why the freshly-generated OTP never reached the UI. This fetches
  /// a new code and returns it so the screen can update in place:
  ///   • returns the 6-digit pilot OTP on pilot-mode success,
  ///   • returns '' on success with no OTP in the response (real SMS path),
  ///   • returns null on failure (errorMsg is set).
  Future<String?> resendOtp(String phone) async {
    isLoading.value = true;
    errorMsg.value  = '';
    try {
      final res = await ApiService.sendOtp(phone.trim());
      if (res['success'] == true) {
        return res['otp']?.toString() ?? '';
      }
      errorMsg.value = res['message']?.toString() ?? 'OTP পাঠানো ব্যর্থ।';
      return null;
    } catch (_) {
      errorMsg.value = 'সংযোগ ব্যর্থ। সার্ভার চালু আছে কিনা দেখুন।';
      return null;
    } finally {
      isLoading.value = false;
    }
  }

  /// Step 2 — verify OTP via backend, receive JWT + user object.
  Future<void> verifyOtp(String phone, String otp) async {
    if (otp.trim().length != 6) {
      errorMsg.value = 'সঠিক ৬ সংখ্যার OTP দিন।';
      return;
    }
    isLoading.value = true;
    errorMsg.value  = '';
    try {
      final res = await ApiService.verifyOtp(phone.trim(), otp.trim());
      if (res['success'] == true) {
        final u = UserModel.fromJson(res['user'] as Map<String, dynamic>);
        user.value = u;
        ApiService.setToken(res['token'] as String);
        _sessionExpiring = false; // re-arm the 401 handler for this new session
        await LocalStorageService.saveUser(u.toJson());
        // Reload persisted data for this session
        Get.find<PatientController>().reloadFromStorage();
        Get.find<PatientController>().syncFromServer();
        if (u.isAdmin) {
          Get.offAllNamed(AppRoutes.adminDashboard);
        } else {
          Get.offAllNamed(AppRoutes.home);
        }
      } else {
        errorMsg.value = res['message']?.toString() ?? 'OTP যাচাই ব্যর্থ।';
      }
    } catch (_) {
      errorMsg.value = 'সংযোগ ব্যর্থ। পুনরায় চেষ্টা করুন।';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateProfile({
    required String name,
    required String block,
    required String district,
  }) async {
    if (user.value == null) return;
    try {
      final res = await ApiService.updateProfile({
        'name': name, 'block': block, 'district': district,
      });
      if (res['success'] == true) {
        final updated = UserModel.fromJson(res['user'] as Map<String, dynamic>);
        user.value = updated;
        LocalStorageService.saveUser(updated.toJson());
      } else {
        final updated = user.value!.copyWith(name: name, block: block, district: district);
        user.value = updated;
        LocalStorageService.saveUser(updated.toJson());
      }
    } on UnauthorizedException {
      logout();
    } catch (_) {
      final updated = user.value!.copyWith(name: name, block: block, district: district);
      user.value = updated;
      LocalStorageService.saveUser(updated.toJson());
    }
  }

  void updateProfileImage(String? imagePath) async {
    if (user.value == null) return;
    String? base64Image;
    if (imagePath != null) {
      try {
        final bytes = await File(imagePath).readAsBytes();
        base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      } catch (_) {}
    }
    final updated = user.value!.copyWith(profileImagePath: base64Image);
    user.value = updated;
    LocalStorageService.saveUser(updated.toJson());
    try {
      await ApiService.updateProfile({'profileImagePath': base64Image});
    } on UnauthorizedException {
      logout();
    } catch (_) {}
  }

  void logout() {
    _sessionExpiring = false; // reset the 401 debounce on a clean logout
    user.value = null;
    ApiService.clearToken();
    LocalStorageService.clearUser();
    // Route through the splash so its animation plays on logout, then it lands
    // the (now logged-out) worker on login.
    Get.offAllNamed(AppRoutes.splash);
  }
}
