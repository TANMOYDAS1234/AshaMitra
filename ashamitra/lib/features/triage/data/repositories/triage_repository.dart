import '../datasources/triage_remote_ds.dart';
import '../datasources/triage_local_ds.dart';
import '../models/triage_model.dart';
import '../models/question_model.dart';

class TriageRepository {
  final TriageRemoteDs _remote;
  final TriageLocalDs _local;
  TriageRepository(this._remote, this._local);

  Future<List<QuestionModel>> getQuestions(String caseType) async {
    final data = await _remote.getQuestions(caseType);
    return data.map((e) => QuestionModel.fromJson(e)).toList();
  }

  Future<TriageModel> submit(Map<String, dynamic> data) async {
    final res = await _remote.submitTriage(data);
    return TriageModel.fromJson(res);
  }
}
