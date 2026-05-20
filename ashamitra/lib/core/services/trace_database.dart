import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// SQLite-backed storage for decision traces and MDSR sync queue.
/// Replaces SharedPreferences — handles large trace volumes without ANR.
/// Append-only writes; no row is ever updated or deleted except MDSR sync flag.
class TraceDatabase {
  static const _dbName = 'asha_traces.db';
  static const _dbVersion = 1;

  Database? _db;

  Future<Database> get _database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE decision_trace (
            id        INTEGER PRIMARY KEY AUTOINCREMENT,
            sessionId TEXT    NOT NULL,
            timestamp TEXT    NOT NULL,
            caseId    TEXT    NOT NULL,
            moduleId  TEXT    NOT NULL,
            finalBand TEXT    NOT NULL,
            firedRuleId TEXT  NOT NULL,
            hardStop  INTEGER NOT NULL,
            invariantLocked INTEGER NOT NULL,
            signOffPending  INTEGER NOT NULL,
            protocolHash TEXT,
            referral  TEXT,
            actionEn  TEXT,
            answers   TEXT,
            ruleTrace TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE mdsr_queue (
            id        INTEGER PRIMARY KEY AUTOINCREMENT,
            sessionId TEXT    NOT NULL,
            timestamp TEXT    NOT NULL,
            moduleId  TEXT    NOT NULL,
            firedRuleId TEXT  NOT NULL,
            band      TEXT    NOT NULL,
            hardStop  INTEGER NOT NULL,
            invariantLocked INTEGER NOT NULL,
            signOffPending  INTEGER NOT NULL,
            referral  TEXT,
            actionEn  TEXT,
            patientId TEXT,
            patientName TEXT,
            ashaId    TEXT,
            clinicalAnswers TEXT,
            synced    INTEGER NOT NULL DEFAULT 0,
            syncedAt  TEXT
          )
        ''');
      },
    );
  }

  // ── Decision trace ──────────────────────────────────────────────────────────

  Future<void> insertTrace({
    required String sessionId,
    required String caseId,
    required String moduleId,
    required String finalBand,
    required String firedRuleId,
    required bool hardStop,
    required bool invariantLocked,
    required bool signOffPending,
    required String? protocolHash,
    required String referral,
    required String actionEn,
    required List<Map<String, dynamic>> answers,
    required List<Map<String, dynamic>> ruleTrace,
  }) async {
    final db = await _database;
    await db.insert('decision_trace', {
      'sessionId': sessionId,
      'timestamp': DateTime.now().toIso8601String(),
      'caseId': caseId,
      'moduleId': moduleId,
      'finalBand': finalBand,
      'firedRuleId': firedRuleId,
      'hardStop': hardStop ? 1 : 0,
      'invariantLocked': invariantLocked ? 1 : 0,
      'signOffPending': signOffPending ? 1 : 0,
      'protocolHash': protocolHash ?? 'unknown',
      'referral': referral,
      'actionEn': actionEn,
      'answers': jsonEncode(answers),
      'ruleTrace': jsonEncode(ruleTrace),
    });
  }

  Future<List<Map<String, dynamic>>> allTraces({int limit = 200}) async {
    final db = await _database;
    final rows = await db.query(
      'decision_trace',
      orderBy: 'id DESC',
      limit: limit,
    );
    return rows.map((r) => {
      ...r,
      'answers': jsonDecode(r['answers'] as String),
      'ruleTrace': jsonDecode(r['ruleTrace'] as String),
      'hardStop': r['hardStop'] == 1,
      'invariantLocked': r['invariantLocked'] == 1,
      'signOffPending': r['signOffPending'] == 1,
    }).toList();
  }

  Future<Map<String, dynamic>?> traceBySession(String sessionId) async {
    final db = await _database;
    final rows = await db.query(
      'decision_trace',
      where: 'sessionId = ?',
      whereArgs: [sessionId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    return {
      ...r,
      'answers': jsonDecode(r['answers'] as String),
      'ruleTrace': jsonDecode(r['ruleTrace'] as String),
      'hardStop': r['hardStop'] == 1,
      'invariantLocked': r['invariantLocked'] == 1,
      'signOffPending': r['signOffPending'] == 1,
    };
  }

  // ── MDSR queue ──────────────────────────────────────────────────────────────

  Future<void> insertMdsr({
    required String sessionId,
    required String moduleId,
    required String firedRuleId,
    required String band,
    required bool hardStop,
    required bool invariantLocked,
    required bool signOffPending,
    required String referral,
    required String actionEn,
    required String? patientId,
    required String? patientName,
    required String? ashaId,
    required List<Map<String, dynamic>> clinicalAnswers,
  }) async {
    final db = await _database;
    await db.insert('mdsr_queue', {
      'sessionId': sessionId,
      'timestamp': DateTime.now().toIso8601String(),
      'moduleId': moduleId,
      'firedRuleId': firedRuleId,
      'band': band,
      'hardStop': hardStop ? 1 : 0,
      'invariantLocked': invariantLocked ? 1 : 0,
      'signOffPending': signOffPending ? 1 : 0,
      'referral': referral,
      'actionEn': actionEn,
      'patientId': patientId ?? 'unknown',
      'patientName': patientName ?? 'unknown',
      'ashaId': ashaId ?? 'unknown',
      'clinicalAnswers': jsonEncode(clinicalAnswers),
      'synced': 0,
    });
  }

  Future<List<Map<String, dynamic>>> pendingMdsr() async {
    final db = await _database;
    final rows = await db.query(
      'mdsr_queue',
      where: 'synced = 0',
      orderBy: 'id ASC',
    );
    return rows.map((r) => {
      ...r,
      'clinicalAnswers': jsonDecode(r['clinicalAnswers'] as String),
      'hardStop': r['hardStop'] == 1,
      'invariantLocked': r['invariantLocked'] == 1,
      'signOffPending': r['signOffPending'] == 1,
    }).toList();
  }

  Future<void> markMdsrSynced(String sessionId) async {
    final db = await _database;
    await db.update(
      'mdsr_queue',
      {'synced': 1, 'syncedAt': DateTime.now().toIso8601String()},
      where: 'sessionId = ?',
      whereArgs: [sessionId],
    );
  }
}
