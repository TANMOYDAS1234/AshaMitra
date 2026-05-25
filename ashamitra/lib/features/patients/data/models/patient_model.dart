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

  PatientModel({
    required this.id,
    required this.name,
    required this.type,
    required this.village,
    required this.mobile,
    required this.lastVisit,
    this.age = '',
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
  }) : createdAt = createdAt ?? DateTime.now();

  RiskLevel get riskFromOutcome {
    if (outcome == 'emergency') return RiskLevel.emergency;
    if (outcome == 'attention') return RiskLevel.high;
    if (outcome == 'safe') return RiskLevel.safe;
    return risk;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'village': village,
        'mobile': mobile,
        'lastVisit': lastVisit,
        'age': age,
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
      };

  factory PatientModel.fromJson(Map<String, dynamic> json) => PatientModel(
        id: json['id'] as String,
        name: json['name'] as String,
        type: json['type'] as String,
        village: json['village'] as String,
        mobile: json['mobile'] as String? ?? '',
        lastVisit: json['lastVisit'] as String,
        age: json['age'] as String? ?? '',
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
      );

  PatientModel copyWith({
    String? id,
    String? name,
    String? type,
    String? village,
    String? mobile,
    String? lastVisit,
    String? age,
    String? gender,
    RiskLevel? risk,
    String? situation,
    String? outcome,
    String? reason,
    String? nextStep,
    List<Map<String, String>>? qaHistory,
    SyncState? syncState,
    int? version,
  }) =>
      PatientModel(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        village: village ?? this.village,
        mobile: mobile ?? this.mobile,
        lastVisit: lastVisit ?? this.lastVisit,
        age: age ?? this.age,
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
      );
}
