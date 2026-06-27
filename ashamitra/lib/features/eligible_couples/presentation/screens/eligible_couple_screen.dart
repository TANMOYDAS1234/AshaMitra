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
import '../../controller/eligible_couple_controller.dart';

// Family-planning methods, in the order the eligible-couple register lists them.
const _fpMethods = <String, String>{
  'none': 'কোনো পদ্ধতি নয়',
  'condom': 'কন্ডোম',
  'ocp': 'বড়ি (OCP)',
  'iucd': 'কপার-টি (IUCD)',
  'injectable': 'অন্তরা ইনজেকশন',
  'female_sterilization': 'মহিলা বন্ধ্যাকরণ',
  'male_sterilization': 'পুরুষ বন্ধ্যাকরণ (NSV)',
  'other': 'অন্যান্য',
};

String _fpLabel(String k) => _fpMethods[k] ?? 'কোনো পদ্ধতি নয়';

String _fmtDate(dynamic iso) {
  final d = DateTime.tryParse((iso ?? '').toString());
  if (d == null) return '';
  String p(int n) => n.toString().padLeft(2, '0');
  return '${p(d.day)}/${p(d.month)}/${d.year}';
}

EligibleCoupleController _coupleCtrl() => Get.isRegistered<EligibleCoupleController>()
    ? Get.find<EligibleCoupleController>()
    : Get.put(EligibleCoupleController(), permanent: true);

