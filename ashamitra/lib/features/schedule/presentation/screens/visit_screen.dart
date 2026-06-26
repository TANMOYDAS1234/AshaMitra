import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/local_storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/components/app_header.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_input.dart';
import '../../../../shared/widgets/patient_photo.dart';
import '../../../patients/controller/patient_controller.dart';
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
  // MCP-card ANC examination — full field set, in the card's row order.
  final _weeks = TextEditingController();    // গর্ভের ক্রমের বয়স (সপ্তাহ)
  final _pulse = TextEditingController();    // নাড়ির গতি
  final _fhr = TextEditingController();       // ভ্রূণের হৃদস্পন্দন /মিনিট
  final _lie = TextEditingController();       // ভ্রূণের অবস্থান Lie/Presentation
  final _other = TextEditingController();     // অন্যান্য সমস্যা
  final _hiv = TextEditingController();       // HIV ফল
  final _syphilis = TextEditingController();  // সিফিলিস ফল
  final _gdm = TextEditingController();       // GDM ফল
  final _tsh = TextEditingController();       // TSH
  final _hbsag = TextEditingController();     // HBsAg
  // Clinical findings present (chips) + single-choice / yes-no items.
  final Set<String> _exam = {};              // ফ্যাকাসে/ফুলে/জন্ডিস/শরীরে ফোলা
  String _fetalMove = '';                     // স্বাভাবিক / কম / নেই
  bool _pvDone = false;                       // যোনিপথ (P/V) করা হয়েছে
  bool _usgDone = false;                      // আল্ট্রাসোনোগ্রাফি করা হয়েছে
  static const _examFindings = ['ফ্যাকাসে ভাব', 'ফুলে যাওয়া', 'জন্ডিস', 'শরীরে কোথাও ফোলা'];
  static const _fetalMoveOpts = ['স্বাভাবিক', 'কম', 'নেই'];
  // Supplements / injections given this ANC visit.
  final Set<String> _ancGiven = {};
  static const _ancSupplements = ['IFA', 'ক্যালসিয়াম', 'অ্যালবেন্ডাজল', 'TD টিকা'];
  // WB MCP-card pg-5 TB screening inside ANC — any flag ⇒ prompt a NAAT test.
  final Set<String> _tb = {};
  static const _ancTbSigns = [
    'কাশি / জ্বর (২ সপ্তাহের বেশি)',
    'রাতে ঘাম হওয়া',
    'গত ৩ মাসে ওজন বাড়েনি',
  ];
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
    _loadDraft(); // resume a half-filled visit, if any
  }

  // ── Draft (resume later) ────────────────────────────────────────────────
  /// Everything the worker entered, so a half-done visit can be reopened.
  Map<String, dynamic> _draftMap() => {
        'given': _given.toList(),
        'ancGiven': _ancGiven.toList(),
        'flags': _flags.toList(),
        'tb': _tb.toList(),
        'exam': _exam.toList(),
        'fetalMove': _fetalMove, 'pvDone': _pvDone, 'usgDone': _usgDone,
        'bp': _bp.text, 'weight': _weight.text, 'hb': _hb.text,
        'bsugar': _bsugar.text, 'urineAlb': _urineAlb.text,
        'urineSugar': _urineSugar.text, 'fundal': _fundal.text,
        'weeks': _weeks.text, 'pulse': _pulse.text, 'fhr': _fhr.text,
        'lie': _lie.text, 'other': _other.text, 'hiv': _hiv.text,
        'syphilis': _syphilis.text, 'gdm': _gdm.text, 'tsh': _tsh.text,
        'hbsag': _hbsag.text,
      };

  void _applyDraft(Map<String, dynamic> d) {
    void fill(TextEditingController c, String k) {
      final v = d[k];
      if (v != null) c.text = v.toString();
    }
    fill(_bp, 'bp'); fill(_weight, 'weight'); fill(_hb, 'hb');
    fill(_bsugar, 'bsugar'); fill(_urineAlb, 'urineAlb');
    fill(_urineSugar, 'urineSugar'); fill(_fundal, 'fundal');
    fill(_weeks, 'weeks'); fill(_pulse, 'pulse'); fill(_fhr, 'fhr');
    fill(_lie, 'lie'); fill(_other, 'other'); fill(_hiv, 'hiv');
    fill(_syphilis, 'syphilis'); fill(_gdm, 'gdm'); fill(_tsh, 'tsh');
    fill(_hbsag, 'hbsag');
    _fetalMove = d['fetalMove']?.toString() ?? '';
    _pvDone = d['pvDone'] == true;
    _usgDone = d['usgDone'] == true;
    void addAll(Set<String> s, String k) {
      final v = d[k];
      if (v is List) s.addAll(v.map((e) => e.toString()));
    }
    if (d['given'] is List) { _given.clear(); addAll(_given, 'given'); }
    addAll(_ancGiven, 'ancGiven');
    addAll(_flags, 'flags');
    addAll(_tb, 'tb');
    addAll(_exam, 'exam');
  }

  void _loadDraft() {
    if (_id.isEmpty) return;
    final d = LocalStorageService.loadVisitDraft(_id);
    if (d != null) _applyDraft(d);
  }

  Future<void> _saveDraft() async {
    if (_id.isEmpty) { Get.back(); return; }
    await LocalStorageService.saveVisitDraft(_id, _draftMap());
    if (!mounted) return;
    Get.back(result: false); // event stays pending → reopen to resume
    Get.snackbar('খসড়া সংরক্ষিত', 'পরে এই ভিজিট থেকে আবার শুরু করতে পারবেন।',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.warningYellow, colorText: Colors.white,
        margin: const EdgeInsets.all(16), borderRadius: 12,
        duration: const Duration(seconds: 2));
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
    _weeks.dispose();
    _pulse.dispose();
    _fhr.dispose();
    _lie.dispose();
    _other.dispose();
    _hiv.dispose();
    _syphilis.dispose();
    _gdm.dispose();
    _tsh.dispose();
    _hbsag.dispose();
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

  /// The linked patient's photo (base64 JPEG in mcpDetails['photo']), looked up
  /// by id from the PatientController — so the ANC/visit screen shows the real
  /// person, not a generic icon. Null when no patient/photo.
  String? get _patientPhotoB64 {
    final pid = _e['patientId']?.toString();
    if (pid == null || pid.isEmpty) return null;
    if (!Get.isRegistered<PatientController>()) return null;
    for (final p in Get.find<PatientController>().patients) {
      if (p.id == pid) return p.mcpDetails['photo']?.toString();
    }
    return null;
  }

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
        // MCP card "গর্ভকালীন পরীক্ষা" — per-visit, in card order.
        'gestWeeks': _weeks.text.trim(),
        'weight': _weight.text.trim(),
        'pulse': _pulse.text.trim(),
        'bp': _bp.text.trim(),
        'examFindings': _exam.toList(), // ফ্যাকাসে/ফুলে/জন্ডিস/শরীরে ফোলা
        'otherProblems': _other.text.trim(),
        // তলপেট পরীক্ষা
        'fundalHeight': _fundal.text.trim(),
        'liePresentation': _lie.text.trim(),
        'fetalMovement': _fetalMove,
        'fhr': _fhr.text.trim(),
        'pvDone': _pvDone,
        // আবশ্যিক + অন্যান্য পরীক্ষা
        'hb': _hb.text.trim(),
        'urineAlbumin': _urineAlb.text.trim(),
        'urineSugar': _urineSugar.text.trim(),
        'bloodSugar': _bsugar.text.trim(),
        'hiv': _hiv.text.trim(),
        'syphilis': _syphilis.text.trim(),
        'usgDone': _usgDone,
        'gdm': _gdm.text.trim(),
        'tsh': _tsh.text.trim(),
        'hbsag': _hbsag.text.trim(),
        'supplementsGiven': _ancGiven.toList(),
        if (_tb.isNotEmpty) ...{
          'tbSymptoms': _tb.toList(),
          'naatNeeded': true,
        },
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
    await LocalStorageService.clearVisitDraft(_id); // visit done → drop the draft
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
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.08)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _body(),
                        ),
                      ),
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
                      const SizedBox(height: 10),
                      // Save a half-done visit and resume it later from the due list.
                      AppButton(
                        label: 'খসড়া সংরক্ষণ করুন (পরে শেষ করব)',
                        onPressed: _saving ? null : _saveDraft,
                        outlined: true,
                        width: double.infinity,
                        icon: Icons.save_outlined,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          // Friendly illustration — drop a PNG at assets/illustrations/<kind>.png
          // (anc/hbnc/hbyc/vaccine). Falls back to a Material icon when absent,
          // so a missing file never breaks anything.
          Container(
            width: 58,
            height: 58,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: Builder(builder: (_) {
              // Show the patient's own photo (captured at registration, stored in
              // mcpDetails['photo']). Falls back to a kind illustration, then icon.
              final photo = patientPhotoProvider(_patientPhotoB64);
              if (photo != null) {
                return Image(image: photo, fit: BoxFit.cover, width: 58, height: 58);
              }
              return Image.asset(
                'assets/illustrations/$_kind.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(icon, color: color, size: 30),
              );
            }),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_e['patientName']?.toString() ?? 'রোগী',
                    style: AppTextStyles.h3),
                const SizedBox(height: 2),
                Text(_label,
                    style: AppTextStyles.label
                        .copyWith(color: color, fontWeight: FontWeight.w700)),
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

  // ANC capture — mirrors the MCP card "গর্ভকালীন যত্ন ও পরিষেবা" page, in the
  // card's exact section + row order so the worker ticks the screen like the card.
  List<Widget> _ancBody() {
    return [
      // ── গর্ভকালীন পরীক্ষা (per-visit measurements) ──
      _sectionTitle('গর্ভকালীন পরীক্ষা', Icons.pregnant_woman_rounded),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: AppInput(hint: 'সপ্তাহ', label: 'গর্ভের বয়স', controller: _weeks, keyboardType: TextInputType.number)),
        const SizedBox(width: 12),
        Expanded(child: AppInput(hint: 'কেজি', label: 'ওজন', controller: _weight, keyboardType: TextInputType.number)),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: AppInput(hint: '/মিনিট', label: 'নাড়ির গতি', controller: _pulse, keyboardType: TextInputType.number)),
        const SizedBox(width: 12),
        Expanded(child: AppInput(hint: 'যেমন 120/80', label: 'রক্তচাপ (BP)', controller: _bp)),
      ]),
      const SizedBox(height: 16),
      ..._flagBody('পরীক্ষায় যা পাওয়া গেছে', _examFindings,
          target: _exam, color: AppColors.warningYellow),
      const SizedBox(height: 14),
      AppInput(hint: 'থাকলে লিখুন', label: 'অন্যান্য সমস্যা', controller: _other),
      const SizedBox(height: 20),

      // ── তলপেট পরীক্ষা (abdominal) ──
      _sectionTitle('তলপেট পরীক্ষা', Icons.child_friendly_rounded),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: AppInput(hint: 'সেমি', label: 'জরায়ুর উচ্চতা', controller: _fundal, keyboardType: TextInputType.number)),
        const SizedBox(width: 12),
        Expanded(child: AppInput(hint: '/মিনিট', label: 'ভ্রূণের হৃদস্পন্দন (FHR)', controller: _fhr, keyboardType: TextInputType.number)),
      ]),
      const SizedBox(height: 14),
      AppInput(hint: 'Lie / Presentation', label: 'ভ্রূণের অবস্থান', controller: _lie),
      const SizedBox(height: 14),
      _choiceRow('ভ্রূণের নড়াচড়া', _fetalMoveOpts, _fetalMove,
          (v) => setState(() => _fetalMove = _fetalMove == v ? '' : v)),
      const SizedBox(height: 12),
      _toggleChip('যোনিপথ (P/V) পরীক্ষা করা হয়েছে', _pvDone,
          (v) => setState(() => _pvDone = v)),
      const SizedBox(height: 20),

      // ── আবশ্যিক পরীক্ষা (mandatory tests) ──
      _sectionTitle('আবশ্যিক পরীক্ষা', Icons.science_outlined),
      const SizedBox(height: 10),
      AppInput(hint: 'g/dL', label: 'হিমোগ্লোবিন (Hb)', controller: _hb,
          keyboardType: TextInputType.number,
          prefixIcon: const Icon(Icons.bloodtype_outlined, color: AppColors.primary, size: 20)),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: AppInput(hint: 'nil/+/++', label: 'মূত্রে অ্যালবুমিন', controller: _urineAlb)),
        const SizedBox(width: 12),
        Expanded(child: AppInput(hint: 'nil/+/++', label: 'মূত্রে শর্করা', controller: _urineSugar)),
      ]),
      const SizedBox(height: 14),
      AppInput(hint: 'mg/dL', label: 'রক্তে শর্করা (GDM স্ক্রিন)', controller: _bsugar,
          keyboardType: TextInputType.number,
          prefixIcon: const Icon(Icons.water_drop_outlined, color: AppColors.primary, size: 20)),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: AppInput(hint: 'নেগেটিভ/পজিটিভ', label: 'HIV', controller: _hiv)),
        const SizedBox(width: 12),
        Expanded(child: AppInput(hint: 'নেগেটিভ/পজিটিভ', label: 'সিফিলিস', controller: _syphilis)),
      ]),
      const SizedBox(height: 14),
      AppInput(hint: 'ফল (থাকলে)', label: 'গর্ভকালীন ডায়াবিটিস (GDM)', controller: _gdm),
      const SizedBox(height: 12),
      _toggleChip('আল্ট্রাসোনোগ্রাফি (USG) করা হয়েছে', _usgDone,
          (v) => setState(() => _usgDone = v)),
      const SizedBox(height: 20),

      // ── অন্যান্য পরীক্ষা ──
      _sectionTitle('অন্যান্য পরীক্ষা', Icons.assignment_outlined),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: AppInput(hint: 'মান', label: 'TSH', controller: _tsh)),
        const SizedBox(width: 12),
        Expanded(child: AppInput(hint: 'নেগেটিভ/পজিটিভ', label: 'HBsAg', controller: _hbsag)),
      ]),
      const SizedBox(height: 20),

      // ── এই ভিজিটে যা দেওয়া হয়েছে (supplements/injection) ──
      _sectionTitle('এই ভিজিটে যা দেওয়া হয়েছে', Icons.medication_outlined),
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
      const SizedBox(height: 20),

      // ── যক্ষ্মা (TB) + বিপদচিহ্ন ──
      ..._flagBody('যক্ষ্মা (TB) লক্ষণ যাচাই', _ancTbSigns,
          target: _tb, color: AppColors.warningYellow),
      if (_tb.isNotEmpty) ...[
        const SizedBox(height: 10),
        _naatBanner(),
      ],
      const SizedBox(height: 18),
      ..._flagBody('বিপদচিহ্ন যাচাই করুন', _ancDangerSigns),
    ];
  }

  // Section header — a small icon + bold primary title, like the card's bands.
  Widget _sectionTitle(String t, IconData icon) => Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(t,
              style: AppTextStyles.label.copyWith(
                  color: AppColors.primary, fontWeight: FontWeight.w800)),
        ],
      );

  // Single-select row (e.g. ভ্রূণের নড়াচড়া: স্বাভাবিক/কম/নেই).
  Widget _choiceRow(String label, List<String> opts, String selected,
      void Function(String) onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: opts.map((o) {
            final sel = selected == o;
            return ChoiceChip(
              label: Text(o),
              selected: sel,
              selectedColor: AppColors.primary,
              backgroundColor: AppColors.surface,
              labelStyle: AppTextStyles.label.copyWith(
                  color: sel ? Colors.white : AppColors.textSecondary),
              onSelected: (_) => onTap(o),
            );
          }).toList(),
        ),
      ],
    );
  }

  // Yes/no toggle chip (e.g. P/V done, USG done).
  Widget _toggleChip(String label, bool value, void Function(bool) onChanged) {
    return FilterChip(
      label: Text(label),
      selected: value,
      showCheckmark: true,
      selectedColor: AppColors.safeGreen,
      backgroundColor: AppColors.surface,
      labelStyle: AppTextStyles.label
          .copyWith(color: value ? Colors.white : AppColors.textSecondary),
      onSelected: onChanged,
    );
  }

  List<Widget> _flagBody(String title, List<String> signs,
      {Set<String>? target, Color? color}) {
    final set = target ?? _flags;
    final c = color ?? AppColors.emergencyRed;
    return [
      Text(title, style: AppTextStyles.label),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: signs.map((s) {
          final sel = set.contains(s);
          return FilterChip(
            label: Text(s),
            selected: sel,
            showCheckmark: false,
            selectedColor: c,
            backgroundColor: AppColors.surface,
            labelStyle: AppTextStyles.label.copyWith(
              color: sel ? Colors.white : AppColors.textSecondary,
            ),
            onSelected: (on) =>
                setState(() => on ? set.add(s) : set.remove(s)),
          );
        }).toList(),
      ),
    ];
  }

  /// Shown when a TB symptom is flagged at ANC (WB MCP card → NAAT test).
  Widget _naatBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warningYellow.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warningYellow, width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.coronavirus_outlined, color: AppColors.warningYellow),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'টিবি সন্দেহ — কফ পরীক্ষা / NAAT করান এবং নিকটস্থ TB কেন্দ্রে জানান।',
              style: AppTextStyles.label.copyWith(
                  color: AppColors.textSecondary, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
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
