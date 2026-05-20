import 'package:get/get.dart';
import '../data/models/patient_model.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/services/api_service.dart';
import '../../../shared/widgets/risk_badge.dart';

class PatientController extends GetxController {
  final isLoading = false.obs;
  final patients  = <PatientModel>[].obs;
  final reports   = <Map<String, dynamic>>[].obs;

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  void _load() {
    final raw = LocalStorageService.loadPatients();
    patients.value = raw.map(PatientModel.fromJson).toList();
    reports.value  = LocalStorageService.loadReports()
        .map((r) => _sanitizeReport(r))
        .toList();
  }

  void reloadFromStorage() => _load();

  /// Primary data load from Atlas. Falls back to local if offline.
  Future<void> syncFromServer() async {
    isLoading.value = true;
    try {
      // Sync patients
      final remotePatients = await ApiService.getPatients();
      if (remotePatients.isNotEmpty) {
        final list = remotePatients
            .map((e) => PatientModel.fromJson(e as Map<String, dynamic>))
            .toList();
        patients.value = list;
        await LocalStorageService.savePatients(list.map((p) => p.toJson()).toList());
      }
      // Sync reports
      final remote = await ApiService.getReports();
      if (remote.isNotEmpty) {
        final remoteReports = remote
            .map((e) => _sanitizeReport(_remoteToLocal(e as Map<String, dynamic>)))
            .toList();
        reports.value = remoteReports;
        LocalStorageService.saveReports(remoteReports);
      }
    } on UnauthorizedException {
      // Token invalid
    } catch (_) {
      // Offline — local data already loaded
    } finally {
      isLoading.value = false;
    }
  }

  /// Map MongoDB report fields → local report map shape.
  Map<String, dynamic> _remoteToLocal(Map<String, dynamic> r) => {
    'id':                  r['_id']?.toString() ?? r['sessionId'] ?? '',
    'sessionId':           r['sessionId'] ?? '',
    'caseType':            r['caseType'] ?? '',
    'caseLabel':           r['caseLabel'] ?? _caseLabel(r['caseType']?.toString() ?? ''),
    'outcome':             _bandToOutcome(r['finalBand']?.toString()),
    'finalBand':           r['finalBand'] ?? 'UNKNOWN',
    'reason':              r['reason'] ?? '',
    'nextStep':            r['nextStep'] ?? '',
    'situation':           r['situation'] ?? '',
    'qaHistory':           r['qaHistory'] ?? [],
    'patientId':           r['patientId'] ?? '',
    'patientName':         r['patientName'] ?? '',
    'triggeredRules':      r['triggeredRules'] ?? [],
    'riskScore':           r['riskScore'] ?? 0,
    'riskLevel':           r['riskLevel'] ?? '',
    'dangerSigns':         r['dangerSigns'] ?? [],
    'suspectedConditions': r['suspectedConditions'] ?? [],
    'facilityType':        r['facilityType'] ?? '',
    'recheckAfterHours':   r['recheckAfterHours'] ?? 0,
    'transportAction':     '',
    'createdAt':           r['createdAt'] ?? DateTime.now().toIso8601String(),
  };

  String _bandToOutcome(String? band) => switch (band?.toUpperCase()) {
    'RED'    => 'emergency',
    'YELLOW' => 'attention',
    _        => 'safe',
  };

  Future<void> _save() async {
    await LocalStorageService.savePatients(
      patients.map((p) => p.toJson()).toList(),
    );
  }

  /// Sanitizes a report loaded from SharedPreferences.
  /// JSON deserialization returns List<dynamic> and num — normalize all types.
  Map<String, dynamic> _sanitizeReport(Map<String, dynamic> r) => {
    ...r,
    'riskScore':        _toInt(r['riskScore']),
    'recheckAfterHours': _toInt(r['recheckAfterHours']),
    'dangerSigns':      _toStringList(r['dangerSigns']),
    'suspectedConditions': _toStringList(r['suspectedConditions']),
    'triggeredRules':   _toStringList(r['triggeredRules']),
    'qaHistory':        _toQaList(r['qaHistory']),
    'outcome':          r['outcome']?.toString() ?? 'safe',
    'finalBand':        r['finalBand']?.toString() ?? '',
    'caseLabel':        r['caseLabel']?.toString() ?? '',
    'patientName':      r['patientName']?.toString() ?? '',
    'facilityType':     r['facilityType']?.toString() ?? '',
    'reason':           r['reason']?.toString() ?? '',
    'nextStep':         r['nextStep']?.toString() ?? '',
    'createdAt':        r['createdAt']?.toString() ?? '',
  };

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  static List<String> _toStringList(dynamic v) {
    if (v == null) return [];
    if (v is List) return v.map((e) => e.toString()).toList();
    return [];
  }

  static List<Map<String, String>> _toQaList(dynamic v) {
    if (v == null) return [];
    if (v is List) {
      return v.map((e) {
        if (e is Map) {
          return e.map((k, val) => MapEntry(k.toString(), val.toString()));
        }
        return <String, String>{};
      }).where((m) => m.isNotEmpty).toList();
    }
    return [];
  }

