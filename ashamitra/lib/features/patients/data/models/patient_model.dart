import '../../../../shared/widgets/risk_badge.dart';

/// Sync state tracking for offline-first patient operations.
/// - synced         : the canonical truth lives on the server, local copy matches
/// - pendingCreate  : added offline, waiting for next online cycle to POST
/// - pendingUpdate  : modified offline since last successful PUT
/// - pendingDelete  : marked for deletion, hidden from UI, waiting to DELETE
enum SyncState { synced, pendingCreate, pendingUpdate, pendingDelete }

class PatientModel {
  final String id;
  final String name;
  final String type;
  final String village;
  final String mobile;
  final String lastVisit;
  final String age;
  /// Unit for [age]: 'days' | 'months' | 'years' (defaults to years). Keeps a
  /// newborn's "6 days" from ever being read as "6 years".
  final String ageUnit;
  final String gender;
  final RiskLevel risk;
  final String? situation;
  final String? outcome;
  final String? reason;
  final String? nextStep;
  final List<Map<String, String>> qaHistory;
  final DateTime createdAt;
  final SyncState syncState;
  /// Server-side version for optimistic concurrency. Incremented on every
  /// successful POST/PUT. The client sends this on PUT; if it no longer
  /// matches the server, the server returns 409 and the client refetches.
  final int version;

  // ── Maternal & child tracking (MCP-card aligned) ──────────────────────────
  /// Date of birth (child / newborn). Drives the immunization + HBNC schedule.
  final DateTime? dob;
  /// Last menstrual period (pregnancy). Drives the ANC1–4 schedule.
  final DateTime? lmp;
  /// Expected delivery date. Auto-computed server-side as lmp + 280 days when
  /// not supplied.
  final DateTime? edd;
  /// Actual delivery date (mother). Drives the PNC postnatal schedule.
  final DateTime? deliveryDate;
  /// Mother's name when this patient is a child.
  final String guardianName;
  /// Masked Aadhaar only (e.g. "XXXX-XXXX-1234"). The raw 12-digit number is
  /// never stored (Aadhaar Act sensitivity).
  final String aadhaarMasked;
  /// Links a child record to its mother's patient id.
  final String? motherId;
  /// True for a multiple birth (twins).
  final bool isTwin;
  /// Birth order within a multiple birth (1, 2, …); 0 when not applicable.
  final int birthOrder;
  /// Full MCP-card identity fields (pg 3) — father's name, address, RCH/MCTS,
  /// PMMVY/JSY + bank, gravida, birth-reg no., Anganwadi/LGD, facility, masked
  /// Aadhaar, etc. Flexible map keyed by the registration form's field keys.
  final Map<String, dynamic> mcpDetails;

  PatientModel({
    required this.id,
    required this.name,
    required this.type,
    required this.village,
    required this.mobile,
    required this.lastVisit,
    this.age = '',
    this.ageUnit = 'years',
    this.gender = '',
    required this.risk,
    this.situation,
    this.outcome,
    this.reason,
    this.nextStep,
    this.qaHistory = const [],
    DateTime? createdAt,
    this.syncState = SyncState.synced,
    this.version = 0,
    this.dob,
    this.lmp,
    this.edd,
    this.deliveryDate,
    this.guardianName = '',
    this.aadhaarMasked = '',
    this.motherId,
    this.isTwin = false,
    this.birthOrder = 0,
    this.mcpDetails = const {},
  }) : createdAt = createdAt ?? DateTime.now();

  /// Government RCH/MCTS registration id — the canonical real-world person key
  /// (the maternal register's "Egiya Bangla Portal ID"). Captured in the form
  /// as `mcpDetails.rchId`; surfaced here for the de-dup matcher + registers.
  String get rchId => (mcpDetails['rchId'] ?? '').toString().trim();

  RiskLevel get riskFromOutcome {
    if (outcome == 'emergency') return RiskLevel.emergency;
    if (outcome == 'attention') return RiskLevel.high;
    if (outcome == 'safe') return RiskLevel.safe;
    return risk;
  }

