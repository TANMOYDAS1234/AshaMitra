import '../../../../core/services/local_storage_service.dart';

class PatientLocalDs {
  static const _key = 'cached_patients';

  Future<void> save(String json) => LocalStorageService.set(_key, json);
  String? get() => LocalStorageService.get(_key);
}
