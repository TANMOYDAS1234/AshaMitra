import '../../../core/services/synced_store.dart';
import '../../../core/services/api_service.dart';

/// Offline-first store for the birth & death (CRS) register.
/// All sync logic lives in [SyncedStore]; this just binds the API + storage keys.
class VitalEventController extends SyncedStore {
  VitalEventController()
      : super(
          storageKey: 'session_vital_events',
          pendingDeleteKey: 'session_pending_vital_event_deletes',
          idPrefix: 've',
          listFn: ApiService.getVitalEvents,
          createFn: ApiService.createVitalEvent,
          updateFn: ApiService.updateVitalEvent,
          deleteFn: ApiService.deleteVitalEvent,
        );

  /// Births/deaths not yet registered with CRS — the worker's pending list.
  int get unregisteredCount =>
      items.where((e) => (e['registered'] ?? false) != true).length;
}
