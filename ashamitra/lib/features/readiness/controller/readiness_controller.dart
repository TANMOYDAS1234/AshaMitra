import 'dart:convert';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../../../core/services/api_service.dart';

/// One item on the readiness form.
class ReadinessItem {
  final String code;
  final String label;
  final String cat; // drug | equipment | transport | facility
  final bool critical;

  const ReadinessItem({
    required this.code,
    required this.label,
    required this.cat,
    required this.critical,
  });

  factory ReadinessItem.fromJson(Map<String, dynamic> j) => ReadinessItem(
        code: j['code']?.toString() ?? '',
        label: j['bn']?.toString() ?? '',
        cat: j['cat']?.toString() ?? 'drug',
        critical: j['critical'] == true,
      );
}

/// A person (ASHA / ANM / BMHO) as seen in the supervisor rollup.
class ReadinessUnit {
  final String id;
  final String name;
  final String role;
  final String block;
  final String subCentre;
  final int? daysAgo;

  /// 'fresh' | 'stale' | 'never'. `stale` and `never` are NOT "fine" — they are
  /// unknown, which is its own kind of danger.
  final String state;
  final List<String> criticalOut;
  final List<String> low;

  const ReadinessUnit({
    required this.id,
    required this.name,
    required this.role,
    required this.block,
    required this.subCentre,
    required this.daysAgo,
    required this.state,
    required this.criticalOut,
    required this.low,
  });

  factory ReadinessUnit.fromJson(Map<String, dynamic> j) => ReadinessUnit(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? '—',
        role: j['role']?.toString() ?? '',
        block: j['block']?.toString() ?? '',
        subCentre: j['subCentre']?.toString() ?? '',
        daysAgo: (j['daysAgo'] as num?)?.toInt(),
        state: j['state']?.toString() ?? 'never',
        criticalOut: ((j['criticalOut'] as List?) ?? []).map((e) => e.toString()).toList(),
        low: ((j['low'] as List?) ?? []).map((e) => e.toString()).toList(),
      );
}

class ReadinessBlock {
  final String block;
  final int criticalOut;
  final int low;
  final int reported;
  final int stale;
  final int never;
  final List<ReadinessUnit> units;

  const ReadinessBlock({
    required this.block,
    required this.criticalOut,
    required this.low,
    required this.reported,
    required this.stale,
    required this.never,
    required this.units,
  });

