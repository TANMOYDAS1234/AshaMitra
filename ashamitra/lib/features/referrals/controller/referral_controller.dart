import 'package:get/get.dart';
import '../data/models/referral_model.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/logger.dart';

/// Where a just-created referral ended up (mirrors PatientSaveOutcome):
///   synced       → written to Atlas now
///   queuedOffline→ kept on the phone, will auto-sync later
///   needsLogin   → 401; the central hook has sent the worker to login
enum ReferralSaveOutcome { synced, queuedOffline, needsLogin }

class ReferralSaveResult {
  final ReferralModel referral;
  final ReferralSaveOutcome outcome;
  const ReferralSaveResult(this.referral, this.outcome);
}

/// Offline-first store for ASHA referrals (Form 3 + outcome tracking).
/// Same contract as [PatientController]: local-first write, then a foreground
/// POST (capped at 20 s) so the caller can confirm "Atlas ✓"; anything that
/// doesn't land stays queued and the next [syncFromServer] retries it.
class ReferralController extends GetxController {
  final isLoading = false.obs;
  final referrals = <ReferralModel>[].obs;

  final _pendingDeletes = <ReferralModel>[].obs;

  /// Open referrals (pending/reached) — drives the home-screen badge.
  int get openCount => referrals.where((r) => r.isOpen).length;

  @override
  void onInit() {
    super.onInit();
    _load();
    syncFromServer();
  }

  void _load() {
    referrals.value =
        LocalStorageService.loadReferrals().map(ReferralModel.fromJson).toList();
    _pendingDeletes.value = LocalStorageService.loadPendingReferralDeletes()
        .map(ReferralModel.fromJson)
        .toList();
  }

  Future<void> _save() async => LocalStorageService.saveReferrals(
        referrals.map((r) => r.toJson()).toList(),
      );

  Future<void> _savePendingDeletes() async =>
      LocalStorageService.savePendingReferralDeletes(
        _pendingDeletes.map((r) => r.toJson()).toList(),
      );

