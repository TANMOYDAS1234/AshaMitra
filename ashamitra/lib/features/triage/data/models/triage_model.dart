class TriageModel {
  final String id;
  final String patientId;
  final String riskLevel;
  final String summary;
  final DateTime createdAt;

  const TriageModel({required this.id, required this.patientId, required this.riskLevel, required this.summary, required this.createdAt});

  factory TriageModel.fromJson(Map<String, dynamic> json) => TriageModel(
        id: json['id'],
        patientId: json['patientId'],
        riskLevel: json['riskLevel'],
        summary: json['summary'],
        createdAt: DateTime.parse(json['createdAt']),
      );
}