  /// Best-effort age normalised to days for age-gated clinical rules
  /// (newborn 0–28 d, child 2 mo–5 y). Null when [age] isn't numeric.
  int? get ageInDays {
    final n = int.tryParse(age.trim());
    if (n == null) return null;
    return switch (ageUnit) {
      'days'   => n,
      'months' => n * 30,
      'years'  => n * 365,
      _        => n * 365,
    };
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'village': village,
        'mobile': mobile,
        'lastVisit': lastVisit,
        'age': age,
        'ageUnit': ageUnit,
        'gender': gender,
        'risk': risk.name,
        if (situation != null) 'situation': situation,
        if (outcome != null) 'outcome': outcome,
        if (reason != null) 'reason': reason,
        if (nextStep != null) 'nextStep': nextStep,
        'qaHistory': qaHistory,
        'createdAt': createdAt.toIso8601String(),
        'syncState': syncState.name,
        'version': version,
        if (dob != null) 'dob': dob!.toIso8601String(),
        if (lmp != null) 'lmp': lmp!.toIso8601String(),
        if (edd != null) 'edd': edd!.toIso8601String(),
        if (deliveryDate != null) 'deliveryDate': deliveryDate!.toIso8601String(),
        if (guardianName.isNotEmpty) 'guardianName': guardianName,
        if (aadhaarMasked.isNotEmpty) 'aadhaarMasked': aadhaarMasked,
        if (motherId != null) 'motherId': motherId,
        if (isTwin) 'isTwin': isTwin,
        if (birthOrder > 0) 'birthOrder': birthOrder,
        if (mcpDetails.isNotEmpty) 'mcpDetails': mcpDetails,
      };

  factory PatientModel.fromJson(Map<String, dynamic> json) => PatientModel(
        id: json['id'] as String,
        name: json['name'] as String,
        type: json['type'] as String,
        village: json['village'] as String,
        mobile: json['mobile'] as String? ?? '',
        lastVisit: json['lastVisit'] as String,
        age: json['age'] as String? ?? '',
        ageUnit: json['ageUnit'] as String? ?? 'years',
        gender: json['gender'] as String? ?? '',
        risk: RiskLevel.values.firstWhere(
          (r) => r.name == json['risk'],
          orElse: () => RiskLevel.safe,
        ),
        situation: json['situation'] as String?,
        outcome: json['outcome'] as String?,
        reason: json['reason'] as String?,
        nextStep: json['nextStep'] as String?,
        qaHistory: (json['qaHistory'] as List? ?? [])
            .map((e) => Map<String, String>.from(e as Map))
            .toList(),
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
            : DateTime.now(),
        // Migration-safe default: rows loaded from old local storage (no
        // syncState field) are assumed already-synced.
        syncState: SyncState.values.firstWhere(
          (s) => s.name == json['syncState'],
          orElse: () => SyncState.synced,
        ),
        version: (json['version'] as num?)?.toInt() ?? 0,
        dob: _parseDate(json['dob']),
        lmp: _parseDate(json['lmp']),
        edd: _parseDate(json['edd']),
        deliveryDate: _parseDate(json['deliveryDate']),
        guardianName: json['guardianName'] as String? ?? '',
        aadhaarMasked: json['aadhaarMasked'] as String? ?? '',
        motherId: json['motherId'] as String?,
        isTwin: json['isTwin'] as bool? ?? false,
        birthOrder: (json['birthOrder'] as num?)?.toInt() ?? 0,
        mcpDetails: (json['mcpDetails'] as Map?)?.cast<String, dynamic>() ?? const {},
      );

  /// Parses a server date (ISO string) or null. Tolerates already-DateTime
  /// values and empty strings so old/local rows never crash deserialization.
  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  PatientModel copyWith({
    String? id,
    String? name,
    String? type,
    String? village,
    String? mobile,
    String? lastVisit,
    String? age,
    String? ageUnit,
    String? gender,
    RiskLevel? risk,
    String? situation,
    String? outcome,
    String? reason,
    String? nextStep,
    List<Map<String, String>>? qaHistory,
    SyncState? syncState,
    int? version,
    DateTime? dob,
    DateTime? lmp,
    DateTime? edd,
    DateTime? deliveryDate,
    String? guardianName,
    String? aadhaarMasked,
    String? motherId,
    bool? isTwin,
    int? birthOrder,
    Map<String, dynamic>? mcpDetails,
  }) =>
      PatientModel(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        village: village ?? this.village,
        mobile: mobile ?? this.mobile,
        lastVisit: lastVisit ?? this.lastVisit,
        age: age ?? this.age,
        ageUnit: ageUnit ?? this.ageUnit,
        gender: gender ?? this.gender,
        risk: risk ?? this.risk,
        situation: situation ?? this.situation,
        outcome: outcome ?? this.outcome,
        reason: reason ?? this.reason,
        nextStep: nextStep ?? this.nextStep,
        qaHistory: qaHistory ?? this.qaHistory,
        createdAt: createdAt,
        syncState: syncState ?? this.syncState,
        version: version ?? this.version,
        dob: dob ?? this.dob,
        lmp: lmp ?? this.lmp,
        edd: edd ?? this.edd,
        deliveryDate: deliveryDate ?? this.deliveryDate,
        guardianName: guardianName ?? this.guardianName,
        aadhaarMasked: aadhaarMasked ?? this.aadhaarMasked,
        motherId: motherId ?? this.motherId,
        isTwin: isTwin ?? this.isTwin,
        birthOrder: birthOrder ?? this.birthOrder,
        mcpDetails: mcpDetails ?? this.mcpDetails,
      );
}