  void addPatient({
    required String name,
    required String type,
    required String village,
    required String mobile,
    String? situation,
    String? outcome,
    String? reason,
    String? nextStep,
    List<Map<String, String>> qaHistory = const [],
  }) {
    final patient = PatientModel(
      id:        'p_${DateTime.now().millisecondsSinceEpoch}',
      name:      name,
      type:      type,
      village:   village,
      mobile:    mobile,
      lastVisit: 'এইমাত্র',
      risk:      _riskFromOutcome(outcome),
      situation: situation,
      outcome:   outcome,
      reason:    reason,
      nextStep:  nextStep,
      qaHistory: qaHistory,
    );
    patients.insert(0, patient);
    _save();
    // Sync to backend — exclude local id field
    final data = patient.toJson()..remove('id');
    ApiService.savePatient(data).catchError((_) {});
  }

  /// Auto-called from TriageResultScreen — saves full DecisionOutput to reports.
  void saveReport({
    required String caseType,
    required String outcome,
    required String reason,
    required String nextStep,
    required String situation,
    required List<Map<String, String>> qaHistory,
    String? patientId,
    String? patientName,
    String finalBand                 = '',
    List<String> triggeredRules      = const [],
    int riskScore                    = 0,
    String riskLevel                 = '',
    List<String> dangerSigns         = const [],
    List<String> suspectedConditions = const [],
    String facilityType              = '',
    int recheckAfterHours            = 0,
    String transportAction           = '',
  }) {
    final report = <String, dynamic>{
      'id':                  'report_${DateTime.now().millisecondsSinceEpoch}',
      'caseType':            caseType,
      'caseLabel':           _caseLabel(caseType),
      'outcome':             outcome,
      'finalBand':           finalBand.isNotEmpty ? finalBand : outcome.toUpperCase(),
      'reason':              reason,
      'nextStep':            nextStep,
      'situation':           situation,
      'qaHistory':           qaHistory,
      'patientId':           patientId ?? '',
      'patientName':         patientName ?? '',
      'triggeredRules':      triggeredRules,
      'riskScore':           riskScore,
      'riskLevel':           riskLevel,
      'dangerSigns':         dangerSigns,
      'suspectedConditions': suspectedConditions,
      'facilityType':        facilityType,
      'recheckAfterHours':   recheckAfterHours,
      'transportAction':     transportAction,
      'createdAt':           DateTime.now().toIso8601String(),
    };
    reports.insert(0, report);
    LocalStorageService.saveReports(reports.toList());
    // Sync to backend — exclude local id
    final data = Map<String, dynamic>.from(report)..remove('id');
    ApiService.saveReport(data).catchError((_) {});
  }

  /// Called from "ফলো-আপ" button — adds to patient list.
  void saveTriageResult({
    required String caseType,
    required String outcome,
    required String reason,
    required String nextStep,
    required String situation,
    required List<Map<String, String>> qaHistory,
  }) {
    final caseLabel = _caseLabel(caseType);
    final patient = PatientModel(
      id:        'triage_${DateTime.now().millisecondsSinceEpoch}',
      name:      'রোগী — $caseLabel',
      type:      caseLabel,
      village:   '—',
      mobile:    '',
      lastVisit: _todayLabel(),
      risk:      _riskFromOutcome(outcome),
      situation: situation,
      outcome:   outcome,
      reason:    reason,
      nextStep:  nextStep,
      qaHistory: qaHistory,
    );
    patients.insert(0, patient);
    _save();
    // Sync to backend — exclude local id field
    final data = patient.toJson()..remove('id');
    ApiService.savePatient(data).catchError((_) {});
  }

  void updatePatient(PatientModel updated) {
    final idx = patients.indexWhere((p) => p.id == updated.id);
    if (idx != -1) { patients[idx] = updated; _save(); }
  }

  void deletePatient(String id) {
    patients.removeWhere((p) => p.id == id);
    _save();
  }

  RiskLevel _riskFromOutcome(String? outcome) => switch (outcome) {
    'emergency' => RiskLevel.emergency,
    'attention' => RiskLevel.high,
    'safe'      => RiskLevel.safe,
    _           => RiskLevel.moderate,
  };

  String _caseLabel(String caseType) => switch (caseType) {
    'pregnancy'    => 'গর্ভবতী মায়ের চেকআপ',
    'postpartum'   => 'প্রসব-পরবর্তী',
    'newborn'      => 'নবজাতক',
    'infant'       => 'শিশু (১-১২ মাস)',
    'child'        => 'শিশু স্বাস্থ্য',
    'immunization' => 'টিকাকরণ',
    'emergency'    => 'জরুরি অবস্থা',
    _              => 'সাধারণ চেকআপ',
  };

  String _todayLabel() {
    final now = DateTime.now();
    return '${now.day}/${now.month}/${now.year}';
  }
}
