import '../../../../core/services/api_service.dart';
import '../../../../core/constants/api_constants.dart';

class AuthRemoteDs {
  final ApiService _api;
  AuthRemoteDs(this._api);

  Future<Map<String, dynamic>> login(String phone) async {
    final res = await _api.post(ApiConstants.authLogin, data: {'phone': phone});
    return res.data;
  }

  Future<Map<String, dynamic>> verifyOtp(String phone, String otp) async {
    final res = await _api.post(ApiConstants.authVerifyOtp, data: {'phone': phone, 'otp': otp});
    return res.data;
  }
}
