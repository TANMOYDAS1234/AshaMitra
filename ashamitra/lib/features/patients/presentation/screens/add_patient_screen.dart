import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/permissions.dart';
import '../../../../shared/components/app_header.dart';
import '../../../../shared/widgets/app_input.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../core/utils/validators.dart';
import '../../controller/patient_controller.dart';
import '../../data/models/patient_model.dart';
import '../../data/patient_matcher.dart';
import '../../../../core/services/api_service.dart';
import '../../../../shared/widgets/patient_photo.dart';
import '../../../../shared/widgets/module_art.dart';
import '../../../schedule/services/checkup_launcher.dart';
import 'aadhaar_scanner_screen.dart';

class AddPatientScreen extends StatefulWidget {
  const AddPatientScreen({super.key});

  @override
  State<AddPatientScreen> createState() => _AddPatientScreenState();
}

class _AddPatientScreenState extends State<AddPatientScreen> {
  late final PatientController _ctrl;
  final _formKey = GlobalKey<FormState>();
  String _caseType = 'Pregnancy';
  String _gender = 'Female';
  // Age unit: 'days' | 'months' | 'years'. Drives how the engine reads age
  // (newborn 0–28 d vs child 2 mo–5 y vs mother's age in years). Defaults
  // smartly from the case type so a newborn's "6" is never read as 6 years.
  String _ageUnit = 'years';
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _villageCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();

  // ── Maternal & child tracking (MCP-card aligned) ────────────────────────
  // These dates are the keystone: entering LMP (pregnancy) or DOB (child/
  // newborn) makes the server auto-generate the ANC / immunization / HBNC
  // due-date schedule for this patient. All optional so a quick save still works.
  final _guardianCtrl = TextEditingController(); // mother's name when child
  String? _motherId; // linked mother's patient id (anchors a child's identity)
  String? _motherPersonId; // stable mother identity (groups her pregnancies)
  DateTime? _dob;   // child / newborn date of birth
  DateTime? _lmp;   // last menstrual period (pregnancy)
  DateTime? _deliveryDate; // mother's actual delivery date → drives PNC schedule
  bool _isTwin = false;
  int _birthOrder = 1; // which of a twin pair (1 or 2)
  bool _scanning = false; // Aadhaar OCR in progress
  bool _saving = false; // patient save → Atlas in progress
  String? _photoB64; // patient photo (compressed JPEG → base64), synced in mcpDetails
  bool _suppressAgeListener = false; // guards the age↔DOB sync from looping
  DateTime? get _edd => _lmp?.add(const Duration(days: 280));

  // ── Full MCP-card identity fields (pg 3) ────────────────────────────────
  // Config-driven so the ~27 fields stay maintainable. `cases` empty = shown
  // for every case type. Values collect into PatientModel.mcpDetails (a map).
  final Map<String, TextEditingController> _mcpCtrls = {};
  final Map<String, bool> _mcpBools = {};
  TextEditingController _mcpCtrl(String key) =>
      _mcpCtrls.putIfAbsent(key, () => TextEditingController());

  static const List<
      ({String key, String label, String section, List<String> cases, bool number, bool isBool})>
      _mcpFields = [
    // পরিবার পরিচয়
    (key: 'nameEn',        label: 'ইংরেজি নাম (Aadhaar — official)', section: 'পরিবার পরিচয়', cases: [], number: false, isBool: false),
    (key: 'fatherName',    label: 'বাবার নাম',              section: 'পরিবার পরিচয়', cases: [], number: false, isBool: false),
    (key: 'address',       label: 'ঠিকানা',                 section: 'পরিবার পরিচয়', cases: [], number: false, isBool: false),
    (key: 'fatherMobile',  label: 'বাবার মোবাইল',           section: 'পরিবার পরিচয়', cases: [], number: true,  isBool: false),
    (key: 'rchId',         label: 'RCH / MCTS নিবন্ধন নং',  section: 'পরিবার পরিচয়', cases: [], number: false, isBool: false),
    (key: 'motherAadhaar', label: 'মায়ের আধার নং',          section: 'পরিবার পরিচয়', cases: [], number: true,  isBool: false),
    (key: 'childAadhaar',  label: 'শিশুর আধার নং',          section: 'পরিবার পরিচয়', cases: ['Newborn', 'Child'], number: true, isBool: false),
    // ব্যাঙ্ক ও যোজনা
    (key: 'pmmvyEligible', label: 'PMMVY-র জন্য যোগ্য?',     section: 'ব্যাঙ্ক ও যোজনা', cases: [], number: false, isBool: true),
    (key: 'jsyRegNo',      label: 'JSY নিবন্ধন নং',          section: 'ব্যাঙ্ক ও যোজনা', cases: [], number: false, isBool: false),
    (key: 'bankName',      label: 'ব্যাঙ্ক ও শাখার নাম',     section: 'ব্যাঙ্ক ও যোজনা', cases: [], number: false, isBool: false),
    (key: 'bankAccount',   label: 'অ্যাকাউন্ট নং',           section: 'ব্যাঙ্ক ও যোজনা', cases: [], number: true,  isBool: false),
    (key: 'ifsc',          label: 'IFSC কোড',               section: 'ব্যাঙ্ক ও যোজনা', cases: [], number: false, isBool: false),
    // জনতাত্ত্বিক (demographics — register columns: religion / caste / blood group)
    (key: 'religion',   label: 'ধর্ম',           section: 'জনতাত্ত্বিক', cases: [], number: false, isBool: false),
    (key: 'caste',      label: 'জাতিগত শ্রেণি',  section: 'জনতাত্ত্বিক', cases: [], number: false, isBool: false),
    (key: 'bloodGroup', label: 'রক্তের গ্রুপ',   section: 'জনতাত্ত্বিক', cases: [], number: false, isBool: false),
    // গর্ভাবস্থা — gravida/para/abortion (G-P-L-A) + living children + delivery
    (key: 'gravida',          label: 'গর্ভসঞ্চারের সংখ্যা (Gravida)', section: 'গর্ভাবস্থা', cases: ['Pregnancy'], number: true,  isBool: false),
    (key: 'para',             label: 'পূর্ববর্তী প্রসব (Para)',       section: 'গর্ভাবস্থা', cases: ['Pregnancy'], number: true,  isBool: false),
    (key: 'prevLiveBirths',   label: 'জীবিত শিশুর সংখ্যা',           section: 'গর্ভাবস্থা', cases: ['Pregnancy'], number: true,  isBool: false),
    (key: 'abortions',        label: 'গর্ভপাত / মৃত প্রসব সংখ্যা',    section: 'গর্ভাবস্থা', cases: ['Pregnancy'], number: true,  isBool: false),
    (key: 'lastChildAge',     label: 'সর্বশেষ সন্তানের বয়স (বছর)',    section: 'গর্ভাবস্থা', cases: ['Pregnancy'], number: true,  isBool: false),
    (key: 'lastDeliveryPlace',label: 'সর্বশেষ প্রসবের স্থান',         section: 'গর্ভাবস্থা', cases: ['Pregnancy'], number: false, isBool: false),
    (key: 'plannedDelivery',  label: 'চিহ্নিত প্রসব কেন্দ্র',         section: 'গর্ভাবস্থা', cases: ['Pregnancy'], number: false, isBool: false),
    (key: 'pregnancyOutcome', label: 'গর্ভাবস্থার ফলাফল',           section: 'গর্ভাবস্থা', cases: ['Pregnancy'], number: false, isBool: false),
    // ঝুঁকির ইতিহাস — prior obstetric complications (MCP card pg 5); any → high-risk
    (key: 'histAPH',        label: 'পূর্বে গর্ভকালীন রক্তস্রাব (APH)',     section: 'ঝুঁকির ইতিহাস', cases: ['Pregnancy'], number: false, isBool: true),
    (key: 'histPPH',        label: 'পূর্বে প্রসবোত্তর রক্তস্রাব (PPH)',     section: 'ঝুঁকির ইতিহাস', cases: ['Pregnancy'], number: false, isBool: true),
    (key: 'histEclampsia',  label: 'পূর্বে খিঁচুনি / এক্লাম্পসিয়া',        section: 'ঝুঁকির ইতিহাস', cases: ['Pregnancy'], number: false, isBool: true),
    (key: 'histPIH',        label: 'পূর্বে গর্ভকালীন উচ্চ রক্তচাপ (PIH)',   section: 'ঝুঁকির ইতিহাস', cases: ['Pregnancy'], number: false, isBool: true),
    (key: 'histLSCS',       label: 'পূর্বে সিজার (LSCS)',                  section: 'ঝুঁকির ইতিহাস', cases: ['Pregnancy'], number: false, isBool: true),
    (key: 'histObstructed', label: 'পূর্বে বাধাপ্রাপ্ত প্রসব',             section: 'ঝুঁকির ইতিহাস', cases: ['Pregnancy'], number: false, isBool: true),
    (key: 'histAbortion',   label: 'পূর্বে গর্ভপাত / মৃত শিশু',            section: 'ঝুঁকির ইতিহাস', cases: ['Pregnancy'], number: false, isBool: true),
    (key: 'histCongenital', label: 'পূর্বে জন্মগত ত্রুটিযুক্ত শিশু',        section: 'ঝুঁকির ইতিহাস', cases: ['Pregnancy'], number: false, isBool: true),
    // দীর্ঘমেয়াদি অসুখ — chronic disease history (MCP card pg 5); any → high-risk
    (key: 'chrTB',           label: 'যক্ষ্মা (TB)',      section: 'দীর্ঘমেয়াদি অসুখ', cases: ['Pregnancy'], number: false, isBool: true),
    (key: 'chrHypertension', label: 'উচ্চ রক্তচাপ',     section: 'দীর্ঘমেয়াদি অসুখ', cases: ['Pregnancy'], number: false, isBool: true),
    (key: 'chrHeart',        label: 'হৃদরোগ',          section: 'দীর্ঘমেয়াদি অসুখ', cases: ['Pregnancy'], number: false, isBool: true),
    (key: 'chrDiabetes',     label: 'ডায়াবেটিস',        section: 'দীর্ঘমেয়াদি অসুখ', cases: ['Pregnancy'], number: false, isBool: true),
    (key: 'chrAsthma',       label: 'হাঁপানি',          section: 'দীর্ঘমেয়াদি অসুখ', cases: ['Pregnancy'], number: false, isBool: true),
    // জন্ম রেকর্ড
    (key: 'birthWeight',   label: 'জন্ম ওজন (কেজি)',         section: 'জন্ম রেকর্ড', cases: ['Newborn', 'Child'], number: true,  isBool: false),
    (key: 'birthTime',     label: 'জন্মের সময়',             section: 'জন্ম রেকর্ড', cases: ['Newborn', 'Child'], number: false, isBool: false),
    (key: 'deliveryPlace', label: 'প্রসবের স্থান',           section: 'জন্ম রেকর্ড', cases: ['Newborn', 'Child'], number: false, isBool: false),
    (key: 'birthRegNo',    label: 'জন্ম নিবন্ধন নং',         section: 'জন্ম রেকর্ড', cases: ['Newborn', 'Child'], number: false, isBool: false),
    (key: 'childRchId',    label: 'শিশুর MCTS / RCH / নিবন্ধন নং', section: 'জন্ম রেকর্ড', cases: ['Newborn', 'Child'], number: false, isBool: false),
    // প্রতিষ্ঠান (MCP card pg 3 — institution block)
    (key: 'anganwadiCentre', label: 'অঙ্গনওয়াড়ি কেন্দ্র',       section: 'প্রতিষ্ঠান', cases: [], number: false, isBool: false),
    (key: 'awcNumber',       label: 'অঙ্গনওয়াড়ি কেন্দ্র নং',    section: 'প্রতিষ্ঠান', cases: [], number: true,  isBool: false),
    (key: 'lgdCode',         label: 'LGD কোড',                section: 'প্রতিষ্ঠান', cases: [], number: false, isBool: false),
    (key: 'panchayat',       label: 'গ্রাম পঞ্চায়েত / ওয়ার্ড',  section: 'প্রতিষ্ঠান', cases: [], number: false, isBool: false),
    (key: 'block',           label: 'ব্লক / মিউনিসিপ্যাল বডি',  section: 'প্রতিষ্ঠান', cases: [], number: false, isBool: false),
    (key: 'postOffice',      label: 'পোস্ট অফিস',             section: 'প্রতিষ্ঠান', cases: [], number: false, isBool: false),
    (key: 'pincode',         label: 'পোস্টাল কোড (পিন)',       section: 'প্রতিষ্ঠান', cases: [], number: true,  isBool: false),
    (key: 'anmName',         label: 'ANM / FHW / FTS নাম',     section: 'প্রতিষ্ঠান', cases: [], number: false, isBool: false),
    (key: 'anmMobile',       label: 'ANM / FTS মোবাইল',        section: 'প্রতিষ্ঠান', cases: [], number: true,  isBool: false),
    (key: 'deliveryCentrePhone', label: 'প্রসব কেন্দ্রের ফোন নং', section: 'প্রতিষ্ঠান', cases: [], number: true, isBool: false),
    (key: 'facilityName',    label: 'প্রাথমিক স্বাস্থ্যকেন্দ্র (PHC/UPHC)', section: 'প্রতিষ্ঠান', cases: [], number: false, isBool: false),
    (key: 'bphc',            label: 'ব্লক প্রাথমিক স্বাস্থ্যকেন্দ্র (BPHC)', section: 'প্রতিষ্ঠান', cases: [], number: false, isBool: false),
    (key: 'ruralHospital',   label: 'গ্রামীণ হাসপাতাল (RH)',    section: 'প্রতিষ্ঠান', cases: [], number: false, isBool: false),
    (key: 'district',        label: 'জেলা',                   section: 'প্রতিষ্ঠান', cases: [], number: false, isBool: false),
    (key: 'subcentreName',   label: 'উপস্বাস্থ্যকেন্দ্রের নাম',  section: 'প্রতিষ্ঠান', cases: [], number: false, isBool: false),
    (key: 'subcentreRegNo',  label: 'উপকেন্দ্র নিবন্ধন নং',     section: 'প্রতিষ্ঠান', cases: [], number: false, isBool: false),
    (key: 'referralHospital',label: 'রেফারেল হাসপাতাল',        section: 'প্রতিষ্ঠান', cases: [], number: false, isBool: false),
    (key: 'vhndDay',         label: 'স্বাস্থ্য পুষ্টি দিবস',    section: 'প্রতিষ্ঠান', cases: [], number: false, isBool: false),
  ];

