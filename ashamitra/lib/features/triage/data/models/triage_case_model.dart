import 'question_model.dart';

class BandResolutionRule {
  final String ruleId;
  final String condition;
  final String risk;
  final String action;

  const BandResolutionRule({
    required this.ruleId,
    required this.condition,
    required this.risk,
    required this.action,
  });

  factory BandResolutionRule.fromJson(Map<String, dynamic> json) =>
      BandResolutionRule(
        ruleId: json['ruleId'] as String,
        condition: json['condition'] as String,
        risk: json['risk'] as String,
        action: json['action'] as String,
      );
}

class TriageCaseModel {
  final String id;
  final String title;
  final String titleEn;
  final String module;
  final String protocol;
  final List<String> keywords;
  final List<QuestionModel> questions;

  const TriageCaseModel({
    required this.id,
    required this.title,
    required this.titleEn,
    required this.module,
    required this.protocol,
    required this.keywords,
    required this.questions,
  });

  factory TriageCaseModel.fromJson(Map<String, dynamic> json) =>
      TriageCaseModel(
        id: json['id'] as String,
        title: json['title'] as String,
        titleEn: json['titleEn'] as String,
        module: (json['module'] as String?) ?? '',
        protocol: (json['protocol'] as String?) ?? '',
        keywords: List<String>.from(json['keywords'] as List),
        questions: (json['questions'] as List)
            .map((q) => QuestionModel.fromJson(q as Map<String, dynamic>))
            .toList(),
      );

  /// Returns the first fired hard-stop question for a given answer map,
  /// or null if none fired.
  QuestionModel? firedHardStop(Map<String, String> answers) {
    for (final q in questions) {
      if (q.hardStop && answers[q.id] == 'হ্যাঁ') return q;
    }
    return null;
  }

  /// Returns all YELLOW-risk questions that were answered 'হ্যাঁ'.
  List<QuestionModel> firedYellowRules(Map<String, String> answers) =>
      questions
          .where((q) =>
              !q.hardStop &&
              q.risk == 'YELLOW' &&
              answers[q.id] == 'হ্যাঁ')
          .toList();
}
