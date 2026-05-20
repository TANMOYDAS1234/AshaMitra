import '../../../../shared/widgets/risk_badge.dart';

class PatientModel {
  final String id;
  final String name;
  final String type;
  final String village;
  final String mobile;
  final String lastVisit;
  final RiskLevel risk;
  final String? situation;
  final String? outcome;
  final String? reason;
  final String? nextStep;
  final List<Map<String, String>> qaHistory;
  final DateTime createdAt;

  PatientModel({
    required this.id,
    required this.name,
    required this.type,
    required this.village,
    required this.mobile,
    required this.lastVisit,
    required this.risk,
    this.situation,
    this.outcome,
    this.reason,
    this.nextStep,
    this.qaHistory = const [],
    DateTime? createdAt,
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
        'risk': risk.name,
        if (situation != null) 'situation': situation,
        if (outcome != null) 'outcome': outcome,
        if (reason != null) 'reason': reason,
        if (nextStep != null) 'nextStep': nextStep,
        'qaHistory': qaHistory,
        'createdAt': createdAt.toIso8601String(),
      };

  factory PatientModel.fromJson(Map<String, dynamic> json) => PatientModel(
        id: json['id'] as String,
        name: json['name'] as String,
        type: json['type'] as String,
        village: json['village'] as String,
        mobile: json['mobile'] as String? ?? '',
        lastVisit: json['lastVisit'] as String,
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
      );

  PatientModel copyWith({
    String? name,
    String? type,
    String? village,
    String? mobile,
    String? lastVisit,
    RiskLevel? risk,
    String? situation,
    String? outcome,
    String? reason,
    String? nextStep,
    List<Map<String, String>>? qaHistory,
  }) =>
      PatientModel(
        id: id,
        name: name ?? this.name,
        type: type ?? this.type,
        village: village ?? this.village,
        mobile: mobile ?? this.mobile,
        lastVisit: lastVisit ?? this.lastVisit,
        risk: risk ?? this.risk,
        situation: situation ?? this.situation,
        outcome: outcome ?? this.outcome,
        reason: reason ?? this.reason,
        nextStep: nextStep ?? this.nextStep,
        qaHistory: qaHistory ?? this.qaHistory,
        createdAt: createdAt,
      );
}
