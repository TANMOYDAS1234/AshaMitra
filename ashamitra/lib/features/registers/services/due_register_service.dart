import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/pdf_helper.dart';
import '../../patients/data/models/patient_model.dart';
import 'due_register_builder.dart';

/// Result of fetching due events — [fromCache] true when the live call returned
/// nothing and we fell back to the last saved snapshot (offline).
typedef DueFetch = ({List<Map<String, dynamic>> events, bool fromCache});

/// Assembles the worker's schedule into the monthly "due-list" registers
/// (ANC / Immunization / HBNC / HBYC) in the official NHM column order and
/// renders them to a shareable PDF (or CSV). 100% client-side, offline-capable:
/// it reuses the proven [PdfHelper] isolate pipeline and caches the last due
/// payload so a register can be generated without a network.
class DueRegisterService {
  static const _cacheKey = 'due_register_cache_v1';

  /// The four register kinds in display order.
  static const kindsAll = ['anc', 'vaccine', 'hbnc', 'hbyc'];

  static String kindLabel(String k) => switch (k) {
        'anc' => 'ANC (গর্ভকালীন)',
        'vaccine' => 'টিকাকরণ',
        'hbnc' => 'নবজাতক (HBNC)',
        'hbyc' => 'শিশু যত্ন (HBYC)',
        _ => k,
      };