/// The eligible-couple (family-planning) register: every married couple with the
/// wife in the reproductive age band, the current FP method and the next
/// follow-up. Answers "who still needs counselling / a follow-up?".
class EligibleCoupleListScreen extends StatelessWidget {
  const EligibleCoupleListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = _coupleCtrl();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('নতুন দম্পতি'),
        onPressed: () => Get.to(() => const EligibleCoupleFormScreen()),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          child: Column(
            children: [
              AppHeader(
                title: 'যোগ্য দম্পতি (পরিবার পরিকল্পনা)',
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
                  return RefreshIndicator(
                    onRefresh: ctrl.syncFromServer,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                      children: items.map((c) => _CoupleCard(data: c)).toList(),
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

  Widget _empty(EligibleCoupleController ctrl) => RefreshIndicator(
        onRefresh: ctrl.syncFromServer,
        child: ListView(
          children: [
            const SizedBox(height: 120),
            Icon(Icons.favorite_outline_rounded,
                size: 64, color: AppColors.primary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Center(
              child: Text('এখনও কোনো দম্পতি নেই',
                  style: AppTextStyles.h3.copyWith(color: AppColors.textSecondary)),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text('যোগ্য দম্পতি যোগ করতে নিচের বোতাম চাপুন',
                  style: AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
            ),
          ],
        ),
      );
}

class _CoupleCard extends StatelessWidget {
  const _CoupleCard({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final highRisk = data['highRisk'] == true;
    final method = (data['fpMethod'] ?? 'none').toString();
    final follow = _fmtDate(data['followUpDate']);
    final closed = (data['status'] ?? 'active').toString() == 'closed';
    final color = closed
        ? AppColors.textSecondary
        : (highRisk ? AppColors.emergencyRed : AppColors.primary);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.surface,
        borderRadius: AppRadius.lgR,
        child: InkWell(
          borderRadius: AppRadius.lgR,
          onTap: () => Get.to(() => const EligibleCoupleFormScreen(), arguments: data),
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
                      child: Text(
                        [
                          (data['wifeName'] ?? '').toString(),
                          if ((data['husbandName'] ?? '').toString().isNotEmpty)
                            '/ ${data['husbandName']}',
                        ].join(' '),
                        style: AppTextStyles.h3,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(closed ? 'বন্ধ' : _fpLabel(method),
                          style: AppTextStyles.caption
                              .copyWith(color: color, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    if ((data['village'] ?? '').toString().isNotEmpty) data['village'],
                    if ((data['sons'] ?? '').toString().isNotEmpty ||
                        (data['daughters'] ?? '').toString().isNotEmpty)
                      'সন্তান: ${data['sons'] ?? 0} ছেলে, ${data['daughters'] ?? 0} মেয়ে',
                  ].join('  ·  '),
                  style: AppTextStyles.label.copyWith(color: AppColors.textSecondary),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                if (follow.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('পরবর্তী ফলো-আপ: $follow',
                      style: AppTextStyles.caption
                          .copyWith(color: highRisk ? AppColors.emergencyRed : AppColors.primary)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Add / edit a couple. Get.arguments = existing record Map (edit) or null (new).
class EligibleCoupleFormScreen extends StatefulWidget {
  const EligibleCoupleFormScreen({super.key});
  @override
  State<EligibleCoupleFormScreen> createState() => _EligibleCoupleFormScreenState();
}

class _EligibleCoupleFormScreenState extends State<EligibleCoupleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _wife = TextEditingController();
  final _husband = TextEditingController();
  final _wifeAge = TextEditingController();
  final _husbandAge = TextEditingController();
  final _village = TextEditingController();
  final _mobile = TextEditingController();
  final _sons = TextEditingController();
  final _daughters = TextEditingController();
  final _youngest = TextEditingController();
  final _notes = TextEditingController();

  String _method = 'none';
  bool _highRisk = false;
  bool _closed = false;
  DateTime? _followUp;
  String _editingId = '';
  String _patientId = '';

  @override
  void initState() {
    super.initState();
    final a = Get.arguments;
    if (a is Map) {
      _editingId = (a['id'] ?? '').toString();
      _patientId = (a['patientId'] ?? '').toString();
      _wife.text = (a['wifeName'] ?? '').toString();
      _husband.text = (a['husbandName'] ?? '').toString();
      _wifeAge.text = (a['wifeAge'] ?? '').toString();
      _husbandAge.text = (a['husbandAge'] ?? '').toString();
      _village.text = (a['village'] ?? '').toString();
      _mobile.text = (a['mobile'] ?? '').toString();
      _sons.text = (a['sons'] ?? '').toString();
      _daughters.text = (a['daughters'] ?? '').toString();
      _youngest.text = (a['youngestChildAge'] ?? '').toString();
      _notes.text = (a['notes'] ?? '').toString();
      _method = (a['fpMethod'] ?? 'none').toString();
      _highRisk = a['highRisk'] == true;
      _closed = (a['status'] ?? 'active').toString() == 'closed';
      _followUp = DateTime.tryParse((a['followUpDate'] ?? '').toString());
    }
  }

  @override
  void dispose() {
    for (final c in [
      _wife, _husband, _wifeAge, _husbandAge, _village,
      _mobile, _sons, _daughters, _youngest, _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickFollowUp() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _followUp ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (d != null) setState(() => _followUp = d);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final ctrl = _coupleCtrl();
    final rec = <String, dynamic>{
      if (_editingId.isNotEmpty) 'id': _editingId,
      'patientId': _patientId,
      'wifeName': _wife.text.trim(),
      'husbandName': _husband.text.trim(),
      'wifeAge': _wifeAge.text.trim(),
      'husbandAge': _husbandAge.text.trim(),
      'village': _village.text.trim(),
      'mobile': _mobile.text.trim(),
      'sons': _sons.text.trim(),
      'daughters': _daughters.text.trim(),
      'youngestChildAge': _youngest.text.trim(),
      'fpMethod': _method,
      'followUpDate': _followUp?.toIso8601String() ?? '',
      'highRisk': _highRisk,
      'notes': _notes.text.trim(),
      'status': _closed ? 'closed' : 'active',
    };
    await ctrl.upsert(rec);
    Get.back();
    Get.snackbar('যোগ্য দম্পতি', 'সংরক্ষিত হয়েছে ✓',
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
              AppHeader(title: _editingId.isEmpty ? 'নতুন দম্পতি' : 'দম্পতি সম্পাদনা'),
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
                          hint: 'স্ত্রীর নাম',
                          label: 'স্ত্রীর নাম',
                          controller: _wife,
                          prefixIcon: const Icon(Icons.person_outline_rounded,
                              color: AppColors.primary, size: 20),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'নাম দিন' : null,
                        ),
                        const SizedBox(height: 14),
                        AppInput(
                          hint: 'স্বামীর নাম',
                          label: 'স্বামীর নাম',
                          controller: _husband,
                          prefixIcon: const Icon(Icons.person_outline_rounded,
                              color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(height: 14),
                        Row(children: [
                          Expanded(
                            child: AppInput(
                              hint: 'স্ত্রীর বয়স',
                              label: 'স্ত্রীর বয়স',
                              controller: _wifeAge,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppInput(
                              hint: 'স্বামীর বয়স',
                              label: 'স্বামীর বয়স',
                              controller: _husbandAge,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ]),
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
                              hint: 'জীবিত ছেলে',
                              label: 'ছেলে',
                              controller: _sons,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppInput(
                              hint: 'জীবিত মেয়ে',
                              label: 'মেয়ে',
                              controller: _daughters,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ]),
                        const SizedBox(height: 14),
                        AppInput(
                          hint: 'সর্বকনিষ্ঠ সন্তানের বয়স (যেমন ৮ মাস)',
                          label: 'সর্বকনিষ্ঠ সন্তানের বয়স',
                          controller: _youngest,
                        ),
                        const SizedBox(height: 14),
                        Text('বর্তমান পদ্ধতি', style: AppTextStyles.label),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _method,
                          isExpanded: true,
                          style: AppTextStyles.body,
                          onChanged: (v) => setState(() => _method = v ?? 'none'),
                          items: _fpMethods.entries
                              .map((e) => DropdownMenuItem(
                                  value: e.key, child: Text(e.value)))
                              .toList(),
                        ),
                        const SizedBox(height: 14),
                        _DateField(
                          label: 'পরবর্তী ফলো-আপ তারিখ',
                          value: _followUp,
                          onTap: _pickFollowUp,
                          onClear: () => setState(() => _followUp = null),
                        ),
                        const SizedBox(height: 6),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          activeThumbColor: AppColors.emergencyRed,
                          title: Text('উচ্চ ঝুঁকি / অগ্রাধিকার',
                              style: AppTextStyles.label),
                          value: _highRisk,
                          onChanged: (v) => setState(() => _highRisk = v),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('রেজিস্টার থেকে বন্ধ (closed)',
                              style: AppTextStyles.label),
                          subtitle: Text('প্রজনন বয়স পেরিয়ে গেছে / স্থানান্তরিত',
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.textSecondary)),
                          value: _closed,
                          onChanged: (v) => setState(() => _closed = v),
                        ),
                        const SizedBox(height: 8),
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

/// Small read-only field that opens a date picker (used by both new modules).
class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final txt = value == null ? 'তারিখ নির্বাচন করুন' : _fmtDate(value!.toIso8601String());
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
                const Icon(Icons.calendar_today_rounded,
                    color: AppColors.primary, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(txt,
                      style: AppTextStyles.body.copyWith(
                          color: value == null
                              ? AppColors.textSecondary
                              : AppColors.onBackground)),
                ),
                if (value != null && onClear != null)
                  GestureDetector(
                    onTap: onClear,
                    child: const Icon(Icons.close_rounded,
                        color: AppColors.textSecondary, size: 18),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Re-export so the vital-events screen can reuse the same date field.
class DatePickField extends StatelessWidget {
  const DatePickField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  @override
  Widget build(BuildContext context) =>
      _DateField(label: label, value: value, onTap: onTap, onClear: onClear);
}
