import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/components/app_header.dart';
import '../../../../shared/widgets/app_input.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../eligible_couples/presentation/screens/eligible_couple_screen.dart'
    show DatePickField;
import '../../controller/medicine_stock_controller.dart';
import '../../services/medicine_stock_pdf.dart';

// Standard ASHA drug-kit items (NHM) — offered as quick-add chips so the worker
// doesn't retype common names. Stored value is the Bengali display name itself.
const _drugKit = [
  'ms_drug_ors', 'ms_drug_paracetamol', 'ms_drug_ifa_adult', 'ms_drug_ifa_paed',
  'ms_drug_folic', 'ms_drug_calcium', 'ms_drug_albendazole', 'ms_drug_zinc',
  'ms_drug_ors_zinc', 'ms_drug_cotrimoxazole', 'ms_drug_misoprostol', 'ms_drug_ocp',
  'ms_drug_ecp', 'ms_drug_condom', 'ms_drug_pregtest', 'ms_drug_sanitary',
  'ms_drug_ddk', 'ms_drug_chlorhexidine', 'ms_drug_povidone', 'ms_drug_gauze',
];

const _units = <String, String>{
  'tablet': 'ms_unit_tablet', 'strip': 'ms_unit_strip', 'packet': 'ms_unit_packet',
  'bottle': 'ms_unit_bottle', 'piece': 'ms_unit_piece', 'tube': 'ms_unit_tube',
};

int _i(dynamic v) => (v is num) ? v.toInt() : int.tryParse('$v') ?? 0;
int closingOf(Map d) =>
    _i(d['openingStock']) + _i(d['receivedQty']) - _i(d['issuedQty']) - _i(d['expiredQty']);

String _monthLabel(String ym) {
  // 'YYYY-MM' → 'MMM YYYY' in Bengali month names.
  final parts = ym.split('-');
  if (parts.length != 2) return ym;
  final m = int.tryParse(parts[1]) ?? 0;
  const names = [
    '', 'ms_mon_1', 'ms_mon_2', 'ms_mon_3', 'ms_mon_4', 'ms_mon_5', 'ms_mon_6',
    'ms_mon_7', 'ms_mon_8', 'ms_mon_9', 'ms_mon_10', 'ms_mon_11', 'ms_mon_12'
  ];
  final mn = (m >= 1 && m <= 12) ? names[m].tr : parts[1];
  return '$mn ${parts[0]}';
}

String _thisMonth() {
  final n = DateTime.now();
  return '${n.year}-${n.month.toString().padLeft(2, '0')}';
}

MedicineStockController _msCtrl() => Get.isRegistered<MedicineStockController>()
    ? Get.find<MedicineStockController>()
    : Get.put(MedicineStockController(), permanent: true);

