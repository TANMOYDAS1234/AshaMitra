import 'dart:convert';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../../../core/services/api_service.dart';

/// District operations — facilities, staffing, cold chain, outbreaks, QA,
/// training, meetings and budget.
///
/// Deliberately holds raw maps rather than a model class per section: these are
/// display-only rollups the server has already shaped, and eight more model
/// classes would be ceremony without benefit.
class OperationsController extends GetxController {
  final data = <String, dynamic>{}.obs;
  final loading = false.obs;
  final error = ''.obs;

  // Surveillance is a separate endpoint — it is field data, and it refreshes on a
  // different rhythm to the district's own assets.
  final surveillance = <String, dynamic>{}.obs;
  final loadingSurv = false.obs;

  Map<String, dynamic> section(String k) =>
      Map<String, dynamic>.from((data[k] as Map?) ?? {});

  List<Map<String, dynamic>> listOf(String section, String key) =>
      (((data[section] as Map?)?[key] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

  List<Map<String, dynamic>> get clusters =>
      ((surveillance['clusters'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

  Map<String, dynamic> get survTotals =>
      Map<String, dynamic>.from((surveillance['totals'] as Map?) ?? {});

  /// Everything on this screen that needs a decision today. Drives the badge on
  /// the entry card, so the CMHO knows whether it is worth opening.
  int get urgentCount {
    final staffing = section('staffing');
    final cold = section('coldChain');
    final ob = section('outbreaks');
    final meet = section('meetings');
    return clusters.length +
        ((ob['open'] as List?) ?? []).length +
        ((cold['failures'] as List?) ?? []).length +
        ((cold['silent'] as List?) ?? []).length +
        ((meet['overdueActions'] as num?)?.toInt() ?? 0) +
        (((staffing['vacant'] as num?)?.toInt() ?? 0) > 0 ? 1 : 0);
  }

  Future<void> load() async {
    loading.value = true;
    error.value = '';
    try {
      final r = await _get('/admin/operations');
      if (r['success'] != true) {
        error.value = r['message']?.toString() ?? 'লোড করা যায়নি';
        return;
      }
      data.value = Map<String, dynamic>.from(r['data'] as Map);
    } catch (_) {
      error.value = 'সংযোগ ব্যর্থ। ইন্টারনেট দেখুন।';
    } finally {
      loading.value = false;
    }
  }

  Future<void> loadSurveillance() async {
    loadingSurv.value = true;
    try {
      final r = await _get('/admin/surveillance');
      if (r['success'] == true) {
        surveillance.value = Map<String, dynamic>.from(r['data'] as Map);
      }
    } catch (_) {
      // Non-fatal: the operations screen still works without the cluster panel.
    } finally {
      loadingSurv.value = false;
    }
  }

  Future<void> loadAll() async {
    await Future.wait([load(), loadSurveillance()]);
  }

  Future<Map<String, dynamic>> _get(String path) async {
    final r = await http.get(
      Uri.parse('${ApiService.baseUrl}$path'),
      headers: {
        'Content-Type': 'application/json',
        if (ApiService.token != null)
          'Authorization': 'Bearer ${ApiService.token}',
      },
    ).timeout(const Duration(seconds: 25));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }
}
