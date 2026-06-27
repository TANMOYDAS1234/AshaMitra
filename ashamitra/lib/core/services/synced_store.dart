import 'package:get/get.dart';
import 'api_service.dart';
import 'local_storage_service.dart';
import '../utils/logger.dart';

typedef ListFn = Future<List<dynamic>> Function();
typedef CreateFn = Future<Map<String, dynamic>?> Function(Map<String, dynamic>);
typedef UpdateFn = Future<Map<String, dynamic>> Function(String, Map<String, dynamic>);
typedef DeleteFn = Future<bool> Function(String);

/// Generic offline-first store for simple owner-scoped collections that share
/// the referral sync contract: local-first write with a `<prefix>_<ts>`
/// placeholder id (also the server `clientId` idempotency key), optimistic
/// `version` on update, and a pending-delete queue flushed on the next sync.
///
/// Records are plain `Map<String, dynamic>` (every row carries `id`,
/// `syncState`, `createdAt`, `version`). The eligible-couple and vital-event
/// controllers configure it with their own API functions + storage keys, so the
/// 200-line sync engine lives here once instead of per module.
class SyncedStore extends GetxController {
  SyncedStore({
    required this.storageKey,
    required this.pendingDeleteKey,
    required this.idPrefix,
    required this.listFn,
    required this.createFn,
    required this.updateFn,
    required this.deleteFn,
  });

  final String storageKey;
  final String pendingDeleteKey;
  final String idPrefix;
  final ListFn listFn;
  final CreateFn createFn;
  final UpdateFn updateFn;
  final DeleteFn deleteFn;

  final items = <Map<String, dynamic>>[].obs;
  final isLoading = false.obs;
  final _pendingDeletes = <Map<String, dynamic>>[].obs;

  static final _objectId = RegExp(r'^[0-9a-fA-F]{24}$');
  static bool _isServerId(String id) => _objectId.hasMatch(id);
  String _sync(Map m) => (m['syncState'] ?? 'synced').toString();
  String _id(Map m) => (m['id'] ?? m['_id'] ?? '').toString();

  @override
  void onInit() {
    super.onInit();
    _load();
    syncFromServer();
  }

  void _load() {
    items.value = LocalStorageService.loadJsonList(storageKey);
    _pendingDeletes.value = LocalStorageService.loadJsonList(pendingDeleteKey);
  }

  Future<void> _save() => LocalStorageService.saveJsonList(storageKey, items.toList());
  Future<void> _savePending() =>
      LocalStorageService.saveJsonList(pendingDeleteKey, _pendingDeletes.toList());

  /// Primary load from Atlas (falls back to local cache when offline).
  Future<void> syncFromServer() async {
    isLoading.value = true;
    try {
      await _flush();
      final remote = await listFn();
      final remoteList = remote.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final deleteIds = _pendingDeletes.map(_id).toSet();
      final stillUnsynced = items.where((r) => _sync(r) != 'synced').toList();
      final unsyncedIds = stillUnsynced.map(_id).toSet();
      final merged = <Map<String, dynamic>>[
        ...remoteList.where((r) => !deleteIds.contains(_id(r)) && !unsyncedIds.contains(_id(r))),
        ...stillUnsynced,
      ]..sort((a, b) =>
          (b['createdAt'] ?? '').toString().compareTo((a['createdAt'] ?? '').toString()));
      items.value = merged;
      await _save();
    } on UnauthorizedException {
      // handled centrally by the 401 hook
    } catch (e) {
      AppLogger.e('sync $storageKey', e); // offline → keep local
    } finally {
      isLoading.value = false;
    }
  }

  /// Drains the offline queue: deletes, then creates, then updates.
  Future<void> _flush() async {
    final stillDeleting = <Map<String, dynamic>>[];
    for (final r in _pendingDeletes.toList()) {
      final id = _id(r);
      if (!_isServerId(id)) continue;
      final ok = await deleteFn(id);
      if (!ok) stillDeleting.add(r);
    }
    if (stillDeleting.length != _pendingDeletes.length) {
      _pendingDeletes.value = stillDeleting;
      await _savePending();
    }

    for (var i = 0; i < items.length; i++) {
      final r = items[i];
      final st = _sync(r);
      final id = _id(r);
      if (st == 'synced') continue;
      final needsPost = st == 'pendingCreate' || (st == 'pendingUpdate' && !_isServerId(id));
      if (needsPost) {
        final data = Map<String, dynamic>.from(r)..remove('id')..remove('syncState');
        data['clientId'] = id;
        final resp = await createFn(data);
        if (resp == null) continue;
        final sid = (resp['id'] ?? '').toString();
        if (sid.isEmpty) continue;
        items[i] = {
          ...r,
          'id': sid,
          'syncState': 'synced',
          'version': (resp['version'] as num?)?.toInt() ?? 0,
        };
      } else if (st == 'pendingUpdate') {
        final data = Map<String, dynamic>.from(r)..remove('id')..remove('syncState');
        final result = await updateFn(id, data);
        if (result['status'] == 'success') {
          final doc = result['data'] as Map<String, dynamic>?;
          items[i] = {
            ...r,
            'syncState': 'synced',
            'version': (doc?['version'] as num?)?.toInt() ??
                (((r['version'] as num?)?.toInt() ?? 0) + 1),
          };
        } else if (result['status'] == 'conflict') {
          final doc = result['data'] as Map<String, dynamic>?;
          if (doc != null) items[i] = {...doc, 'syncState': 'pendingUpdate'};
        }
      }
    }
    await _save();
  }

  /// Creates (when `draft['id']` is empty) or updates a record, local-first,
  /// then flushes to the server (capped so the UI never hangs offline).
  Future<void> upsert(Map<String, dynamic> draft) async {
    final id = (draft['id'] ?? '').toString();
    if (id.isEmpty) {
      final newId = '${idPrefix}_${DateTime.now().millisecondsSinceEpoch}';
      items.insert(0, {
        ...draft,
        'id': newId,
        'syncState': 'pendingCreate',
        'createdAt': DateTime.now().toIso8601String(),
        'version': 0,
      });
    } else {
      final idx = items.indexWhere((r) => _id(r) == id);
      if (idx == -1) return;
      final existing = items[idx];
      final asCreate = !_isServerId(id) || _sync(existing) == 'pendingCreate';
      items[idx] = {
        ...existing,
        ...draft,
        'syncState': asCreate ? 'pendingCreate' : 'pendingUpdate',
      };
    }
    await _save();
    await _flush().timeout(const Duration(seconds: 25), onTimeout: () {});
  }

  /// Optimistic delete: drop from the list, queue the server DELETE.
  void remove(String id) {
    final idx = items.indexWhere((r) => _id(r) == id);
    if (idx == -1) return;
    final removed = items[idx];
    items.removeAt(idx);
    _save();
    if (!_isServerId(id) || _sync(removed) == 'pendingCreate') return;
    _pendingDeletes.add({...removed, 'syncState': 'pendingDelete'});
    _savePending();
    deleteFn(id).then((ok) {
      if (!ok) return;
      _pendingDeletes.removeWhere((r) => _id(r) == id);
      _savePending();
    });
  }
}
