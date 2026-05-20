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

  @override
  void onInit() {
    super.onInit();
    ApiService.loadToken(); // non-blocking pre-warm; restoreSession also loads token
  }

  bool restoreSession() {
    final json = LocalStorageService.loadUser();
    if (json == null) return false;
    user.value = UserModel.fromJson(json);
    // Synchronously restore token so all subsequent API calls are authenticated
    final token = LocalStorageService.get('jwt_token');
    if (token != null) ApiService.setTokenInMemory(token);
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
    user.value = null;
    ApiService.clearToken();
    LocalStorageService.clearUser();
    Get.offAllNamed(AppRoutes.login);
  }
}
