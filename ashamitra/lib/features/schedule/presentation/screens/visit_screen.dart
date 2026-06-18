import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/components/app_header.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_input.dart';
import '../../../../app/routes.dart';

/// Unified "conduct visit" screen — one UI shell for every scheduled visit
/// type (ANC, immunization, HBNC newborn home visit). The body adapts to the
/// event's `kind`; completing it records what the worker did (ANC vitals,
/// vaccines given, danger-sign flags) into the ScheduleEvent and marks it done.
///
/// Opened from the due list with the event map as Get.arguments.
class VisitScreen extends StatefulWidget {
  const VisitScreen({super.key});

  @override
  State<VisitScreen> createState() => _VisitScreenState();
}

class _VisitScreenState extends State<VisitScreen> {
  late final Map<String, dynamic> _e;
  bool _saving = false;

  // Vaccine: which of the milestone's vaccines were given (default: all).
  final Set<String> _given = {};
  // ANC vitals (matches the paper ANC register).
  final _bp = TextEditingController();
  final _weight = TextEditingController();
  final _hb = TextEditingController();
  final _bsugar = TextEditingController();
  final _urineAlb = TextEditingController();
  final _urineSugar = TextEditingController();
  final _fundal = TextEditingController();
  // Supplements / injections given this ANC visit.
  final Set<String> _ancGiven = {};
  static const _ancSupplements = ['IFA', 'ক্যালসিয়াম', 'অ্যালবেন্ডাজল', 'TD টিকা'];
  // Danger-sign flags (ANC / newborn / young-child).
  final Set<String> _flags = {};

  static const _ancDangerSigns = [
    'পা/মুখ/হাত ফোলা',
    'চোখে ঝাপসা দেখা',
    'তীব্র মাথাব্যথা',
    'যোনিপথে রক্তপাত',
    'খিঁচুনি',
    'গর্ভস্থ শিশুর নড়াচড়া কম',
    'তীব্র জ্বর',
  ];

  static const _newbornDangerSigns = [
    'দুধ খেতে পারছে না',
    'খিঁচুনি',
    'দ্রুত শ্বাস (৬০+/মিনিট)',
    'বুক ভেতরে ঢুকছে',
    'গা গরম (জ্বর)',
    'গা ঠান্ডা',
    'নিস্তেজ / সাড়া কম',
    'নাভিতে পুঁজ / লালভাব',
  ];

