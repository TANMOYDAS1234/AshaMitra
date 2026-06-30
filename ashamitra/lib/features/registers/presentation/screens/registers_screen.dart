import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/services/local_storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/components/app_header.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../patients/controller/patient_controller.dart';
import '../../../medicine_stock/controller/medicine_stock_controller.dart';
import '../../../medicine_stock/services/medicine_stock_pdf.dart';
import '../../services/due_register_service.dart';

/// P0 — Register / report auto-generator. Turns the schedule the app already
/// computes (ANC / immunization / HBNC / HBYC due items) into the official
/// NHM monthly "due-list" register as a shareable PDF or CSV — killing the
/// "double-double" hand-copying. 100% client-side + offline (cached due list).
class RegistersScreen extends StatefulWidget {
  const RegistersScreen({super.key});

  @override
  State<RegistersScreen> createState() => _RegistersScreenState();
}

class _RegistersScreenState extends State<RegistersScreen> {
  late final PatientController _ctrl;
  bool _loading = true;
  bool _busy = false;
  bool _fromCache = false;
  List<Map<String, dynamic>> _events = [];
  int _horizon = 45;
  final Set<String> _kinds = {...DueRegisterService.kindsAll};
  // 'due'  = monthly work-plan (what's pending) · 'full' = the cumulative
  // notebook substitute (Maternal / Immunization / Diary, full history) ·
  // 'medicine' = the monthly medicine account (Form 2).
  String _mode = 'due';
  final Set<String> _registers = {...DueRegisterService.kindsFull};

  late final MedicineStockController _ms;
  String _msMonth = '';

  @override
  void initState() {
    super.initState();
    _ctrl = Get.isRegistered<PatientController>()
        ? Get.find<PatientController>()
        : Get.put(PatientController(), permanent: true);
    _ms = Get.isRegistered<MedicineStockController>()
        ? Get.find<MedicineStockController>()
        : Get.put(MedicineStockController(), permanent: true);
    _msMonth = _ymNow();
    // Refresh once the medicine stock syncs so the month chips appear.
    _ms.syncFromServer().then((_) {
      if (mounted) setState(() {});
    });
    _load();
  }