  // Enumerable fields render as dropdowns (better data quality than free text).
  // The selected option is stored in the field's controller text, so it flows
  // through _collectMcp / edit-load unchanged like any other text field.
  static const Map<String, List<String>> _fieldOptions = {
    'religion':   ['হিন্দু', 'মুসলিম', 'খ্রিস্টান', 'শিখ', 'বৌদ্ধ', 'অন্যান্য'],
    'caste':      ['সাধারণ (General)', 'SC', 'ST', 'OBC', 'BPL'],
    'bloodGroup': ['A+', 'A−', 'B+', 'B−', 'O+', 'O−', 'AB+', 'AB−', 'জানা নেই'],
    'pregnancyOutcome': ['জীবিত শিশুর প্রসব', 'মৃত শিশুর প্রসব', 'প্রযোজ্য নয়'],
  };

  // ── Speak-to-fill (voice dictation for free-text fields) ────────────────
  // Many ASHA workers type slowly; letting them speak the name/village in
  // Bengali fills the field in Bengali script via on-device STT. Lazily
  // initialised on first mic tap so we never prompt for the mic on open.
  final _stt = SpeechToText();
  bool _sttReady = false;
  String? _dictating; // 'name' | 'village' | null — which field is active

  /// If non-null, this screen is in EDIT mode for an existing patient.
  /// Pre-fills the form fields and the Save button calls updatePatient
  /// instead of addPatient. Triage-derived fields (outcome, reason,
  /// nextStep, qaHistory, risk, lastVisit) are preserved unchanged.
  PatientModel? _editing;

  @override
  void initState() {
    super.initState();
    _ctrl = Get.isRegistered<PatientController>()
        ? Get.find<PatientController>()
        : Get.put(PatientController(), permanent: true);

    // Edit-mode detection: pass the existing PatientModel as Get.arguments.
    final args = Get.arguments;
    if (args is PatientModel) {
      _editing = args;
      _nameCtrl.text    = args.name;
      _ageCtrl.text     = args.age;
      _villageCtrl.text = args.village == 'Unknown' || args.village == '—' ? '' : args.village;
      _mobileCtrl.text  = args.mobile;
      _caseType = args.type;
      _gender   = args.gender.isNotEmpty ? args.gender : 'Female';
      _ageUnit  = args.ageUnit.isNotEmpty ? args.ageUnit : _defaultAgeUnit(args.type);
      _dob          = args.dob;
      _lmp          = args.lmp;
      _deliveryDate = args.deliveryDate;
      _guardianCtrl.text = args.guardianName;
      _motherId     = args.motherId;
      _isTwin       = args.isTwin;
      _birthOrder   = args.birthOrder > 0 ? args.birthOrder : 1;
      for (final f in _mcpFields) {
        final v = args.mcpDetails[f.key];
        if (v == null) continue;
        if (f.isBool) {
          _mcpBools[f.key] = v == true;
        } else {
          _mcpCtrl(f.key).text = v.toString();
        }
      }
      _photoB64 = args.mcpDetails['photo']?.toString();
      _motherPersonId = args.mcpDetails['motherPersonId']?.toString();
    } else if (args is Map<String, dynamic>) {
      // 1b fix: when the worker reaches Add Patient from a case tile on the
      // dashboard, the case ID is passed in as 'caseType'. Pre-select that
      // chip so they don't have to manually pick the case again — they
      // already told us which case they're filing a patient for.
      final preselected = args['caseType']?.toString();
      if (preselected != null && preselected.isNotEmpty &&
          ['Pregnancy', 'Newborn', 'Child', 'Other'].contains(preselected)) {
        _caseType = preselected;
      }
      // Assistant pre-fill: name + age spoken via an "add <name> বয়স <n> বছর"
      // voice command.
      final prefName = args['name']?.toString();
      if (prefName != null && prefName.trim().isNotEmpty) {
        _nameCtrl.text = prefName.trim();
      }
      final prefAge = args['age']?.toString();
      if (prefAge != null && prefAge.trim().isNotEmpty) {
        _ageCtrl.text = prefAge.trim();
      }
      final prefUnit = args['ageUnit']?.toString();
      if (prefUnit != null && const ['years', 'months', 'days'].contains(prefUnit)) {
        _ageUnit = prefUnit;
      } else {
        _ageUnit = _defaultAgeUnit(_caseType);
      }
    } else {
      _ageUnit = _defaultAgeUnit(_caseType);
    }

    // Age → DOB sync for child/newborn: typing age auto-fills DOB (today − age);
    // worker can still pick a DOB and the age follows. Listener added AFTER the
    // edit-load above so loading doesn't fire it. One-time derive handles a
    // loaded patient that has an age but no DOB yet (e.g. legacy records).
    _ageCtrl.addListener(_onAgeChanged);
    if (_dob == null) {
      final d = _dobFromAge();
      if (d != null) _dob = d;
    }
  }

