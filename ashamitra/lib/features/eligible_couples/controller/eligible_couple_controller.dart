import '../../../core/services/synced_store.dart';
import '../../../core/services/api_service.dart';

/// Offline-first store for the eligible-couple (family-planning) register.
/// All sync logic lives in [SyncedStore]; this just binds the API + storage keys.
class EligibleCoupleController extends SyncedStore {
  EligibleCoupleController()
      : super(
          storageKey: 'session_eligible_couples',
          pendingDeleteKey: 'session_pending_eligible_couple_deletes',
          idPrefix: 'ec',
          listFn: ApiService.getEligibleCouples,
          createFn: ApiService.createEligibleCouple,
          updateFn: ApiService.updateEligibleCouple,
          deleteFn: ApiService.deleteEligibleCouple,
        );

  int get activeCount =>
      items.where((c) => (c['status'] ?? 'active').toString() == 'active').length;
}
