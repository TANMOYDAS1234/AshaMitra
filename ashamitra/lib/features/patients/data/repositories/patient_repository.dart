import '../datasources/patient_remote_ds.dart';
import '../datasources/patient_local_ds.dart';
import '../models/patient_model.dart';

class PatientRepository {
  final PatientRemoteDs _remote;
  final PatientLocalDs _local;
  PatientRepository(this._remote, this._local);

  Future<List<PatientModel>> getAll() async {
    final data = await _remote.getAll();
    return data.map((e) => PatientModel.fromJson(e)).toList();
  }

  Future<PatientModel> create(Map<String, dynamic> data) async {
    final res = await _remote.create(data);
    return PatientModel.fromJson(res);
  }

  Future<PatientModel> getById(String id) async {
    final res = await _remote.getById(id);
    return PatientModel.fromJson(res);
  }
}
