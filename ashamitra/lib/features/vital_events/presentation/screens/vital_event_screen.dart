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
import '../../controller/vital_event_controller.dart';
import '../../../eligible_couples/presentation/screens/eligible_couple_screen.dart'
    show DatePickField;

const _sexes = <String, String>{'Female': 'মেয়ে / মহিলা', 'Male': 'ছেলে / পুরুষ', 'Other': 'অন্যান্য'};
const _places = <String, String>{
  'home': 'বাড়ি',
  'institution': 'প্রতিষ্ঠান (হাসপাতাল)',
  'transit': 'পথে',
  'other': 'অন্যান্য',
};
const _deliveryTypes = <String, String>{
  'normal': 'স্বাভাবিক',
  'caesarean': 'সিজার',
  'assisted': 'যন্ত্রসহায়',
};
const _attendedBy = <String, String>{
  'doctor': 'ডাক্তার',
  'anm': 'ANM',
  'sba': 'প্রশিক্ষিত (SBA)',
  'tba': 'দাই (TBA)',
  'relative': 'আত্মীয়',
};

String _fmtDate(dynamic iso) {
  final d = DateTime.tryParse((iso ?? '').toString());
  if (d == null) return '';
  String p(int n) => n.toString().padLeft(2, '0');
  return '${p(d.day)}/${p(d.month)}/${d.year}';
}

VitalEventController _vitalCtrl() => Get.isRegistered<VitalEventController>()
    ? Get.find<VitalEventController>()
    : Get.put(VitalEventController(), permanent: true);