  factory ReadinessBlock.fromJson(Map<String, dynamic> j) => ReadinessBlock(
        block: j['block']?.toString() ?? 'অজানা',
        criticalOut: (j['criticalOut'] as num?)?.toInt() ?? 0,
        low: (j['low'] as num?)?.toInt() ?? 0,
        reported: (j['reported'] as num?)?.toInt() ?? 0,
        stale: (j['stale'] as num?)?.toInt() ?? 0,
        never: (j['never'] as num?)?.toInt() ?? 0,
        units: ((j['units'] as List?) ?? [])
            .map((e) => ReadinessUnit.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// Everything we do NOT currently know about. Treated as risk, not as silence.
  int get unknown => stale + never;
}

class CriticalGap {
  final String code;
  final String label;
  final int count;
  final List<ReadinessUnit> places;

  const CriticalGap({
    required this.code,
    required this.label,
    required this.count,
    required this.places,
  });

  factory CriticalGap.fromJson(Map<String, dynamic> j) => CriticalGap(
        code: j['code']?.toString() ?? '',
        label: j['bn']?.toString() ?? '',
        count: (j['count'] as num?)?.toInt() ?? 0,
        places: ((j['places'] as List?) ?? [])
            .map((e) => ReadinessUnit.fromJson({
                  ...e as Map<String, dynamic>,
                  'state': 'fresh',
                  'criticalOut': const [],
                  'low': const [],
                }))
            .toList(),
      );
}

class ReadinessController extends GetxController {
  // ── The worker's own check-in ──────────────────────────────────────────────
  final items = <ReadinessItem>[].obs;
  final answers = <String, String>{}.obs; // code -> ok|low|out
  final lastSubmittedAt = Rxn<DateTime>();
  final loadingForm = false.obs;
  final submitting = false.obs;

  // ── The supervisor rollup ──────────────────────────────────────────────────
  final critical = <CriticalGap>[].obs;
  final blocks = <ReadinessBlock>[].obs;
  final coverage = <String, int>{}.obs;
  final staleDays = 10.obs;
  final loadingSummary = false.obs;
  final summaryError = ''.obs;

  int get criticalCount =>
      critical.fold<int>(0, (s, c) => s + c.count);

  /// People we have no current answer from. Counted as risk — a sub-centre that
  /// never reports is as dangerous as one reporting a stockout, and easier to miss.
  int get unknownCount => (coverage['stale'] ?? 0) + (coverage['never'] ?? 0);

  Future<void> loadForm() async {
    loadingForm.value = true;
    try {
      final res = await _get('/readiness/catalogue');
      if (res['success'] != true) return;
      items.value = ((res['items'] as List?) ?? [])
          .map((e) => ReadinessItem.fromJson(e as Map<String, dynamic>))
          .toList();
      staleDays.value = (res['staleDays'] as num?)?.toInt() ?? 10;

      // Prefill from the last check-in so a weekly update is a few taps, not a
      // fresh form every time.
      final last = res['last'] as Map<String, dynamic>?;
      answers.clear();
      if (last != null) {
        lastSubmittedAt.value = DateTime.tryParse(last['at']?.toString() ?? '');
        for (final it in ((last['items'] as List?) ?? [])) {
          final m = it as Map<String, dynamic>;
          answers[m['code'].toString()] = m['status'].toString();
        }
      }
      // Anything unanswered starts at 'ok' — but the button stays disabled until
      // the worker has actually looked (see the screen), so this is a default,
      // not an assumption.
      for (final i in items) {
        answers.putIfAbsent(i.code, () => 'ok');
      }
    } finally {
      loadingForm.value = false;
    }
  }

  void setAnswer(String code, String status) => answers[code] = status;

  /// Returns the number of critical items escalated, or -1 on failure.
  Future<int> submit() async {
    submitting.value = true;
    try {
      final payload = items
          .map((i) => {'code': i.code, 'status': answers[i.code] ?? 'ok'})
          .toList();
      final res = await _post('/readiness/report', {'items': payload});
      if (res['success'] != true) return -1;
      lastSubmittedAt.value = DateTime.now();
      return (res['escalated'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return -1;
    } finally {
      submitting.value = false;
    }
  }

  Future<void> loadSummary() async {
    loadingSummary.value = true;
    summaryError.value = '';
    try {
      final res = await _get('/readiness/summary');
      if (res['success'] != true) {
        summaryError.value = res['message']?.toString() ?? 'লোড করা যায়নি';
        return;
      }
      final d = (res['data'] as Map<String, dynamic>?) ?? {};
      staleDays.value = (d['staleDays'] as num?)?.toInt() ?? 10;
      critical.value = ((d['critical'] as List?) ?? [])
          .map((e) => CriticalGap.fromJson(e as Map<String, dynamic>))
          .toList();
      blocks.value = ((d['blocks'] as List?) ?? [])
          .map((e) => ReadinessBlock.fromJson(e as Map<String, dynamic>))
          .toList();
      final c = (d['coverage'] as Map<String, dynamic>?) ?? {};
      coverage.value = {
        'expected': (c['expected'] as num?)?.toInt() ?? 0,
        'reported': (c['reported'] as num?)?.toInt() ?? 0,
        'stale': (c['stale'] as num?)?.toInt() ?? 0,
        'never': (c['never'] as num?)?.toInt() ?? 0,
      };
    } catch (_) {
      summaryError.value = 'সংযোগ ব্যর্থ। ইন্টারনেট দেখুন।';
    } finally {
      loadingSummary.value = false;
    }
  }

  // ── transport ──────────────────────────────────────────────────────────────

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (ApiService.token != null) 'Authorization': 'Bearer ${ApiService.token}',
      };

  Future<Map<String, dynamic>> _get(String path) async {
    final r = await http
        .get(Uri.parse('${ApiService.baseUrl}$path'), headers: _headers)
        .timeout(const Duration(seconds: 20));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final r = await http
        .post(Uri.parse('${ApiService.baseUrl}$path'),
            headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 20));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }
}