/// The ASHA monthly medicine account (Form 2): every drug-kit item per month
/// with opening/received/issued/expired/closing balance, and a one-tap Form-2
/// PDF the worker can hand in instead of writing three copies.
class MedicineStockListScreen extends StatelessWidget {
  const MedicineStockListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = _msCtrl();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text('ms_new'.tr),
        onPressed: () => Get.to(() => const MedicineStockFormScreen()),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          child: Column(
            children: [
              AppHeader(
                title: 'ms_list_title'.tr,
                actions: [
                  HeaderActionCircle(
                    icon: Icons.refresh_rounded,
                    tooltip: 'ms_refresh'.tr,
                    onTap: ctrl.syncFromServer,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Obx(() {
                  final months = ctrl.months;
                  if (ctrl.items.isEmpty) return _empty(ctrl);
                  return RefreshIndicator(
                    onRefresh: ctrl.syncFromServer,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                      children: months.expand((m) {
                        final rows = ctrl.forMonth(m)
                          ..sort((a, b) => (a['medicineName'] ?? '')
                              .toString()
                              .compareTo((b['medicineName'] ?? '').toString()));
                        return [
                          _monthHeader(m, rows),
                          ...rows.map((r) => _StockCard(data: r)),
                          const SizedBox(height: 14),
                        ];
                      }).toList(),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _monthHeader(String m, List<Map<String, dynamic>> rows) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8, left: 2, right: 2),
        child: Row(
          children: [
            Expanded(
              child: Text(_monthLabel(m),
                  style: AppTextStyles.h3.copyWith(color: AppColors.primary)),
            ),
            TextButton.icon(
              onPressed: () => MedicineStockPdf.generate(
                  month: _monthLabel(m), rows: rows),
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
              label: Text('ms_form2_pdf'.tr),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ],
        ),
      );

  Widget _empty(MedicineStockController ctrl) => RefreshIndicator(
        onRefresh: ctrl.syncFromServer,
        child: ListView(
          children: [
            const SizedBox(height: 120),
            Icon(Icons.medication_outlined,
                size: 64, color: AppColors.primary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Center(
              child: Text('ms_empty_title'.tr,
                  style: AppTextStyles.h3.copyWith(color: AppColors.textSecondary)),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text('ms_empty_subtitle'.tr,
                  style: AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
            ),
          ],
        ),
      );
}

class _StockCard extends StatelessWidget {
  const _StockCard({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final closing = closingOf(data);
    final threshold = _i(data['lowStockThreshold']);
    final low = threshold > 0 && closing <= threshold;
    final color = low ? AppColors.emergencyRed : AppColors.safeGreen;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: AppRadius.lgR,
        child: InkWell(
          borderRadius: AppRadius.lgR,
          onTap: () => Get.to(() => const MedicineStockFormScreen(), arguments: data),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: AppRadius.lgR,
              boxShadow: AppShadows.low,
              border: Border(left: BorderSide(color: color, width: 4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text((data['medicineName'] ?? '').toString(),
                          style: AppTextStyles.h3,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                          low
                              ? 'ms_low_stock'.trParams({'n': '$closing'})
                              : 'ms_balance'.trParams({'n': '$closing'}),
                          style: AppTextStyles.caption
                              .copyWith(color: color, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    'ms_open_short'.trParams({'n': '${_i(data['openingStock'])}'}),
                    'ms_recv_short'.trParams({'n': '${_i(data['receivedQty'])}'}),
                    'ms_issued_short'.trParams({'n': '${_i(data['issuedQty'])}'}),
                    if (_i(data['expiredQty']) > 0)
                      'ms_expired_short'.trParams({'n': '${_i(data['expiredQty'])}'}),
                  ].join('  ·  '),
                  style: AppTextStyles.label.copyWith(color: AppColors.textSecondary),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Add / edit a medicine stock line. Get.arguments = existing record Map or null.
class MedicineStockFormScreen extends StatefulWidget {
  const MedicineStockFormScreen({super.key});
  @override
  State<MedicineStockFormScreen> createState() => _MedicineStockFormScreenState();
}

class _MedicineStockFormScreenState extends State<MedicineStockFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _opening = TextEditingController();
  final _received = TextEditingController();
  final _issued = TextEditingController();
  final _expired = TextEditingController();
  final _threshold = TextEditingController();
  final _notes = TextEditingController();

  String _unit = 'tablet';
  String _month = _thisMonth();
  DateTime? _receivedDate;
  String _editingId = '';

  @override
  void initState() {
    super.initState();
    final a = Get.arguments;
    if (a is Map) {
      _editingId = (a['id'] ?? '').toString();
      _name.text = (a['medicineName'] ?? '').toString();
      _opening.text = _numText(a['openingStock']);
      _received.text = _numText(a['receivedQty']);
      _issued.text = _numText(a['issuedQty']);
      _expired.text = _numText(a['expiredQty']);
      _threshold.text = _numText(a['lowStockThreshold']);
      _notes.text = (a['notes'] ?? '').toString();
      _unit = (a['unit'] ?? 'tablet').toString();
      _month = (a['month'] ?? _thisMonth()).toString();
      _receivedDate = DateTime.tryParse((a['receivedDate'] ?? '').toString());
    }
  }

  String _numText(dynamic v) {
    final n = _i(v);
    return n == 0 ? '' : '$n';
  }

  @override
  void dispose() {
    for (final c in [
      _name, _opening, _received, _issued, _expired, _threshold, _notes
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  int get _closing =>
      (int.tryParse(_opening.text) ?? 0) +
      (int.tryParse(_received.text) ?? 0) -
      (int.tryParse(_issued.text) ?? 0) -
      (int.tryParse(_expired.text) ?? 0);

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final cur = DateTime.tryParse('$_month-01') ?? now;
    final d = await showDatePicker(
      context: context,
      initialDate: cur,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      helpText: 'ms_pick_month'.tr,
    );
    if (d != null) {
      setState(() => _month = '${d.year}-${d.month.toString().padLeft(2, '0')}');
    }
  }

  Future<void> _pickReceivedDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _receivedDate ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
    );
    if (d != null) setState(() => _receivedDate = d);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final ctrl = _msCtrl();
    final rec = <String, dynamic>{
      if (_editingId.isNotEmpty) 'id': _editingId,
      'medicineName': _name.text.trim(),
      'unit': _unit,
      'month': _month,
      'openingStock': int.tryParse(_opening.text) ?? 0,
      'receivedQty': int.tryParse(_received.text) ?? 0,
      'receivedDate': _receivedDate?.toIso8601String() ?? '',
      'issuedQty': int.tryParse(_issued.text) ?? 0,
      'expiredQty': int.tryParse(_expired.text) ?? 0,
      'closingStock': _closing,
      'lowStockThreshold': int.tryParse(_threshold.text) ?? 0,
      'notes': _notes.text.trim(),
      'status': 'active',
    };
    await ctrl.upsert(rec);
    Get.back();
    Get.snackbar('ms_snack_title'.tr, 'ms_snack_saved'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.safeGreen,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        duration: const Duration(seconds: 2));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          child: Column(
            children: [
              AppHeader(title: _editingId.isEmpty ? 'ms_new'.tr : 'ms_edit'.tr),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppInput(
                          hint: 'ms_name_hint'.tr,
                          label: 'ms_name'.tr,
                          controller: _name,
                          prefixIcon: const Icon(Icons.medication_rounded,
                              color: AppColors.primary, size: 20),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'ms_name_required'.tr : null,
                        ),
                        const SizedBox(height: 8),
                        if (_editingId.isEmpty) _drugChips(),
                        const SizedBox(height: 14),
                        Row(children: [
                          Expanded(child: _unitDropdown()),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _DatePickButton(
                              label: 'ms_month'.tr,
                              text: _monthLabel(_month),
                              onTap: _pickMonth,
                            ),
                          ),
                        ]),
                        const SizedBox(height: 14),
                        Row(children: [
                          Expanded(
                            child: AppInput(
                              hint: 'ms_qty_hint'.tr,
                              label: 'ms_opening'.tr,
                              controller: _opening,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppInput(
                              hint: 'ms_qty_hint'.tr,
                              label: 'ms_received'.tr,
                              controller: _received,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 14),
                        DatePickField(
                          label: 'ms_received_date'.tr,
                          value: _receivedDate,
                          onTap: _pickReceivedDate,
                          onClear: () => setState(() => _receivedDate = null),
                        ),
                        const SizedBox(height: 14),
                        Row(children: [
                          Expanded(
                            child: AppInput(
                              hint: 'ms_qty_hint'.tr,
                              label: 'ms_issued'.tr,
                              controller: _issued,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppInput(
                              hint: 'ms_qty_hint'.tr,
                              label: 'ms_expired'.tr,
                              controller: _expired,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 14),
                        _closingBanner(),
                        const SizedBox(height: 14),
                        AppInput(
                          hint: 'ms_threshold_hint'.tr,
                          label: 'ms_threshold'.tr,
                          controller: _threshold,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 14),
                        AppInput(
                          hint: 'ms_notes'.tr,
                          label: 'ms_notes'.tr,
                          controller: _notes,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 24),
                        AppButton(
                          label: 'ms_save'.tr,
                          icon: Icons.check_rounded,
                          width: double.infinity,
                          onPressed: _save,
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _drugChips() => Wrap(
        spacing: 8,
        runSpacing: 6,
        children: _drugKit.map((k) {
          return ActionChip(
            label: Text(k.tr, style: AppTextStyles.caption),
            backgroundColor: AppColors.primarySoft,
            side: BorderSide.none,
            onPressed: () => setState(() => _name.text = k.tr),
          );
        }).toList(),
      );

  Widget _unitDropdown() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ms_unit'.tr, style: AppTextStyles.label),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _unit,
            isExpanded: true,
            style: AppTextStyles.body,
            onChanged: (v) => setState(() => _unit = v ?? 'tablet'),
            items: _units.entries
                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value.tr)))
                .toList(),
          ),
        ],
      );

  Widget _closingBanner() {
    final low = (int.tryParse(_threshold.text) ?? 0) > 0 &&
        _closing <= (int.tryParse(_threshold.text) ?? 0);
    final color = low ? AppColors.emergencyRed : AppColors.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.calculate_rounded, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text('ms_closing'.trParams({'n': '$_closing'}),
                style: AppTextStyles.label
                    .copyWith(color: color, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

/// Read-only field that opens a month picker (mirrors DatePickField styling).
class _DatePickButton extends StatelessWidget {
  const _DatePickButton({required this.label, required this.text, required this.onTap});
  final String label;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.event_rounded, color: AppColors.primary, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(text, style: AppTextStyles.body)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
