import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static late SharedPreferences _prefs;

  static const _keyUser = 'session_user';
  static const _keyLanguage = 'session_language';
  static const _keyPatients = 'session_patients';
  static const _keyTriageSessions = 'session_triage';
  static const _keyReports = 'session_reports';
  static const _keyPendingDeletes = 'session_pending_deletes';
  static const _keyPendingReportDeletes = 'session_pending_report_deletes';

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

  // ── Pending deletes (offline-resilient sync) ─────────────────
  // Patients the user deleted while offline. Hidden from the UI but
  // retained here so the next syncFromServer can flush the DELETE call
  // and the server-side row doesn't reappear after every refresh.
  static Future<void> savePendingDeletes(List<Map<String, dynamic>> list) =>
      _prefs.setString(_keyPendingDeletes, jsonEncode(list));
  static List<Map<String, dynamic>> loadPendingDeletes() {
    final raw = _prefs.getString(_keyPendingDeletes);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) { return []; }
  }

  // ── Pending report deletes (offline-resilient sync) ──────────
  // Mirrors the pending-patient-delete pattern: reports the worker
  // tried to delete while offline. Stored as full snapshots so the
  // UI can hide them and the next syncFromServer can both flush the
  // DELETE and the merge step can re-exclude any server rows that
  // still match (handles the 75-sec-timeout-then-retry case).
  static Future<void> savePendingReportDeletes(List<Map<String, dynamic>> list) =>
      _prefs.setString(_keyPendingReportDeletes, jsonEncode(list));
  static List<Map<String, dynamic>> loadPendingReportDeletes() {
    final raw = _prefs.getString(_keyPendingReportDeletes);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) { return []; }
  }
}
