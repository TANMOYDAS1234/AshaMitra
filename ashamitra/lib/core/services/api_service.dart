import 'dart:convert';
import 'package:http/http.dart' as http;
import 'local_storage_service.dart';

class UnauthorizedException implements Exception {}

class _ApiResponse {
  final dynamic data;
  final int statusCode;
  _ApiResponse(this.data, this.statusCode);
}

class ApiService {
  static const baseUrl = 'https://ashamitra-backend.onrender.com/api';

  static String? _token;

  static void setToken(String token) {
    _token = token;
    LocalStorageService.set('jwt_token', token);
  }

  static void setTokenInMemory(String token) => _token = token;

  static Future<void> loadToken() async {
    _token = LocalStorageService.get('jwt_token');
  }

  static void clearToken() {
    _token = null;
    LocalStorageService.remove('jwt_token');
  }

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  /// Throws [UnauthorizedException] on 401 — caller forces logout.
  static void _guard(int status) {
    if (status == 401) throw UnauthorizedException();
  }

  // ── Generic instance methods (used by datasources) ─────────────────────────

  Future<_ApiResponse> get(String path) async {
    final res = await http
        .get(Uri.parse('$baseUrl$path'), headers: _headers)
        .timeout(const Duration(seconds: 15));
    return _ApiResponse(jsonDecode(res.body), res.statusCode);
  }

  Future<_ApiResponse> post(String path, {Map<String, dynamic>? data}) async {
    final res = await http
        .post(Uri.parse('$baseUrl$path'),
            headers: _headers, body: jsonEncode(data ?? {}))
        .timeout(const Duration(seconds: 15));
    return _ApiResponse(jsonDecode(res.body), res.statusCode);
  }

  Future<_ApiResponse> put(String path, {Map<String, dynamic>? data}) async {
    final res = await http
        .put(Uri.parse('$baseUrl$path'),
            headers: _headers, body: jsonEncode(data ?? {}))
        .timeout(const Duration(seconds: 15));
    return _ApiResponse(jsonDecode(res.body), res.statusCode);
  }

  Future<_ApiResponse> delete(String path) async {
    final res = await http
        .delete(Uri.parse('$baseUrl$path'), headers: _headers)
        .timeout(const Duration(seconds: 15));
    return _ApiResponse(jsonDecode(res.body), res.statusCode);
  }

  // ── Auth ───────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> sendOtp(String phone) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/send-otp'),
      headers: _headers,
      body: jsonEncode({'phone': phone}),
    ).timeout(const Duration(seconds: 15));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> verifyOtp(String phone, String otp) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/verify-otp'),
      headers: _headers,
      body: jsonEncode({'phone': phone, 'otp': otp}),
    ).timeout(const Duration(seconds: 15));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final res = await http.put(
      Uri.parse('$baseUrl/auth/profile'),
      headers: _headers,
      body: jsonEncode(data),
    ).timeout(const Duration(seconds: 30));
    _guard(res.statusCode);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── Patients ───────────────────────────────────────────────────────────────

  static Future<List<dynamic>> getPatients() async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/patients'), headers: _headers)
          .timeout(const Duration(seconds: 15));
      _guard(res.statusCode);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body['data'] as List? ?? [];
    } catch (_) {
      return [];
    }
  }

  static Future<bool> savePatient(Map<String, dynamic> patient) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/patients'),
        headers: _headers,
        body: jsonEncode(patient),
      ).timeout(const Duration(seconds: 15));
      _guard(res.statusCode);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body['success'] == true;
    } catch (_) {
      return false;
    }
  }

  // ── Reports ────────────────────────────────────────────────────────────────

  static Future<bool> saveReport(Map<String, dynamic> report) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/reports'),
        headers: _headers,
        body: jsonEncode(report),
      ).timeout(const Duration(seconds: 15));
      _guard(res.statusCode);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body['success'] == true;
    } catch (_) {
      return false;
    }
  }

  static Future<List<dynamic>> getReports() async {
    final res = await http
        .get(Uri.parse('$baseUrl/reports'), headers: _headers)
        .timeout(const Duration(seconds: 15));
    _guard(res.statusCode);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return body['data'] as List? ?? [];
  }

  // ── Admin — Workers ────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getWorkers() async {
    final res = await http.get(
      Uri.parse('$baseUrl/admin/workers'),
      headers: _headers,
    ).timeout(const Duration(seconds: 15));
    _guard(res.statusCode);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> addWorker(Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('$baseUrl/admin/workers'),
      headers: _headers,
      body: jsonEncode(data),
    ).timeout(const Duration(seconds: 15));
    _guard(res.statusCode);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> deactivateWorker(String id) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/admin/workers/$id/deactivate'),
      headers: _headers,
    ).timeout(const Duration(seconds: 15));
    _guard(res.statusCode);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> activateWorker(String id) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/admin/workers/$id/activate'),
      headers: _headers,
    ).timeout(const Duration(seconds: 15));
    _guard(res.statusCode);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getWorkerProfile(String id) async {
    final res = await http.get(
      Uri.parse('$baseUrl/admin/workers/$id/profile'),
      headers: _headers,
    ).timeout(const Duration(seconds: 15));
    _guard(res.statusCode);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getWorkerPatients(String id) async {
    final res = await http.get(
      Uri.parse('$baseUrl/admin/workers/$id/patients'),
      headers: _headers,
    ).timeout(const Duration(seconds: 15));
    _guard(res.statusCode);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getWorkerReports(String id) async {
    final res = await http.get(
      Uri.parse('$baseUrl/admin/workers/$id/reports'),
      headers: _headers,
    ).timeout(const Duration(seconds: 15));
    _guard(res.statusCode);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── Admin — Reports ────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getAdminReports({
    String? band,
    String? date,
    String? month,
    String? year,
  }) async {
    final params = <String, String>{};
    if (band  != null) params['band']  = band;
    if (date  != null) params['date']  = date;
    if (month != null) params['month'] = month;
    if (year  != null) params['year']  = year;
    final uri = Uri.parse('$baseUrl/admin/reports')
        .replace(queryParameters: params.isEmpty ? null : params);
    final res = await http.get(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));
    _guard(res.statusCode);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getAdminStats() async {
    final res = await http.get(
      Uri.parse('$baseUrl/admin/stats'),
      headers: _headers,
    ).timeout(const Duration(seconds: 15));
    _guard(res.statusCode);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
