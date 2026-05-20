import '../../../../core/services/local_storage_service.dart';

class TriageLocalDs {
  static const _key = 'pending_triages';

  Future<void> savePending(String json) => LocalStorageService.set(_key, json);
  String? getPending() => LocalStorageService.get(_key);
  Future<void> clear() => LocalStorageService.remove(_key);
}