  /// Primary load from Atlas (falls back to local cache when offline).
  Future<void> syncFromServer() async {
    isLoading.value = true;
    try {
      await _flushPendingOps();
      final remote = await ApiService.getReferrals();
      final remoteList =
          remote.map((e) => ReferralModel.fromJson(e as Map<String, dynamic>)).toList();

      final pendingDeleteIds = _pendingDeletes.map((r) => r.id).toSet();
      final stillUnsynced =
          referrals.where((r) => r.syncState != SyncState.synced).toList();
      final stillUnsyncedIds = stillUnsynced.map((r) => r.id).toSet();

      final merged = <ReferralModel>[
        ...remoteList.where((r) =>
            !pendingDeleteIds.contains(r.id) && !stillUnsyncedIds.contains(r.id)),
        ...stillUnsynced,
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      referrals.value = merged;
      await _save();
    } on UnauthorizedException {
      // handled centrally by AuthController's 401 hook
    } catch (e) {
      AppLogger.e('Referral sync failed', e); // offline → keep local
    } finally {
      isLoading.value = false;
    }
  }

  /// Drains the offline queue: deletes, then creates, then updates.
  Future<void> _flushPendingOps() async {
    // 1. Deletes
    final stillDeleting = <ReferralModel>[];
    for (final r in _pendingDeletes.toList()) {
      if (!_isServerId(r.id)) continue; // never reached server — drop silently
      final ok = await ApiService.deleteReferral(r.id);
      if (!ok) stillDeleting.add(r);
    }
    if (stillDeleting.length != _pendingDeletes.length) {
      _pendingDeletes.value = stillDeleting;
      await _savePendingDeletes();
    }

    // 2 & 3. Creates and updates
    for (var i = 0; i < referrals.length; i++) {
      final r = referrals[i];
      if (r.syncState == SyncState.synced) continue;

      final needsPost = r.syncState == SyncState.pendingCreate ||
          (r.syncState == SyncState.pendingUpdate && !_isServerId(r.id));

      if (needsPost) {
        final data = r.toJson()..remove('id')..remove('syncState');
        data['clientId'] = r.id; // idempotency key
        final resp = await ApiService.createReferral(data);
        if (resp == null) continue;
        final serverId = resp['id']?.toString();
        if (serverId == null || serverId.isEmpty) continue;
        referrals[i] = r.copyWith(
          id: serverId,
          syncState: SyncState.synced,
          version: (resp['version'] as num?)?.toInt() ?? 0,
        );
      } else if (r.syncState == SyncState.pendingUpdate) {
        final data = r.toJson()..remove('id')..remove('syncState');
        final result = await ApiService.updateReferral(r.id, data);
        if (result['status'] == 'success') {
          final doc = result['data'] as Map<String, dynamic>?;
          referrals[i] = r.copyWith(
            syncState: SyncState.synced,
            version: (doc?['version'] as num?)?.toInt() ?? r.version + 1,
          );
        } else if (result['status'] == 'conflict') {
          final doc = result['data'] as Map<String, dynamic>?;
          if (doc != null) {
            // Server's current state + our outcome edits on top, re-queued.
            final server = ReferralModel.fromJson(doc);
            referrals[i] = server.copyWith(
              status: r.status,
              reachedDate: r.reachedDate,
              admittedBy: r.admittedBy,
              relation: r.relation,
              facilityNotes: r.facilityNotes,
              outcome: r.outcome,
              syncState: SyncState.pendingUpdate,
            );
          }
        }
        // 'failure' → stays pendingUpdate, retried next sync
      }
    }
    await _save();
  }

  /// Creates a referral. Local-first, then a foreground POST capped at 20 s so
  /// the caller can confirm where it landed.
  Future<ReferralSaveResult> addReferral(ReferralModel draft) async {
    final referral = draft.copyWith(
      id: 'ref_${DateTime.now().millisecondsSinceEpoch}',
      syncState: SyncState.pendingCreate,
    );
    referrals.insert(0, referral);
    await _save();
    final outcome = await _syncOnePendingCreate(referral.id).timeout(
      const Duration(seconds: 20),
      onTimeout: () => ReferralSaveOutcome.queuedOffline,
    );
    return ReferralSaveResult(referral, outcome);
  }

  Future<ReferralSaveOutcome> _syncOnePendingCreate(String placeholderId) async {
    final idx = referrals.indexWhere((r) => r.id == placeholderId);
    if (idx == -1) return ReferralSaveOutcome.queuedOffline;
    final r = referrals[idx];
    if (r.syncState != SyncState.pendingCreate) return ReferralSaveOutcome.synced;

    final data = r.toJson()..remove('id')..remove('syncState');
    data['clientId'] = r.id;
    final resp = await ApiService.createReferral(data);
    if (resp == null) {
      return ApiService.token == null
          ? ReferralSaveOutcome.needsLogin
          : ReferralSaveOutcome.queuedOffline;
    }
    final serverId = resp['id']?.toString();
    if (serverId == null || serverId.isEmpty) return ReferralSaveOutcome.synced;
    final cur = referrals.indexWhere((q) => q.id == placeholderId);
    if (cur == -1) return ReferralSaveOutcome.synced;
    referrals[cur] = r.copyWith(
      id: serverId,
      syncState: SyncState.synced,
      version: (resp['version'] as num?)?.toInt() ?? 0,
    );
    await _save();
    return ReferralSaveOutcome.synced;
  }

  /// Updates a referral (typically the outcome: status/admittedBy/notes).
  /// Optimistic-concurrency aware; returns true once the local change is
  /// persisted + queued (it syncs immediately when online).
  Future<bool> updateReferral(ReferralModel updated) async {
    final idx = referrals.indexWhere((r) => r.id == updated.id);
    if (idx == -1) return false;
    final existing = referrals[idx];
    final shouldUpsert =
        !_isServerId(updated.id) || existing.syncState == SyncState.pendingCreate;

    final next = updated.copyWith(
      syncState: shouldUpsert ? SyncState.pendingCreate : SyncState.pendingUpdate,
      version: updated.version == 0 ? existing.version : updated.version,
    );
    referrals[idx] = next;
    await _save();

    if (shouldUpsert) {
      _syncOnePendingCreate(next.id);
      return true;
    }
    final data = next.toJson()..remove('id')..remove('syncState');
    final result = await ApiService.updateReferral(next.id, data);
    if (result['status'] == 'success') {
      final doc = result['data'] as Map<String, dynamic>?;
      referrals[idx] = next.copyWith(
        syncState: SyncState.synced,
        version: (doc?['version'] as num?)?.toInt() ?? next.version + 1,
      );
      await _save();
    } else if (result['status'] == 'conflict') {
      final doc = result['data'] as Map<String, dynamic>?;
      if (doc != null) {
        referrals[idx] = ReferralModel.fromJson(doc).copyWith(
          status: next.status,
          reachedDate: next.reachedDate,
          admittedBy: next.admittedBy,
          relation: next.relation,
          facilityNotes: next.facilityNotes,
          outcome: next.outcome,
          syncState: SyncState.pendingUpdate,
        );
        await _save();
      }
    }
    // 'failure' → stays pendingUpdate, retried next sync
    return true;
  }

  /// Optimistic delete: drop from the list, queue the server DELETE.
  void deleteReferral(String id) {
    final idx = referrals.indexWhere((r) => r.id == id);
    if (idx == -1) return;
    final removed = referrals[idx];
    referrals.removeAt(idx);
    _save();
    if (!_isServerId(id) || removed.syncState == SyncState.pendingCreate) return;
    _pendingDeletes.add(removed.copyWith(syncState: SyncState.pendingDelete));
    _savePendingDeletes();
    ApiService.deleteReferral(id).then((ok) {
      if (!ok) return;
      _pendingDeletes.removeWhere((r) => r.id == id);
      _savePendingDeletes();
    });
  }

  static final _objectIdPattern = RegExp(r'^[0-9a-fA-F]{24}$');
  static bool _isServerId(String id) => _objectIdPattern.hasMatch(id);
}