  static String _ymNow() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}';
  }

  String _ymLabel(String ym) {
    final parts = ym.split('-');
    if (parts.length != 2) return ym;
    final m = int.tryParse(parts[1]) ?? 0;
    final name = (m >= 1 && m <= 12) ? _bnMonths[m - 1] : parts[1];
    return '$name ${parts[0]}';
  }

  /// Months that have medicine entries, plus the current month, newest first.
  List<String> _msMonths() {
    final s = {_ymNow(), ..._ms.months}.toList()..sort((a, b) => b.compareTo(a));
    return s;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await DueRegisterService.fetchDue(withinDays: _horizon);
    if (!mounted) return;
    setState(() {
      _events = r.events;
      _fromCache = r.fromCache;
      _loading = false;
    });
  }

  int _countFor(String kind) =>
      _events.where((e) => (e['kind']?.toString() ?? '') == kind).length;

  int get _selectedCount =>
      _events.where((e) => _kinds.contains(e['kind']?.toString() ?? '')).length;

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

  static const _bnMonths = [
    'জানুয়ারি', 'ফেব্রুয়ারি', 'মার্চ', 'এপ্রিল', 'মে', 'জুন',
    'জুলাই', 'আগস্ট', 'সেপ্টেম্বর', 'অক্টোবর', 'নভেম্বর', 'ডিসেম্বর',
  ];
  String _monthLabel() {
    final n = DateTime.now();
    return '${_bnMonths[n.month - 1]} ${n.year}';
  }

  /// Count of beneficiaries for a full-register type (from the local patient
  /// list — no events needed).
  int _fullCountFor(String reg) {
    final ps = _ctrl.patients;
    return switch (reg) {
      'maternal' => ps.where((p) => p.type == 'Pregnancy' || p.lmp != null).length,
      'immunization' =>
        ps.where((p) => (p.type == 'Newborn' || p.type == 'Child') && p.dob != null).length,
      'diary' => ps.length,
      _ => 0,
    };
  }

  Future<void> _generate({required bool csv}) async {
    if (_mode == 'due' && _kinds.isEmpty) {
      _snack('reg_snack_select_kind'.tr, AppColors.warningYellow);
      return;
    }
    if (_mode == 'full' && _registers.isEmpty) {
      _snack('reg_snack_select_register'.tr, AppColors.warningYellow);
      return;
    }
    // Medicine account (Form 2) has its own landscape PDF — handle separately.
    if (_mode == 'medicine') {
      setState(() => _busy = true);
      try {
        await _ms.syncFromServer();
        final rows = _ms.forMonth(_msMonth);
        if (rows.isEmpty) {
          _snack('reg_medicine_no_data'.tr, AppColors.warningYellow);
          return;
        }
        await MedicineStockPdf.generate(
          month: _ymLabel(_msMonth), rows: rows, header: _header());
      } catch (e) {
        _snack('reg_snack_failed'.trParams({'error': '$e'}), AppColors.emergencyRed);
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }
    setState(() => _busy = true);
    try {
      final Map<String, dynamic> data;
      if (_mode == 'due') {
        final r = await DueRegisterService.fetchDue(withinDays: _horizon);
        if (mounted) {
          setState(() {
            _events = r.events;
            _fromCache = r.fromCache;
          });
        }
        data = DueRegisterService.assemble(
          events: r.events,
          patients: _ctrl.patients.toList(),
          kinds: _kinds.toList(),
          monthLabel: _monthLabel(),
          withinDays: _horizon,
          header: _header(),
        );
      } else {
        final r = await DueRegisterService.fetchAll();
        if (mounted) setState(() => _fromCache = r.fromCache);
        data = DueRegisterService.assembleFull(
          events: r.events,
          patients: _ctrl.patients.toList(),
          registers: _registers.toList(),
          header: _header(),
        );
      }
      if (csv) {
        await DueRegisterService.generateCsv(data);
      } else {
        await DueRegisterService.generatePdf(data);
      }
    } catch (e) {
      _snack('reg_snack_failed'.trParams({'error': '$e'}), AppColors.emergencyRed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg, Color c) => Get.snackbar('reg_snack_title'.tr, msg,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: c,
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
      borderRadius: 12);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          child: Column(
            children: [
              AppHeader(title: 'reg_header_title'.tr),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                        children: [
                          _intro(),
                          const SizedBox(height: 16),
                          _modeToggle(),
                          const SizedBox(height: 18),
                          ...switch (_mode) {
                            'due' => _dueControls(),
                            'full' => _fullControls(),
                            _ => _medicineControls(),
                          },
                          const SizedBox(height: 18),
                          _summary(),
                          if (_fromCache) ...[
                            const SizedBox(height: 10),
                            _cacheNote(),
                          ],
                          const SizedBox(height: 24),
                          AppButton(
                            label: 'reg_btn_pdf'.tr,
                            onPressed: _busy ? null : () => _generate(csv: false),
                            isLoading: _busy,
                            width: double.infinity,
                          ),
                          // Medicine account is PDF-only (the official Form-2 layout).
                          if (_mode != 'medicine') ...[
                            const SizedBox(height: 10),
                            AppButton(
                              label: 'reg_btn_csv'.tr,
                              onPressed: _busy ? null : () => _generate(csv: true),
                              outlined: true,
                              width: double.infinity,
                            ),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _intro() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_stories_rounded, color: AppColors.primary, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'reg_intro'.tr,
                style: AppTextStyles.label.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );

  Widget _sectionLabel(String t) =>
      Text(t, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700));

  // Segmented control: monthly due-list (work-plan) vs the full cumulative
  // register (the notebook substitute).
  Widget _modeToggle() {
    final opts = [
      ('due', 'reg_mode_due'.tr),
      ('full', 'reg_mode_full'.tr),
      ('medicine', 'reg_mode_medicine'.tr),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: opts.map((o) {
          final sel = _mode == o.$1;
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(11),
              onTap: () => setState(() => _mode = o.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: sel ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(o.$2,
                    style: AppTextStyles.label.copyWith(
                        color: sel ? AppColors.onPrimary : AppColors.textSecondary,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  List<Widget> _dueControls() => [
        _sectionLabel('reg_section_horizon'.tr),
        const SizedBox(height: 8),
        _horizonChips(),
        const SizedBox(height: 18),
        _sectionLabel('reg_section_which_list'.tr),
        const SizedBox(height: 8),
        _kindChips(),
      ];

  List<Widget> _fullControls() => [
        _sectionLabel('reg_section_which_register'.tr),
        const SizedBox(height: 8),
        _registerChips(),
      ];

  List<Widget> _medicineControls() => [
        _sectionLabel('reg_section_which_month'.tr),
        const SizedBox(height: 8),
        _monthChips(),
      ];

  Widget _monthChips() {
    final months = _msMonths();
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: months.map((m) {
        final sel = _msMonth == m;
        final c = _ms.forMonth(m).length;
        return ChoiceChip(
          label: Text('${_ymLabel(m)} ($c)'),
          selected: sel,
          selectedColor: AppColors.primary,
          labelStyle: AppTextStyles.label.copyWith(
              color: sel ? AppColors.onPrimary : AppColors.textSecondary),
          onSelected: (_) => setState(() => _msMonth = m),
        );
      }).toList(),
    );
  }

  Widget _registerChips() {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: DueRegisterService.kindsFull.map((k) {
        final sel = _registers.contains(k);
        final c = _fullCountFor(k);
        return FilterChip(
          label: Text('${DueRegisterService.fullLabel(k)} ($c)'),
          selected: sel,
          showCheckmark: true,
          checkmarkColor: AppColors.onPrimary,
          selectedColor: AppColors.primary,
          backgroundColor: AppColors.surface,
          labelStyle: AppTextStyles.label.copyWith(
              color: sel ? AppColors.onPrimary : AppColors.textSecondary),
          onSelected: (v) => setState(() {
            if (v) {
              _registers.add(k);
            } else {
              _registers.remove(k);
            }
          }),
        );
      }).toList(),
    );
  }

  Widget _horizonChips() {
    final opts = [
      (30, 'reg_horizon_30'.tr),
      (45, 'reg_horizon_45'.tr),
      (60, 'reg_horizon_60'.tr),
      (90, 'reg_horizon_90'.tr),
    ];
    return Wrap(
      spacing: 10,
      children: opts.map((o) {
        final sel = _horizon == o.$1;
        return ChoiceChip(
          label: Text(o.$2),
          selected: sel,
          selectedColor: AppColors.primary,
          labelStyle: AppTextStyles.label.copyWith(
              color: sel ? AppColors.onPrimary : AppColors.textSecondary),
          onSelected: (_) {
            setState(() => _horizon = o.$1);
            _load();
          },
        );
      }).toList(),
    );
  }

  Widget _kindChips() {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: DueRegisterService.kindsAll.map((k) {
        final sel = _kinds.contains(k);
        final c = _countFor(k);
        return FilterChip(
          label: Text('${DueRegisterService.kindLabel(k)} ($c)'),
          selected: sel,
          showCheckmark: true,
          checkmarkColor: AppColors.onPrimary,
          selectedColor: AppColors.primary,
          backgroundColor: AppColors.surface,
          labelStyle: AppTextStyles.label.copyWith(
              color: sel ? AppColors.onPrimary : AppColors.textSecondary),
          onSelected: (v) => setState(() {
            if (v) {
              _kinds.add(k);
            } else {
              _kinds.remove(k);
            }
          }),
        );
      }).toList(),
    );
  }

  String _summaryText() {
    if (_mode == 'due') {
      return _selectedCount == 0
          ? 'reg_summary_due_empty'.tr
          : 'reg_summary_due_count'.trParams({'count': '$_selectedCount'});
    }
    if (_mode == 'medicine') {
      final c = _ms.forMonth(_msMonth).length;
      return 'reg_summary_medicine'
          .trParams({'month': _ymLabel(_msMonth), 'count': '$c'});
    }
    final parts = DueRegisterService.kindsFull
        .where(_registers.contains)
        .map((r) => '${DueRegisterService.fullLabel(r)}: ${_fullCountFor(r)}')
        .toList();
    return parts.isEmpty ? 'reg_summary_full_empty'.tr : parts.join('  ·  ');
  }

  Widget _summary() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.list_alt_rounded, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(_summaryText(), style: AppTextStyles.body),
          ),
        ],
      ),
    );
  }

  Widget _cacheNote() => Row(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 16, color: AppColors.warningYellow),
          const SizedBox(width: 6),
          Expanded(
            child: Text('reg_cache_note'.tr,
                style: AppTextStyles.label.copyWith(color: AppColors.warningYellow)),
          ),
        ],
      );
}
