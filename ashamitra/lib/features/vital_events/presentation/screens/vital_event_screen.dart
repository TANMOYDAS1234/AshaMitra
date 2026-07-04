import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/components/app_header.dart';
import '../../../../shared/widgets/app_input.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/module_list_card.dart';
import '../../../../shared/widgets/module_hero.dart';
import '../../controller/vital_event_controller.dart';
import '../../../patients/controller/patient_controller.dart';
import '../../../patients/data/models/patient_model.dart';
import '../../../../shared/widgets/date_pick_field.dart';

Map<String, String> get _sexes => {
      'Female': 've_sex_female'.tr,
      'Male': 've_sex_male'.tr,
      'Other': 've_sex_other'.tr,
    };
Map<String, String> get _places => {
      'home': 've_place_home'.tr,
      'institution': 've_place_institution'.tr,
      'transit': 've_place_transit'.tr,
      'other': 've_place_other'.tr,
    };
Map<String, String> get _deliveryTypes => {
      'normal': 've_delivery_normal'.tr,
      'caesarean': 've_delivery_caesarean'.tr,
      'assisted': 've_delivery_assisted'.tr,
    };
Map<String, String> get _attendedBy => {
      'doctor': 've_attended_doctor'.tr,
      'anm': 've_attended_anm'.tr,
      'sba': 've_attended_sba'.tr,
      'tba': 've_attended_tba'.tr,
      'relative': 've_attended_relative'.tr,
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

PatientController _patientCtrl() => Get.isRegistered<PatientController>()
    ? Get.find<PatientController>()
    : Get.put(PatientController(), permanent: true);

/// Birth events the worker hasn't logged yet but the registry already implies:
/// every Newborn registration (DOB) and every pregnancy with a recorded
/// delivery date. Tapping one opens the form pre-filled — the worker only adds
/// the CRS registration number, then it becomes a real saved record.
List<Map<String, dynamic>> _birthCandidates(List<PatientModel> patients) {
  final out = <Map<String, dynamic>>[];
  for (final p in patients) {
    final t = p.type.toLowerCase();
    if (t.contains('newborn') && p.dob != null) {
      out.add({
        'eventType': 'birth',
        'personName': p.name,
        'sex': p.gender,
        'eventDate': p.dob!.toIso8601String(),
        'birthWeight': (p.mcpDetails['birthWeight'] ?? '').toString(),
        'motherName': p.guardianName,
        'village': p.village,
        'mobile': p.mobile,
        'patientId': p.id,
      });
    } else if (t.contains('pregn') && p.deliveryDate != null) {
      out.add({
        'eventType': 'birth',
        'personName': '',
        'sex': '',
        'eventDate': p.deliveryDate!.toIso8601String(),
        'motherName': p.name,
        'village': p.village,
        'mobile': p.mobile,
        'patientId': p.id,
      });
    }
  }
  return out;
}

/// The birth & death (CRS) register — the vital events an ASHA reports to the
/// ANM/sub-centre each month. Tracks whether each event is registered yet.
class VitalEventListScreen extends StatelessWidget {
  const VitalEventListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = _vitalCtrl();
    final pc = _patientCtrl();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text('ve_new_record'.tr),
        onPressed: () => Get.to(() => const VitalEventFormScreen()),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          child: Column(
            children: [
              AppHeader(
                title: 've_list_title'.tr,
                actions: [
                  HeaderActionCircle(
                    icon: Icons.refresh_rounded,
                    tooltip: 've_refresh'.tr,
                    onTap: ctrl.syncFromServer,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Obx(() {
                  final saved = ctrl.items.toList();
                  final savedPids = saved
                      .map((e) => (e['patientId'] ?? '').toString())
                      .where((s) => s.isNotEmpty)
                      .toSet();
                  final suggestions = _birthCandidates(pc.patients.toList())
                      .where((c) => !savedPids.contains(c['patientId']))
                      .toList()
                    ..sort((a, b) => (b['eventDate'] ?? '')
                        .toString()
                        .compareTo((a['eventDate'] ?? '').toString()));
                  if (saved.isEmpty && suggestions.isEmpty) return _empty(ctrl);
                  final pending = ctrl.unregisteredCount;
                  final births = saved
                      .where((e) =>
                          (e['eventType'] ?? 'birth').toString() == 'birth')
                      .length;
                  final deaths = saved
                      .where((e) =>
                          (e['eventType'] ?? '').toString() == 'death')
                      .length;
                  return RefreshIndicator(
                    onRefresh: ctrl.syncFromServer,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                      children: [
                        ModuleHero(
                          chip: 've_hero_chip'.tr,
                          icon: Icons.menu_book_rounded,
                          stats: [
                            ModuleStat('$births', 've_stat_births'.tr,
                                emphasize: true),
                            ModuleStat('$deaths', 've_stat_deaths'.tr),
                            ModuleStat('$pending', 've_stat_pending'.tr,
                                warn: pending > 0),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (saved.isNotEmpty)
                          ModuleSectionHeader('ve_list_header'.tr,
                              count: saved.length),
                        ...saved.map((e) => _VitalCard(data: e)),
                        if (suggestions.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8, left: 4),
                            child: Text(
                                've_suggested_header'.trParams(
                                    {'count': '${suggestions.length}'}),
                                style: AppTextStyles.label.copyWith(
                                    color: AppColors.primary, fontWeight: FontWeight.w700)),
                          ),
                          ...suggestions.map((e) => _VitalCard(data: e, suggested: true)),
                        ],
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
              child: Text('ve_empty_title'.tr,
                  style: AppTextStyles.h3.copyWith(color: AppColors.textSecondary)),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text('ve_empty_subtitle'.tr,
                  style: AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
            ),
          ],
        ),
      );
}

class _VitalCard extends StatelessWidget {
  const _VitalCard({required this.data, this.suggested = false});
  final Map<String, dynamic> data;
  final bool suggested;

  @override
  Widget build(BuildContext context) {
    final isBirth = (data['eventType'] ?? 'birth').toString() == 'birth';
    final registered = data['registered'] == true;
    final accent = isBirth ? AppColors.safeGreen : AppColors.emergencyRed;
    final date = _fmtDate(data['eventDate']);
    final name = (data['personName'] ?? '').toString();
    final (badgeLabel, badgeColor) = suggested
        ? ('ve_chip_suggested'.tr, AppColors.primary)
        : (registered
            ? ('ve_chip_registered'.tr, AppColors.safeGreen)
            : ('ve_chip_pending'.tr, AppColors.accent));
    final subtitle = [
      isBirth ? 've_birth'.tr : 've_death'.tr,
      if (date.isNotEmpty) date,
      if ((data['village'] ?? '').toString().isNotEmpty) data['village'],
    ].join('  ·  ');
    return ModuleListCard(
      icon: isBirth
          ? Icons.child_friendly_rounded
          : Icons.local_florist_rounded,
      title: name.isNotEmpty
          ? name
          : (isBirth ? 've_newborn'.tr : 've_deceased'.tr),
      subtitle: subtitle,
      accent: accent,
      badge: badgeLabel,
      badgeColor: badgeColor,
      onTap: () =>
          Get.to(() => const VitalEventFormScreen(), arguments: data),
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
    Get.snackbar('ve_snack_title'.tr, 've_snack_saved'.tr,
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
              AppHeader(title: _editingId.isEmpty ? 've_new_record'.tr : 've_edit_record'.tr),
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
                          _typeChip('birth', 've_birth'.tr, Icons.child_friendly_rounded,
                              AppColors.safeGreen),
                          const SizedBox(width: 12),
                          _typeChip('death', 've_death'.tr, Icons.local_florist_rounded,
                              AppColors.emergencyRed),
                        ]),
                        const SizedBox(height: 18),
                        AppInput(
                          hint: isBirth ? 've_name_hint_birth'.tr : 've_name_hint_death'.tr,
                          label: isBirth ? 've_name_label_birth'.tr : 've_name_label_death'.tr,
                          controller: _name,
                          prefixIcon: const Icon(Icons.person_outline_rounded,
                              color: AppColors.primary, size: 20),
                          validator: (v) => (!isBirth && (v == null || v.trim().isEmpty))
                              ? 've_name_required'.tr
                              : null,
                        ),
                        const SizedBox(height: 14),
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(child: _dropdown('ve_sex'.tr, _sex, _sexes,
                              (v) => setState(() => _sex = v))),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DatePickField(
                              label: isBirth ? 've_birth_date'.tr : 've_death_date'.tr,
                              value: _eventDate,
                              onTap: _pickDate,
                              onClear: () => setState(() => _eventDate = null),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 14),
                        _dropdown(isBirth ? 've_place_birth'.tr : 've_place_death'.tr, _place, _places,
                            (v) => setState(() => _place = v)),
                        const SizedBox(height: 14),
                        AppInput(
                          hint: 've_facility_hint'.tr,
                          label: 've_facility_label'.tr,
                          controller: _facility,
                        ),
                        const SizedBox(height: 14),
                        Row(children: [
                          Expanded(
                            child: AppInput(
                              hint: 've_village_hint'.tr,
                              label: 've_village_label'.tr,
                              controller: _village,
                              prefixIcon: const Icon(Icons.location_on_outlined,
                                  color: AppColors.primary, size: 20),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppInput(
                              hint: 've_mobile'.tr,
                              label: 've_mobile'.tr,
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
                              hint: 've_mother_name'.tr,
                              label: 've_mother_name'.tr,
                              controller: _mother,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppInput(
                              hint: 've_father_name'.tr,
                              label: 've_father_name'.tr,
                              controller: _father,
                            ),
                          ),
                        ]),
                        const SizedBox(height: 14),
                        // ── Birth-specific ──
                        if (isBirth) ...[
                          AppInput(
                            hint: 've_birth_weight_hint'.tr,
                            label: 've_birth_weight_label'.tr,
                            controller: _birthWeight,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            prefixIcon: const Icon(Icons.monitor_weight_outlined,
                                color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(height: 14),
                          _dropdown('ve_delivery_type'.tr, _deliveryType, _deliveryTypes,
                              (v) => setState(() => _deliveryType = v)),
                          const SizedBox(height: 14),
                          _dropdown('ve_attended_by'.tr, _attended, _attendedBy,
                              (v) => setState(() => _attended = v)),
                          const SizedBox(height: 14),
                        ],
                        // ── Death-specific ──
                        if (!isBirth) ...[
                          AppInput(
                            hint: 've_age_at_death_hint'.tr,
                            label: 've_age_at_death_label'.tr,
                            controller: _ageAtDeath,
                          ),
                          const SizedBox(height: 14),
                          AppInput(
                            hint: 've_cause_hint'.tr,
                            label: 've_cause_label'.tr,
                            controller: _cause,
                            maxLines: 2,
                          ),
                          const SizedBox(height: 6),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            activeThumbColor: AppColors.emergencyRed,
                            title: Text('ve_maternal_death'.tr,
                                style: AppTextStyles.label),
                            value: _maternalDeath,
                            onChanged: (v) => setState(() => _maternalDeath = v),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            activeThumbColor: AppColors.emergencyRed,
                            title: Text('ve_infant_death'.tr, style: AppTextStyles.label),
                            value: _infantDeath,
                            onChanged: (v) => setState(() => _infantDeath = v),
                          ),
                          const SizedBox(height: 8),
                        ],
                        // ── Registration ──
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          activeThumbColor: AppColors.safeGreen,
                          title: Text('ve_registered_switch'.tr, style: AppTextStyles.label),
                          value: _registered,
                          onChanged: (v) => setState(() => _registered = v),
                        ),
                        if (_registered) ...[
                          const SizedBox(height: 8),
                          AppInput(
                            hint: 've_registration_no'.tr,
                            label: 've_registration_no'.tr,
                            controller: _regNo,
                          ),
                        ],
                        const SizedBox(height: 14),
                        AppInput(
                          hint: 've_notes'.tr,
                          label: 've_notes'.tr,
                          controller: _notes,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 24),
                        AppButton(
                          label: 've_save'.tr,
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
