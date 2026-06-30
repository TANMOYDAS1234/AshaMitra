import '../../../core/services/synced_store.dart';
import '../../../core/services/api_service.dart';

/// Offline-first store for the NCD / CBAC (30+ screening) register.
/// All sync logic lives in [SyncedStore]; this just binds the API + storage keys.
class NcdCbacController extends SyncedStore {
  NcdCbacController()
      : super(
          storageKey: 'session_ncd_cbac',
          pendingDeleteKey: 'session_pending_ncd_cbac_deletes',
          idPrefix: 'nc',
          listFn: ApiService.getNcdCbac,
          createFn: ApiService.createNcdCbac,
          updateFn: ApiService.updateNcdCbac,
          deleteFn: ApiService.deleteNcdCbac,
        );

  /// People screened as high-risk (score ≥ 4) who are still open.
  int get highRiskCount => items
      .where((c) =>
          (c['status'] ?? 'active').toString() == 'active' &&
          ((c['riskScore'] as num?)?.toInt() ?? 0) >= 4)
      .length;
}
