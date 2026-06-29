import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../../../core/utils/permissions.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/local_storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/components/app_header.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../app/routes.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_input.dart';
import '../../../../shared/widgets/module_art.dart';
import '../../../../shared/widgets/patient_photo.dart';
import '../../../patients/controller/patient_controller.dart';
import '../../../patients/data/models/patient_model.dart';
import '../../services/reminder_service.dart';

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
  final _formKey = GlobalKey<FormState>();
  // Voice dictation (same as Add Patient) for the free-text fields.
  final _stt = SpeechToText();
  bool _sttReady = false;
  String? _dictating;
  // Previous completed ANC for this patient → reference + trend comparison.
  Map<String, dynamic>? _prevAnc;
  String _prevAncDate = '';

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
  // Extra MCP-card ANC fields (exam + mandatory tests + notes).
  final _ga = TextEditingController();        // গর্ভকাল (সপ্তাহ)
  final _pulse = TextEditingController();      // নাড়ির গতি
  final _fhr = TextEditingController();        // গর্ভস্থ শিশুর হৃদস্পন্দন /মিনিট
  final _lie = TextEditingController();        // Lie / Presentation
  final _hiv = TextEditingController();        // HIV (R/NR)
  final _syphilis = TextEditingController();   // সিফিলিস (R/NR)
  final _usg = TextEditingController();        // আল্ট্রাসোনোগ্রাফি (হ্যাঁ/না)
  final _notes = TextEditingController();      // অন্যান্য সমস্যা / মন্তব্য
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
    'ফ্যাকাসে ভাব (রক্তাল্পতা)',
    'জন্ডিস',
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

  // ── HBNC: newborn measurements + mother PNC (MCP card pg 7) ──────────────
  final _hbWeight = TextEditingController(); // নবজাতকের ওজন (কেজি)
  final _hbTemp = TextEditingController();   // নবজাতকের তাপমাত্রা (°F)
  final _pncBp = TextEditingController();    // মায়ের রক্তচাপ
  final _pncTemp = TextEditingController();  // মায়ের তাপমাত্রা (°F)
  final Set<String> _pncFlags = {};
  static const _pncDangerSigns = [
    'অতিরিক্ত রক্তস্রাব',
    'দুর্গন্ধযুক্ত স্রাব (লোকিয়া)',
    'স্তন ফোলা / ব্যথা',
    'তীব্র জ্বর',
    'খিঁচুনি',
    'সেলাইয়ে সংক্রমণ',
    'বিষণ্নতা / মানসিক সমস্যা',
  ];

  // ── HBYC: growth (weight + MUAC → SAM/MAM) + services given ──────────────
  final _ycWeight = TextEditingController(); // ওজন (কেজি)
  final _ycMuac = TextEditingController();   // MUAC বাহুর মাপ (মিমি)
  final Set<String> _hbycGiven = {};
  static const _hbycGivenItems = [
    'ভিটামিন এ', 'ORS প্যাকেট', 'আয়রন সিরাপ', 'কৃমিনাশক', 'পুষ্টি পরামর্শ',
  ];

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    _e = args is Map ? Map<String, dynamic>.from(args) : <String, dynamic>{};
    // Pre-tick all vaccines for this visit (worker unticks any not given).
    if (_kind == 'vaccine') _given.addAll(_vaccines);
    _loadDraft(); // resume a half-filled visit, if any
    if (_kind == 'anc') _loadPrevAnc(); // last ANC → reference + trends
  }

  /// Loads the patient's most recent *completed* ANC record so this visit can
  /// show "গত বার" reference values, flag trends (Hb↓ / no weight gain / high
  /// BP), and carry forward the one-time tests (HIV/syphilis). Best-effort.
  Future<void> _loadPrevAnc() async {
    final pid = _e['patientId']?.toString() ?? '';
    if (pid.isEmpty) return;
    List<dynamic> evs;
    try {
      evs = await ApiService.getScheduleForPatient(pid);
    } catch (_) {
      return;
    }
    final done = evs
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((e) =>
            (e['kind']?.toString() == 'anc') &&
            (e['status']?.toString() == 'done') &&
            e['id']?.toString() != _id &&
            e['record'] is Map)
        .toList()
      // latest-dated previous ANC first
      ..sort((a, b) => (b['dueDate']?.toString() ?? '')
          .compareTo(a['dueDate']?.toString() ?? ''));
    if (done.isEmpty || !mounted) return;
    final rec = Map<String, dynamic>.from(done.first['record'] as Map);
    setState(() {
      _prevAnc = rec;
      // Show BOTH the scheduled (guideline) date and the day it was actually
      // recorded, e.g. "09/09/2026 · সম্পন্ন 27/06/2026".
      String f(dynamic v) {
        final dt = DateTime.tryParse((v ?? '').toString());
        if (dt == null) return '';
        String p(int n) => n.toString().padLeft(2, '0');
        return '${p(dt.day)}/${p(dt.month)}/${dt.year}';
      }

      final sched = f(done.first['dueDate']);
      final recd = f(done.first['doneDate'] ?? rec['completedAt']);
      _prevAncDate = (recd.isNotEmpty && recd != sched)
          ? '$sched · সম্পন্ন $recd'
          : (recd.isNotEmpty ? recd : sched);
      // Carry forward once-per-pregnancy results when this visit hasn't set them.
      if (_hiv.text.trim().isEmpty && (rec['hiv']?.toString() ?? '').isNotEmpty) {
        _hiv.text = rec['hiv'].toString();
      }
      if (_syphilis.text.trim().isEmpty && (rec['syphilis']?.toString() ?? '').isNotEmpty) {
        _syphilis.text = rec['syphilis'].toString();
      }
    });
  }

  /// Leading number from a free-text value ("10.4 g/dL" → 10.4, "120/80" → 120).
  double? _leadNum(String? s) {
    if (s == null) return null;
    final m = RegExp(r'[\d.]+').firstMatch(s);
    return m == null ? null : double.tryParse(m.group(0)!);
  }

  // ── Draft (resume later) ────────────────────────────────────────────────
  /// Everything the worker entered, so a half-done visit can be reopened.
  Map<String, dynamic> _draftMap() => {
        'given': _given.toList(),
        'ancGiven': _ancGiven.toList(),
        'flags': _flags.toList(),
        'tb': _tb.toList(),
        'bp': _bp.text, 'weight': _weight.text, 'hb': _hb.text,
        'bsugar': _bsugar.text, 'urineAlb': _urineAlb.text,
        'urineSugar': _urineSugar.text, 'fundal': _fundal.text,
        'ga': _ga.text, 'pulse': _pulse.text, 'fhr': _fhr.text,
        'lie': _lie.text, 'hiv': _hiv.text, 'syphilis': _syphilis.text,
        'usg': _usg.text, 'notes': _notes.text,
        'hbWeight': _hbWeight.text, 'hbTemp': _hbTemp.text,
        'pncBp': _pncBp.text, 'pncTemp': _pncTemp.text,
        'pncFlags': _pncFlags.toList(),
        'ycWeight': _ycWeight.text, 'ycMuac': _ycMuac.text,
        'hbycGiven': _hbycGiven.toList(),
      };

  void _applyDraft(Map<String, dynamic> d) {
    void fill(TextEditingController c, String k) {
      final v = d[k];
      if (v != null) c.text = v.toString();
    }
    fill(_bp, 'bp'); fill(_weight, 'weight'); fill(_hb, 'hb');
    fill(_bsugar, 'bsugar'); fill(_urineAlb, 'urineAlb');
    fill(_urineSugar, 'urineSugar'); fill(_fundal, 'fundal');
    fill(_ga, 'ga'); fill(_pulse, 'pulse'); fill(_fhr, 'fhr');
    fill(_lie, 'lie'); fill(_hiv, 'hiv'); fill(_syphilis, 'syphilis');
    fill(_usg, 'usg'); fill(_notes, 'notes');
    fill(_hbWeight, 'hbWeight'); fill(_hbTemp, 'hbTemp');
    fill(_pncBp, 'pncBp'); fill(_pncTemp, 'pncTemp');
    fill(_ycWeight, 'ycWeight'); fill(_ycMuac, 'ycMuac');
    void addAll(Set<String> s, String k) {
      final v = d[k];
      if (v is List) s.addAll(v.map((e) => e.toString()));
    }
    if (d['given'] is List) { _given.clear(); addAll(_given, 'given'); }
    addAll(_ancGiven, 'ancGiven');
    addAll(_flags, 'flags');
    addAll(_tb, 'tb');
    addAll(_pncFlags, 'pncFlags');
    addAll(_hbycGiven, 'hbycGiven');
  }

  void _loadDraft() {
    if (_id.isEmpty) return;
    final d = LocalStorageService.loadVisitDraft(_id);
    if (d != null) _applyDraft(d);
  }

  // Set once the visit is saved "done" — stops the exit auto-save from
  // re-creating a draft for an already-completed visit.
  bool _completed = false;

  /// Silently persist a half-filled visit when the worker leaves the screen, so
  /// it can be resumed later (replaces the old "save draft" button). Skips when
  /// the visit is already done/saving or nothing has been entered.
  Future<void> _autoSaveDraft() async {
    if (_id.isEmpty || _completed || _saving) return;
    final d = _draftMap();
    final hasData = d.values.any((v) =>
        (v is String && v.trim().isNotEmpty) || (v is List && v.isNotEmpty));
    if (!hasData) return;
    await LocalStorageService.saveVisitDraft(_id, d);
  }

  @override
  void dispose() {
    try { _stt.stop(); } catch (_) {}
    _bp.dispose();
    _weight.dispose();
    _hb.dispose();
    _bsugar.dispose();
    _urineAlb.dispose();
    _urineSugar.dispose();
    _fundal.dispose();
    _ga.dispose();
    _pulse.dispose();
    _fhr.dispose();
    _lie.dispose();
    _hiv.dispose();
    _syphilis.dispose();
    _usg.dispose();
    _notes.dispose();
    _hbWeight.dispose();
    _hbTemp.dispose();
    _pncBp.dispose();
    _pncTemp.dispose();
    _ycWeight.dispose();
    _ycMuac.dispose();
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

  bool get _hasDanger =>
      _flags.isNotEmpty ||
      _pncFlags.isNotEmpty ||
      _muacStatus == 'SAM' ||
      _autoAncFlags().isNotEmpty;

  /// True when this ANC visit is being opened before its clinical window opens
  /// (the due date is the window start). ANC1 (registration) is exempt — earlier
  /// is always fine. Some measurements aren't assessable yet when too early.
  bool get _tooEarly {
    if (_kind != 'anc') return false;
    if ((_e['code'] ?? '').toString() == 'ANC1') return false;
    final due = DateTime.tryParse((_e['dueDate'] ?? '').toString());
    if (due == null) return false;
    return DateTime.now().isBefore(DateTime(due.year, due.month, due.day));
  }

  String get _windowStartText {
    final due = DateTime.tryParse((_e['dueDate'] ?? '').toString());
    if (due == null) return '';
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(due.day)}/${p(due.month)}/${due.year}';
  }

  /// MUAC normalised to millimetres (accepts "11.5" cm or "115" mm).
  int? get _muacMm {
    final raw = _ycMuac.text.trim().replaceAll(RegExp(r'[^0-9.]'), '');
    final v = double.tryParse(raw);
    if (v == null || v <= 0) return null;
    return (v < 40 ? v * 10 : v).round(); // <40 → entered in cm
  }

  /// SAM (<115 mm) · MAM (115–124) · normal (≥125). Empty when no MUAC.
  String get _muacStatus {
    final mm = _muacMm;
    if (mm == null) return '';
    if (mm < 115) return 'SAM';
    if (mm < 125) return 'MAM';
    return 'normal';
  }

  // ── Voice dictation (free-text fields) ──────────────────────────────────
  Future<void> _initStt() async {
    final ok = await AppPermissions.requestMicrophone();
    if (!ok) {
      if (mounted) setState(() => _sttReady = false);
      return;
    }
    _sttReady = await _stt.initialize(
      onError: (_) {
        if (mounted) setState(() => _dictating = null);
      },
      onStatus: (s) {
        if ((s == SpeechToText.doneStatus || s == SpeechToText.notListeningStatus) &&
            mounted) {
          setState(() => _dictating = null);
        }
      },
    );
    if (mounted) setState(() {});
  }

  Future<void> _dictate(String field, TextEditingController ctrl) async {
    if (_dictating == field) {
      try { await _stt.stop(); } catch (_) {}
      if (mounted) setState(() => _dictating = null);
      return;
    }
    if (!_sttReady) {
      await _initStt();
      if (!_sttReady) {
        Get.snackbar('app_name'.tr, 'mic_permission_denied'.tr,
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppColors.warningYellow, colorText: Colors.white,
            margin: const EdgeInsets.all(16), borderRadius: 12);
        return;
      }
    }
    try { await _stt.stop(); } catch (_) {}
    if (mounted) setState(() => _dictating = field);
    await _stt.listen(
      listenOptions: SpeechListenOptions(
        localeId: 'bn_IN',
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: true,
      ),
      onResult: (r) {
        if (!mounted) return;
        ctrl.text = r.recognizedWords;
        ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length);
        if (r.finalResult && mounted) setState(() => _dictating = null);
      },
    );
  }

  Widget _micSuffix(String field, TextEditingController ctrl) {
    final active = _dictating == field;
    return IconButton(
      tooltip: 'speak'.tr,
      icon: Icon(active ? Icons.mic_rounded : Icons.mic_none_rounded,
          color: active ? AppColors.emergencyRed : AppColors.primary, size: 20),
      onPressed: () => _dictate(field, ctrl),
    );
  }

  // ── Validators (all optional — empty is allowed; flag implausible values) ──
  String? _vBp(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return null;
    final m = RegExp(r'^(\d{2,3})\s*/\s*(\d{2,3})$').firstMatch(s);
    if (m == null) return 'যেমন 120/80';
    final sys = int.parse(m.group(1)!), dia = int.parse(m.group(2)!);
    if (sys < 70 || sys > 260 || dia < 40 || dia > 160) return 'BP যাচাই করুন';
    return null;
  }

  String? Function(String?) _range(double min, double max, {String unit = ''}) =>
      (v) {
        final s = (v ?? '').trim();
        if (s.isEmpty) return null;
        final n = double.tryParse(s);
        if (n == null) return 'সংখ্যায় লিখুন';
        if (n < min || n > max) return 'মান $min–$max${unit.isNotEmpty ? ' $unit' : ''}';
        return null;
      };

  String? _vUrine(String? v) {
    final s = (v ?? '').trim().toLowerCase();
    if (s.isEmpty) return null;
    if (RegExp(r'^(nil|trace|\+{1,3})$').hasMatch(s)) return null;
    return 'nil / + / ++ / +++';
  }

  String? _vMuac(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return null;
    final n = double.tryParse(s.replaceAll(RegExp(r'[^0-9.]'), ''));
    if (n == null) return 'সংখ্যায় লিখুন';
    final mm = n < 40 ? n * 10 : n; // accept cm or mm
    if (mm < 70 || mm > 250) return 'MUAC যাচাই করুন';
    return null;
  }

  Future<void> _complete() async {
    if (!(_formKey.currentState?.validate() ?? true)) {
      Get.snackbar('তথ্য যাচাই করুন', 'লাল চিহ্নিত ঘরগুলো ঠিক করুন।',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.warningYellow, colorText: Colors.white,
          margin: const EdgeInsets.all(16), borderRadius: 12);
      return;
    }
    // Completing before the visit's window opens → confirm (some measurements
    // aren't assessable yet, and marking it done stops further reminders).
    if (_tooEarly) {
      final proceed = await Get.dialog<bool>(
        AlertDialog(
          title: const Text('সময়ের আগে?'),
          content: Text(
              'এই চেকআপ নির্ধারিত $_windowStartText থেকে। এখন সম্পন্ন করলে কিছু '
              'পরিমাপ সঠিক নাও হতে পারে এবং পরে আর মনে করানো হবে না। তবুও সম্পন্ন করবেন?'),
          actions: [
            TextButton(
                onPressed: () => Get.back(result: false),
                child: const Text('অপেক্ষা করুন')),
            TextButton(
                onPressed: () => Get.back(result: true),
                child: const Text('তবুও সম্পন্ন করুন')),
          ],
        ),
      );
      if (proceed != true) return;
    }
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
        'gaWeeks': _ga.text.trim(),
        'bp': _bp.text.trim(),
        'pulse': _pulse.text.trim(),
        'weight': _weight.text.trim(),
        'hb': _hb.text.trim(),
        'bloodSugar': _bsugar.text.trim(),
        'urineAlbumin': _urineAlb.text.trim(),
        'urineSugar': _urineSugar.text.trim(),
        'fundalHeight': _fundal.text.trim(),
        'fhr': _fhr.text.trim(),
        'lie': _lie.text.trim(),
        'hiv': _hiv.text.trim(),
        'syphilis': _syphilis.text.trim(),
        'usg': _usg.text.trim(),
        'notes': _notes.text.trim(),
        'supplementsGiven': _ancGiven.toList(),
        if (_tb.isNotEmpty) ...{
          'tbSymptoms': _tb.toList(),
          'naatNeeded': true,
        },
      },
      if (_kind == 'hbnc') ...{
        'babyWeight': _hbWeight.text.trim(),
        'babyTemp': _hbTemp.text.trim(),
        'motherPnc': {
          'bp': _pncBp.text.trim(),
          'temp': _pncTemp.text.trim(),
          if (_pncFlags.isNotEmpty) 'dangerFlags': _pncFlags.toList(),
        },
      },
      if (_kind == 'hbyc') ...{
        'weight': _ycWeight.text.trim(),
        'muac': _ycMuac.text.trim(),
        if (_muacStatus.isNotEmpty) 'muacStatus': _muacStatus,
        'servicesGiven': _hbycGiven.toList(),
      },
      if (_kind == 'pnc') ...{
        'bp': _pncBp.text.trim(),
        'temp': _pncTemp.text.trim(),
        if (_pncFlags.isNotEmpty) 'pncFlags': _pncFlags.toList(),
      },
      // Manual ticks + measurement-derived ANC flags (deduped).
      if ({..._flags, ..._autoAncFlags()}.isNotEmpty)
        'dangerFlags': {..._flags, ..._autoAncFlags()}.toList(),
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
    _completed = true;
    await LocalStorageService.clearVisitDraft(_id); // visit done → drop the draft
    // Find the next pending checkup for this patient to surface on completion.
    Map<String, dynamic>? next;
    final pid = _e['patientId']?.toString() ?? '';
    if (pid.isNotEmpty) {
      try {
        final evs = await ApiService.getScheduleForPatient(pid);
        final pending = evs
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .where((e) =>
                (e['status'] ?? '') != 'done' && (e['id']?.toString() ?? '') != _id)
            .toList()
          ..sort((a, b) =>
              (a['dueDate'] ?? '').toString().compareTo((b['dueDate'] ?? '').toString()));
        if (pending.isNotEmpty) next = pending.first;
      } catch (_) {}
    }
    if (!mounted) {
      Get.back(result: true);
      return;
    }
    await _showDoneDialog(next);
    Get.back(result: true); // due list refreshes
  }

  String _fmtDate(dynamic iso) {
    final d = DateTime.tryParse((iso ?? '').toString());
    if (d == null) return '';
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(d.day)}/${p(d.month)}/${d.year}';
  }

  /// Completion confirmation: success + the next checkup date + a one-tap remind.
  Future<void> _showDoneDialog(Map<String, dynamic>? next) async {
    final name = (_e['patientName'] ?? '').toString();
    final nextLabel = (next?['label'] ?? '').toString();
    final nextDate = next != null ? _fmtDate(next['dueDate']) : '';
    final action = await Get.dialog<String>(
      AlertDialog(
        title: Row(children: const [
          Icon(Icons.check_circle_rounded, color: AppColors.safeGreen),
          SizedBox(width: 8),
          Text('ভিজিট সম্পন্ন'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$name — $_label সম্পন্ন হয়েছে ✓', style: AppTextStyles.body),
            const SizedBox(height: 14),
            if (next != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('পরবর্তী চেকআপ',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 2),
                    Text('$nextLabel${nextDate.isNotEmpty ? ' — $nextDate' : ''}',
                        style: AppTextStyles.label.copyWith(
                            fontWeight: FontWeight.w700, color: AppColors.primary)),
                  ],
                ),
              )
            else
              Text('সব নির্ধারিত চেকআপ সম্পন্ন!',
                  style: AppTextStyles.label.copyWith(color: AppColors.safeGreen)),
          ],
        ),
        actions: [
          if (next != null)
            TextButton.icon(
              onPressed: () => Get.back(result: 'remind'),
              icon: const Icon(Icons.notifications_active_outlined, size: 18),
              label: const Text('মনে করান'),
            ),
          TextButton(
              onPressed: () => Get.back(result: 'ok'), child: const Text('ঠিক আছে')),
        ],
      ),
    );
    if (action == 'remind' && next != null) {
      await ReminderService.remind(Get.context!, {
        ...next,
        'patientName': name,
        'patientMobile': _e['patientMobile'] ?? _patient()?.mobile ?? '',
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Leaving a half-filled visit auto-saves a draft so it can be resumed.
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _autoSaveDraft();
      },
      child: Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          child: Column(
            children: [
              AppHeader(
                title: _e['patientName']?.toString().trim().isNotEmpty == true
                    ? _e['patientName'].toString()
                    : 'রোগী',
                subtitle: _label, // the ANC/checkup name now sits under the name
                leading: GestureDetector(onTap: _openProfile, child: _headerAvatar()),
                onTitleTap: _openProfile, // tap name → patient profile
                actions: [
                  HeaderActionCircle(
                    icon: Icons.call_rounded,
                    tooltip: 'ফোন করুন',
                    color: AppColors.safeGreen,
                    onTap: _callPatient,
                  ),
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _moduleIllustration(),
                      const SizedBox(height: 16),
                      if (_tooEarly) ...[
                        _tooEarlyBanner(),
                        const SizedBox(height: 12),
                      ],
                      Form(
                        key: _formKey,
                        child: Container(
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
                      ),
                      if (_hasDanger) ...[
                        const SizedBox(height: 16),
                        _dangerBanner(),
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
      ),
    );
  }

  // The patient this visit belongs to (from the cached list), for the header
  // avatar, the "open profile" tap, and the call action.
  PatientModel? _patient() {
    final pid = _e['patientId']?.toString() ?? '';
    if (pid.isEmpty || !Get.isRegistered<PatientController>()) return null;
    final list = Get.find<PatientController>().patients;
    final i = list.indexWhere((p) => p.id == pid);
    return i == -1 ? null : list[i];
  }

  ImageProvider? _patientPhoto() {
    final p = _patient();
    if (p == null) return null;
    return patientPhotoProvider(p.mcpDetails['photo']?.toString());
  }

  /// Header avatar — patient photo, or their initial on a tinted circle.
  Widget _headerAvatar() {
    final photo = _patientPhoto();
    final name = (_e['patientName']?.toString() ?? '').trim();
    return CircleAvatar(
      radius: 20,
      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
      backgroundImage: photo,
      child: photo == null
          ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: AppTextStyles.labelLg.copyWith(color: AppColors.primary))
          : null,
    );
  }

  /// Open this patient's profile (draft auto-saves via PopScope; visit stays
  /// underneath so the worker returns right where they left off).
  void _openProfile() {
    final p = _patient();
    if (p == null) {
      Get.snackbar('তথ্য নেই', 'রোগীর প্রোফাইল পাওয়া গেল না।',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    Get.toNamed(AppRoutes.patientProfile, arguments: p.toJson());
  }

  Future<void> _callPatient() async {
    final mobile =
        (_e['patientMobile'] ?? _patient()?.mobile ?? '').toString().replaceAll(RegExp(r'\D'), '');
    if (mobile.isEmpty) {
      Get.snackbar('নম্বর নেই', 'এই রোগীর মোবাইল নম্বর নেই।',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.warningYellow, colorText: Colors.white,
          margin: const EdgeInsets.all(16), borderRadius: 12);
      return;
    }
    try {
      await launchUrl(Uri.parse('tel:$mobile'), mode: LaunchMode.externalApplication);
    } catch (_) {
      Get.snackbar('খুলতে পারিনি', 'ফোন অ্যাপ খোলা গেল না।',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  /// Big, MCP-card-style illustration banner per module — makes the visit feel
  /// friendly + easy. Drop an image at `assets/illustrations/<kind>.png`
  /// (anc / pnc / hbnc / hbyc / vaccine) and it shows here automatically;
  /// absent → nothing (zero-height, no gap).
  Widget _moduleIllustration() => Container(
        height: 200,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          // Soft tinted backdrop so the contained image's letterbox blends in.
          color: const Color(0xFFFDEFE9),
          borderRadius: BorderRadius.circular(16),
        ),
        // Show the FULL illustration (no cropping) — fit inside the banner.
        child: Image.asset(
          'assets/illustrations/$_kind.png',
          fit: BoxFit.contain,
          // No PNG dropped in → show the code-drawn illustration for this module.
          errorBuilder: (_, __, ___) => ModuleArt(kind: _kind, height: 200),
        ),
      );

  List<Widget> _body() {
    switch (_kind) {
      case 'vaccine':
        return _vaccineBody();
      case 'anc':
        return _ancBody();
      case 'hbnc':
        return _hbncBody();
      case 'hbyc':
        return _hbycBody();
      case 'pnc':
        return _pncBody();
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

  /// "গত বার" reference card — last ANC's key values for at-a-glance comparison.
  Widget _prevAncCard() {
    final p = _prevAnc!;
    String v(String k) => (p[k]?.toString() ?? '').trim();
    final bits = <String>[
      if (v('bp').isNotEmpty) 'BP ${v('bp')}',
      if (v('weight').isNotEmpty) 'ওজন ${v('weight')} কেজি',
      if (v('hb').isNotEmpty) 'Hb ${v('hb')}',
      if (v('bloodSugar').isNotEmpty) 'সুগার ${v('bloodSugar')}',
    ];
    if (bits.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text('গত বার${_prevAncDate.isNotEmpty ? ' ($_prevAncDate)' : ''}',
                  style: AppTextStyles.label.copyWith(
                      color: AppColors.primary, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 4),
          Text(bits.join('  ·  '),
              style: AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  /// Small inline trend hint under a vital (color-coded). Empty when no signal.
  Widget _trendChip(String text, Color color) => Padding(
        padding: const EdgeInsets.only(top: 4, left: 2),
        child: Row(
          children: [
            Icon(Icons.trending_flat_rounded, size: 14, color: color),
            const SizedBox(width: 4),
            Expanded(
              child: Text(text,
                  style: AppTextStyles.label
                      .copyWith(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

  Widget _hbTrend() {
    final cur = _leadNum(_hb.text);
    final prev = _leadNum(_prevAnc?['hb']?.toString());
    if (cur != null && cur < 7) {
      return _trendChip('⚠ তীব্র রক্তাল্পতা (Hb < ৭) — রেফার করুন', AppColors.emergencyRed);
    }
    if (cur == null || prev == null) return const SizedBox.shrink();
    if (cur < prev) return _trendChip('↓ Hb কমেছে (গত বার $prev)', AppColors.emergencyRed);
    return _trendChip('✓ গত বার $prev', AppColors.safeGreen);
  }

  Widget _weightTrend() {
    final cur = _leadNum(_weight.text);
    final prev = _leadNum(_prevAnc?['weight']?.toString());
    if (cur == null || prev == null) return const SizedBox.shrink();
    if (cur <= prev) {
      return _trendChip('ওজন বাড়েনি (গত বার $prev কেজি)', AppColors.warningYellow);
    }
    return _trendChip('✓ +${(cur - prev).toStringAsFixed(1)} কেজি', AppColors.safeGreen);
  }

  Widget _bpTrend() {
    final parts = _bp.text.split('/');
    final sys = _leadNum(parts.isNotEmpty ? parts[0] : '');
    final dia = _leadNum(parts.length > 1 ? parts[1] : '');
    if ((sys != null && sys >= 140) || (dia != null && dia >= 90)) {
      return _trendChip('⚠ উচ্চ রক্তচাপ (≥140/90) — মনোযোগ দিন', AppColors.emergencyRed);
    }
    return const SizedBox.shrink();
  }

  /// Danger signs auto-derived from the ANC measurements (so the 1st ANC visit
  /// raises real flags even when the worker doesn't tick a checkbox). These are
  /// merged with the manually-ticked [_flags] when the visit is saved.
  List<String> _autoAncFlags() {
    if (_kind != 'anc') return const [];
    final out = <String>[];
    final parts = _bp.text.split('/');
    final sys = _leadNum(parts.isNotEmpty ? parts[0] : '');
    final dia = _leadNum(parts.length > 1 ? parts[1] : '');
    if ((sys != null && sys >= 140) || (dia != null && dia >= 90)) {
      out.add('উচ্চ রক্তচাপ (≥১৪০/৯০)');
    }
    final hb = _leadNum(_hb.text);
    if (hb != null) {
      if (hb < 7) {
        out.add('তীব্র রক্তাল্পতা (Hb < ৭)');
      } else if (hb < 11) {
        out.add('রক্তাল্পতা (Hb < ১১)');
      }
    }
    final alb = _urineAlb.text.trim().toLowerCase();
    const negatives = ['', 'nil', 'absent', 'negative', 'neg', '0', '-', 'নেই', 'অনুপস্থিত'];
    if (!negatives.contains(alb)) {
      out.add('মূত্রে অ্যালবুমিন (প্রি-এক্লাম্পসিয়া ঝুঁকি)');
    }
    return out;
  }

  List<Widget> _ancBody() {
    return [
      if (_prevAnc != null) ...[
        _prevAncCard(),
        const SizedBox(height: 14),
      ],
      Text('পরিমাপ লিখুন', style: AppTextStyles.label),
      const SizedBox(height: 8),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: AppInput(
              hint: 'সপ্তাহ',
              label: 'গর্ভকাল (সপ্তাহ)',
              controller: _ga,
              keyboardType: TextInputType.number,
              validator: _range(1, 45, unit: 'সপ্তাহ'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AppInput(
              hint: '/মিনিট',
              label: 'নাড়ির গতি',
              controller: _pulse,
              keyboardType: TextInputType.number,
              validator: _range(30, 200),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      AppInput(
        hint: 'যেমন 120/80',
        label: 'রক্তচাপ (BP)',
        controller: _bp,
        prefixIcon: const Icon(Icons.favorite_outline, color: AppColors.primary, size: 20),
        suffixIcon: _micSuffix('bp', _bp),
        validator: _vBp,
        onChanged: (_) => setState(() {}),
      ),
      _bpTrend(),
      const SizedBox(height: 14),
      AppInput(
        hint: 'কেজি',
        label: 'ওজন',
        controller: _weight,
        keyboardType: TextInputType.number,
        prefixIcon: const Icon(Icons.monitor_weight_outlined, color: AppColors.primary, size: 20),
        validator: _range(25, 200, unit: 'কেজি'),
        onChanged: (_) => setState(() {}),
      ),
      _weightTrend(),
      const SizedBox(height: 14),
      AppInput(
        hint: 'g/dL',
        label: 'হিমোগ্লোবিন (Hb)',
        controller: _hb,
        keyboardType: TextInputType.number,
        prefixIcon: const Icon(Icons.bloodtype_outlined, color: AppColors.primary, size: 20),
        validator: _range(2, 20),
        onChanged: (_) => setState(() {}),
      ),
      _hbTrend(),
      const SizedBox(height: 14),
      AppInput(
        hint: 'mg/dL',
        label: 'রক্তে শর্করা (Blood sugar)',
        controller: _bsugar,
        keyboardType: TextInputType.number,
        prefixIcon: const Icon(Icons.water_drop_outlined, color: AppColors.primary, size: 20),
        validator: _range(30, 500),
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
              validator: _vUrine,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AppInput(
              hint: 'nil/+/++',
              label: 'মূত্রে শর্করা',
              controller: _urineSugar,
              validator: _vUrine,
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
        validator: _range(10, 45),
      ),
      const SizedBox(height: 14),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: AppInput(
              hint: '/মিনিট',
              label: 'শিশুর হৃদস্পন্দন (FHR)',
              controller: _fhr,
              keyboardType: TextInputType.number,
              validator: _range(60, 220),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AppInput(
              hint: 'Lie / Presentation',
              label: 'গর্ভস্থ অবস্থান',
              controller: _lie,
              suffixIcon: _micSuffix('lie', _lie),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Text('আবশ্যিক পরীক্ষা', style: AppTextStyles.label),
      const SizedBox(height: 8),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: AppInput(hint: 'R / NR', label: 'HIV', controller: _hiv),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AppInput(hint: 'R / NR', label: 'সিফিলিস', controller: _syphilis),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AppInput(hint: 'হ্যাঁ/না', label: 'USG', controller: _usg),
          ),
        ],
      ),
      const SizedBox(height: 14),
      AppInput(
        hint: 'অন্যান্য সমস্যা / মন্তব্য',
        label: 'মন্তব্য',
        controller: _notes,
        maxLines: 2,
        suffixIcon: _micSuffix('notes', _notes),
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
      const SizedBox(height: 18),
      ..._flagBody('যক্ষ্মা (TB) লক্ষণ যাচাই', _ancTbSigns,
          target: _tb, color: AppColors.warningYellow),
      if (_tb.isNotEmpty) ...[
        const SizedBox(height: 10),
        _naatBanner(),
      ],
    ];
  }

  // ── PNC: mother's postnatal visit (own schedule, from delivery date) ──────
  List<Widget> _pncBody() {
    return [
      Text('মায়ের প্রসব-পরবর্তী অবস্থা (PNC)', style: AppTextStyles.label),
      const SizedBox(height: 8),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: AppInput(
                hint: 'যেমন 110/70',
                label: 'রক্তচাপ (BP)',
                controller: _pncBp,
                suffixIcon: _micSuffix('pncBp', _pncBp),
                validator: _vBp),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AppInput(
                hint: '°F',
                label: 'তাপমাত্রা',
                controller: _pncTemp,
                keyboardType: TextInputType.number,
                validator: _range(90, 110)),
          ),
        ],
      ),
      const SizedBox(height: 14),
      ..._flagBody('মায়ের বিপদচিহ্ন যাচাই করুন', _pncDangerSigns, target: _pncFlags),
    ];
  }

  // ── HBNC: postnatal home visit — mother PNC + newborn (MCP card pg 7) ─────
  List<Widget> _hbncBody() {
    Widget num2(String l1, TextEditingController c1, String h1, String l2,
            TextEditingController c2, String h2,
            {String? Function(String?)? v1,
            String? Function(String?)? v2,
            bool number1 = false}) =>
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
                child: AppInput(
                    hint: h1,
                    label: l1,
                    controller: c1,
                    keyboardType: number1 ? TextInputType.number : null,
                    validator: v1)),
            const SizedBox(width: 12),
            Expanded(
                child: AppInput(
                    hint: h2,
                    label: l2,
                    controller: c2,
                    keyboardType: TextInputType.number,
                    validator: v2)),
          ],
        );
    return [
      Text('মায়ের প্রসব-পরবর্তী অবস্থা (PNC)', style: AppTextStyles.label),
      const SizedBox(height: 8),
      num2('রক্তচাপ (BP)', _pncBp, 'যেমন 110/70', 'তাপমাত্রা (°F)', _pncTemp, '°F',
          v1: _vBp, v2: _range(90, 110)),
      const SizedBox(height: 14),
      ..._flagBody('মায়ের বিপদচিহ্ন', _pncDangerSigns, target: _pncFlags),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Divider(height: 1),
      ),
      Text('নবজাতকের অবস্থা', style: AppTextStyles.label),
      const SizedBox(height: 8),
      num2('ওজন (কেজি)', _hbWeight, 'কেজি', 'তাপমাত্রা (°F)', _hbTemp, '°F',
          number1: true, v1: _range(0.5, 8), v2: _range(90, 110)),
      const SizedBox(height: 14),
      ..._flagBody('নবজাতকের বিপদচিহ্ন যাচাই করুন', _newbornDangerSigns),
    ];
  }

  // ── HBYC: growth (weight + MUAC → SAM/MAM) + services + care (pg 8) ───────
  List<Widget> _hbycBody() {
    final status = _muacStatus;
    return [
      Text('বৃদ্ধি পর্যবেক্ষণ', style: AppTextStyles.label),
      const SizedBox(height: 8),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: AppInput(
                hint: 'কেজি',
                label: 'ওজন',
                controller: _ycWeight,
                keyboardType: TextInputType.number,
                validator: _range(1, 30, unit: 'কেজি')),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AppInput(
                hint: 'মিমি (যেমন 125)',
                label: 'MUAC (বাহুর মাপ)',
                controller: _ycMuac,
                keyboardType: TextInputType.number,
                validator: _vMuac,
                onChanged: (_) => setState(() {})),
          ),
        ],
      ),
      if (status.isNotEmpty) ...[
        const SizedBox(height: 10),
        _muacBanner(status),
      ],
      const SizedBox(height: 16),
      Text('এই ভিজিটে দেওয়া হয়েছে', style: AppTextStyles.label),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _hbycGivenItems.map((s) {
          final sel = _hbycGiven.contains(s);
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
                setState(() => on ? _hbycGiven.add(s) : _hbycGiven.remove(s)),
          );
        }).toList(),
      ),
      const SizedBox(height: 18),
      ..._flagBody('শিশুর যত্ন ও বিপদচিহ্ন যাচাই করুন', _hbycSigns),
    ];
  }

  /// MUAC → nutrition status banner (SAM red / MAM amber / normal green).
  Widget _muacBanner(String status) {
    final (color, text) = switch (status) {
      'SAM' => (
          AppColors.emergencyRed,
          'তীব্র অপুষ্টি (SAM) — এখনই NRC/পুষ্টি পুনর্বাসন কেন্দ্রে রেফার করুন।'
        ),
      'MAM' => (
          AppColors.warningYellow,
          'মাঝারি অপুষ্টি (MAM) — পুষ্টি পরামর্শ ও ঘন ঘন ফলো-আপ দিন।'
        ),
      _ => (AppColors.safeGreen, 'বাহুর মাপ স্বাভাবিক।'),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.straighten_rounded, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: AppTextStyles.label
                    .copyWith(color: color, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
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

  // Shown when an ANC visit is opened before its window starts.
  Widget _tooEarlyBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warningYellow.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warningYellow, width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule_rounded, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'এই চেকআপ এখনও সময়ের আগে (নির্ধারিত $_windowStartText থেকে)। '
              'কিছু পরিমাপ (যেমন বৃদ্ধি, হৃৎস্পন্দন) এখন সঠিক নাও হতে পারে — '
              'সম্ভব হলে সময়মতো করুন।',
              style: AppTextStyles.label.copyWith(
                  color: AppColors.accentDeep, fontWeight: FontWeight.w600, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
