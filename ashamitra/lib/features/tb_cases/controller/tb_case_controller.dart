import '../../../core/services/synced_store.dart';
import '../../../core/services/api_service.dart';

/// Offline-first store for the TB register (presumptive screening + DOTS).
/// All sync logic lives in [SyncedStore]; this just binds the API + storage keys.
class TbCaseController extends SyncedStore {
  TbCaseController()
      : super(
          storageKey: 'session_tb_cases',
          pendingDeleteKey: 'session_pending_tb_case_deletes',
          idPrefix: 'tb',
          listFn: ApiService.getTbCases,
          createFn: ApiService.createTbCase,
          updateFn: ApiService.updateTbCase,
          deleteFn: ApiService.deleteTbCase,
        );

  /// Cases currently on DOTS treatment.
  int get onTreatmentCount =>
      items.where((c) => (c['stage'] ?? '').toString() == 'on_treatment').length;
}
