import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/services/api_service.dart';
import '../../../app/routes.dart';
import '../../../core/services/local_storage_service.dart';
import '../../auth/controller/auth_controller.dart';
import '../../auth/data/models/user_model.dart';

class AdminController extends GetxController {
  final isLoading       = false.obs;
  final ashaWorkers     = <UserModel>[].obs;
  final reports         = <Map<String, dynamic>>[].obs;
  final filteredReports = <Map<String, dynamic>>[].obs;
  /// Soft-deleted reports surfaced via the audit endpoint. Populated only
  /// when [loadDeletedReports] is called (the admin "Deleted reports"
  /// screen). Each entry includes the original report fields plus
  /// ashaName / ashaDistrict / ashaBlock from the populated worker doc.
  final deletedReports  = <Map<String, dynamic>>[].obs;
  final isLoadingDeleted = false.obs;
  final errorMsg        = ''.obs;

  final totalWorkers  = 0.obs;
  final totalPatients = 0.obs;
  final totalReports  = 0.obs;
  final redReports    = 0.obs;
  final yellowReports = 0.obs;
  final greenReports  = 0.obs;

  // ── Module aggregates (across all ASHAs) ──
  final ncdScreened     = 0.obs;
  final ncdHighRisk     = 0.obs;
  final tbPresumptive   = 0.obs;
  final tbOnTreatment   = 0.obs;
  final medLowStock     = 0.obs;
  final vitalPendingCrs = 0.obs;
  final referralOpen    = 0.obs;

  final filterMode = 'all'.obs;
  final filterDate = Rxn<DateTime>();

  // Location filter dimensions — populated from /api/admin/locations.
  final districts          = <String>[].obs;
  final blocks             = <String>[].obs;
  final selectedWorkerId   = Rxn<String>();   // null = all workers
  final selectedDistrict   = Rxn<String>();   // null = all districts
  final selectedBlock      = Rxn<String>();   // null = all blocks

  @override
  void onInit() {
    super.onInit();
    loadStats();
    loadAshaWorkers();
    loadReports();
    loadLocations();
    loadUnassigned();
  }

  void _handleUnauth() {
    ApiService.clearToken();
    LocalStorageService.clearUser();
    // Don't yank off the splash: these admin-stat calls fire from AppBinding on
    // startup and 401 for a logged-out worker. The splash routes itself when it
    // finishes; interrupting it here was cutting the animation short.
    if (AuthController.splashActive || Get.currentRoute == AppRoutes.splash) {
      return;
    }
    Get.offAllNamed(AppRoutes.login);
  }

  // ── Stats ──────────────────────────────────────────────────────

