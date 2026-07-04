import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../app/routes.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/local_storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/components/app_header.dart';
import '../../../../shared/components/bottom_nav.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../patients/controller/patient_controller.dart';
import '../../../patients/data/models/patient_model.dart';
import '../../../patients/services/mcp_report_pdf.dart';
import '../../services/checkup_log_pdf.dart';

/// The "Reports" tab, repurposed as a **checkup log** — every completed checkup
/// (ANC / PNC / vaccine / HBNC / HBYC) across all patients, newest first, with a
/// danger-flag band. (Triage isn't used, so the old triage-report view is
/// replaced by this activity feed. Official register exports live in Registers.)
class CheckupLogScreen extends StatefulWidget {
  const CheckupLogScreen({super.key});
  @override
  State<CheckupLogScreen> createState() => _CheckupLogScreenState();
}

class _CheckupLogScreenState extends State<CheckupLogScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _done = const [];
  String _kind = 'all';   // all | anc | vaccine | hbnc | hbyc | pnc
  String _time = 'all';   // all | today | week | month
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    List<dynamic> raw;
    try {
      raw = await ApiService.getAllSchedule();
    } catch (_) {
      raw = const [];
    }
    final done = raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((e) => (e['status'] ?? '') == 'done')
        .toList()
      ..sort((a, b) => _completedAt(b).compareTo(_completedAt(a))); // newest first
    if (!mounted) return;
    setState(() {
      _done = done;
      _loading = false;
    });
  }

  String _completedAt(Map<String, dynamic> e) {
    final rec = e['record'] is Map ? (e['record'] as Map) : const {};
    return (rec['completedAt'] ?? e['doneDate'] ?? e['dueDate'] ?? '').toString();
  }

  DateTime? _completedDate(Map<String, dynamic> e) =>
      DateTime.tryParse(_completedAt(e));

  List<String> _flags(Map<String, dynamic> e) {
    final rec = e['record'] is Map ? (e['record'] as Map) : const {};
    final out = <String>[];
    void add(dynamic v) {
      if (v is List) out.addAll(v.map((x) => x.toString()).where((s) => s.isNotEmpty));
    }
    add(rec['dangerFlags']);
    add(rec['tbSymptoms']);
    add(rec['pncFlags']);
    if (rec['motherPnc'] is Map) add((rec['motherPnc'] as Map)['dangerFlags']);
    return out;
  }

  String _summary(Map<String, dynamic> e) {
    final rec = e['record'] is Map ? (e['record'] as Map) : const {};
    final kind = (e['kind'] ?? '').toString();
    String r(String k) => (rec[k] ?? '').toString().trim();
    if (kind == 'anc') {
      final bits = <String>[
        if (r('bp').isNotEmpty) 'BP ${r('bp')}',
        if (r('hb').isNotEmpty) 'Hb ${r('hb')}',
        if (r('weight').isNotEmpty) '${'clog_summary_weight'.tr} ${r('weight')}',
      ];
      return bits.join(' · ');
    }
    if (kind == 'vaccine') {
      final g = (rec['givenVaccines'] as List?)?.length ?? 0;
      return g > 0 ? 'clog_summary_vaccines'.trParams({'count': '$g'}) : '';
    }
    if (kind == 'hbyc') {
      final ms = r('muacStatus');
      final w = r('weight');
      return [
        if (w.isNotEmpty) '${'clog_summary_weight'.tr} $w',
        if (ms.isNotEmpty) 'MUAC: $ms',
      ].join(' · ');
    }
    if (kind == 'hbnc') {
      final bw = r('babyWeight');
      return bw.isNotEmpty ? '${'clog_summary_baby_weight'.tr} $bw' : '';
    }
    if (kind == 'pnc') {
      final bp = r('bp');
      return bp.isNotEmpty ? 'BP $bp' : '';
    }
    return '';
  }

  static IconData _icon(String k) => switch (k) {
        'vaccine' => Icons.vaccines_rounded,
        'anc' => Icons.pregnant_woman_rounded,
        'pnc' => Icons.volunteer_activism_rounded,
        'hbnc' => Icons.child_care_rounded,
        'hbyc' => Icons.child_friendly_rounded,
        _ => Icons.event_note_rounded,
      };

  static String _kindLabel(String k) => switch (k) {
        'anc' => 'clog_kind_anc'.tr,
        'vaccine' => 'clog_kind_vaccine'.tr,
        'hbnc' => 'clog_kind_hbnc'.tr,
        'hbyc' => 'clog_kind_hbyc'.tr,
        'pnc' => 'clog_kind_pnc'.tr,
        _ => k,
      };

  String _fmtDate(DateTime? d) {
    if (d == null) return '';
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(d.day)}/${p(d.month)}/${d.year}';
  }

  // ── PDF + navigation ──────────────────────────────────────────────────────
  PatientController get _pc => Get.isRegistered<PatientController>()
      ? Get.find<PatientController>()
      : Get.put(PatientController(), permanent: true);

  PatientModel? _patientFor(Map<String, dynamic> e) {
    final pid = (e['patientId'] ?? '').toString();
    if (pid.isEmpty) return null;
    final i = _pc.patients.indexWhere((p) => p.id == pid);
    return i == -1 ? null : _pc.patients[i];
  }

  Map<String, String> _header() {
    final u = LocalStorageService.loadUser() ?? const {};
    String s(List<String> keys) {
      for (final k in keys) {
        final v = (u[k] ?? '').toString().trim();
        if (v.isNotEmpty) return v;
      }
      return '';
    }
    return {
      'asha': s(['name', 'fullName']),
      'block': s(['block']),
      'district': s(['district']),
      'facility': s(['subCentre', 'subcentre', 'facilityName', 'facility']),
    };
  }

  void _openProfile(Map<String, dynamic> e) {
    final p = _patientFor(e);
    if (p == null) {
      Get.snackbar('clog_title'.tr, 'prof_patient_not_found'.tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.warningYellow, colorText: Colors.white,
          margin: const EdgeInsets.all(16), borderRadius: 12);
      return;
    }
    Get.toNamed(AppRoutes.patientProfile, arguments: p.toJson());
  }

  Future<void> _downloadOne(Map<String, dynamic> e) async {
    final p = _patientFor(e);
    if (p == null) {
      Get.snackbar('clog_title'.tr, 'prof_patient_not_found'.tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.warningYellow, colorText: Colors.white,
          margin: const EdgeInsets.all(16), borderRadius: 12);
      return;
    }
    try {
      await McpReportPdf.generateForEvent(p, e, header: _header());
    } catch (_) {
      Get.snackbar('clog_title'.tr, 'prof_report_failed'.tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.emergencyRed, colorText: Colors.white,
          margin: const EdgeInsets.all(16), borderRadius: 12);
    }
  }

  Future<void> _downloadAll(List<Map<String, dynamic>> visible) async {
    if (visible.isEmpty) {
      Get.snackbar('clog_title'.tr, 'clog_no_match'.tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.warningYellow, colorText: Colors.white,
          margin: const EdgeInsets.all(16), borderRadius: 12);
      return;
    }
    final rows = visible.map((e) {
      final flags = _flags(e);
      return [
        _fmtDate(_completedDate(e)),
        (e['patientName'] ?? '').toString(),
        _kindLabel((e['kind'] ?? '').toString()),
        (e['label'] ?? '').toString(),
        flags.isEmpty
            ? 'clog_band_ok'.tr
            : 'clog_band_danger'.trParams({'count': '${flags.length}'}),
        _summary(e),
      ];
    }).toList();
    final now = DateTime.now();
    final month = _done.where((e) {
      final d = _completedDate(e);
      return d != null && d.year == now.year && d.month == now.month;
    }).length;
    final danger = _done.where((e) => _flags(e).isNotEmpty).length;
    try {
      await CheckupLogPdf.generate(
        rows: rows,
        stats: {'total': '${visible.length}', 'month': '$month', 'danger': '$danger'},
        header: _header(),
      );
    } catch (_) {
      Get.snackbar('clog_title'.tr, 'prof_report_failed'.tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.emergencyRed, colorText: Colors.white,
          margin: const EdgeInsets.all(16), borderRadius: 12);
    }
  }

  bool _matches(Map<String, dynamic> e) {
    if (_kind != 'all' && (e['kind'] ?? '') != _kind) return false;
    if (_query.isNotEmpty) {
      final hay = '${e['patientName'] ?? ''} ${e['label'] ?? ''}'.toLowerCase();
      if (!hay.contains(_query)) return false;
    }
    if (_time != 'all') {
      final d = _completedDate(e);
      if (d == null) return false;
      final now = DateTime.now();
      switch (_time) {
        case 'today':
          if (!(d.year == now.year && d.month == now.month && d.day == now.day)) {
            return false;
          }
          break;
        case 'week':
          if (now.difference(d).inDays >= 7) return false;
          break;
        case 'month':
          if (!(d.year == now.year && d.month == now.month)) return false;
          break;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final visible = _done.where(_matches).toList();
    final monthCount = _done.where((e) {
      final d = _completedDate(e);
      final now = DateTime.now();
      return d != null && d.year == now.year && d.month == now.month;
    }).length;
    final dangerCount = _done.where((e) => _flags(e).isNotEmpty).length;

    return Scaffold(
      bottomNavigationBar: const BottomNav(currentIndex: 3),
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppHeader(
                title: 'clog_title'.tr,
                subtitle: 'clog_subtitle'.tr,
                showBack: false,
                actions: [
                  HeaderActionCircle(
                    icon: Icons.refresh_rounded,
                    tooltip: 'clog_refresh'.tr,
                    onTap: _load,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Gradient hero — the report summary at a glance + a PDF CTA.
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: _heroBanner(
                  total: _done.length,
                  month: monthCount,
                  danger: dangerCount,
                  visible: visible,
                ),
              ),
              const SizedBox(height: 14),
              // Search
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v.toLowerCase().trim()),
                  decoration: InputDecoration(
                    hintText: 'clog_search_hint'.tr,
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: AppColors.primary, size: 22),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Kind chips
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _chip('clog_kind_all'.tr, 'all', _kind, (v) => setState(() => _kind = v)),
                    _chip('clog_kind_anc'.tr, 'anc', _kind, (v) => setState(() => _kind = v)),
                    _chip('clog_kind_vaccine'.tr, 'vaccine', _kind, (v) => setState(() => _kind = v)),
                    _chip('clog_kind_hbnc'.tr, 'hbnc', _kind, (v) => setState(() => _kind = v)),
                    _chip('clog_kind_hbyc'.tr, 'hbyc', _kind, (v) => setState(() => _kind = v)),
                    _chip('clog_kind_pnc'.tr, 'pnc', _kind, (v) => setState(() => _kind = v)),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              // Time chips
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _chip('filter_all_time'.tr, 'all', _time, (v) => setState(() => _time = v)),
                    _chip('filter_today'.tr, 'today', _time, (v) => setState(() => _time = v)),
                    _chip('filter_week'.tr, 'week', _time, (v) => setState(() => _time = v)),
                    _chip('filter_month'.tr, 'month', _time, (v) => setState(() => _time = v)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (!_loading && visible.isNotEmpty) _listHeader(visible.length),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : (_done.isEmpty
                        ? EmptyState(
                            icon: Icons.fact_check_outlined,
                            title: 'clog_empty_title'.tr,
                            subtitle: 'clog_empty_subtitle'.tr,
                          )
                        : (visible.isEmpty
                            ? EmptyState(
                                icon: Icons.filter_alt_off_rounded,
                                title: 'clog_no_match'.tr,
                                subtitle: 'clog_no_match_sub'.tr,
                              )
                            : RefreshIndicator(
                                onRefresh: _load,
                                child: ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                                  itemCount: visible.length,
                                  itemBuilder: (_, i) => _card(visible[i]),
                                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                                ),
                              ))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, String value, String current, ValueChanged<String> onTap) {
    final sel = current == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Center(
        child: ChoiceChip(
          label: Text(label),
          selected: sel,
          selectedColor: AppColors.primary,
          labelStyle: AppTextStyles.label.copyWith(
              color: sel ? AppColors.onPrimary : AppColors.textSecondary),
          onSelected: (_) => onTap(value),
        ),
      ),
    );
  }

  // ── Gradient hero summary (home-style) ────────────────────────────────────
  Widget _heroBanner({
    required int total,
    required int month,
    required int danger,
    required List<Map<String, dynamic>> visible,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDeep, AppColors.primary, AppColors.purple],
          stops: [0.0, 0.5, 1.0],
        ),
        boxShadow: AppShadows.tinted(AppColors.primary, strength: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('clog_subtitle'.tr,
                      style: AppTextStyles.caption.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                ),
                const Spacer(),
                Icon(Icons.insights_rounded,
                    color: Colors.white.withValues(alpha: 0.85), size: 22),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                    child: _heroStat('$total', 'clog_stat_total'.tr,
                        emphasize: true)),
                const SizedBox(width: 10),
                Expanded(child: _heroStat('$month', 'clog_stat_month'.tr)),
                const SizedBox(width: 10),
                Expanded(
                    child: _heroStat('$danger', 'clog_stat_danger'.tr,
                        danger: danger > 0)),
              ],
            ),
            const SizedBox(height: 16),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _downloadAll(visible),
                child: SizedBox(
                  height: 46,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.download_rounded,
                          color: AppColors.primary, size: 19),
                      const SizedBox(width: 8),
                      Text('clog_pdf_all'.tr,
                          style: AppTextStyles.label.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroStat(String value, String label,
      {bool emphasize = false, bool danger = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: emphasize ? 0.24 : 0.13),
        borderRadius: BorderRadius.circular(16),
        border: danger
            ? Border.all(color: Colors.white.withValues(alpha: 0.55), width: 1)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (danger) ...[
                const Icon(Icons.warning_amber_rounded,
                    color: Colors.white, size: 15),
                const SizedBox(width: 3),
              ],
              Text(value,
                  style: AppTextStyles.h2.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      height: 1.0)),
            ],
          ),
          const SizedBox(height: 3),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption
                  .copyWith(color: Colors.white.withValues(alpha: 0.85))),
        ],
      ),
    );
  }

  /// Section header with the home-style gradient accent bar.
  Widget _listHeader(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.accent],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text('clog_recent'.tr,
              style: AppTextStyles.label.copyWith(
                  color: AppColors.onBackground,
                  fontWeight: FontWeight.w800,
                  fontSize: 14)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('$count',
                style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _card(Map<String, dynamic> e) {
    final kind = (e['kind'] ?? '').toString();
    final flags = _flags(e);
    final ok = flags.isEmpty;
    final color = ok ? AppColors.safeGreen : AppColors.emergencyRed;
    final date = _fmtDate(_completedDate(e));
    final summary = _summary(e);
    final name = (e['patientName'] ?? '').toString();
    return Material(
      color: ok ? AppColors.surface : const Color(0xFFFEF2F2),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openProfile(e), // tap → patient profile
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: AppShadows.low,
            border: ok
                ? null
                : Border.all(color: AppColors.emergencyRed, width: 1.0),
            // Coloured status rail on the left edge.
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0)],
              stops: const [0.014, 0.014],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 46, height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle),
                  child: Icon(_icon(kind), size: 22, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(name,
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.h3),
                          ),
                          if (date.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text(date,
                                style: AppTextStyles.caption
                                    .copyWith(color: AppColors.textSecondary)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${_kindLabel(kind)} · ${(e['label'] ?? '').toString()}',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySm
                            .copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(
                                  ok
                                      ? Icons.check_circle_rounded
                                      : Icons.warning_amber_rounded,
                                  size: 13, color: color),
                              const SizedBox(width: 4),
                              Text(
                                ok
                                    ? 'clog_band_ok'.tr
                                    : 'clog_band_danger'
                                        .trParams({'count': '${flags.length}'}),
                                style: AppTextStyles.caption.copyWith(
                                    color: color, fontWeight: FontWeight.w700),
                              ),
                            ]),
                          ),
                          if (summary.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(summary,
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.caption.copyWith(
                                      color: AppColors.textSecondary)),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Per-checkup report PDF
                IconButton(
                  tooltip: 'clog_pdf_one'.tr,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _downloadOne(e),
                  icon: const Icon(Icons.download_rounded,
                      size: 20, color: AppColors.primary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