/// The birth & death (CRS) register — the vital events an ASHA reports to the
/// ANM/sub-centre each month. Tracks whether each event is registered yet.
class VitalEventListScreen extends StatelessWidget {
  const VitalEventListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = _vitalCtrl();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('নতুন নথি'),
        onPressed: () => Get.to(() => const VitalEventFormScreen()),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          child: Column(
            children: [
              AppHeader(
                title: 'জন্ম ও মৃত্যু নথি',
                actions: [
                  HeaderActionCircle(
                    icon: Icons.refresh_rounded,
                    tooltip: 'রিফ্রেশ',
                    onTap: ctrl.syncFromServer,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Obx(() {
                  final items = ctrl.items.toList();
                  if (items.isEmpty) return _empty(ctrl);
                  final pending = ctrl.unregisteredCount;
                  return RefreshIndicator(
                    onRefresh: ctrl.syncFromServer,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                      children: [
                        if (pending > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10, left: 4),
                            child: Text('$pending টি নথিভুক্তি বাকি (CRS)',
                                style: AppTextStyles.label
                                    .copyWith(color: AppColors.accent)),
                          ),
                        ...items.map((e) => _VitalCard(data: e)),
                      ],
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

  Widget _empty(VitalEventController ctrl) => RefreshIndicator(
        onRefresh: ctrl.syncFromServer,
        child: ListView(
          children: [
            const SizedBox(height: 120),
            Icon(Icons.menu_book_rounded,
                size: 64, color: AppColors.primary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Center(
              child: Text('এখনও কোনো নথি নেই',
                  style: AppTextStyles.h3.copyWith(color: AppColors.textSecondary)),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text('জন্ম বা মৃত্যু যোগ করতে নিচের বোতাম চাপুন',
                  style: AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
            ),
          ],
        ),
      );
}

class _VitalCard extends StatelessWidget {
  const _VitalCard({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final isBirth = (data['eventType'] ?? 'birth').toString() == 'birth';
    final registered = data['registered'] == true;
    final color = isBirth ? AppColors.safeGreen : AppColors.emergencyRed;
    final date = _fmtDate(data['eventDate']);
    final name = (data['personName'] ?? '').toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.surface,
        borderRadius: AppRadius.lgR,
        child: InkWell(
          borderRadius: AppRadius.lgR,
          onTap: () => Get.to(() => const VitalEventFormScreen(), arguments: data),
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
                    Icon(isBirth ? Icons.child_friendly_rounded : Icons.local_florist_rounded,
                        size: 18, color: color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        name.isNotEmpty ? name : (isBirth ? 'নবজাতক' : 'মৃত ব্যক্তি'),
                        style: AppTextStyles.h3,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (registered ? AppColors.safeGreen : AppColors.accent)
                            .withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(registered ? 'নথিভুক্ত' : 'বাকি',
                          style: AppTextStyles.caption.copyWith(
                              color: registered ? AppColors.safeGreen : AppColors.accent,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    isBirth ? 'জন্ম' : 'মৃত্যু',
                    if (date.isNotEmpty) date,
                    if ((data['village'] ?? '').toString().isNotEmpty) data['village'],
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

/// Add / edit a birth or death. Get.arguments = existing record Map or null.
class VitalEventFormScreen extends StatefulWidget {
  const VitalEventFormScreen({super.key});
  @override
  State<VitalEventFormScreen> createState() => _VitalEventFormScreenState();
}

class _VitalEventFormScreenState extends State<VitalEventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _facility = TextEditingController();
  final _village = TextEditingController();
  final _mobile = TextEditingController();
  final _mother = TextEditingController();
  final _father = TextEditingController();
  final _birthWeight = TextEditingController();
  final _ageAtDeath = TextEditingController();
  final _cause = TextEditingController();
  final _regNo = TextEditingController();
  final _notes = TextEditingController();

  String _eventType = 'birth';
  String _sex = 'Female';
  String _place = 'institution';
  String _deliveryType = 'normal';
  String _attended = 'anm';
  bool _maternalDeath = false;
  bool _infantDeath = false;
  bool _registered = false;
  DateTime? _eventDate;
  String _editingId = '';
  String _patientId = '';

  @override
  void initState() {
    super.initState();
    final a = Get.arguments;
    if (a is Map) {
      _editingId = (a['id'] ?? '').toString();
      _patientId = (a['patientId'] ?? '').toString();
      _eventType = (a['eventType'] ?? 'birth').toString();
      _name.text = (a['personName'] ?? '').toString();
      _facility.text = (a['facilityName'] ?? '').toString();
      _village.text = (a['village'] ?? '').toString();
      _mobile.text = (a['mobile'] ?? '').toString();
      _mother.text = (a['motherName'] ?? '').toString();
      _father.text = (a['fatherName'] ?? '').toString();
      _birthWeight.text = (a['birthWeight'] ?? '').toString();
      _ageAtDeath.text = (a['ageAtDeath'] ?? '').toString();
      _cause.text = (a['causeOfDeath'] ?? '').toString();
      _regNo.text = (a['registrationNo'] ?? '').toString();
      _notes.text = (a['notes'] ?? '').toString();
      if (_sexes.containsKey(a['sex'])) _sex = a['sex'];
      if (_places.containsKey(a['place'])) _place = a['place'];
      if (_deliveryTypes.containsKey(a['deliveryType'])) _deliveryType = a['deliveryType'];
      if (_attendedBy.containsKey(a['attendedBy'])) _attended = a['attendedBy'];
      _maternalDeath = a['maternalDeath'] == true;
      _infantDeath = a['infantDeath'] == true;
      _registered = a['registered'] == true;
      _eventDate = DateTime.tryParse((a['eventDate'] ?? '').toString());
    }
  }

  @override
  void dispose() {
    for (final c in [
      _name, _facility, _village, _mobile, _mother, _father,
      _birthWeight, _ageAtDeath, _cause, _regNo, _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _eventDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (d != null) setState(() => _eventDate = d);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final isBirth = _eventType == 'birth';
    final rec = <String, dynamic>{
      if (_editingId.isNotEmpty) 'id': _editingId,
      'patientId': _patientId,
      'eventType': _eventType,
      'personName': _name.text.trim(),
      'sex': _sex,
      'eventDate': _eventDate?.toIso8601String() ?? '',
      'place': _place,
      'facilityName': _facility.text.trim(),
      'village': _village.text.trim(),
      'mobile': _mobile.text.trim(),
      'motherName': _mother.text.trim(),
      'fatherName': _father.text.trim(),
      // birth
      'birthWeight': isBirth ? _birthWeight.text.trim() : '',
      'deliveryType': isBirth ? _deliveryType : '',
      'attendedBy': isBirth ? _attended : '',
      // death
      'ageAtDeath': isBirth ? '' : _ageAtDeath.text.trim(),
      'causeOfDeath': isBirth ? '' : _cause.text.trim(),
      'maternalDeath': isBirth ? false : _maternalDeath,
      'infantDeath': isBirth ? false : _infantDeath,
      // registration
      'registered': _registered,
      'registrationNo': _regNo.text.trim(),
      'notes': _notes.text.trim(),
    };
    await _vitalCtrl().upsert(rec);
    Get.back();
    Get.snackbar('জন্ম ও মৃত্যু', 'সংরক্ষিত হয়েছে ✓',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.safeGreen,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        duration: const Duration(seconds: 2));
  }

  Widget _typeChip(String value, String label, IconData icon, Color color) {
    final sel = _eventType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _eventType = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: sel ? color : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: sel ? color : AppColors.cardBorder, width: 1.4),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: sel ? Colors.white : color),
              const SizedBox(width: 8),
              Text(label,
                  style: AppTextStyles.label.copyWith(
                      color: sel ? Colors.white : AppColors.textSecondary,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dropdown(String label, String value, Map<String, String> opts,
          ValueChanged<String> onChanged) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.label),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: value,
            isExpanded: true,
            style: AppTextStyles.body,
            onChanged: (v) => onChanged(v ?? value),
            items: opts.entries
                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final isBirth = _eventType == 'birth';
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          child: Column(
            children: [
              AppHeader(title: _editingId.isEmpty ? 'নতুন নথি' : 'নথি সম্পাদনা'),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          _typeChip('birth', 'জন্ম', Icons.child_friendly_rounded,
                              AppColors.safeGreen),
                          const SizedBox(width: 12),
                          _typeChip('death', 'মৃত্যু', Icons.local_florist_rounded,
                              AppColors.emergencyRed),
                        ]),
                        const SizedBox(height: 18),
                        AppInput(
                          hint: isBirth ? 'নবজাতকের নাম (থাকলে)' : 'মৃত ব্যক্তির নাম',
                          label: isBirth ? 'নবজাতকের নাম' : 'নাম',
                          controller: _name,
                          prefixIcon: const Icon(Icons.person_outline_rounded,
                              color: AppColors.primary, size: 20),
                          validator: (v) => (!isBirth && (v == null || v.trim().isEmpty))
                              ? 'নাম দিন'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(child: _dropdown('লিঙ্গ', _sex, _sexes,
                              (v) => setState(() => _sex = v))),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DatePickField(
                              label: isBirth ? 'জন্ম তারিখ' : 'মৃত্যুর তারিখ',
                              value: _eventDate,
                              onTap: _pickDate,
                              onClear: () => setState(() => _eventDate = null),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 14),
                        _dropdown(isBirth ? 'জন্মস্থান' : 'মৃত্যুর স্থান', _place, _places,
                            (v) => setState(() => _place = v)),
                        const SizedBox(height: 14),
                        AppInput(
                          hint: 'প্রতিষ্ঠানের নাম (থাকলে)',
                          label: 'প্রতিষ্ঠান',
                          controller: _facility,
                        ),
                        const SizedBox(height: 14),
                        Row(children: [
                          Expanded(
                            child: AppInput(
                              hint: 'গ্রাম / এলাকা',
                              label: 'গ্রাম',
                              controller: _village,
                              prefixIcon: const Icon(Icons.location_on_outlined,
                                  color: AppColors.primary, size: 20),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppInput(
                              hint: 'মোবাইল',
                              label: 'মোবাইল',
                              controller: _mobile,
                              keyboardType: TextInputType.phone,
                              maxLength: 10,
                            ),
                          ),
                        ]),
                        const SizedBox(height: 14),
                        Row(children: [
                          Expanded(
                            child: AppInput(
                              hint: 'মায়ের নাম',
                              label: 'মায়ের নাম',
                              controller: _mother,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppInput(
                              hint: 'বাবার নাম',
                              label: 'বাবার নাম',
                              controller: _father,
                            ),
                          ),
                        ]),
                        const SizedBox(height: 14),
                        // ── Birth-specific ──
                        if (isBirth) ...[
                          AppInput(
                            hint: 'জন্ম ওজন (কেজি)',
                            label: 'জন্ম ওজন',
                            controller: _birthWeight,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            prefixIcon: const Icon(Icons.monitor_weight_outlined,
                                color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(height: 14),
                          _dropdown('প্রসবের ধরন', _deliveryType, _deliveryTypes,
                              (v) => setState(() => _deliveryType = v)),
                          const SizedBox(height: 14),
                          _dropdown('কে প্রসব করিয়েছেন', _attended, _attendedBy,
                              (v) => setState(() => _attended = v)),
                          const SizedBox(height: 14),
                        ],
                        // ── Death-specific ──
                        if (!isBirth) ...[
                          AppInput(
                            hint: 'মৃত্যুকালীন বয়স (যেমন ৩২ বছর / ৫ দিন)',
                            label: 'বয়স',
                            controller: _ageAtDeath,
                          ),
                          const SizedBox(height: 14),
                          AppInput(
                            hint: 'মৃত্যুর সম্ভাব্য কারণ',
                            label: 'মৃত্যুর কারণ',
                            controller: _cause,
                            maxLines: 2,
                          ),
                          const SizedBox(height: 6),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            activeThumbColor: AppColors.emergencyRed,
                            title: Text('মাতৃমৃত্যু (গর্ভাবস্থা/প্রসব/৪২ দিন)',
                                style: AppTextStyles.label),
                            value: _maternalDeath,
                            onChanged: (v) => setState(() => _maternalDeath = v),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            activeThumbColor: AppColors.emergencyRed,
                            title: Text('শিশুমৃত্যু (< ১ বছর)', style: AppTextStyles.label),
                            value: _infantDeath,
                            onChanged: (v) => setState(() => _infantDeath = v),
                          ),
                          const SizedBox(height: 8),
                        ],
                        // ── Registration ──
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          activeThumbColor: AppColors.safeGreen,
                          title: Text('CRS-এ নথিভুক্ত হয়েছে', style: AppTextStyles.label),
                          value: _registered,
                          onChanged: (v) => setState(() => _registered = v),
                        ),
                        if (_registered) ...[
                          const SizedBox(height: 8),
                          AppInput(
                            hint: 'রেজিস্ট্রেশন নম্বর',
                            label: 'রেজিস্ট্রেশন নম্বর',
                            controller: _regNo,
                          ),
                        ],
                        const SizedBox(height: 14),
                        AppInput(
                          hint: 'মন্তব্য',
                          label: 'মন্তব্য',
                          controller: _notes,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 24),
                        AppButton(
                          label: 'সংরক্ষণ করুন',
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
}
