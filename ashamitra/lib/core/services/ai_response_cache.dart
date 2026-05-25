import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

/// Disk-backed cache for AI (Groq/Gemini) responses. Lets the conversational
/// triage flow work offline once a given prompt has been answered at least
/// once. Same prompt (after normalization) → same response → cached forever.
///
/// Keys match the backend's normalization (lowercase, single-spaced) so the
/// server cache and the client cache stay aligned.
///
/// Size cap 30 MB with LRU-style eviction (oldest mtime evicted first).
class AiResponseCache {
  static final AiResponseCache _instance = AiResponseCache._();
  factory AiResponseCache() => _instance;
  AiResponseCache._();

  static const _cacheLimit = 30 * 1024 * 1024; // 30 MB
  static const _versionTag = 'v1'; // bump to invalidate everything

  Future<Directory> get _cacheDir async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/ai_response_cache');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  String _key(String prompt) {
    // Match server normalization: trim + lowercase + collapse whitespace
    final normalized = prompt.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final hash = sha1.convert(utf8.encode(normalized)).toString();
    return '$_versionTag-$hash';
  }

  /// Returns a cached response body (as decoded JSON map) for [prompt], or
  /// null if there is no cache hit.
  Future<Map<String, dynamic>?> get(String prompt) async {
    if (prompt.trim().isEmpty) return null;
    final dir  = await _cacheDir;
    final file = File('${dir.path}/${_key(prompt)}.json');
    if (!file.existsSync()) return null;
    try {
      final raw = await file.readAsString();
      // Touch mtime so LRU eviction protects recently-used entries.
      file.setLastModifiedSync(DateTime.now());
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      // Corrupted entry — remove it.
      try { file.deleteSync(); } catch (_) {}
      return null;
    }
  }

  /// Stores [responseBody] (the full decoded /api/chat response) for [prompt].
  /// Best-effort — silent on failure.
  Future<void> put(String prompt, Map<String, dynamic> responseBody) async {
    if (prompt.trim().isEmpty) return;
    try {
      final dir  = await _cacheDir;
      final file = File('${dir.path}/${_key(prompt)}.json');
      await file.writeAsString(jsonEncode(responseBody));
      await _evictIfNeeded(dir);
    } catch (_) {
      // ignore — cache is best-effort
    }
  }

  Future<void> _evictIfNeeded(Directory dir) async {
    final files = dir.listSync().whereType<File>().toList();
    int total = files.fold(0, (sum, f) => sum + f.lengthSync());
    if (total <= _cacheLimit) return;
    files.sort((a, b) =>
        a.statSync().modified.compareTo(b.statSync().modified));
    for (final f in files) {
      if (total <= _cacheLimit) break;
      total -= f.lengthSync();
      try { f.deleteSync(); } catch (_) {}
    }
  }

  Future<({int files, int bytes})> stats() async {
    final dir = await _cacheDir;
    final files = dir.listSync().whereType<File>().toList();
    final bytes = files.fold(0, (sum, f) => sum + f.lengthSync());
    return (files: files.length, bytes: bytes);
  }

  Future<void> clear() async {
    final dir = await _cacheDir;
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }
}
