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
  static const _cacheKeyAll = 'full_register_cache_v1';

  /// The four due-list kinds in display order.
  static const kindsAll = ['anc', 'vaccine', 'hbnc', 'hbyc'];

  /// The cumulative full-register types (the actual paper notebooks).
  /// Eligible-couple & birth/death registers moved to their own home tiles, so
  /// the generator focuses on the registers nothing else produces.
  static const kindsFull = ['maternal', 'immunization', 'diary'];

  static String kindLabel(String k) => switch (k) {
        'anc' => 'ANC (গর্ভকালীন)',
        'vaccine' => 'টিকাকরণ',
        'hbnc' => 'নবজাতক (HBNC)',
        'hbyc' => 'শিশু যত্ন (HBYC)',
        _ => k,
      };

  static String fullLabel(String k) => switch (k) {
        'maternal' => 'মাতৃ রেজিস্টার',
        'immunization' => 'শিশু টিকা রেজিস্টার',
        'eligible' => 'যোগ্য দম্পতি রেজিস্টার',
        'vital' => 'জন্ম ও মৃত্যু রেজিস্টার',
        'diary' => 'আশা ডায়েরি',
        _ => k,
      };

  static const _fpMethodBn = {
    'none': 'নেই',
    'condom': 'কন্ডোম',
    'ocp': 'বড়ি',
    'iucd': 'IUCD',
    'injectable': 'অন্তরা',
    'female_sterilization': 'মহিলা বন্ধ্যাকরণ',
    'male_sterilization': 'NSV',
    'other': 'অন্যান্য',
  };
  static const _placeBn = {
    'home': 'বাড়ি',
    'institution': 'প্রতিষ্ঠান',
    'transit': 'পথে',
    'other': 'অন্যান্য',
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

  // ── Full (cumulative) registers — the notebook substitute ──────────────────
  // Unlike the due-list (a monthly work-plan), these are the actual registers
  // the worker hand-copies: one row per beneficiary with full history. Reuses
  // the same generic PDF/CSV builder via the shared {title, sections} shape.
  static Future<DueFetch> fetchAll() async {
    final raw = await ApiService.getAllSchedule();
    if (raw.isNotEmpty) {
      final list = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      await LocalStorageService.set(_cacheKeyAll, jsonEncode(list));
      return (events: list, fromCache: false);
    }
    final cached = LocalStorageService.get(_cacheKeyAll);
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

  static Map<String, dynamic> assembleFull({
    required List<Map<String, dynamic>> events,
    required List<PatientModel> patients,
    required List<String> registers,
    List<Map<String, dynamic>> couples = const [],
    List<Map<String, dynamic>> vitals = const [],
    Map<String, String> header = const {},
  }) {
    final byPatient = <String, List<Map<String, dynamic>>>{};
    for (final e in events) {
      final pid = e['patientId']?.toString() ?? '';
      if (pid.isEmpty) continue;
      (byPatient[pid] ??= []).add(e);
    }
    final sections = <Map<String, dynamic>>[];
    if (registers.contains('maternal')) sections.add(_maternalSection(patients, byPatient));
    if (registers.contains('immunization')) sections.add(_immunizationSection(patients, byPatient));
    if (registers.contains('eligible')) sections.add(_eligibleSection(couples));
    if (registers.contains('vital')) sections.add(_vitalSection(vitals));
    if (registers.contains('diary')) sections.add(_diarySection(patients, events));
    return {
      'title': 'পূর্ণ রেজিস্টার (নোটবুকের বিকল্প)',
      'monthLabel': '',
      'generatedAt': _stamp(),
      'header': header,
      'sections': sections,
      'fileName': _fileName(header['block'], 'pdf').replaceFirst('due_register', 'full_register'),
      'csvFileName': _fileName(header['block'], 'csv').replaceFirst('due_register', 'full_register'),
    };
  }

  static bool _isDone(Map<String, dynamic> e) => (e['status']?.toString()) == 'done';
  static DateTime? _doneOn(Map<String, dynamic> e) =>
      DateTime.tryParse(e['doneDate']?.toString() ?? '');

  static Map<String, dynamic> _maternalSection(
      List<PatientModel> patients, Map<String, List<Map<String, dynamic>>> byPatient) {
    final mothers = patients
        .where((p) => p.type == 'Pregnancy' || p.lmp != null)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final rows = <List<String>>[];
    for (var i = 0; i < mothers.length; i++) {
      final p = mothers[i];
      final anc = (byPatient[p.id] ?? [])
          .where((e) => (e['kind']?.toString()) == 'anc')
          .toList()
        ..sort((a, b) => _due(a).compareTo(_due(b)));
      String ancCell(int idx) {
        if (idx >= anc.length) return '';
        final e = anc[idx];
        if (_isDone(e)) {
          final dd = _d(_doneOn(e));
          final v = _vitalsShort(e['record']);
          return [dd, v].where((s) => s.isNotEmpty).join('\n');
        }
        return 'বকেয়া ${_d(_due(e))}';
      }
      var tt = 0;
      for (final e in anc) {
        if (!_isDone(e)) continue;
        final r = e['record'];
        if (r is Map && r['supplementsGiven'] is List &&
            (r['supplementsGiven'] as List).any((s) => s.toString().contains('TD'))) {
          tt++;
        }
      }
      rows.add([
        '${i + 1}', p.rchId, p.name, (p.mcpDetails['fatherName'] ?? '').toString(),
        _village(p), _ageText(p), _d(p.lmp), _d(p.edd), _gpla(p),
        (p.mcpDetails['highRisk'] == true) ? 'উচ্চ' : '',
        ancCell(0), ancCell(1), ancCell(2), ancCell(3), tt > 0 ? '$tt' : '',
      ]);
    }
    return {
      'title': 'মাতৃ রেজিস্টার — সকল গর্ভবতী (${mothers.length})',
      'columns': const [
        '#', 'RCH/MCTS', 'নাম', 'স্বামী/পিতা', 'গ্রাম', 'বয়স', 'LMP', 'EDD',
        'G-P-L-A', 'ঝুঁকি', 'ANC-১', 'ANC-২', 'ANC-৩', 'ANC-৪', 'TT',
      ],
      'rows': rows,
      'note': 'প্রতিটি ANC ঘরে — সম্পন্ন হলে তারিখ + BP/ওজন/Hb; না হলে "বকেয়া <তারিখ>"। প্রসব ও PNC কলাম প্রসব-নথিভুক্তির পরে যুক্ত হবে।',
    };
  }

  static Map<String, dynamic> _immunizationSection(
      List<PatientModel> patients, Map<String, List<Map<String, dynamic>>> byPatient) {
    final kids = patients
        .where((p) => (p.type == 'Newborn' || p.type == 'Child') && p.dob != null)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    // (label, lowWeeks, highWeeks) from DOB — robust to schedule code naming.
    const buckets = [
      ('জন্ম-ডোজ', -1, 2), ('৬ সপ্তাহ', 3, 8), ('১০ সপ্তাহ', 8, 12),
      ('১৪ সপ্তাহ', 12, 20), ('৯ মাস', 28, 52), ('১৬-২৪ মাস', 56, 130),
    ];
    final rows = <List<String>>[];
    for (var i = 0; i < kids.length; i++) {
      final p = kids[i];
      final vac = (byPatient[p.id] ?? [])
          .where((e) => (e['kind']?.toString()) == 'vaccine')
          .toList();
      String cellFor(int lo, int hi) {
        for (final e in vac) {
          final w = _offsetWeeks(p.dob, e['dueDate']);
          if (w == null || w < lo || w > hi) continue;
          return _isDone(e) ? _d(_doneOn(e)) : 'বকেয়া';
        }
        return '';
      }
      rows.add([
        '${i + 1}', p.rchId, p.name, _mother(p), _genderShort(p), _d(p.dob),
        _birthWeight(p),
        ...buckets.map((b) => cellFor(b.$2, b.$3)),
      ]);
    }
    return {
      'title': 'শিশু টিকা রেজিস্টার — সকল শিশু (${kids.length})',
      'columns': const [
        '#', 'RCH/MCTS', 'শিশুর নাম', 'মা', 'লিঙ্গ', 'DOB', 'জন্ম ওজন',
        'জন্ম-ডোজ', '৬ সপ্তাহ', '১০ সপ্তাহ', '১৪ সপ্তাহ', '৯ মাস', '১৬-২৪ মাস',
      ],
      'rows': rows,
      'note': 'প্রতিটি মাইলফলক ঘরে — দেওয়া হলে তারিখ; বাকি থাকলে "বকেয়া"।',
    };
  }

  static Map<String, dynamic> _diarySection(
      List<PatientModel> patients, List<Map<String, dynamic>> events) {
    final entries = <(DateTime, List<String>)>[];
    for (final p in patients) {
      entries.add((p.createdAt, [
        _d(p.createdAt), p.name, 'নিবন্ধন (${_caseTypeLabel(p.type)})', _village(p),
      ]));
    }
    for (final e in events) {
      if (_isDone(e)) {
        final dt = _doneOn(e);
        if (dt != null) {
          final r = e['record'];
          final danger = (r is Map && r['dangerFlags'] is List &&
                  (r['dangerFlags'] as List).isNotEmpty)
              ? 'বিপদচিহ্ন'
              : '';
          entries.add((dt, [
            _d(dt), e['patientName']?.toString() ?? '', e['label']?.toString() ?? '', danger,
          ]));
        }
      }
      final rem = e['lastRemindedAt']?.toString();
      if (rem != null && rem.isNotEmpty) {
        final dt = DateTime.tryParse(rem);
        if (dt != null) {
          entries.add((dt, [
            _d(dt), e['patientName']?.toString() ?? '',
            'মনে করানো (${e['lastReminderChannel'] ?? ''})', '',
          ]));
        }
      }
    }
    entries.sort((a, b) => b.$1.compareTo(a.$1));
    final rows = entries.take(250).map((e) => e.$2).toList();
    return {
      'title': 'আশা ডায়েরি — কার্যকলাপ (${rows.length})',
      'columns': const ['তারিখ', 'উপভোক্তা', 'পরিষেবা', 'মন্তব্য'],
      'rows': rows,
      'note': '',
    };
  }

  // ── Eligible-couple (family-planning) register ────────────────────────────
  static Map<String, dynamic> _eligibleSection(List<Map<String, dynamic>> couples) {
    final active = couples
        .where((c) => (c['status'] ?? 'active').toString() != 'closed')
        .toList()
      ..sort((a, b) => (a['wifeName'] ?? '').toString().compareTo((b['wifeName'] ?? '').toString()));
    final rows = <List<String>>[];
    for (var i = 0; i < active.length; i++) {
      final c = active[i];
      String g(String k) => (c[k] ?? '').toString().trim();
      rows.add([
        '${i + 1}',
        g('wifeName'),
        g('husbandName'),
        g('wifeAadhaar'),
        _village0(g('village')),
        g('wifeAge'),
        g('sons'),
        g('daughters'),
        _fpMethodBn[g('fpMethod')] ?? 'নেই',
        _diso(c['followUpDate']),
        c['highRisk'] == true ? 'উচ্চ' : '',
        g('mobile'),
      ]);
    }
    return {
      'title': 'যোগ্য দম্পতি রেজিস্টার — সক্রিয় (${active.length})',
      'columns': const [
        '#', 'স্ত্রী', 'স্বামী', 'আধার', 'গ্রাম', 'স্ত্রীর বয়স', 'ছেলে', 'মেয়ে',
        'বর্তমান পদ্ধতি', 'ফলো-আপ', 'ঝুঁকি', 'মোবাইল',
      ],
      'rows': rows,
      'note': 'প্রজনন বয়সের (১৫–৪৯) দম্পতি। পদ্ধতি ও পরবর্তী ফলো-আপ তারিখ সহ।',
    };
  }

  // ── Birth & death (CRS) register ──────────────────────────────────────────
  static Map<String, dynamic> _vitalSection(List<Map<String, dynamic>> vitals) {
    final list = [...vitals]..sort((a, b) =>
        (b['eventDate'] ?? '').toString().compareTo((a['eventDate'] ?? '').toString()));
    final rows = <List<String>>[];
    var births = 0, deaths = 0, pending = 0;
    for (var i = 0; i < list.length; i++) {
      final e = list[i];
      String g(String k) => (e[k] ?? '').toString().trim();
      final isBirth = (e['eventType'] ?? 'birth').toString() == 'birth';
      if (isBirth) {
        births++;
      } else {
        deaths++;
      }
      if (e['registered'] != true) pending++;
      final detail = isBirth
          ? [
              if (g('birthWeight').isNotEmpty) 'ওজন ${g('birthWeight')}',
              if (g('motherName').isNotEmpty) 'মা ${g('motherName')}',
            ].join(' · ')
          : [
              if (g('ageAtDeath').isNotEmpty) g('ageAtDeath'),
              if (g('causeOfDeath').isNotEmpty) g('causeOfDeath'),
              if (e['maternalDeath'] == true) 'মাতৃমৃত্যু',
              if (e['infantDeath'] == true) 'শিশুমৃত্যু',
            ].where((s) => s.isNotEmpty).join(' · ');
      rows.add([
        '${i + 1}',
        isBirth ? 'জন্ম' : 'মৃত্যু',
        g('personName'),
        _genderShort0(g('sex')),
        _diso(e['eventDate']),
        _placeBn[g('place')] ?? '',
        _village0(g('village')),
        detail,
        e['registered'] == true ? (g('registrationNo').isNotEmpty ? g('registrationNo') : 'হ্যাঁ') : 'বাকি',
      ]);
    }
    return {
      'title': 'জন্ম ও মৃত্যু রেজিস্টার (জন্ম $births · মৃত্যু $deaths)',
      'columns': const [
        '#', 'ধরন', 'নাম', 'লিঙ্গ', 'তারিখ', 'স্থান', 'গ্রাম', 'বিবরণ', 'নথিভুক্তি',
      ],
      'rows': rows,
      'note': pending > 0 ? '$pending টি নথিভুক্তি বাকি (CRS-এ জমা দিন)।' : '',
    };
  }

  static String _village0(String v) => (v == 'Unknown' || v == '—') ? '' : v;
  static String _genderShort0(String s) => switch (s) {
        'Female' => 'মে',
        'Male' => 'পু',
        _ => '',
      };
  static String _diso(dynamic iso) => _d(DateTime.tryParse((iso ?? '').toString()));

  static int? _offsetWeeks(DateTime? dob, dynamic dueIso) {
    if (dob == null) return null;
    final due = DateTime.tryParse(dueIso?.toString() ?? '');
    if (due == null) return null;
    return (due.difference(dob).inDays / 7).round();
  }

  static String _vitalsShort(dynamic record) {
    if (record is! Map) return '';
    String g(String k) => (record[k] ?? '').toString().trim();
    final parts = <String>[];
    if (g('bp').isNotEmpty) parts.add('BP${g('bp')}');
    if (g('weight').isNotEmpty) parts.add('ওজ${g('weight')}');
    if (g('hb').isNotEmpty) parts.add('Hb${g('hb')}');
    return parts.join(' ');
  }

  static String _caseTypeLabel(String t) => switch (t) {
        'Pregnancy' => 'গর্ভবতী',
        'Newborn' => 'নবজাতক',
        'Child' => 'শিশু',
        _ => 'অন্যান্য',
      };

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
