class QuestionModel {
  final String id;
  final String ruleId;
  final String text;
  final String textEn;
  final List<String> options;
  final List<String> symptoms;
  final String risk;       // 'RED' | 'YELLOW' | 'GREEN'
  final bool hardStop;
  final String action;
  final String? riskNote;
  final bool? invariant;

  const QuestionModel({
    required this.id,
    required this.ruleId,
    required this.text,
    required this.textEn,
    required this.options,
    required this.symptoms,
    required this.risk,
    required this.hardStop,
    required this.action,
    this.riskNote,
    this.invariant,
  });

  factory QuestionModel.fromJson(Map<String, dynamic> json) => QuestionModel(
        id: json['id'] as String,
        ruleId: (json['ruleId'] as String?) ?? '',
        text: json['text'] as String,
        textEn: (json['textEn'] as String?) ?? '',
        options: List<String>.from(json['options'] as List),
        symptoms: json['symptoms'] != null
            ? List<String>.from(json['symptoms'] as List)
            : [],
        risk: (json['risk'] as String?) ?? 'GREEN',
        hardStop: (json['hardStop'] as bool?) ?? false,
        action: (json['action'] as String?) ?? '',
        riskNote: json['riskNote'] as String?,
        invariant: json['invariant'] as bool?,
      );
}