  Future<void> loadStats() async {
    try {
      final res = await ApiService.getAdminStats();
      if (res['success'] == true) {
        final d = res['data'] as Map<String, dynamic>;
        totalWorkers.value  = (d['totalWorkers']  as num?)?.toInt() ?? 0;
        totalPatients.value = (d['totalPatients'] as num?)?.toInt() ?? 0;
        totalReports.value  = (d['totalReports']  as num?)?.toInt() ?? 0;
        redReports.value    = (d['redReports']    as num?)?.toInt() ?? 0;
        yellowReports.value = (d['yellowReports'] as num?)?.toInt() ?? 0;
        greenReports.value  = (d['greenReports']  as num?)?.toInt() ?? 0;
        final m = (d['modules'] as Map?)?.cast<String, dynamic>() ?? const {};
        int mi(String k) => (m[k] as num?)?.toInt() ?? 0;
        ncdScreened.value     = mi('ncdScreened');
        ncdHighRisk.value     = mi('ncdHighRisk');
        tbPresumptive.value   = mi('tbPresumptive');
        tbOnTreatment.value   = mi('tbOnTreatment');
        medLowStock.value     = mi('medLowStock');
        vitalPendingCrs.value = mi('vitalPendingCrs');
        referralOpen.value    = mi('referralOpen');
      }
    } on UnauthorizedException {
      _handleUnauth();
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> getWorkerPatients(String workerId) async {
    try {
      final res = await ApiService.getWorkerPatients(workerId);
      if (res['success'] == true)
        return (res['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } on UnauthorizedException { _handleUnauth(); } catch (_) {}
    return [];
  }

  Future<List<Map<String, dynamic>>> getWorkerReports(String workerId) async {
    try {
      final res = await ApiService.getWorkerReports(workerId);
      if (res['success'] == true)
        return (res['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } on UnauthorizedException { _handleUnauth(); } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>?> getWorkerProfile(String workerId) async {
    try {
      final res = await ApiService.getWorkerProfile(workerId);
      if (res['success'] == true) return res['data'] as Map<String, dynamic>;
    } on UnauthorizedException { _handleUnauth(); } catch (_) {}
    return null;
  }

  /// Direct reports of a member of my subtree — drills one level down the tree
  /// (BMHO taps an ANM → her ASHAs; CMHO taps a BMHO → his ANMs).
  Future<List<UserModel>> getWorkerTeam(String workerId) async {
    try {
      final res = await ApiService.getWorkerTeam(workerId);
      if (res['success'] == true) {
        return (res['data'] as List)
            .map((d) => UserModel.fromJson(d as Map<String, dynamic>))
            .toList();
      }
    } on UnauthorizedException { _handleUnauth(); } catch (_) {}
    return [];
  }

  // ── ASHA Workers ───────────────────────────────────────────────

  /// Populates [deletedReports] from the admin audit endpoint. Each row
  /// carries the original report fields plus the worker name / district /
  /// block (server-side populated). Sorted by most-recent deletion first.
  Future<void> loadDeletedReports() async {
    isLoadingDeleted.value = true;
    try {
      final data = await ApiService.getDeletedReports();
      deletedReports.value = data
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } on UnauthorizedException {
      _handleUnauth();
    } catch (_) {
      errorMsg.value = 'মুছে ফেলা রিপোর্ট লোড ব্যর্থ।';
    } finally {
      isLoadingDeleted.value = false;
    }
  }

  /// Restores a soft-deleted report (admin-only — cross-worker scope).
  /// Optimistically removes from [deletedReports] so the audit list updates
  /// immediately; rolls back on server failure. Also refreshes the main
  /// [reports] list so the restored row appears there next time admin
  /// views it.
  Future<bool> restoreDeletedReport(String reportId) async {
    final idx = deletedReports.indexWhere((r) => r['id'] == reportId);
    if (idx == -1) return false;
    final snapshot = deletedReports[idx];
    deletedReports.removeAt(idx);
    try {
      final ok = await ApiService.adminRestoreReport(reportId);
      if (!ok) {
        deletedReports.insert(idx.clamp(0, deletedReports.length), snapshot);
        return false;
      }
      // Drop the cached live list so the next loadReports() pulls fresh.
      reports.removeWhere((r) => r['id'] == reportId);
      return true;
    } on UnauthorizedException {
      deletedReports.insert(idx.clamp(0, deletedReports.length), snapshot);
      _handleUnauth();
      return false;
    } catch (_) {
      deletedReports.insert(idx.clamp(0, deletedReports.length), snapshot);
      return false;
    }
  }

  /// Hard-deletes a soft-deleted report (admin-only, irreversible).
  /// Server enforces "audit first" — rejects with 400 if the report
  /// isn't already soft-deleted. Optimistic UI: row disappears from the
  /// audit list immediately; restored on failure.
  Future<bool> permanentlyDeleteReport(String reportId) async {
    final idx = deletedReports.indexWhere((r) => r['id'] == reportId);
    if (idx == -1) return false;
    final snapshot = deletedReports[idx];
    deletedReports.removeAt(idx);
    try {
      final ok = await ApiService.adminPermanentlyDeleteReport(reportId);
      if (!ok) {
        deletedReports.insert(idx.clamp(0, deletedReports.length), snapshot);
        return false;
      }
      return true;
    } on UnauthorizedException {
      deletedReports.insert(idx.clamp(0, deletedReports.length), snapshot);
      _handleUnauth();
      return false;
    } catch (_) {
      deletedReports.insert(idx.clamp(0, deletedReports.length), snapshot);
      return false;
    }
  }

  Future<void> loadAshaWorkers() async {
    isLoading.value = true;
    try {
      final res = await ApiService.getWorkers();
      if (res['success'] == true) {
        ashaWorkers.value = (res['data'] as List)
            .map((d) => UserModel.fromJson(d as Map<String, dynamic>))
            .toList();
      } else {
        errorMsg.value = res['message']?.toString() ?? 'ASHA তালিকা লোড ব্যর্থ।';
      }
    } on UnauthorizedException {
      _handleUnauth();
    } catch (_) {
      errorMsg.value = 'সংযোগ ব্যর্থ।';
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> addAshaWorker({
    required String phone,
    required String name,
    required String block,
    required String district,
  }) async {
    try {
      final res = await ApiService.addWorker({
        'phone': phone, 'name': name,
        'block': block, 'district': district,
      });
      if (res['success'] == true) {
        await loadAshaWorkers();
        await loadStats();
        return true;
      }
      errorMsg.value = res['message']?.toString() ?? 'ASHA যোগ করা ব্যর্থ।';
      return false;
    } on UnauthorizedException {
      _handleUnauth();
      return false;
    } catch (_) {
      errorMsg.value = 'সংযোগ ব্যর্থ।';
      return false;
    }
  }

  Future<bool> removeAshaWorker(String id) async {
    try {
      final res = await ApiService.deactivateWorker(id);
      if (res['success'] == true) {
        await loadAshaWorkers();
        await loadStats();
        return true;
      }
      errorMsg.value = res['message']?.toString() ?? 'ASHA সরানো ব্যর্থ।';
      return false;
    } on UnauthorizedException {
      _handleUnauth();
      return false;
    } catch (_) {
      errorMsg.value = 'সংযোগ ব্যর্থ।';
      return false;
    }
  }

  Future<bool> reactivateAshaWorker(String id) async {
    try {
      final res = await ApiService.activateWorker(id);
      if (res['success'] == true) {
        await loadAshaWorkers();
        await loadStats();
        return true;
      }
      errorMsg.value = res['message']?.toString() ?? 'পুনরায় সক্রিয় করা ব্যর্থ।';
      return false;
    } on UnauthorizedException {
      _handleUnauth();
      return false;
    } catch (_) {
      errorMsg.value = 'সংযোগ ব্যর্থ।';
      return false;
    }
  }

  // ── Reports ────────────────────────────────────────────────────

  Future<void> loadReports({String? band, DateTime? date, String? month, String? year}) async {
    isLoading.value = true;
    try {
      final res = await ApiService.getAdminReports(
        band:     band,
        date:     date != null ? DateFormat('yyyy-MM-dd').format(date) : null,
        month:    month,
        year:     year,
        worker:   selectedWorkerId.value,
        district: selectedDistrict.value,
        block:    selectedBlock.value,
      );
      if (res['success'] == true) {
        final list = (res['data'] as List)
            .map((d) => Map<String, dynamic>.from(d as Map))
            .toList();
        reports.value         = list;
        filteredReports.value = list;
      } else {
        errorMsg.value = res['message']?.toString() ?? 'রিপোর্ট লোড ব্যর্থ।';
      }
    } on UnauthorizedException {
      _handleUnauth();
    } catch (_) {
      errorMsg.value = 'সংযোগ ব্যর্থ।';
    } finally {
      isLoading.value = false;
    }
  }

  // ── District / block HMIS analytics (the CMHO dashboard) ───────────────
  final district = Rxn<Map<String, dynamic>>();
  final isLoadingDistrict = false.obs;

  Future<void> loadDistrict({int months = 12}) async {
    isLoadingDistrict.value = true;
    try {
      final res = await ApiService.getDistrict(months: months);
      if (res['success'] == true) {
        district.value = Map<String, dynamic>.from(res['data'] as Map);
      }
    } on UnauthorizedException {
      _handleUnauth();
    } catch (_) {
      errorMsg.value = 'বিশ্লেষণ লোড ব্যর্থ।';
    } finally {
      isLoadingDistrict.value = false;
    }
  }

  Map<String, dynamic> get dIndicators =>
      Map<String, dynamic>.from((district.value?['indicators'] as Map?) ?? {});

  List<Map<String, dynamic>> get dBlocks =>
      ((district.value?['blocks'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

  Map<String, dynamic> get dAlerts =>
      Map<String, dynamic>.from((district.value?['alerts'] as Map?) ?? {});

  List<Map<String, dynamic>> dAlert(String key) =>
      ((dAlerts[key] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

  /// Total open escalations — drives the badge on the District tab.
  int get dAlertCount =>
      dAlert('maternalDeaths').length +
      dAlert('infantDeaths').length +
      dAlert('stockouts').length +
      dAlert('silentAshas').length +
      dAlert('overdueReferrals').length;

  // ── Unassigned members (adoptable into my team) ────────────────────────
  // The migration leaves the legacy ANM with no supervisor. A newly created
  // BMHO adopts her from here — otherwise the tree could never be assembled
  // above the ANM.
  final unassigned = <UserModel>[].obs;

  Future<void> loadUnassigned() async {
    try {
      final res = await ApiService.getUnassigned();
      if (res['success'] == true) {
        unassigned.value = (res['data'] as List)
            .map((d) => UserModel.fromJson(d as Map<String, dynamic>))
            .toList();
      }
    } on UnauthorizedException {
      _handleUnauth();
    } catch (_) {}
  }

  /// Adopt an unattached member into my team (I become their supervisor).
  Future<bool> adopt(String workerId) async {
    final me = Get.find<AuthController>().user.value;
    if (me == null) return false;
    try {
      final res = await ApiService.setWorkerSupervisor(workerId, me.id);
      if (res['success'] == true) {
        await loadAshaWorkers();
        await loadUnassigned();
        await loadStats();
        return true;
      }
      errorMsg.value = res['message']?.toString() ?? 'দলে যোগ করা যায়নি।';
    } on UnauthorizedException {
      _handleUnauth();
    } catch (_) {
      errorMsg.value = 'সংযোগ ব্যর্থ।';
    }
    return false;
  }

  // ── Team search ────────────────────────────────────────────────────────
  final workerQuery = ''.obs;

  /// Direct reports narrowed by the search box (name / phone / block / district).
  List<UserModel> get visibleWorkers {
    final q = workerQuery.value.trim().toLowerCase();
    if (q.isEmpty) return ashaWorkers;
    return ashaWorkers
        .where((w) =>
            w.name.toLowerCase().contains(q) ||
            w.phone.contains(q) ||
            w.block.toLowerCase().contains(q) ||
            w.district.toLowerCase().contains(q))
        .toList();
  }

  // ── Bulk actions ───────────────────────────────────────────────────────
  final selectedWorkers = <String>{}.obs;

  void toggleSelect(String id) {
    if (selectedWorkers.contains(id)) {
      selectedWorkers.remove(id);
    } else {
      selectedWorkers.add(id);
    }
  }

  void clearSelection() => selectedWorkers.clear();

  /// Activate/deactivate every selected member in one pass. Returns how many
  /// succeeded so the UI can report honestly on partial failure.
  Future<int> bulkSetActive(bool active) async {
    final ids = selectedWorkers.toList();
    var ok = 0;
    isLoading.value = true;
    try {
      for (final id in ids) {
        try {
          final res = active
              ? await ApiService.activateWorker(id)
              : await ApiService.deactivateWorker(id);
          if (res['success'] == true) ok++;
        } catch (_) {/* keep going — report the partial count */}
      }
    } finally {
      isLoading.value = false;
    }
    clearSelection();
    await loadAshaWorkers();
    await loadStats();
    return ok;
  }

  // ── Analytics ──────────────────────────────────────────────────────────
  // Derived from the reports already loaded for this panel — which the server
  // has scoped to the supervisor's own subtree — so a CMHO's curve is their
  // district, an ANM's is her ASHAs. No extra round-trip.

  /// Reports per day over the last [days] days, oldest → newest.
  List<int> reportsTrend({int days = 14}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final counts = List<int>.filled(days, 0);
    for (final r in reports) {
      final ts = DateTime.tryParse((r['createdAt'] ?? '').toString());
      if (ts == null) continue;
      final d = DateTime(ts.year, ts.month, ts.day);
      final idx = days - 1 - today.difference(d).inDays; // last slot = today
      if (idx >= 0 && idx < days) counts[idx]++;
    }
    return counts;
  }

  /// Total reports captured in the last [days] days.
  int reportsInLast({int days = 14}) =>
      reportsTrend(days: days).fold(0, (a, b) => a + b);

  /// Reports per day for one band (RED / YELLOW / GREEN), oldest → newest.
  List<int> bandTrend(String band, {int days = 14}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final counts = List<int>.filled(days, 0);
    final want = band.toUpperCase();
    for (final r in reports) {
      if ((r['finalBand']?.toString().toUpperCase() ?? '') != want) continue;
      final ts = DateTime.tryParse((r['createdAt'] ?? '').toString());
      if (ts == null) continue;
      final d = DateTime(ts.year, ts.month, ts.day);
      final idx = days - 1 - today.difference(d).inDays;
      if (idx >= 0 && idx < days) counts[idx]++;
    }
    return counts;
  }

  /// Percent change of the last 7 days against the 7 before them.
  /// Returns null when there's no meaningful baseline — better to show nothing
  /// than to print a confident "+100%" off a single report.
  double? trendDelta(List<int> series) {
    if (series.length < 14) return null;
    final n = series.length;
    final recent = series.sublist(n - 7).fold<int>(0, (a, b) => a + b);
    final prior = series.sublist(n - 14, n - 7).fold<int>(0, (a, b) => a + b);
    if (prior == 0) return null;
    return ((recent - prior) / prior) * 100;
  }

  /// Loads district + block distinct lists for the filter dropdowns.
  Future<void> loadLocations() async {
    try {
      final res = await ApiService.getAdminLocations();
      if (res['success'] == true) {
        final data = res['data'] as Map<String, dynamic>;
        districts.value = ((data['districts'] as List?) ?? []).map((e) => e.toString()).toList();
        blocks.value    = ((data['blocks']    as List?) ?? []).map((e) => e.toString()).toList();
      }
    } on UnauthorizedException {
      _handleUnauth();
    } catch (_) {}
  }

  /// Re-runs the report query with the currently selected band/date AND
  /// the worker/district/block selections. Called by the new filter UI.
  Future<void> applyLocationFilters() async {
    // Re-fire the current band/date filter — keeps both filter axes in sync.
    final mode = filterMode.value;
    final date = filterDate.value;
    switch (mode) {
      case 'red':    return loadReports(band: 'RED');
      case 'yellow': return loadReports(band: 'YELLOW');
      case 'green':  return loadReports(band: 'GREEN');
      case 'day':    if (date != null) return loadReports(date: date); break;
      case 'month':  if (date != null) return loadReports(month: DateFormat('yyyy-MM').format(date)); break;
      case 'year':   if (date != null) return loadReports(year: date.year.toString()); break;
    }
    return loadReports();
  }

  void clearLocationFilters() {
    selectedWorkerId.value = null;
    selectedDistrict.value = null;
    selectedBlock.value    = null;
    applyLocationFilters();
  }

  void setFilter(String mode, {DateTime? date}) {
    filterMode.value = mode;
    filterDate.value = date;
    switch (mode) {
      case 'all':
        loadReports();
      case 'red':
        loadReports(band: 'RED');
      case 'yellow':
        loadReports(band: 'YELLOW');
      case 'green':
        loadReports(band: 'GREEN');
      case 'day':
        if (date != null) loadReports(date: date);
      case 'month':
        if (date != null)
          loadReports(month: DateFormat('yyyy-MM').format(date));
      case 'year':
        if (date != null)
          loadReports(year: date.year.toString());
    }
  }
}