  // ── Fetch (cache-first fallback for offline) ──────────────────────────────
  static Future<DueFetch> fetchDue({int withinDays = 45}) async {
    final raw = await ApiService.getScheduleDue(withinDays: withinDays);
    if (raw.isNotEmpty) {
      final list = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      await LocalStorageService.set(_cacheKey, jsonEncode(list));
      return (events: list, fromCache: false);
    }
    // Empty live result → fall back to the last saved snapshot (likely offline).
    final cached = LocalStorageService.get(_cacheKey);
    if (cached != null && cached.isNotEmpty) {
      try {
        final list = (jsonDecode(cached) as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        return (events: list, fromCache: true);
      } catch (_) {}
    }
    return (events: const <Map<String, dynamic>>[], fromCache: false);
  }

  // ── Assembly → the plain-data map the isolate builder consumes ────────────
  static Map<String, dynamic> assemble({
    required List<Map<String, dynamic>> events,
    required List<PatientModel> patients,
    required List<String> kinds,
    required String monthLabel,
    required int withinDays,
    Map<String, String> header = const {},
  }) {
    final byId = {for (final p in patients) p.id: p};
    final sections = <Map<String, dynamic>>[];

    for (final kind in kindsAll) {
      if (!kinds.contains(kind)) continue;
      final evs = events.where((e) => (e['kind']?.toString() ?? '') == kind).toList()
        ..sort((a, b) => _due(a).compareTo(_due(b)));
      sections.add(_section(kind, evs, byId));
    }

    return {
      'title': 'মাসিক বকেয়া রেজিস্টার (কাজের তালিকা)',
      'monthLabel': monthLabel,
      'generatedAt': _stamp(),
      'header': {...header, 'horizon': '$withinDays দিন'},
      'sections': sections,
      'fileName': _fileName(header['block'], 'pdf'),
      'csvFileName': _fileName(header['block'], 'csv'),
    };
  }

  static Map<String, dynamic> _section(
      String kind, List<Map<String, dynamic>> evs, Map<String, PatientModel> byId) {
    final rows = <List<String>>[];
    String? note;

    PatientModel? pat(Map<String, dynamic> e) => byId[e['patientId']?.toString()];

    switch (kind) {
      case 'anc':
        for (var i = 0; i < evs.length; i++) {
          final e = evs[i];
          final p = pat(e);
          rows.add([
            '${i + 1}',
            p?.rchId ?? '',
            p?.name ?? (e['patientName']?.toString() ?? ''),
            (p?.mcpDetails['fatherName'] ?? '').toString(),
            _village(p),
            _ageText(p),
            _d(p?.lmp),
            _d(p?.edd),
            _gaWeeks(p?.lmp, e['dueDate']),
            _gpla(p),
            e['label']?.toString() ?? '',
            _dueText(e),
            _mobile(p, e),
            (p?.mcpDetails['highRisk'] == true) ? 'উচ্চ-ঝুঁকি' : '',
          ]);
        }
        return {
          'title': 'ক. ANC বকেয়া তালিকা (${evs.length})',
          'columns': const [
            '#', 'RCH/MCTS', 'নাম', 'স্বামী/পিতা', 'গ্রাম', 'বয়স',
            'LMP', 'EDD', 'GA সপ্তাহ', 'G-P-L-A', 'ANC', 'বকেয়া', 'মোবাইল', 'ঝুঁকি',
          ],
          'rows': rows,
          'note': note ?? '',
        };

      case 'vaccine':
        var full = 0, complete = 0;
        for (var i = 0; i < evs.length; i++) {
          final e = evs[i];
          final p = pat(e);
          final vax = _vaccines(e);
          final low = '$vax ${e['label'] ?? ''}'.toLowerCase();
          if (low.contains('বুস্টার') || low.contains('booster') || low.contains('dpt')) {
            complete++;
          } else if (low.contains('mr') || low.contains('এমআর')) {
            full++;
          }
          rows.add([
            '${i + 1}',
            p?.rchId ?? '',
            p?.name ?? (e['patientName']?.toString() ?? ''),
            _mother(p),
            _d(p?.dob),
            _ageText(p),
            _genderShort(p),
            _village(p),
            vax,
            _dueText(e),
            _mobile(p, e),
          ]);
        }
        final est = full * 100 + complete * 50;
        note =
            'টিকা প্রণোদনা (RI Form 6): পূর্ণ টিকাকরণে ₹১০০, সম্পূর্ণ টিকাকরণে ₹৫০। '
            'আনুমানিক সম্ভাব্য: ₹$est (পূর্ণ $full × ₹১০০ + সম্পূর্ণ $complete × ₹৫০)।';
        return {
          'title': 'খ. টিকাকরণ বকেয়া তালিকা / RI ডিউ-লিস্ট (${evs.length})',
          'columns': const [
            '#', 'RCH/MCTS', 'শিশুর নাম', 'মা', 'DOB', 'বয়স', 'লিঙ্গ',
            'গ্রাম', 'প্রদেয় টিকা', 'বকেয়া', 'মোবাইল',
          ],
          'rows': rows,
          'note': note,
        };

      case 'hbnc':
        for (var i = 0; i < evs.length; i++) {
          final e = evs[i];
          final p = pat(e);
          rows.add([
            '${i + 1}',
            p?.name ?? (e['patientName']?.toString() ?? ''),
            _mother(p),
            _d(p?.dob),
            _birthWeight(p),
            e['label']?.toString() ?? '',
            _dueText(e),
            _mobile(p, e),
          ]);
        }
        return {
          'title': 'গ. নবজাতক গৃহ-পরিদর্শন (HBNC) বকেয়া (${evs.length})',
          'columns': const [
            '#', 'নবজাতক', 'মা', 'DOB', 'জন্ম ওজন', 'পরিদর্শন', 'বকেয়া', 'মোবাইল',
          ],
          'rows': rows,
          'note': '',
        };

      case 'hbyc':
      default:
        for (var i = 0; i < evs.length; i++) {
          final e = evs[i];
          final p = pat(e);
          rows.add([
            '${i + 1}',
            p?.name ?? (e['patientName']?.toString() ?? ''),
            _mother(p),
            _d(p?.dob),
            _ageText(p),
            e['label']?.toString() ?? '',
            _dueText(e),
            _mobile(p, e),
          ]);
        }
        return {
          'title': 'ঘ. শিশু যত্ন (HBYC) বকেয়া (${evs.length})',
          'columns': const [
            '#', 'শিশুর নাম', 'মা', 'DOB', 'বয়স', 'পরিদর্শন', 'বকেয়া', 'মোবাইল',
          ],
          'rows': rows,
          'note': '',
        };
    }
  }

  // ── Output ────────────────────────────────────────────────────────────────
  static Future<void> generatePdf(Map<String, dynamic> data) async {
    final regular = await PdfHelper.loadFontBytes(bold: false);
    final bold = await PdfHelper.loadFontBytes(bold: true);
    List<int> bytes;
    try {
      bytes = await Isolate.run(() => buildDueRegisterPdf((regular, bold, data)))
          .timeout(const Duration(seconds: 90));
    } catch (_) {
      // Isolate failed (some devices) → build on the UI thread as a fallback.
      bytes = await buildDueRegisterPdf((regular, bold, data))
          .timeout(const Duration(seconds: 60));
    }
    await PdfHelper.saveAndOpen(bytes, data['fileName']?.toString() ?? 'due_register.pdf')
        .timeout(const Duration(seconds: 15));
  }

  static Future<void> generateCsv(Map<String, dynamic> data) async {
    final sb = StringBuffer();
    for (final s in (data['sections'] as List)) {
      final sec = (s as Map).cast<String, dynamic>();
      sb.writeln(_csvRow([sec['title'].toString()]));
      sb.writeln(_csvRow((sec['columns'] as List).map((e) => e.toString()).toList()));
      for (final r in (sec['rows'] as List)) {
        sb.writeln(_csvRow((r as List).map((e) => e.toString()).toList()));
      }
      final note = (sec['note'] ?? '').toString();
      if (note.isNotEmpty) sb.writeln(_csvRow([note]));
      sb.writeln();
    }
    // UTF-8 BOM so Excel renders Bengali correctly.
    final bytes = utf8.encode('﻿$sb');
    await _saveAndOpenBytes(bytes, data['csvFileName']?.toString() ?? 'due_register.csv');
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  static DateTime _due(Map<String, dynamic> e) =>
      DateTime.tryParse(e['dueDate']?.toString() ?? '') ?? DateTime(2100);

  static String _d(DateTime? dt) => dt == null
      ? ''
      : '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

  static String _dueText(Map<String, dynamic> e) {
    final overdue = e['overdue'] == true;
    final d = (e['daysUntil'] as num?)?.toInt() ?? 0;
    final date = _d(_due(e));
    if (d == 0) return 'আজ ($date)';
    if (overdue) return '${d.abs()} দিন পার ($date)';
    return '$d দিন বাকি ($date)';
  }

  static String _ageText(PatientModel? p) {
    if (p == null || p.age.isEmpty) return '';
    final u = switch (p.ageUnit) {
      'days' => 'দিন',
      'months' => 'মাস',
      _ => 'বছর',
    };
    return '${p.age} $u';
  }

  static String _gaWeeks(DateTime? lmp, dynamic dueIso) {
    if (lmp == null) return '';
    final due = DateTime.tryParse(dueIso?.toString() ?? '');
    if (due == null) return '';
    final wk = (due.difference(lmp).inDays / 7).floor();
    return wk >= 0 && wk <= 45 ? '$wk' : '';
  }

  static String _gpla(PatientModel? p) {
    if (p == null) return '';
    String g(String k) => (p.mcpDetails[k] ?? '').toString().trim();
    final parts = [g('gravida'), g('para'), g('prevLiveBirths'), g('abortions')]
        .map((v) => v.isEmpty ? '–' : v)
        .toList();
    return parts.every((v) => v == '–') ? '' : parts.join('/');
  }

  static String _village(PatientModel? p) {
    final v = p?.village ?? '';
    return (v == 'Unknown' || v == '—') ? '' : v;
  }

  static String _mother(PatientModel? p) {
    if (p == null) return '';
    final g = p.guardianName.trim();
    return g.isNotEmpty ? g : (p.mcpDetails['motherName'] ?? '').toString();
  }

  static String _mobile(PatientModel? p, Map<String, dynamic> e) {
    final m = (p?.mobile ?? '').trim();
    return m.isNotEmpty ? m : (e['patientMobile']?.toString() ?? '');
  }

  static String _genderShort(PatientModel? p) => switch (p?.gender) {
        'Female' => 'মে',
        'Male' => 'পু',
        _ => '',
      };

  static String _birthWeight(PatientModel? p) {
    final w = (p?.mcpDetails['birthWeight'] ?? '').toString().trim();
    return w.isEmpty ? '' : '$w কেজি';
  }

  static String _vaccines(Map<String, dynamic> e) {
    final meta = e['meta'];
    if (meta is Map && meta['vaccines'] is List) {
      return (meta['vaccines'] as List).join(', ');
    }
    return e['label']?.toString() ?? '';
  }

  static String _csvRow(List<String> cells) =>
      cells.map((c) => '"${c.replaceAll('"', '""')}"').join(',');

  static String _fileName(String? block, String ext) {
    final now = DateTime.now();
    final b = (block ?? '').replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    final stamp = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    return 'due_register${b.isEmpty ? '' : '_$b'}_$stamp.$ext';
  }

  static String _stamp() {
    final n = DateTime.now();
    String p(int v) => v.toString().padLeft(2, '0');
    return '${p(n.day)}/${p(n.month)}/${n.year} ${p(n.hour)}:${p(n.minute)}';
  }

  static Future<void> _saveAndOpenBytes(List<int> bytes, String fileName) async {
    try {
      final Directory dir;
      if (Platform.isAndroid) {
        final external = await getExternalStorageDirectory() ??
            await getApplicationDocumentsDirectory();
        dir = Directory('${external.path}/asha_reports');
        if (!dir.existsSync()) dir.createSync(recursive: true);
      } else {
        dir = await getApplicationDocumentsDirectory();
      }
      final path = '${dir.path}/$fileName';
      await File(path).writeAsBytes(bytes, flush: true);
      final result = await OpenFile.open(path);
      Get.snackbar(
        result.type == ResultType.done ? 'খোলা হয়েছে' : 'সংরক্ষিত',
        'ফাইল: $fileName',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.safeGreen,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        duration: const Duration(seconds: 5),
      );
    } catch (e) {
      Get.snackbar('ব্যর্থ', 'ফাইল সংরক্ষণ করা গেল না: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.emergencyRed,
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
          borderRadius: 12);
    }
  }
}
