import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/local_storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/components/app_header.dart';
import '../../../../app/routes.dart';

/// Worker's due / overdue shortlist — the "easily shortlist due-vaccination
/// patients" view. Consumes GET /api/schedule/due, which returns pending
/// ANC / immunization / HBNC events due within a horizon (overdue included),
/// soonest first. The worker can filter by kind and mark an item done with
/// one tap (PATCH /api/schedule/:id).
class DueListScreen extends StatefulWidget {
  const DueListScreen({super.key});

  @override
  State<DueListScreen> createState() => _DueListScreenState();
}

class _DueListScreenState extends State<DueListScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _events = []; // master list (all fetched)
  String _kind = 'all';     // all | vaccine | anc | hbnc | hbyc
  String _sort = 'due';     // due (soonest first) | name
  bool _overdueOnly = false;
  bool _notRemindedOnly = false;
  final _searchCtrl = TextEditingController();
  String _query = '';

  // Look-ahead horizon (days). 30 covers "the next month" of due items.
  static const _horizonDays = 30;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // Fetch ALL due/overdue items once; filtering + sorting happen client-side
  // (instant, no re-fetch on every chip tap).
  Future<void> _load() async {
    setState(() => _loading = true);
    final raw = await ApiService.getScheduleDue(withinDays: _horizonDays);
    if (!mounted) return;
    setState(() {
      _events = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      _loading = false;
    });
  }

  // ── Client-side filter + sort ────────────────────────────────────────────
  bool _isReminded(Map<String, dynamic> e) =>
      (e['lastRemindedAt']?.toString() ?? '').isNotEmpty;

  List<Map<String, dynamic>> _apply(List<Map<String, dynamic>> src) {
    final q = _query.trim().toLowerCase();
    final list = src.where((e) {
      if (_kind != 'all' && (e['kind']?.toString() ?? '') != _kind) return false;
      if (_overdueOnly && e['overdue'] != true) return false;
      if (_notRemindedOnly && _isReminded(e)) return false;
      if (q.isNotEmpty) {
        final hay =
            '${e['patientName'] ?? ''} ${e['label'] ?? ''} ${_vaccinesLine(e)}'
                .toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();
    if (_sort == 'name') {
      list.sort((a, b) => (a['patientName'] ?? '')
          .toString()
          .toLowerCase()
          .compareTo((b['patientName'] ?? '').toString().toLowerCase()));
    } else {
      // 'due' — soonest / most-overdue first (daysUntil ascending).
      list.sort((a, b) => ((a['daysUntil'] as num?)?.toInt() ?? 0)
          .compareTo((b['daysUntil'] as num?)?.toInt() ?? 0));
    }
    return list;
  }

  int _countForKind(String kind) => kind == 'all'
      ? _events.length
      : _events.where((e) => (e['kind']?.toString() ?? '') == kind).length;

  /// Open the unified visit screen to conduct + record the visit. Refresh the
  /// list when it returns done (the event drops off the pending shortlist).
  Future<void> _openVisit(Map<String, dynamic> e) async {
    final result = await Get.toNamed(AppRoutes.visit, arguments: e);
    if (result == true) _load();
  }

  // ── Remind the patient (Call / WhatsApp / SMS) + log it ──────────────────
  String _reminderMsg(Map<String, dynamic> e) {
    final name = (e['patientName'] ?? 'due_patient_fallback'.tr).toString();
    final label = (e['label'] ?? '').toString();
    final due = _dueText(e);
    final kind = (e['kind'] ?? '').toString();
    if (kind == 'anc') {
      return 'due_remind_anc'.trParams({'name': name, 'label': label, 'due': due});
    }
    if (kind == 'vaccine') {
      return 'due_remind_vaccine'.trParams({'name': name, 'label': label, 'due': due});
    }
    return 'due_remind_generic'.trParams({'name': name, 'label': label, 'due': due});
  }

  String? _lastRemindedText(Map<String, dynamic> e) {
    final at = e['lastRemindedAt']?.toString();
    if (at == null || at.isEmpty) return null;
    final dt = DateTime.tryParse(at);
    if (dt == null) return null;
    final days = DateTime.now().difference(dt).inDays;
    final ch = (e['lastReminderChannel'] ?? '').toString();
    final chBn = switch (ch) {
      'call' => 'due_channel_call'.tr,
      'whatsapp' => 'WhatsApp',
      'sms' => 'SMS',
      _ => '',
    };
    final whenBn = days <= 0 ? 'due_today'.tr : 'due_days_ago'.trParams({'days': '$days'});
    return 'due_reminded'.trParams({'channel': chBn, 'when': whenBn});
  }

  Future<void> _remind(Map<String, dynamic> e) async {
    final mobile = (e['patientMobile'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
    if (mobile.isEmpty) {
      Get.snackbar('due_no_number_title'.tr, 'due_no_number_msg'.tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.warningYellow, colorText: Colors.white,
          margin: const EdgeInsets.all(16), borderRadius: 12);
      return;
    }
    final channel = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.call, color: AppColors.safeGreen),
              title: Text('due_call'.tr),
              subtitle: Text(mobile),
              onTap: () => Navigator.pop(context, 'call'),
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble, color: Color(0xFF25D366)),
              title: const Text('WhatsApp'),
              onTap: () => Navigator.pop(context, 'whatsapp'),
            ),
            ListTile(
              leading: const Icon(Icons.sms_outlined, color: AppColors.primary),
              title: const Text('SMS'),
              onTap: () => Navigator.pop(context, 'sms'),
            ),
          ],
        ),
      ),
    );
    if (channel == null) return;
    final msg = _reminderMsg(e);
    final wa = mobile.length == 10 ? '91$mobile' : mobile;
    final uri = switch (channel) {
      'whatsapp' => Uri.parse('https://wa.me/$wa?text=${Uri.encodeComponent(msg)}'),
      'sms' => Uri.parse('sms:$mobile?body=${Uri.encodeComponent(msg)}'),
      _ => Uri.parse('tel:$mobile'),
    };
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      Get.snackbar('due_open_failed_title'.tr, 'due_open_failed_msg'.tr,
          snackPosition: SnackPosition.BOTTOM);
    }
    final updated = await ApiService.logReminder(e['id'].toString(), channel);
    if (!mounted || updated == null) return;
    setState(() {
      final i = _events.indexWhere((x) => x['id'] == e['id']);
      if (i != -1) {
        _events[i]['lastRemindedAt'] = updated['lastRemindedAt'];
        _events[i]['lastReminderChannel'] = updated['lastReminderChannel'];
      }
    });
  }

  Widget _remindBar(Map<String, dynamic> e) {
    final last = _lastRemindedText(e);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => _remind(e),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.notifications_active_outlined,
                    size: 15, color: AppColors.primary),
                const SizedBox(width: 6),
                Text('due_remind'.tr,
                    style: AppTextStyles.label.copyWith(
                        color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
        if (last != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.check_circle, size: 12, color: AppColors.safeGreen),
              const SizedBox(width: 4),
              Text(last,
                  style: AppTextStyles.label
                      .copyWith(color: AppColors.safeGreen, fontSize: 11)),
            ],
          ),
        ],
      ],
    );
  }

  // ── Display helpers ───────────────────────────────────────────────────────
  String _dueText(Map<String, dynamic> e) {
    final overdue = e['overdue'] == true;     // clinical window closed
    final inWindow = e['inWindow'] == true;   // due now, still in window
    final d = (e['daysUntil'] as num?)?.toInt() ?? 0;
    final toEnd = (e['daysToWindowEnd'] as num?)?.toInt() ?? d;
    if (overdue) return 'due_overdue_days'.trParams({'days': '${toEnd.abs()}'});
    if (inWindow) {
      return toEnd <= 0
          ? 'due_last_day'.tr
          : 'due_do_now_days_left'.trParams({'days': '$toEnd'});
    }
    if (d == 0) return 'due_from_today'.tr;
    return 'due_days_left'.trParams({'days': '$d'});
  }

  IconData _kindIcon(String kind) => switch (kind) {
        'vaccine' => Icons.vaccines_rounded,
        'anc'     => Icons.pregnant_woman_rounded,
        'pnc'     => Icons.volunteer_activism_rounded,
        'hbnc'    => Icons.child_care_rounded,
        'hbyc'    => Icons.child_friendly_rounded,
        _         => Icons.event_note_rounded,
      };

  String _vaccinesLine(Map<String, dynamic> e) {
    final meta = e['meta'];
    if (meta is Map && meta['vaccines'] is List) {
      return (meta['vaccines'] as List).join(', ');
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final visible = _loading ? <Map<String, dynamic>>[] : _apply(_events);
    final overdue = visible.where((e) => e['overdue'] == true).toList();
    final dueSoon = visible.where((e) => e['overdue'] != true).toList();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          child: Column(
            children: [
              AppHeader(title: 'due_screen_title'.tr),
              const SizedBox(height: 8),
              _searchField(),
              const SizedBox(height: 8),
              _filterBar(),
              const SizedBox(height: 6),
              _controlsBar(),
              const SizedBox(height: 4),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: visible.isEmpty
                            ? _emptyState()
                            : ListView(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                                children: [
                                  if (overdue.isNotEmpty) ...[
                                    _sectionHeader('due_section_overdue'.tr, overdue.length,
                                        AppColors.emergencyRed),
                                    ...overdue.map(_eventTile),
                                    const SizedBox(height: 12),
                                  ],
                                  if (dueSoon.isNotEmpty) ...[
                                    _sectionHeader('due_section_upcoming'.tr, dueSoon.length,
                                        AppColors.warningYellow),
                                    ...dueSoon.map(_eventTile),
                                  ],
                                ],
                              ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _query = v),
        textInputAction: TextInputAction.search,
        style: AppTextStyles.body,
        decoration: InputDecoration(
          isDense: true,
          hintText: 'due_search_hint'.tr,
          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.primary),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _query = '');
                  },
                ),
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _filterBar() {
    final filters = [
      ('all', 'due_filter_all'.tr),
      ('vaccine', 'due_filter_vaccine'.tr),
      ('anc', 'ANC'),
      ('pnc', 'PNC'),
      ('hbnc', 'due_filter_newborn'.tr),
      ('hbyc', 'due_filter_child_care'.tr),
    ];
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: filters.map((f) {
          final sel = _kind == f.$1;
          final c = _countForKind(f.$1);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(c > 0 ? '${f.$2} ($c)' : f.$2),
              selected: sel,
              selectedColor: AppColors.primary,
              labelStyle: AppTextStyles.label.copyWith(
                color: sel ? AppColors.onPrimary : AppColors.textSecondary,
              ),
              onSelected: (_) => setState(() => _kind = f.$1),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Sort menu + workflow quick-toggles (overdue-only, not-yet-reminded).
  Widget _controlsBar() {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          PopupMenuButton<String>(
            initialValue: _sort,
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (_) => [
              PopupMenuItem(value: 'due', child: Text('due_sort_by_date'.tr)),
              PopupMenuItem(value: 'name', child: Text('due_sort_by_name'.tr)),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sort_rounded, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(_sort == 'name' ? 'due_sort_by_name'.tr : 'due_sort_by_date'.tr,
                      style: AppTextStyles.label.copyWith(fontSize: 12)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: Text('due_chip_overdue_only'.tr),
            selected: _overdueOnly,
            showCheckmark: false,
            selectedColor: AppColors.emergencyRed,
            backgroundColor: AppColors.surface,
            labelStyle: AppTextStyles.label.copyWith(
                color: _overdueOnly ? Colors.white : AppColors.textSecondary,
                fontSize: 12),
            onSelected: (v) => setState(() => _overdueOnly = v),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: Text('due_chip_not_reminded'.tr),
            selected: _notRemindedOnly,
            showCheckmark: false,
            selectedColor: AppColors.primary,
            backgroundColor: AppColors.surface,
            labelStyle: AppTextStyles.label.copyWith(
                color: _notRemindedOnly ? Colors.white : AppColors.textSecondary,
                fontSize: 12),
            onSelected: (v) => setState(() => _notRemindedOnly = v),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8, left: 4),
      child: Row(
        children: [
          Container(width: 8, height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text('$title ($count)', style: AppTextStyles.h3.copyWith(color: color)),
        ],
      ),
    );
  }

  Widget _eventTile(Map<String, dynamic> e) {
    final overdue = e['overdue'] == true;
    final inWindow = e['inWindow'] == true;
    final color = overdue
        ? AppColors.emergencyRed
        : (inWindow ? AppColors.primary : AppColors.warningYellow);
    final kind = e['kind']?.toString() ?? '';
    final mobile = e['patientMobile']?.toString() ?? '';
    final vaccines = kind == 'vaccine' ? _vaccinesLine(e) : '';
    // A half-filled visit was saved for this event — show a "খসড়া" chip so the
    // worker knows to reopen and finish it.
    final hasDraft =
        LocalStorageService.loadVisitDraft(e['id']?.toString() ?? '') != null;

    return GestureDetector(
      onTap: () => _openVisit(e),
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_kindIcon(kind), color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e['patientName']?.toString() ?? '—',
                    style: AppTextStyles.body, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(e['label']?.toString() ?? '',
                    style: AppTextStyles.label, maxLines: 2, overflow: TextOverflow.ellipsis),
                if (vaccines.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(vaccines,
                      style: AppTextStyles.label.copyWith(
                          color: AppColors.textSecondary, fontSize: 11),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(_dueText(e),
                        style: AppTextStyles.label.copyWith(
                            color: color, fontWeight: FontWeight.w700, fontSize: 12)),
                    if (hasDraft) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.warningYellow.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.edit_note_rounded,
                                size: 13, color: AppColors.warningYellow),
                            const SizedBox(width: 3),
                            Text('due_draft'.tr,
                                style: AppTextStyles.label.copyWith(
                                    color: AppColors.warningYellow,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ],
                    if (mobile.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      const Icon(Icons.phone_outlined,
                          size: 13, color: AppColors.textSecondary),
                      const SizedBox(width: 3),
                      Text(mobile,
                          style: AppTextStyles.label
                              .copyWith(color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                _remindBar(e),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Tap the card to open the structured checkup form. No value-less
          // one-tap "done" — every completion goes through the form so the
          // visit record (BP/Hb/weight/flags) is always captured.
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.textSecondary, size: 26),
        ],
      ),
    ));
  }

  Widget _emptyState() {
    // Distinguish "nothing due at all" from "filter/search hid everything".
    final filtered = _events.isNotEmpty;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.22),
        Icon(filtered ? Icons.search_off_rounded : Icons.event_available_rounded,
            size: 64,
            color: filtered ? AppColors.textSecondary : AppColors.safeGreen),
        const SizedBox(height: 14),
        Center(
          child: Text(filtered ? 'due_empty_no_match'.tr : 'due_empty_none_title'.tr,
              style: AppTextStyles.h3.copyWith(color: AppColors.textSecondary)),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
              filtered ? 'due_empty_no_match_hint'.tr : 'due_empty_none_hint'.tr,
              style: AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
        ),
      ],
    );
  }
}