  // HBYC young-child home-visit checklist (IIBYC card) — care + danger items.
  static const _hbycSigns = [
    'শিশু অসুস্থ',
    'বুকের দুধ / পরিপূরক খাবার ঠিকমতো হচ্ছে না',
    'ওজন বাড়ছে না',
    'টিকা বাকি আছে',
    'ডায়রিয়া / নিউমোনিয়ার লক্ষণ',
    'বিকাশে দেরি',
    'ঘরে ORS / আয়রন সিরাপ নেই',
  ];

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    _e = args is Map ? Map<String, dynamic>.from(args) : <String, dynamic>{};
    // Pre-tick all vaccines for this visit (worker unticks any not given).
    if (_kind == 'vaccine') _given.addAll(_vaccines);
  }

  @override
  void dispose() {
    _bp.dispose();
    _weight.dispose();
    _hb.dispose();
    _bsugar.dispose();
    _urineAlb.dispose();
    _urineSugar.dispose();
    _fundal.dispose();
    super.dispose();
  }

  String get _kind => _e['kind']?.toString() ?? '';
  String get _label => _e['label']?.toString() ?? 'ভিজিট';
  String get _id => _e['id']?.toString() ?? '';
  List<String> get _vaccines {
    final meta = _e['meta'];
    if (meta is Map && meta['vaccines'] is List) {
      return (meta['vaccines'] as List).map((v) => v.toString()).toList();
    }
    return [];
  }

  bool get _hasDanger => _flags.isNotEmpty;

  // ── Complication → full triage hand-off ─────────────────────────────────
  // A complication at a scheduled visit routes the worker into the matching
  // clinical triage case (the deterministic engine), carrying the SAME patient
  // — so they get a graded RED/YELLOW band, suspected condition, exact facility
  // and a saved Report, instead of just a "refer" note.
  String? _caseIdForKind(String kind) => switch (kind) {
        'anc' => 'pregnancy',
        'hbnc' => 'newborn',
        'vaccine' => 'child',
        'hbyc' => 'child',
        _ => null,
      };

  String _caseTitle(String caseId) => switch (caseId) {
        'pregnancy' => '🤰 গর্ভবতী মায়ের চেকআপ',
        'newborn' => '👶 নবজাতক চেকআপ (০-২৮ দিন)',
        'child' => '🧒 শিশু স্বাস্থ্য যাচাই',
        _ => 'স্বাস্থ্য যাচাই',
      };

  void _openTriage() {
    final caseId = _caseIdForKind(_kind);
    if (caseId == null) return;
    Get.toNamed(AppRoutes.voiceTriage, arguments: {
      'caseId': caseId,
      'caseTitle': _caseTitle(caseId),
      'patientId': _e['patientId']?.toString(),
      'patientName': _e['patientName']?.toString(),
    });
  }

  Future<void> _complete() async {
    if (_id.isEmpty) {
      Get.back();
      return;
    }
    setState(() => _saving = true);
    final record = <String, dynamic>{
      if (_kind == 'vaccine') ...{
        'givenVaccines': _given.toList(),
        'allGiven': _given.length == _vaccines.length,
      },
      if (_kind == 'anc') ...{
        'bp': _bp.text.trim(),
        'weight': _weight.text.trim(),
        'hb': _hb.text.trim(),
        'bloodSugar': _bsugar.text.trim(),
        'urineAlbumin': _urineAlb.text.trim(),
        'urineSugar': _urineSugar.text.trim(),
        'fundalHeight': _fundal.text.trim(),
        'supplementsGiven': _ancGiven.toList(),
      },
      if (_flags.isNotEmpty) 'dangerFlags': _flags.toList(),
      'completedAt': DateTime.now().toIso8601String(),
    };
    final ok = await ApiService.markScheduleEvent(_id, 'done', record: record);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok == null) {
      Get.snackbar('সংযোগ সমস্যা', 'এখন সংরক্ষণ করা গেল না, আবার চেষ্টা করুন।',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.warningYellow, colorText: Colors.white,
          margin: const EdgeInsets.all(16), borderRadius: 12);
      return;
    }
    Get.back(result: true); // due list refreshes
    Get.snackbar('ভিজিট সম্পন্ন ✓', '${_e['patientName'] ?? ''} — $_label',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.safeGreen, colorText: Colors.white,
        margin: const EdgeInsets.all(16), borderRadius: 12,
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
              AppHeader(title: _label),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _patientCard(),
                      const SizedBox(height: 18),
                      ..._body(),
                      if (_hasDanger) ...[
                        const SizedBox(height: 16),
                        _dangerBanner(),
                      ],
                      if (_caseIdForKind(_kind) != null) ...[
                        const SizedBox(height: 14),
                        AppButton(
                          label: _hasDanger
                              ? 'জটিলতা — সম্পূর্ণ ট্রায়াজ করুন'
                              : 'সম্পূর্ণ স্বাস্থ্য যাচাই (ট্রায়াজ)',
                          onPressed: _openTriage,
                          // Emphasised (filled) when a danger sign is present.
                          outlined: !_hasDanger,
                          width: double.infinity,
                          icon: Icons.medical_services_outlined,
                        ),
                      ],
                      const SizedBox(height: 28),
                      AppButton(
                        label: _saving ? 'সংরক্ষণ হচ্ছে…' : 'ভিজিট সম্পন্ন করুন',
                        onPressed: _saving ? null : _complete,
                        width: double.infinity,
                        icon: Icons.check_circle_outline_rounded,
                      ),
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

  Widget _patientCard() {
    final color = switch (_kind) {
      'vaccine' => const Color(0xFF6366F1),
      'anc' => AppColors.primary,
      'hbnc' => AppColors.sky,
      'hbyc' => const Color(0xFF10B981),
      _ => AppColors.primary,
    };
    final icon = switch (_kind) {
      'vaccine' => Icons.vaccines_rounded,
      'anc' => Icons.pregnant_woman_rounded,
      'hbnc' => Icons.child_care_rounded,
      'hbyc' => Icons.child_friendly_rounded,
      _ => Icons.event_note_rounded,
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_e['patientName']?.toString() ?? 'রোগী',
                    style: AppTextStyles.h3),
                Text(_label, style: AppTextStyles.label),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _body() {
    switch (_kind) {
      case 'vaccine':
        return _vaccineBody();
      case 'anc':
        return _ancBody();
      case 'hbnc':
        return _flagBody('নবজাতকের বিপদচিহ্ন যাচাই করুন', _newbornDangerSigns);
      case 'hbyc':
        return _flagBody('শিশুর যত্ন ও বিপদচিহ্ন যাচাই করুন', _hbycSigns);
      default:
        return [Text('এই ভিজিটটি সম্পন্ন হিসেবে চিহ্নিত করুন।',
            style: AppTextStyles.body)];
    }
  }

  List<Widget> _vaccineBody() {
    if (_vaccines.isEmpty) {
      return [Text('এই ভিজিটে টিকার তালিকা নেই।', style: AppTextStyles.body)];
    }
    return [
      Text('এই ভিজিটে দেওয়ার টিকা', style: AppTextStyles.label),
      const SizedBox(height: 6),
      ..._vaccines.map((v) => CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            activeColor: AppColors.primary,
            controlAffinity: ListTileControlAffinity.leading,
            value: _given.contains(v),
            title: Text(v, style: AppTextStyles.body),
            onChanged: (on) => setState(() =>
                on == true ? _given.add(v) : _given.remove(v)),
          )),
    ];
  }

  List<Widget> _ancBody() {
    return [
      Text('পরিমাপ লিখুন', style: AppTextStyles.label),
      const SizedBox(height: 8),
      AppInput(
        hint: 'যেমন 120/80',
        label: 'রক্তচাপ (BP)',
        controller: _bp,
        prefixIcon: const Icon(Icons.favorite_outline, color: AppColors.primary, size: 20),
      ),
      const SizedBox(height: 14),
      AppInput(
        hint: 'কেজি',
        label: 'ওজন',
        controller: _weight,
        keyboardType: TextInputType.number,
        prefixIcon: const Icon(Icons.monitor_weight_outlined, color: AppColors.primary, size: 20),
      ),
      const SizedBox(height: 14),
      AppInput(
        hint: 'g/dL',
        label: 'হিমোগ্লোবিন (Hb)',
        controller: _hb,
        keyboardType: TextInputType.number,
        prefixIcon: const Icon(Icons.bloodtype_outlined, color: AppColors.primary, size: 20),
      ),
      const SizedBox(height: 14),
      AppInput(
        hint: 'mg/dL',
        label: 'রক্তে শর্করা (Blood sugar)',
        controller: _bsugar,
        keyboardType: TextInputType.number,
        prefixIcon: const Icon(Icons.water_drop_outlined, color: AppColors.primary, size: 20),
      ),
      const SizedBox(height: 14),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: AppInput(
              hint: 'nil/+/++',
              label: 'মূত্রে অ্যালবুমিন',
              controller: _urineAlb,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AppInput(
              hint: 'nil/+/++',
              label: 'মূত্রে শর্করা',
              controller: _urineSugar,
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      AppInput(
        hint: 'সেমি',
        label: 'জরায়ুর উচ্চতা (Fundal height)',
        controller: _fundal,
        keyboardType: TextInputType.number,
        prefixIcon: const Icon(Icons.straighten_outlined, color: AppColors.primary, size: 20),
      ),
      const SizedBox(height: 16),
      Text('এই ভিজিটে যা দেওয়া হয়েছে', style: AppTextStyles.label),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _ancSupplements.map((s) {
          final sel = _ancGiven.contains(s);
          return FilterChip(
            label: Text(s),
            selected: sel,
            showCheckmark: true,
            selectedColor: AppColors.safeGreen,
            backgroundColor: AppColors.surface,
            labelStyle: AppTextStyles.label.copyWith(
              color: sel ? Colors.white : AppColors.textSecondary,
            ),
            onSelected: (on) =>
                setState(() => on ? _ancGiven.add(s) : _ancGiven.remove(s)),
          );
        }).toList(),
      ),
      const SizedBox(height: 18),
      ..._flagBody('বিপদচিহ্ন যাচাই করুন', _ancDangerSigns),
    ];
  }

  List<Widget> _flagBody(String title, List<String> signs) {
    return [
      Text(title, style: AppTextStyles.label),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: signs.map((s) {
          final sel = _flags.contains(s);
          return FilterChip(
            label: Text(s),
            selected: sel,
            showCheckmark: false,
            selectedColor: AppColors.emergencyRed,
            backgroundColor: AppColors.surface,
            labelStyle: AppTextStyles.label.copyWith(
              color: sel ? Colors.white : AppColors.textSecondary,
            ),
            onSelected: (on) =>
                setState(() => on ? _flags.add(s) : _flags.remove(s)),
          );
        }).toList(),
      ),
    ];
  }

  Widget _dangerBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.emergencyRed.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.emergencyRed, width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.emergencyRed),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'বিপদচিহ্ন শনাক্ত হয়েছে — এখনই নিকটতম FRU/PHC-তে রেফার করুন (১০৮)।',
              style: AppTextStyles.label.copyWith(
                  color: AppColors.emergencyRed, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
