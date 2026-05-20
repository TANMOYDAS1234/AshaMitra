import '../../../../core/services/api_service.dart';
import '../../../../core/constants/api_constants.dart';

class PatientRemoteDs {
  final ApiService _api;
  PatientRemoteDs(this._api);

  Future<List<dynamic>> getAll() async {
    final res = await _api.get(ApiConstants.patients);
    return res.data;
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> data) async {
    final res = await _api.post(ApiConstants.patients, data: data);
    return res.data;
  }

  Future<Map<String, dynamic>> getById(String id) async {
    final res = await _api.get('${ApiConstants.patients}/$id');
    return res.data;
  }
}
