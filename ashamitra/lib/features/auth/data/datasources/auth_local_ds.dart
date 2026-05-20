import '../../../../core/services/local_storage_service.dart';

class AuthLocalDs {
  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';

  Future<void> saveToken(String token) => LocalStorageService.set(_tokenKey, token);
  String? getToken() => LocalStorageService.get(_tokenKey);
  Future<void> saveUser(String userJson) => LocalStorageService.set(_userKey, userJson);
  String? getUser() => LocalStorageService.get(_userKey);
  Future<void> clear() async {
    await LocalStorageService.remove(_tokenKey);
    await LocalStorageService.remove(_userKey);
  }
}
