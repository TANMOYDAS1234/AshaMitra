import '../../../../core/services/api_service.dart';
import '../../../../core/constants/api_constants.dart';

class TriageRemoteDs {
  final ApiService _api;
  TriageRemoteDs(this._api);

  Future<Map<String, dynamic>> submitTriage(Map<String, dynamic> data) async {
    final res = await _api.post(ApiConstants.triage, data: data);
    return res.data;
  }

  Future<List<dynamic>> getQuestions(String caseType) async {
    final res = await _api.get('${ApiConstants.triage}/questions?type=$caseType');
    return res.data;
  }
}