  @override
  void dispose() {
    try { _stt.stop(); } catch (_) {}
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _villageCtrl.dispose();
    _mobileCtrl.dispose();
    _guardianCtrl.dispose();
    for (final c in _mcpCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _isEditing => _editing != null;

  // Smart default age unit per case: newborn → days, child → months,
  // pregnancy/other → years (the mother's / person's age).
  static String _defaultAgeUnit(String caseType) => switch (caseType) {
        'Newborn' => 'days',
        'Child'   => 'months',
        _         => 'years',
      };

  String _ageUnitLabel(String u) => switch (u) {
        'days'   => 'age_unit_days'.tr,
        'months' => 'age_unit_months'.tr,
        _        => 'age_unit_years'.tr,
      };

  // ── Maternal & child date pickers ───────────────────────────────────────
  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _pickLmp() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _lmp ?? now.subtract(const Duration(days: 56)),
      firstDate: now.subtract(const Duration(days: 310)), // within ~10 months
      lastDate: now,
      helpText: 'শেষ মাসিকের তারিখ (LMP)',
    );
    if (picked != null && mounted) setState(() => _lmp = picked);
  }

  Future<void> _pickDeliveryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deliveryDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)), // within the last year
      lastDate: now,
      helpText: 'প্রসবের তারিখ (delivery date)',
    );
    if (picked != null && mounted) setState(() => _deliveryDate = picked);
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? now,
      // Child/newborn: ~6 yrs back; adults (pregnancy/other): ~110 yrs back.
      firstDate: now.subtract(Duration(
          days: (_caseType == 'Newborn' || _caseType == 'Child') ? 6 * 365 : 110 * 365)),
      lastDate: now,
      helpText: 'জন্ম তারিখ (DOB)',
    );
    if (picked != null && mounted) {
      setState(() {
        _dob = picked;
        _setAgeFromDob(picked); // keep age in sync with the chosen DOB
      });
    }
  }

  // ── Age ↔ DOB sync (child / newborn) ────────────────────────────────────────
  /// DOB computed from the entered age + unit (today − age). Null if no age.
  DateTime? _dobFromAge() {
    final n = int.tryParse(_ageCtrl.text.trim());
    if (n == null || n <= 0) return null;
    final now = DateTime.now();
    switch (_ageUnit) {
      case 'days':
        return now.subtract(Duration(days: n));
      case 'months':
        return DateTime(now.year, now.month - n, now.day);
      default: // years
        return DateTime(now.year - n, now.month, now.day);
    }
  }

  /// Worker typed an age → auto-fill DOB (child/newborn only). The worker can
  /// still tap the DOB field afterwards to adjust it.
  void _onAgeChanged() {
    if (_suppressAgeListener) return;
    final d = _dobFromAge();
    if (d != null && mounted) setState(() => _dob = d);
  }

  /// Worker picked a DOB → set the age (+ unit) to match, without re-triggering
  /// the age listener (guarded to avoid a loop).
  void _setAgeFromDob(DateTime dob) {
    final days = DateTime.now().difference(dob).inDays;
    final String unit;
    final int val;
    if (_caseType == 'Newborn' || days <= 60) {
      unit = 'days';
      val = days;
    } else if (days < 730) {
      unit = 'months';
      val = (days / 30.44).floor();
    } else {
      unit = 'years';
      val = (days / 365.25).floor();
    }
    _suppressAgeListener = true;
    _ageUnit = unit;
    _ageCtrl.text = '$val';
    _suppressAgeListener = false;
  }

  /// Tappable, read-only date row used for LMP / DOB.
  Widget _dateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: AppShadows.low,
            ),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 20),
                const SizedBox(width: 12),
                Text(
                  value != null ? _fmtDate(value) : 'তারিখ নির্বাচন করুন',
                  style: value != null
                      ? AppTextStyles.body
                      : AppTextStyles.body
                          .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Conditional maternal/child section shown below the case-type chips:
  /// Pregnancy → LMP (auto-shows EDD); Newborn/Child → DOB + mother's name +
  /// twin toggle. Entering these dates is what generates the ANC / vaccine /
  /// HBNC reminder schedule server-side.
  Widget _mchSection() {
    if (_caseType == 'Pregnancy') {
      return Column(
        children: [
          const SizedBox(height: 16),
          _dateField(
            label: 'শেষ মাসিকের তারিখ (LMP) — আবশ্যক',
            value: _lmp,
            onTap: _pickLmp,
            icon: Icons.calendar_month_outlined,
          ),
          if (_edd != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_available_rounded,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'সম্ভাব্য প্রসবের তারিখ (EDD): ${_fmtDate(_edd!)}',
                      style: AppTextStyles.label.copyWith(color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Mother's DOB — record only (auto from age, editable). Does NOT drive
          // the schedule (that's LMP above); the server guards baby-vaccines.
          _dateField(
            label: 'মায়ের জন্ম তারিখ (DOB)',
            value: _dob,
            onTap: _pickDob,
            icon: Icons.cake_outlined,
          ),
          const SizedBox(height: 16),
          // Set ONLY after she delivers → generates the PNC (postnatal) schedule.
          _dateField(
            label: 'প্রসবের তারিখ — প্রসব হলে দিন (PNC সূচি তৈরি হবে)',
            value: _deliveryDate,
            onTap: _pickDeliveryDate,
            icon: Icons.child_friendly_outlined,
          ),
        ],
      );
    }
    if (_caseType == 'Newborn' || _caseType == 'Child') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          _dateField(
            label: 'জন্ম তারিখ (DOB) — আবশ্যক',
            value: _dob,
            onTap: _pickDob,
            icon: Icons.cake_outlined,
          ),
          const SizedBox(height: 16),
          AppInput(
            hint: 'মায়ের নাম',
            label: 'মায়ের নাম',
            controller: _guardianCtrl,
            prefixIcon: const Icon(Icons.woman_outlined,
                color: AppColors.primary, size: 20),
          ),
          const SizedBox(height: 10),
          _motherLinkField(),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: _isTwin,
            activeThumbColor: AppColors.primary,
            title: Text('যমজ শিশু?', style: AppTextStyles.label),
            onChanged: (v) => setState(() => _isTwin = v),
          ),
          if (_isTwin)
            Row(
              children: [1, 2].map((n) {
                final sel = _birthOrder == n;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: ChoiceChip(
                    label: Text('শিশু $n'),
                    selected: sel,
                    selectedColor: AppColors.primary,
                    labelStyle: AppTextStyles.label.copyWith(
                      color: sel ? AppColors.onPrimary : AppColors.textSecondary,
                    ),
                    onSelected: (_) => setState(() => _birthOrder = n),
                  ),
                );
              }).toList(),
            ),
        ],
      );
    }
    // Other: DOB only (record; auto from age, editable).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        _dateField(
          label: 'জন্ম তারিখ (DOB)',
          value: _dob,
          onTap: _pickDob,
          icon: Icons.cake_outlined,
        ),
      ],
    );
  }

  // ── Mother link (anchors a child's identity) ────────────────────────────
  /// A child often has no Aadhaar/phone, so we anchor it to the mother. Linking
  /// sets `motherId` (used by the de-dup matcher: same mother + DOB + birth
  /// order = same child) and auto-fills the mother's name.
  Widget _motherLinkField() {
    final linked = _motherId != null && _motherId!.isNotEmpty;
    return Align(
      alignment: Alignment.centerLeft,
      child: linked
          ? InputChip(
              avatar: const Icon(Icons.link_rounded, size: 16, color: AppColors.primary),
              label: Text(
                'মা যুক্ত: ${_guardianCtrl.text.trim().isEmpty ? 'নির্বাচিত' : _guardianCtrl.text.trim()}',
                style: AppTextStyles.label,
              ),
              backgroundColor: AppColors.primary.withValues(alpha: 0.08),
              onDeleted: () => setState(() => _motherId = null),
            )
          : OutlinedButton.icon(
              onPressed: _pickMother,
              icon: const Icon(Icons.link_rounded, size: 18, color: AppColors.primary),
              label: Text('তালিকা থেকে মা যুক্ত করুন (ঐচ্ছিক)',
                  style: AppTextStyles.label.copyWith(color: AppColors.primary)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
    );
  }

  /// Searchable picker of the worker's existing mothers (pregnancy / female
  /// records). Sets [_motherId] + the mother's name on selection.
  Future<void> _pickMother() async {
    final all = _ctrl.patients
        .where((p) =>
            p.id != _editing?.id &&
            p.syncState != SyncState.pendingDelete &&
            (p.type == 'Pregnancy' || p.gender == 'Female'))
        .toList();
    if (all.isEmpty) {
      _showSnack('মা পাওয়া যায়নি',
          'তালিকায় কোনো গর্ভবতী/মহিলা রোগী নেই — মায়ের নাম হাতে লিখুন।',
          AppColors.warningYellow);
      return;
    }
    String query = '';
    final picked = await showModalBottomSheet<PatientModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final q = query.toLowerCase().trim();
          final filtered = q.isEmpty
              ? all
              : all
                  .where((p) =>
                      p.name.toLowerCase().contains(q) || p.mobile.contains(q))
                  .toList();
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text('মা নির্বাচন করুন', style: AppTextStyles.h3),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      autofocus: false,
                      decoration: InputDecoration(
                        hintText: 'নাম বা মোবাইল দিয়ে খুঁজুন',
                        prefixIcon: const Icon(Icons.search_rounded),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (v) => setSheet(() => query = v),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: filtered
                          .map((p) => ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      AppColors.primary.withValues(alpha: 0.10),
                                  backgroundImage: patientPhotoProvider(
                                      p.mcpDetails['photo']?.toString()),
                                  child: patientPhotoProvider(
                                              p.mcpDetails['photo']?.toString()) ==
                                          null
                                      ? const Icon(Icons.woman_outlined,
                                          color: AppColors.primary, size: 20)
                                      : null,
                                ),
                                title: Text(p.name, style: AppTextStyles.body),
                                subtitle: Text(
                                  [
                                    if (p.village.isNotEmpty && p.village != 'Unknown')
                                      p.village,
                                    if (p.mobile.isNotEmpty) p.mobile,
                                  ].join(' • '),
                                  style: AppTextStyles.label
                                      .copyWith(color: AppColors.textSecondary),
                                ),
                                onTap: () => Navigator.pop(ctx, p),
                              ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _motherId = picked.id;
        if (_guardianCtrl.text.trim().isEmpty) _guardianCtrl.text = picked.name;
      });
    }
  }

  // ── Possible-duplicate confirmation (worker decides) ─────────────────────
  /// Before creating, check the worker's own list for likely duplicates. Returns
  /// true if it's safe to create (none found, or worker chose "add as new").
  /// If the worker recognises an existing person, opens that profile and returns
  /// false so we don't create a second record. See [PatientMatcher].
  Future<bool> _confirmNotDuplicate() async {
    final dups = _ctrl.findDuplicates(
      name: _nameCtrl.text.trim(),
      mobile: _mobileCtrl.text.trim(),
      village: _villageCtrl.text.trim(),
      rchId: _mcpCtrl('rchId').text.trim(),
      motherAadhaar: _mcpCtrl('motherAadhaar').text.trim(),
      motherId: _motherId,
      dob: (_caseType == 'Newborn' || _caseType == 'Child') ? _dob : null,
      birthOrder: _isTwin ? _birthOrder : 0,
    );
    if (dups.isEmpty) return true;
    if (!mounted) return false;
    final res = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Row(
                children: [
                  const Icon(Icons.people_alt_outlined, color: AppColors.warningYellow),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('সম্ভাব্য ডুপ্লিকেট রোগী', style: AppTextStyles.h3),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'এই রোগী হয়তো আগে থেকেই তালিকায় আছেন। মিলে গেলে সেটি খুলুন — না হলে নতুন হিসেবে যোগ করুন।',
                style: AppTextStyles.label.copyWith(color: AppColors.textSecondary),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: dups.map((m) {
                  final p = m.patient;
                  final photo = patientPhotoProvider(p.mcpDetails['photo']?.toString());
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.10),
                      backgroundImage: photo,
                      child: photo == null
                          ? const Icon(Icons.person_outline, color: AppColors.primary)
                          : null,
                    ),
                    title: Text(p.name, style: AppTextStyles.body),
                    subtitle: Text(
                      [
                        if (p.age.isNotEmpty) '${p.age} ${_ageUnitLabel(p.ageUnit)}',
                        if (p.village.isNotEmpty && p.village != 'Unknown') p.village,
                        m.reason,
                      ].join(' • '),
                      style: AppTextStyles.label.copyWith(color: AppColors.textSecondary),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (m.strong ? AppColors.emergencyRed : AppColors.warningYellow)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(m.strong ? 'নিশ্চিত মিল' : 'সম্ভাব্য',
                          style: AppTextStyles.label.copyWith(
                              fontSize: 11,
                              color: m.strong
                                  ? AppColors.emergencyRed
                                  : AppColors.warningYellow)),
                    ),
                    onTap: () => Navigator.pop(ctx, m),
                  );
                }).toList(),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx, null),
                      child: Text('বাতিল', style: AppTextStyles.label),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(ctx, 'new'),
                      icon: const Icon(Icons.person_add_alt_1, size: 18),
                      label: const Text('নতুন রোগী যোগ করুন'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (res is DuplicateMatch) {
      final p = res.patient;
      // Same woman + we're registering a pregnancy → a NEW MCP card is issued
      // each pregnancy, so offer "new pregnancy (same mother)" vs "open existing".
      if (res.sameMother && _caseType == 'Pregnancy' && mounted) {
        final choice = await _sameMotherChoice(p);
        if (choice == 'new') {
          _prefillFromMother(p);
          return true; // proceed to create a fresh pregnancy record
        }
        if (choice == 'open') {
          Get.toNamed(AppRoutes.patientProfile, arguments: p.toJson());
        }
        return false; // 'open' or cancel → don't create here
      }
      Get.toNamed(AppRoutes.patientProfile, arguments: p.toJson());
      return false;
    }
    return res == 'new';
  }

  /// Returns 'new' | 'open' | null. Lets the worker say it's the same mother
  /// starting another pregnancy, vs the existing record.
  Future<String?> _sameMotherChoice(PatientModel m) => showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('একই মা'),
          content: Text(
              '${m.name} আগে থেকেই তালিকায় আছেন। প্রতিটি গর্ভাবস্থার জন্য আলাদা MCP কার্ড হয় — '
              'এটি কি নতুন গর্ভ, নাকি পুরোনো রেকর্ড দেখবেন?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'open'),
              child: const Text('পুরোনো রেকর্ড খুলুন'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'new'),
              child: const Text('নতুন গর্ভ হিসেবে যোগ করুন'),
            ),
          ],
        ),
      );

  static bool _realAadhaar(String s) => RegExp(r'\d{4}$').hasMatch(s.trim());

  /// Carries a returning mother's STABLE details into the form for a new
  /// pregnancy: identity, demographics, family, bank, institution, and the
  /// risk/chronic history (these inform this pregnancy's risk). Pregnancy-
  /// specific fields stay fresh — LMP/EDD/outcome/RCH are NOT copied (a new
  /// pregnancy gets its own). Links her pregnancies via [_motherPersonId].
  void _prefillFromMother(PatientModel m) {
    final md = m.mcpDetails;
    setState(() {
      _caseType = 'Pregnancy';
      _gender = 'Female';
      _ageUnit = 'years';
      if (_nameCtrl.text.trim().isEmpty) _nameCtrl.text = m.name;
      if (_villageCtrl.text.trim().isEmpty && m.village != 'Unknown') {
        _villageCtrl.text = m.village;
      }
      if (_mobileCtrl.text.trim().isEmpty) _mobileCtrl.text = m.mobile;
      // DOB is stable → carry it and recompute age; fresh pregnancy ⇒ no LMP yet.
      if (m.dob != null) {
        _dob = m.dob;
        _setAgeFromDob(m.dob!);
      } else if (_ageCtrl.text.trim().isEmpty && m.age.isNotEmpty) {
        _ageCtrl.text = m.age;
      }
      _lmp = null;

      // Stable text/dropdown fields to carry forward (NOT rchId — per pregnancy).
      const carry = [
        'fatherName', 'address', 'fatherMobile', 'motherAadhaar',
        'religion', 'caste', 'bloodGroup',
        'bankName', 'bankAccount', 'ifsc',
        'anganwadiCentre', 'awcNumber', 'lgdCode', 'panchayat', 'block',
        'postOffice', 'pincode', 'anmName', 'anmMobile', 'deliveryCentrePhone',
        'facilityName', 'bphc', 'ruralHospital', 'district', 'subcentreName',
        'subcentreRegNo', 'referralHospital', 'vhndDay',
        'para', 'prevLiveBirths', 'lastDeliveryPlace', 'lastChildAge',
      ];
      for (final k in carry) {
        final v = md[k];
        if (v != null && v.toString().trim().isNotEmpty) _mcpCtrl(k).text = v.toString();
      }
      // New gravidity = previous + 1 (best-effort; worker can adjust).
      final oldG = int.tryParse((md['gravida'] ?? '').toString().trim());
      if (oldG != null) _mcpCtrl('gravida').text = '${oldG + 1}';

      // Carry-forward boolean history: prior obstetric complications + chronic
      // disease persist and inform this pregnancy; PMMVY eligibility too.
      for (final k in [..._highRiskHistory.keys, 'pmmvyEligible']) {
        if (md[k] == true) _mcpBools[k] = true;
      }

      // Link her pregnancies under one stable id (prefer Aadhaar — same every
      // pregnancy; else reuse an existing personId; else her record id).
      final existingPersonId = (md['motherPersonId'] ?? '').toString().trim();
      final aad = (md['motherAadhaar'] ?? '').toString().trim();
      _motherPersonId = existingPersonId.isNotEmpty
          ? existingPersonId
          : (_realAadhaar(aad) ? aad : m.id);
    });
    _showSnack('একই মা — নতুন গর্ভ',
        'পূর্বের তথ্য বসানো হয়েছে — এখন নতুন LMP দিন।', AppColors.safeGreen);
  }

  // Sections promoted OUT of the collapse and shown inline (clinical priority):
  // the high-risk history drives the auto high-risk flag, so it must not be
  // buried. Only relevant to Pregnancy.
  static const Set<String> _promotedSections = {'ঝুঁকির ইতিহাস', 'দীর্ঘমেয়াদি অসুখ'};

  /// How many collapsed MCP fields (relevant to this case, excluding the
  /// promoted risk sections) are filled — drives the "X/Y পূরণ" header badge so
  /// completeness is visible without forcing every field on-screen.
  ({int filled, int total}) _mcpProgress() {
    int filled = 0, total = 0;
    for (final f in _mcpFields) {
      if (!(f.cases.isEmpty || f.cases.contains(_caseType))) continue;
      if (_promotedSections.contains(f.section)) continue;
      total++;
      final isFilled = f.isBool
          ? (_mcpBools[f.key] == true)
          : ((_mcpCtrls[f.key]?.text.trim() ?? '').isNotEmpty);
      if (isFilled) filled++;
    }
    return (filled: filled, total: total);
  }

  /// Pregnancy high-risk history shown INLINE (not inside the collapse) because
  /// it's clinical, not administrative — and it live-flags উচ্চ ঝুঁকি as toggles
  /// are set. Renders the 'ঝুঁকির ইতিহাস' + 'দীর্ঘমেয়াদি অসুখ' fields.
  Widget _riskHistorySection() {
    if (_caseType != 'Pregnancy') return const SizedBox.shrink();
    final hist = _mcpFields
        .where((f) => f.section == 'ঝুঁকির ইতিহাস' &&
            (f.cases.isEmpty || f.cases.contains(_caseType)))
        .toList();
    final chronic = _mcpFields
        .where((f) => f.section == 'দীর্ঘমেয়াদি অসুখ' &&
            (f.cases.isEmpty || f.cases.contains(_caseType)))
        .toList();
    if (hist.isEmpty && chronic.isEmpty) return const SizedBox.shrink();
    final hr = _assessHighRisk();
    final accent = hr.high ? AppColors.emergencyRed : AppColors.primary;
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgR,
        boxShadow: AppShadows.low,
        border: Border.all(color: accent.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.health_and_safety_outlined, color: accent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('ঝুঁকির ইতিহাস (উচ্চ-ঝুঁকি যাচাই)',
                    style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700)),
              ),
              if (hr.high)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.emergencyRed.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('উচ্চ ঝুঁকি',
                      style: AppTextStyles.label.copyWith(
                          color: AppColors.emergencyRed,
                          fontWeight: FontWeight.w800,
                          fontSize: 11)),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text('পূর্বের গর্ভ-জটিলতা বা দীর্ঘমেয়াদি অসুখ থাকলে চিহ্নিত করুন',
              style: AppTextStyles.label
                  .copyWith(color: AppColors.textSecondary, fontSize: 11)),
          ...hist.map(_mcpFieldWidget),
          if (chronic.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('দীর্ঘমেয়াদি অসুখ',
                style: AppTextStyles.label.copyWith(color: AppColors.primary)),
            ...chronic.map(_mcpFieldWidget),
          ],
        ],
      ),
    );
  }

  // ── Full MCP-card identity section (collapsible) ─────────────────────────
  Widget _mcpSection() {
    const sections = [
      'পরিবার পরিচয়',
      'জনতাত্ত্বিক',
      'ব্যাঙ্ক ও যোজনা',
      'গর্ভাবস্থা',
      'ঝুঁকির ইতিহাস',
      'দীর্ঘমেয়াদি অসুখ',
      'জন্ম রেকর্ড',
      'প্রতিষ্ঠান',
    ];
    final children = <Widget>[];
    for (final sec in sections) {
      if (_promotedSections.contains(sec)) continue; // shown inline by _riskHistorySection
      final fields = _mcpFields
          .where((f) =>
              f.section == sec &&
              (f.cases.isEmpty || f.cases.contains(_caseType)))
          .toList();
      if (fields.isEmpty) continue;
      children.add(Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 6),
        child: Text(sec,
            style: AppTextStyles.label.copyWith(color: AppColors.primary)),
      ));
      children.addAll(fields.map(_mcpFieldWidget));
    }
    if (children.isEmpty) return const SizedBox.shrink();
    final p = _mcpProgress();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 8),
          leading: const Icon(Icons.assignment_outlined, color: AppColors.primary),
          // Title carries a filled-count badge so completeness is visible
          // without forcing every field on-screen (progressive disclosure).
          // Kept in the title (not `trailing`) so the expand chevron remains.
          title: Row(
            children: [
              Flexible(child: Text('বিস্তারিত তথ্য (MCP কার্ড)', style: AppTextStyles.label)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: (p.filled == 0 ? AppColors.textSecondary : AppColors.primary)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${p.filled}/${p.total}',
                    style: AppTextStyles.label.copyWith(
                        color: p.filled == 0 ? AppColors.textSecondary : AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 11)),
              ),
            ],
          ),
          subtitle: Text('ঐচ্ছিক — পরিবার, যোজনা, প্রতিষ্ঠানের তথ্য',
              style: AppTextStyles.label
                  .copyWith(color: AppColors.textSecondary, fontSize: 11)),
          children: children,
        ),
      ),
    );
  }

  Widget _mcpFieldWidget(
      ({String key, String label, String section, List<String> cases, bool number, bool isBool}) f) {
    if (f.isBool) {
      return SwitchListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        value: _mcpBools[f.key] ?? false,
        activeThumbColor: AppColors.primary,
        title: Text(f.label, style: AppTextStyles.label),
        onChanged: (v) => setState(() => _mcpBools[f.key] = v),
      );
    }
    final options = _fieldOptions[f.key];
    if (options != null) {
      final cur = _mcpCtrl(f.key).text;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(f.label, style: AppTextStyles.label),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: options.contains(cur) ? cur : null,
              isExpanded: true,
              style: AppTextStyles.body,
              decoration: const InputDecoration(),
              hint: Text('নির্বাচন করুন', style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
              items: options
                  .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                  .toList(),
              onChanged: (v) => setState(() => _mcpCtrl(f.key).text = v ?? ''),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppInput(
        hint: f.label,
        label: f.label,
        controller: _mcpCtrl(f.key),
        keyboardType: f.number ? TextInputType.number : TextInputType.text,
        // Voice-fill on text fields (numbers are unreliable by Bengali STT).
        suffixIcon: f.number ? null : _micSuffix(f.key, _mcpCtrl(f.key)),
        validator: (f.key == 'motherAadhaar' || f.key == 'childAadhaar')
            ? _validateAadhaar
            : null,
      ),
    );
  }

  /// Builds the mcpDetails map from the section's controllers/toggles, limited
  /// to fields relevant to the current case type. Aadhaar numbers are masked —
  /// the raw 12-digit value is never stored (Aadhaar Act).
  Map<String, dynamic> _collectMcp() {
    final m = <String, dynamic>{};
    for (final f in _mcpFields) {
      if (!(f.cases.isEmpty || f.cases.contains(_caseType))) continue;
      if (f.isBool) {
        if (_mcpBools[f.key] == true) m[f.key] = true;
        continue;
      }
      final v = _mcpCtrls[f.key]?.text.trim() ?? '';
      if (v.isEmpty) continue;
      m[f.key] = (f.key == 'motherAadhaar' || f.key == 'childAadhaar')
          ? _maskAadhaar(v)
          : v;
    }
    final hr = _assessHighRisk();
    if (hr.high) {
      m['highRisk'] = true;
      m['highRiskReason'] = hr.reason;
    }
    if (_photoB64 != null && _photoB64!.isNotEmpty) m['photo'] = _photoB64;
    if (_motherPersonId != null && _motherPersonId!.isNotEmpty) {
      m['motherPersonId'] = _motherPersonId;
    }
    return m;
  }

  /// High-risk obstetric / chronic-disease history → each toggle, when set,
  /// auto-flags the pregnancy high-risk (MCP card pg 5). Key → reason label.
  static const Map<String, String> _highRiskHistory = {
    'histAPH':        'পূর্বে গর্ভকালীন রক্তস্রাব (APH)',
    'histPPH':        'পূর্বে প্রসবোত্তর রক্তস্রাব (PPH)',
    'histEclampsia':  'পূর্বে এক্লাম্পসিয়া / খিঁচুনি',
    'histPIH':        'পূর্বে গর্ভকালীন উচ্চ রক্তচাপ',
    'histLSCS':       'পূর্বে সিজার (LSCS)',
    'histObstructed': 'পূর্বে বাধাপ্রাপ্ত প্রসব',
    'histAbortion':   'পূর্বে গর্ভপাত / মৃত শিশু',
    'histCongenital': 'পূর্বে জন্মগত ত্রুটিযুক্ত শিশু',
    'chrTB':          'যক্ষ্মা',
    'chrHypertension':'উচ্চ রক্তচাপ',
    'chrHeart':       'হৃদরোগ',
    'chrDiabetes':    'ডায়াবেটিস',
    'chrAsthma':      'হাঁপানি',
  };

  /// Flags a high-risk pregnancy at registration — matches the centre's
  /// "High-Risk PW / Teenage Pregnancy" tracking. Teenage (<19), elderly
  /// (≥35), grand-multipara (gravida ≥5), or any prior obstetric complication /
  /// chronic disease (MCP card pg 5) are standard high-risk criteria.
  ({bool high, String reason}) _assessHighRisk() {
    if (_caseType != 'Pregnancy') return (high: false, reason: '');
    final reasons = <String>[];
    final age = int.tryParse(_ageCtrl.text.trim());
    if (_ageUnit == 'years' && age != null) {
      if (age < 19) {
        reasons.add('কিশোরী গর্ভধারণ (<১৯ বছর)');
      } else if (age >= 35) {
        reasons.add('৩৫+ বয়সে গর্ভধারণ');
      }
    }
    final grav = int.tryParse(_mcpCtrls['gravida']?.text.trim() ?? '');
    if (grav != null && grav >= 5) reasons.add('গ্র্যান্ড মাল্টিপ্যারা (গর্ভ ৫+)');
    _highRiskHistory.forEach((k, label) {
      if (_mcpBools[k] == true) reasons.add(label);
    });
    return (high: reasons.isNotEmpty, reason: reasons.join(', '));
  }

  String _maskAadhaar(String s) {
    final digits = s.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4) return 'XXXX';
    return 'XXXX-XXXX-${digits.substring(digits.length - 4)}';
  }

  // ── Aadhaar OCR (server-side; image never stored) ───────────────────────
  DateTime? _parseDob(String s) {
    s = s.trim();
    // yyyy-mm-dd (or yyyy/mm/dd)
    final iso = RegExp(r'^(\d{4})[/-](\d{2})[/-](\d{2})$').firstMatch(s);
    if (iso != null) {
      try {
        return DateTime(int.parse(iso.group(1)!), int.parse(iso.group(2)!), int.parse(iso.group(3)!));
      } catch (_) {
        return null;
      }
    }
    // dd-mm-yyyy (or dd/mm/yyyy) — the common Aadhaar form
    final dmy = RegExp(r'^(\d{2})[/-](\d{2})[/-](\d{4})$').firstMatch(s);
    if (dmy != null) {
      try {
        return DateTime(int.parse(dmy.group(3)!), int.parse(dmy.group(2)!), int.parse(dmy.group(1)!));
      } catch (_) {
        return null;
      }
    }
    // bare yyyy (year-of-birth only)
    final y = RegExp(r'^(\d{4})$').firstMatch(s);
    if (y != null) return DateTime(int.parse(y.group(1)!), 1, 1);
    return null;
  }

  /// Aadhaar autofill. Offers a LIVE QR scan (most reliable — decoded and
  /// parsed on-device, works offline) plus photo fallbacks (image sent to the
  /// backend for QR decode, then OCR).
  Future<void> _scanAadhaar() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary),
              title: const Text('লাইভ QR স্ক্যান'),
              subtitle: const Text('সবচেয়ে নির্ভরযোগ্য — ক্যামেরা QR কোডের দিকে ধরুন'),
              onTap: () => Navigator.pop(context, 'live'),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
              title: const Text('ক্যামেরা দিয়ে ছবি তুলুন'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
              title: const Text('গ্যালারি থেকে বাছুন'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    if (choice == 'live') {
      await _liveScanAadhaar();
    } else {
      await _photoScanAadhaar(choice == 'camera');
    }
  }

  /// Live on-device QR scan. The scanner validates + parses the Aadhaar QR
  /// itself and returns the demographics map (null if the worker backed out).
  /// No network needed — works offline in the field.
  Future<void> _liveScanAadhaar() async {
    final parsed = await Get.to<Map<String, dynamic>>(
        () => const AadhaarScannerScreen());
    if (parsed == null || !mounted) return;
    _applyAadhaar(parsed);
  }

  /// Photo path: send the card image to the backend (QR decode, then OCR).
  Future<void> _photoScanAadhaar(bool fromCamera) async {
    final file = await ImagePicker().pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return;
    setState(() => _scanning = true);
    final bytes = await file.readAsBytes();
    final r = await ApiService.ocrAadhaar(bytes);
    if (!mounted) return;
    setState(() => _scanning = false);
    if (r == null) {
      _showSnack(
        'আধার স্ক্যান',
        'তথ্য পড়া গেল না। আধার কার্ডের পিছনের QR কোডটি — আলোয়, সমান করে, সম্পূর্ণ ফ্রেমে — কাছ থেকে তুলুন, তারপর আবার চেষ্টা করুন। অথবা লাইভ QR স্ক্যান ব্যবহার করুন।',
        AppColors.warningYellow,
      );
      return;
    }
    _applyAadhaar(r);
  }

  /// Fills the form from a parsed Aadhaar map (identical shape whether it came
  /// from the live-QR scan or the server). Bilingual, Bengali-primary: the
  /// Aadhaar English name → official `nameEn`; the Bengali `name` stays from
  /// voice (filled only as a fallback when blank, so the record is never
  /// nameless).
  void _applyAadhaar(Map<String, dynamic> r) {
    String? detectedCase;
    setState(() {
      final enName = (r['name'] ?? '').toString().trim();
      if (enName.isNotEmpty) {
        _mcpCtrl('nameEn').text = enName;
        if (_nameCtrl.text.trim().isEmpty) _nameCtrl.text = enName;
      }
      final g = r['gender']?.toString();
      if (g == 'Female' || g == 'Male') _gender = g!;
      final dobRaw = r['dob']?.toString();
      final dob = dobRaw != null ? _parseDob(dobRaw) : null;
      if (dob != null) _dob = dob;

      // Auto-detect the case type from age + gender — a smart default; the
      // worker can still tap a different chip. Newborn ≤6 weeks, child <5 yrs,
      // an adult woman of reproductive age → pregnancy, otherwise other. Also
      // fills বয়স in the matching unit so the worker doesn't retype it.
      if (dob != null) {
        final days = DateTime.now().difference(dob).inDays;
        final years = days / 365.25;
        if (days <= 42) {
          detectedCase = 'Newborn';
        } else if (years < 5) {
          detectedCase = 'Child';
        } else if (g == 'Female' && years >= 12 && years <= 49) {
          detectedCase = 'Pregnancy';
        } else {
          detectedCase = 'Other';
        }
        _caseType = detectedCase!;
        _ageUnit = _defaultAgeUnit(detectedCase!);
        _ageCtrl.text = switch (_ageUnit) {
          'days' => '$days',
          'months' => '${(days / 30.4375).floor()}',
          _ => '${years.floor()}',
        };
      }

      // QR demographics (English) → official fields.
      final addr = (r['address'] ?? '').toString().trim();
      if (addr.isNotEmpty) _mcpCtrl('address').text = addr;
      final dist = (r['district'] ?? '').toString().trim();
      if (dist.isNotEmpty) _mcpCtrl('district').text = dist;
      final co = (r['careOf'] ?? '').toString().trim();
      if (co.isNotEmpty && _mcpCtrl('fatherName').text.trim().isEmpty) {
        _mcpCtrl('fatherName').text = co;
      }
      final aad = r['aadhaar']?.toString(); // already masked
      if (aad != null && aad.isNotEmpty) {
        // Use the just-detected case to route the masked number correctly.
        final key = (_caseType == 'Newborn' || _caseType == 'Child')
            ? 'childAadhaar'
            : 'motherAadhaar';
        _mcpCtrl(key).text = aad;
      }
    });
    final via = r['source']?.toString() == 'qr' ? 'QR (যাচাইকৃত)' : 'OCR';
    final caseHint = detectedCase != null ? ' • কেস: ${_caseLabel(detectedCase!)}' : '';
    _showSnack('আধার $via ✓', 'তথ্য বসানো হয়েছে$caseHint — যাচাই করে নিন।',
        AppColors.safeGreen);
  }

  /// Capture/choose/remove the patient's photo. Compressed hard (small JPEG)
  /// since it's base64'd into mcpDetails and synced with the patient to Atlas.
  Future<void> _pickPhoto() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
              title: const Text('ক্যামেরা দিয়ে তুলুন'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
              title: const Text('গ্যালারি থেকে বাছুন'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            if (_photoB64 != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.emergencyRed),
                title: const Text('ছবি সরান'),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    if (choice == 'remove') {
      setState(() => _photoB64 = null);
      return;
    }
    final file = await ImagePicker().pickImage(
      source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 45,
      maxWidth: 600,
      maxHeight: 600,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() => _photoB64 = base64Encode(bytes));
  }

  /// Circular tappable avatar at the top of the form — shows the photo (or a
  /// camera placeholder) and opens [_pickPhoto].
  Widget _photoAvatar() {
    ImageProvider? img;
    if (_photoB64 != null && _photoB64!.isNotEmpty) {
      try {
        img = MemoryImage(base64Decode(_photoB64!));
      } catch (_) {/* corrupt → show placeholder */}
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: GestureDetector(
          onTap: _pickPhoto,
          // Hold to view the photo full-screen (tap changes/removes it).
          onLongPress: _photoB64 == null
              ? null
              : () => showPatientPhotoDialog(context, _photoB64, name: _nameCtrl.text),
          child: Stack(
            children: [
              CircleAvatar(
                radius: 46,
                backgroundColor: AppColors.primary.withValues(alpha: 0.10),
                backgroundImage: img,
                child: img == null
                    ? const Icon(Icons.add_a_photo_outlined,
                        color: AppColors.primary, size: 28)
                    : null,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 2),
                  ),
                  child: Icon(img == null ? Icons.add : Icons.edit,
                      color: Colors.white, size: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _aadhaarScanButton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _scanning ? null : _scanAadhaar,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                _scanning
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.document_scanner_outlined, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('আধার কার্ড স্ক্যান করুন',
                          style: AppTextStyles.label.copyWith(
                              color: AppColors.primary, fontWeight: FontWeight.w700)),
                      Text('নাম, জন্মতারিখ, লিঙ্গ স্বয়ংক্রিয়ভাবে বসবে',
                          style: AppTextStyles.label.copyWith(
                              color: AppColors.textSecondary, fontSize: 11)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSnack(String title, String body, Color color) {
    Get.snackbar(
      title, body,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: color,
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 2),
    );
  }

  // ── Speak-to-fill ───────────────────────────────────────────────────────
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
        if ((s == SpeechToText.doneStatus ||
                s == SpeechToText.notListeningStatus) &&
            mounted) {
          setState(() => _dictating = null);
        }
      },
    );
    if (mounted) setState(() {});
  }

  /// Toggle dictation for [field], writing the recognised Bengali text into
  /// [ctrl]. Tapping the same field's mic again stops it.
  Future<void> _dictate(String field, TextEditingController ctrl) async {
    if (_dictating == field) {
      try { await _stt.stop(); } catch (_) {}
      if (mounted) setState(() => _dictating = null);
      return;
    }
    if (!_sttReady) {
      await _initStt();
      if (!_sttReady) {
        _showSnack('app_name'.tr, 'mic_permission_denied'.tr,
            AppColors.warningYellow);
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
        ctrl.selection =
            TextSelection.collapsed(offset: ctrl.text.length);
        if (r.finalResult && mounted) setState(() => _dictating = null);
      },
    );
  }

  Widget _micSuffix(String field, TextEditingController ctrl) {
    final active = _dictating == field;
    return IconButton(
      tooltip: 'speak'.tr,
      icon: Icon(
        active ? Icons.mic_rounded : Icons.mic_none_rounded,
        color: active ? AppColors.emergencyRed : AppColors.primary,
        size: 20,
      ),
      onPressed: () => _dictate(field, ctrl),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final mchError = _mchDateError();
    if (mchError != null) {
      _showSnack('তারিখ প্রয়োজন', mchError, AppColors.warningYellow);
      return;
    }

    if (_isEditing) {
      final updated = _editing!.copyWith(
        name:    _nameCtrl.text.trim(),
        type:    _caseType,
        village: _villageCtrl.text.trim().isEmpty ? 'Unknown' : _villageCtrl.text.trim(),
        mobile:  _mobileCtrl.text.trim(),
        age:     _ageCtrl.text.trim(),
        ageUnit: _ageUnit,
        gender:  _gender,
        dob:          _dob,
        lmp:          _caseType == 'Pregnancy' ? _lmp : null,
        edd:          _caseType == 'Pregnancy' ? _edd : null,
        deliveryDate: _caseType == 'Pregnancy' ? _deliveryDate : null,
        guardianName: _guardianCtrl.text.trim(),
        motherId:     _motherId,
        isTwin:       _isTwin,
        birthOrder:   _isTwin ? _birthOrder : 0,
        mcpDetails:   _collectMcp(),
      );
      final result = await _ctrl.updatePatient(updated);
      if (!mounted) return;
      if (result == 'duplicate') {
        _showSnack('cannot_save'.tr, 'duplicate_patient_msg'.tr, AppColors.warningYellow);
        return;
      }
      Get.back();
      _showSnack('patient_updated'.tr,
          'patient_updated_msg'.trParams({'name': updated.name}), AppColors.safeGreen);
      return;
    }

    // De-dup: before creating, surface likely existing records so the worker
    // can open one instead of minting a duplicate (she knows her families).
    if (!await _confirmNotDuplicate()) return;
    if (!mounted) return;

    // ADD mode — Atlas-first: await the server write, then confirm where it
    // landed (Atlas ✓ / offline-queued / sent-to-login).
    final name = _nameCtrl.text.trim();
    setState(() => _saving = true);
    final result = await _ctrl.addPatient(
      name: name,
      type: _caseType,
      village: _villageCtrl.text.trim().isEmpty ? 'Unknown' : _villageCtrl.text.trim(),
      mobile: _mobileCtrl.text.trim(),
      age: _ageCtrl.text.trim(),
      ageUnit: _ageUnit,
      gender: _gender,
      dob:          _dob, // record for all cases; backend guards baby-vaccine gen to child/newborn
      lmp:          _caseType == 'Pregnancy' ? _lmp : null,
      edd:          _caseType == 'Pregnancy' ? _edd : null,
      guardianName: _guardianCtrl.text.trim(),
      motherId:     _motherId,
      isTwin:       _isTwin,
      birthOrder:   _isTwin ? _birthOrder : 0,
      mcpDetails:   _collectMcp(),
      highRisk:     _assessHighRisk().high,
    );
    if (!mounted) return; // 401 hook may have navigated us to login
    setState(() => _saving = false);
    if (result.outcome == PatientSaveOutcome.needsLogin || ApiService.token == null) {
      // This save — OR a concurrent in-flight call — hit a 401 and the hook is
      // taking us to login (token is cleared synchronously). The patient is
      // safe on the phone and syncs after re-login; don't pop/navigate over
      // the login screen.
      return;
    }
    Get.back();
    if (result.outcome == PatientSaveOutcome.synced) {
      _showSnack('সংরক্ষিত ✓', 'Atlas-এ সংরক্ষিত হয়েছে — $name', AppColors.safeGreen);
    } else {
      _showSnack('ফোনে সংরক্ষিত',
          '$name — ইন্টারনেট এলে নিজে থেকে Atlas-এ সিঙ্ক হবে।', AppColors.warningYellow);
    }
  }

  Future<void> _saveAndCheckup() async {
    if (!_formKey.currentState!.validate()) return;
    final mchError = _mchDateError();
    if (mchError != null) {
      _showSnack('তারিখ প্রয়োজন', mchError, AppColors.warningYellow);
      return;
    }
    if (!await _confirmNotDuplicate()) return;
    if (!mounted) return;
    setState(() => _saving = true);
    final result = await _ctrl.addPatient(
      name: _nameCtrl.text.trim(),
      type: _caseType,
      village: _villageCtrl.text.trim().isEmpty ? 'Unknown' : _villageCtrl.text.trim(),
      mobile: _mobileCtrl.text.trim(),
      age: _ageCtrl.text.trim(),
      ageUnit: _ageUnit,
      gender: _gender,
      dob:          _dob, // record for all cases; backend guards baby-vaccine gen to child/newborn
      lmp:          _caseType == 'Pregnancy' ? _lmp : null,
      edd:          _caseType == 'Pregnancy' ? _edd : null,
      guardianName: _guardianCtrl.text.trim(),
      motherId:     _motherId,
      isTwin:       _isTwin,
      birthOrder:   _isTwin ? _birthOrder : 0,
      mcpDetails:   _collectMcp(),
      highRisk:     _assessHighRisk().high,
    );
    if (!mounted) return; // 401 hook may have navigated us to login
    setState(() => _saving = false);
    if (result.outcome == PatientSaveOutcome.needsLogin || ApiService.token == null) {
      // Session expired (this save or a concurrent call) → 401 hook is taking
      // us to login; abort the checkup so triage isn't stacked over login.
      return;
    }
    final patient = result.patient;
    if (result.outcome == PatientSaveOutcome.queuedOffline) {
      Get.snackbar(
        'ফোনে সংরক্ষিত',
        '${patient.name} — ইন্টারনেট এলে নিজে থেকে Atlas-এ সিঙ্ক হবে।',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.warningYellow,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        duration: const Duration(seconds: 4),
      );
    }
    // Checkup = the structured MCP-card visit form for the just-registered
    // patient — their next due visit, generated from the LMP/DOB just entered.
    await CheckupLauncher.start(
        patientId: patient.id, patientName: patient.name);
  }

  // Localized display labels for the English-valued gender / case options.
  // ── Field validators ───────────────────────────────────────────────────────
  /// Age must be a positive number, plausible for the chosen unit, and (for a
  /// pregnancy) within reproductive years.
  String? _validateAge(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'বয়স দিন';
    final n = int.tryParse(s);
    if (n == null || n <= 0) return 'সঠিক বয়স দিন';
    if (_ageUnit == 'days' && n > 90) return 'দিনের হিসাবে বেশি — ইউনিট/বয়স দেখুন';
    if (_ageUnit == 'months' && n > 60) return 'মাসের হিসাবে বেশি — ইউনিট/বয়স দেখুন';
    if (_ageUnit == 'years' && n > 120) return 'বয়স যাচাই করুন';
    // Floor 12 / ceiling 55 catches typos without blocking real teenage
    // pregnancies (12–18 are allowed but auto-flagged high-risk).
    if (_caseType == 'Pregnancy' && _ageUnit == 'years' && (n < 12 || n > 55)) {
      return 'গর্ভবতীর বয়স সাধারণত ১২–৫৫ বছর';
    }
    return null;
  }

  /// Gender must fit the case type — a pregnancy beneficiary is female.
  String? _validateGender(String? v) {
    if (_caseType == 'Pregnancy' && v != 'Female') {
      return 'গর্ভাবস্থার জন্য লিঙ্গ "মহিলা" হতে হবে';
    }
    return null;
  }

  /// Aadhaar: optional, but if typed it must be 12 digits. A value already
  /// masked by the scan (contains X) is accepted as-is.
  String? _validateAadhaar(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return null;
    if (s.contains('X') || s.contains('x')) return null; // masked from scan
    final digits = s.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 12) return 'আধার নম্বর ১২ সংখ্যার হতে হবে';
    return null;
  }

  /// The schedule keystone date is mandatory: a pregnancy needs LMP (drives the
  /// ANC schedule) and a child/newborn needs DOB (drives vaccines/HBNC). These
  /// are tappable date rows (not form fields), so they're checked here on save.
  /// Returns an error message, or null if OK.
  String? _mchDateError() {
    if (_caseType == 'Pregnancy' && _lmp == null) {
      return 'গর্ভবতীর জন্য শেষ মাসিকের তারিখ (LMP) দিন — ANC সূচি তৈরির জন্য জরুরি।';
    }
    if ((_caseType == 'Newborn' || _caseType == 'Child') && _dob == null) {
      return 'শিশুর জন্ম তারিখ (DOB) দিন — টিকা সূচি তৈরির জন্য জরুরি।';
    }
    return null;
  }

  // The stored value stays English (the patient model + reports rely on it);
  // only what the worker reads is translated.
  String _genderLabel(String g) => switch (g) {
        'Female' => 'gender_female'.tr,
        'Male' => 'gender_male'.tr,
        _ => 'gender_other'.tr,
      };
  String _caseLabel(String c) => switch (c) {
        'Pregnancy' => 'case_pregnancy'.tr,
        'Newborn' => 'case_newborn'.tr,
        'Child' => 'case_child'.tr,
        _ => 'case_other'.tr,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          child: Column(
            children: [
              AppHeader(title: (_isEditing ? 'edit_patient' : 'add_patient').tr),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _photoAvatar(),
                        // Friendly per-case illustration (Gemini art if present,
                        // else the code-drawn figure) — updates with the chips.
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                            'assets/illustrations/${ModuleArt.kindKey(_caseType)}.png',
                            height: 120,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                            errorBuilder: (_, __, ___) =>
                                ModuleArt(kind: _caseType, height: 120),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _aadhaarScanButton(),
                        AppInput(
                          hint: 'full_name'.tr,
                          label: 'patient_name'.tr,
                          controller: _nameCtrl,
                          prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.primary, size: 20),
                          suffixIcon: _micSuffix('name', _nameCtrl),
                          validator: (v) => v == null || v.trim().isEmpty ? 'name_required'.tr : null,
                        ),
                        const SizedBox(height: 16),
                        // ── Age + unit ──────────────────────────────────────
                        Text('age'.tr, style: AppTextStyles.label),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: AppInput(
                                hint: 'age'.tr,
                                controller: _ageCtrl,
                                keyboardType: TextInputType.number,
                                prefixIcon: const Icon(Icons.cake_outlined, color: AppColors.primary, size: 20),
                                validator: _validateAge,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 5,
                              // ValueKey(_ageUnit) forces the field to rebuild when
                              // the case chip changes the unit programmatically —
                              // otherwise `initialValue` is init-only and the shown
                              // unit wouldn't follow the case type.
                              child: DropdownButtonFormField<String>(
                                key: ValueKey('ageUnit_$_ageUnit'),
                                initialValue: _ageUnit,
                                isExpanded: true,
                                onChanged: (v) => setState(() {
                                  _ageUnit = v ?? _ageUnit;
                                  final d = _dobFromAge();
                                  if (d != null) _dob = d;
                                }),
                                style: AppTextStyles.body,
                                decoration: const InputDecoration(),
                                items: ['days', 'months', 'years']
                                    .map((u) => DropdownMenuItem(value: u, child: Text(_ageUnitLabel(u))))
                                    .toList(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // ── Gender ──────────────────────────────────────────
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('gender'.tr, style: AppTextStyles.label),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: _gender,
                              isExpanded: true,
                              onChanged: (v) => setState(() => _gender = v!),
                              style: AppTextStyles.body,
                              decoration: const InputDecoration(),
                              validator: _validateGender,
                              // Value stays English (stored in the model);
                              // only the shown label is localized.
                              items: ['Female', 'Male', 'Other']
                                  .map((g) => DropdownMenuItem(value: g, child: Text(_genderLabel(g))))
                                  .toList(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        AppInput(
                          hint: 'village_hint'.tr,
                          label: 'village'.tr,
                          controller: _villageCtrl,
                          prefixIcon: const Icon(Icons.location_on_outlined, color: AppColors.primary, size: 20),
                          suffixIcon: _micSuffix('village', _villageCtrl),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'গ্রাম/এলাকার নাম দিন' : null,
                        ),
                        const SizedBox(height: 16),
                        AppInput(
                          hint: 'mobile_hint'.tr,
                          label: 'mobile_number'.tr,
                          controller: _mobileCtrl,
                          keyboardType: TextInputType.phone,
                          maxLength: 10,
                          prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.primary, size: 20),
                          validator: Validators.phone,
                        ),
                        const SizedBox(height: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('case_type'.tr, style: AppTextStyles.label),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              children: ['Pregnancy', 'Newborn', 'Child', 'Other'].map((c) {
                                final sel = c == _caseType;
                                return Material(
                                  color: sel ? AppColors.primary : AppColors.surface,
                                  borderRadius: AppRadius.pillR,
                                  child: InkWell(
                                    onTap: () => setState(() {
                                      _caseType = c;
                                      // Age unit follows the case type dynamically:
                                      // newborn→days, child→months, pregnancy/other→
                                      // years. Worker can still override the dropdown.
                                      _ageUnit = _defaultAgeUnit(c);
                                      // Re-derive DOB from age for the new unit.
                                      final d = _dobFromAge();
                                      if (d != null) _dob = d;
                                    }),
                                    borderRadius: AppRadius.pillR,
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 180),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                                      decoration: BoxDecoration(
                                        color: sel ? AppColors.primary : AppColors.surface,
                                        borderRadius: AppRadius.pillR,
                                        boxShadow: sel
                                            ? AppShadows.tinted(AppColors.primary, strength: 2)
                                            : AppShadows.low,
                                      ),
                                      child: Text(
                                        _caseLabel(c),
                                        style: AppTextStyles.label.copyWith(
                                          color: sel ? AppColors.onPrimary : AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                        _mchSection(),
                        _riskHistorySection(),
                        _mcpSection(),
                        const SizedBox(height: 32),
                        Column(
                          children: [
                            AppButton(
                              label: (_isEditing ? 'save_changes' : 'save_patient').tr,
                              onPressed: _saving ? null : _save,
                              isLoading: _saving,
                              outlined: !_isEditing, // edit mode: primary; add mode: secondary (paired with checkup)
                              width: double.infinity,
                            ),
                            // "Save & Start Checkup" only makes sense for new patients —
                            // editing doesn't need a follow-up checkup step.
                            if (!_isEditing) ...[
                              const SizedBox(height: 10),
                              AppButton(
                                label: 'save_and_start_checkup'.tr,
                                onPressed: _saving ? null : _saveAndCheckup,
                                icon: Icons.mic_rounded,
                                width: double.infinity,
                              ),
                            ],
                          ],
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
