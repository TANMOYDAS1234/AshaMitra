import '../../../core/services/synced_store.dart';
import '../../../core/services/api_service.dart';

/// Offline-first store for the ASHA monthly medicine account (Form 2).
/// All sync logic lives in [SyncedStore]; this just binds the API + storage keys.
class MedicineStockController extends SyncedStore {
  MedicineStockController()
      : super(
          storageKey: 'session_medicine_stock',
          pendingDeleteKey: 'session_pending_medicine_stock_deletes',
          idPrefix: 'ms',
          listFn: ApiService.getMedicineStock,
          createFn: ApiService.createMedicineStock,
          updateFn: ApiService.updateMedicineStock,
          deleteFn: ApiService.deleteMedicineStock,
        );

  /// Distinct months present, newest first ('YYYY-MM').
  List<String> get months {
    final s = items
        .map((e) => (e['month'] ?? '').toString())
        .where((m) => m.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    return s;
  }

  /// Rows for one month.
  List<Map<String, dynamic>> forMonth(String month) =>
      items.where((e) => (e['month'] ?? '').toString() == month).toList();

  /// Lines running low (closing ≤ threshold, threshold > 0).
  int get lowStockCount => items.where((e) {
        final t = (e['lowStockThreshold'] as num?)?.toInt() ?? 0;
        final c = (e['closingStock'] as num?)?.toInt() ?? 0;
        return t > 0 && c <= t;
      }).length;
}
