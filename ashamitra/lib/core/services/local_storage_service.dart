import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static late SharedPreferences _prefs;

  static const _keyUser = 'session_user';
  static const _keyLanguage = 'session_language';
  static const _keyPatients = 'session_patients';
  static const _keyTriageSessions = 'session_triage';
  static const _keyReports = 'session_reports';

  static Future<void> init() async =>
      _prefs = await SharedPreferences.getInstance();

  // ── Generic ──────────────────────────────────────────────────
  static Future<void> set(String key, String value) =>
      _prefs.setString(key, value);
  static String? get(String key) => _prefs.getString(key);
  static Future<void> remove(String key) => _prefs.remove(key);

  // ── User session ─────────────────────────────────────────────
  static Future<void> saveUser(Map<String, dynamic> json) =>
      _prefs.setString(_keyUser, jsonEncode(json));
  static Map<String, dynamic>? loadUser() {
    final raw = _prefs.getString(_keyUser);
    if (raw == null) return null;
    try { return jsonDecode(raw) as Map<String, dynamic>; } catch (_) { return null; }
  }
  static Future<void> clearUser() => _prefs.remove(_keyUser);

  // ── Language ─────────────────────────────────────────────────
  static Future<void> saveLanguage(int index) =>
      _prefs.setInt(_keyLanguage, index);
  static int loadLanguage() => _prefs.getInt(_keyLanguage) ?? 0;

  // ── Patients ─────────────────────────────────────────────────
  static Future<void> savePatients(List<Map<String, dynamic>> list) =>
      _prefs.setString(_keyPatients, jsonEncode(list));
  static List<Map<String, dynamic>> loadPatients() {
    final raw = _prefs.getString(_keyPatients);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) { return []; }
  }

  // ── Triage sessions ──────────────────────────────────────────
  static Future<void> saveTriageSessions(List<Map<String, dynamic>> list) =>
      _prefs.setString(_keyTriageSessions, jsonEncode(list));
  static List<Map<String, dynamic>> loadTriageSessions() {
    final raw = _prefs.getString(_keyTriageSessions);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) { return []; }
  }

  // ── Reports ──────────────────────────────────────────────────
  static Future<void> saveReports(List<Map<String, dynamic>> list) =>
      _prefs.setString(_keyReports, jsonEncode(list));
  static List<Map<String, dynamic>> loadReports() {
    final raw = _prefs.getString(_keyReports);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) { return []; }
  }
}
