import '../../../patients/data/models/patient_model.dart' show SyncState;

export '../../../patients/data/models/patient_model.dart' show SyncState;

/// An ASHA referral (paper "Form 3") plus the OUTCOME tracking the field
/// interviews flagged as the #1 missing piece — today a patient vanishes once
/// she leaves the sub-centre. [status] moves pending → reached → completed (or
/// cancelled); the worker records who admitted her + the outcome when known.
///
/// Offline-first, mirroring [PatientModel]: a locally-created referral gets a
/// `ref_<ts>` placeholder id (also used as the server-side `clientId`
/// idempotency key) until its first successful sync swaps in the Mongo `_id`.
class ReferralModel {
  final String id;
  final String patientId;     // links to the PatientModel (may be a placeholder)
  final String patientName;
  final String age;
  final String gender;
  final String guardianName;
  final String village;
  final String mobile;
  final String caseType;      // pregnancy | newborn | child | other
  final String symptoms;      // illness / danger signs (the "why")
  final String currentWeight; // child (Form 3)
  final String imnci;         // IMNCI classification (child)
  final String medicinesGiven;
  final String referredTo;    // facility referred to (FRU / PHC / DH …)
  final String reason;        // band / danger summary
  final String band;          // RED | YELLOW

  // ── Outcome tracking ──────────────────────────────────────────────────────
  /// pending → the slip is created, patient not yet confirmed reached.
  /// reached → patient reached the facility.
  /// completed → outcome recorded (admitted / treated / referred up …).
  /// cancelled → referral called off.
  final String status;
  final DateTime? reachedDate;
  final String admittedBy;
  final String relation;
  final String facilityNotes;
  final String outcome;       // admitted / treated & sent home / referred up …

  final DateTime createdAt;
  final SyncState syncState;
  final int version;

  ReferralModel({
    required this.id,
    this.patientId = '',
    required this.patientName,
    this.age = '',
    this.gender = '',
    this.guardianName = '',
    this.village = '',
    this.mobile = '',
    this.caseType = '',
    this.symptoms = '',
    this.currentWeight = '',
    this.imnci = '',
    this.medicinesGiven = '',
    this.referredTo = '',
    this.reason = '',
    this.band = '',
    this.status = 'pending',
    this.reachedDate,
    this.admittedBy = '',
    this.relation = '',
    this.facilityNotes = '',
    this.outcome = '',
    DateTime? createdAt,
    this.syncState = SyncState.synced,
    this.version = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  /// True until the referral's outcome is settled — drives the "open referrals"
  /// badge and the worker's follow-up list.
  bool get isOpen => status == 'pending' || status == 'reached';

  Map<String, dynamic> toJson() => {
        'id': id,
        'patientId': patientId,
        'patientName': patientName,
        'age': age,
        'gender': gender,
        'guardianName': guardianName,
        'village': village,
        'mobile': mobile,
        'caseType': caseType,
        'symptoms': symptoms,
        'currentWeight': currentWeight,
        'imnci': imnci,
        'medicinesGiven': medicinesGiven,
        'referredTo': referredTo,
        'reason': reason,
        'band': band,
        'status': status,
        if (reachedDate != null) 'reachedDate': reachedDate!.toIso8601String(),
        'admittedBy': admittedBy,
        'relation': relation,
        'facilityNotes': facilityNotes,
        'outcome': outcome,
        'createdAt': createdAt.toIso8601String(),
        'syncState': syncState.name,
        'version': version,
      };

  factory ReferralModel.fromJson(Map<String, dynamic> json) => ReferralModel(
        // Server sends `id` (mapped from _id by toClient); local cache also
        // stores `id`. Fall back to _id just in case a raw doc slips through.
        id: (json['id'] ?? json['_id'] ?? '').toString(),
        patientId: json['patientId'] as String? ?? '',
        patientName: json['patientName'] as String? ?? '',
        age: json['age'] as String? ?? '',
        gender: json['gender'] as String? ?? '',
        guardianName: json['guardianName'] as String? ?? '',
        village: json['village'] as String? ?? '',
        mobile: json['mobile'] as String? ?? '',
        caseType: json['caseType'] as String? ?? '',
        symptoms: json['symptoms'] as String? ?? '',
        currentWeight: json['currentWeight'] as String? ?? '',
        imnci: json['imnci'] as String? ?? '',
        medicinesGiven: json['medicinesGiven'] as String? ?? '',
        referredTo: json['referredTo'] as String? ?? '',
        reason: json['reason'] as String? ?? '',
        band: json['band'] as String? ?? '',
        status: json['status'] as String? ?? 'pending',
        reachedDate: _parseDate(json['reachedDate']),
        admittedBy: json['admittedBy'] as String? ?? '',
        relation: json['relation'] as String? ?? '',
        facilityNotes: json['facilityNotes'] as String? ?? '',
        outcome: json['outcome'] as String? ?? '',
        createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
        // Migration-safe: rows from old cache (no syncState) are already-synced.
        syncState: SyncState.values.firstWhere(
          (s) => s.name == json['syncState'],
          orElse: () => SyncState.synced,
        ),
        version: (json['version'] as num?)?.toInt() ?? 0,
      );

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  ReferralModel copyWith({
    String? id,
    String? patientId,
    String? patientName,
    String? age,
    String? gender,
    String? guardianName,
    String? village,
    String? mobile,
    String? caseType,
    String? symptoms,
    String? currentWeight,
    String? imnci,
    String? medicinesGiven,
    String? referredTo,
    String? reason,
    String? band,
    String? status,
    DateTime? reachedDate,
    String? admittedBy,
    String? relation,
    String? facilityNotes,
    String? outcome,
    SyncState? syncState,
    int? version,
  }) =>
      ReferralModel(
        id: id ?? this.id,
        patientId: patientId ?? this.patientId,
        patientName: patientName ?? this.patientName,
        age: age ?? this.age,
        gender: gender ?? this.gender,
        guardianName: guardianName ?? this.guardianName,
        village: village ?? this.village,
        mobile: mobile ?? this.mobile,
        caseType: caseType ?? this.caseType,
        symptoms: symptoms ?? this.symptoms,
        currentWeight: currentWeight ?? this.currentWeight,
        imnci: imnci ?? this.imnci,
        medicinesGiven: medicinesGiven ?? this.medicinesGiven,
        referredTo: referredTo ?? this.referredTo,
        reason: reason ?? this.reason,
        band: band ?? this.band,
        status: status ?? this.status,
        reachedDate: reachedDate ?? this.reachedDate,
        admittedBy: admittedBy ?? this.admittedBy,
        relation: relation ?? this.relation,
        facilityNotes: facilityNotes ?? this.facilityNotes,
        outcome: outcome ?? this.outcome,
        createdAt: createdAt,
        syncState: syncState ?? this.syncState,
        version: version ?? this.version,
      );
}
