import 'dart:convert';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../../../core/services/api_service.dart';

/// One headline number on a programme card.
class ProgStat {
  final String label;
  final num? value;   // null = no denominator. Render "—", never 0.
  final String suffix;
  final bool alarm;

  const ProgStat({required this.label, this.value, this.suffix = '', this.alarm = false});

  factory ProgStat.fromJson(Map<String, dynamic> j) => ProgStat(
        label: j['label']?.toString() ?? '',
        value: j['value'] as num?,
        suffix: j['suffix']?.toString() ?? '',
        alarm: j['alarm'] == true,
      );

  String get display => value == null ? '—' : '$value$suffix';
}

/// A named person a supervisor can actually act on.
class ProgRow {
  final String name;
  final String detail;
  final String village;
  final String block;
  final String mobile;

  const ProgRow({
    required this.name,
    required this.detail,
    required this.village,
    required this.block,
    required this.mobile,
  });

  factory ProgRow.fromJson(Map<String, dynamic> j) => ProgRow(
        name: j['name']?.toString() ?? '—',
        detail: j['detail']?.toString() ?? '',
        village: j['village']?.toString() ?? '',
        block: j['block']?.toString() ?? '',
        mobile: j['mobile']?.toString() ?? '',
      );

  String get where =>
      [village, block].where((s) => s.isNotEmpty).join(' · ');
}

/// A thing that must be done, with the people it must be done to.
class ProgAction {
  final String title;
  final String severity; // high | medium | none
  final List<ProgRow> rows;

  const ProgAction({required this.title, required this.severity, required this.rows});

  factory ProgAction.fromJson(Map<String, dynamic> j) => ProgAction(
        title: j['title']?.toString() ?? '',
        severity: j['severity']?.toString() ?? 'none',
        rows: ((j['rows'] as List?) ?? [])
            .map((e) => ProgRow.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class ProgBlock {
  final String block;
  final int total;
  final int flagged;

  const ProgBlock({required this.block, required this.total, required this.flagged});

  factory ProgBlock.fromJson(Map<String, dynamic> j) => ProgBlock(
        block: j['block']?.toString() ?? 'অজানা',
        total: (j['total'] as num?)?.toInt() ?? 0,
        flagged: (j['flagged'] as num?)?.toInt() ?? 0,
      );
}

class Programme {
  final String key;
  final String name;
  final String icon;
  final List<ProgStat> headline;
  final List<ProgAction> actions;
  final List<ProgBlock> blocks;

  const Programme({
    required this.key,
    required this.name,
    required this.icon,
    required this.headline,
    required this.actions,
    required this.blocks,
  });

  factory Programme.fromJson(Map<String, dynamic> j) => Programme(
        key: j['key']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        icon: j['icon']?.toString() ?? '',
        headline: ((j['headline'] as List?) ?? [])
            .map((e) => ProgStat.fromJson(e as Map<String, dynamic>))
            .toList(),
        actions: ((j['actions'] as List?) ?? [])
            .map((e) => ProgAction.fromJson(e as Map<String, dynamic>))
            .toList(),
        blocks: ((j['blocks'] as List?) ?? [])
            .map((e) => ProgBlock.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// Actions that actually have people in them. An action with no rows is not a
  /// problem to solve — it's a clean bill of health, and showing an empty
  /// "0 people" list as if it were work invites the supervisor to stop reading.
  List<ProgAction> get liveActions => actions.where((a) => a.rows.isNotEmpty).toList();

  int get urgentCount => liveActions
      .where((a) => a.severity == 'high')
      .fold<int>(0, (s, a) => s + a.rows.length);
}

class ProgrammesController extends GetxController {
  final programmes = <Programme>[].obs;
  final loading = false.obs;
  final error = ''.obs;
  final months = 12.obs;

  /// Total people needing action across every programme — the number that goes
  /// on the entry card.
  int get totalUrgent =>
      programmes.fold<int>(0, (s, p) => s + p.urgentCount);

  Future<void> load({int? months}) async {
    if (months != null) this.months.value = months;
    loading.value = true;
    error.value = '';
    try {
      final r = await http.get(
        Uri.parse('${ApiService.baseUrl}/admin/programmes?months=${this.months.value}'),
        headers: {
          'Content-Type': 'application/json',
          if (ApiService.token != null) 'Authorization': 'Bearer ${ApiService.token}',
        },
      ).timeout(const Duration(seconds: 25));
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      if (j['success'] != true) {
        error.value = j['message']?.toString() ?? 'লোড করা যায়নি';
        return;
      }
      final d = (j['data'] as Map<String, dynamic>?) ?? {};
      programmes.value = ((d['programmes'] as List?) ?? [])
          .map((e) => Programme.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      error.value = 'সংযোগ ব্যর্থ। ইন্টারনেট দেখুন।';
    } finally {
      loading.value = false;
    }
  }
}
