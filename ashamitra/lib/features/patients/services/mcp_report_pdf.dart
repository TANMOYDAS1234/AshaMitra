import 'dart:isolate';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../core/services/api_service.dart';
import '../../../core/utils/pdf_helper.dart';
import '../data/models/patient_model.dart';

/// Generates a one-/two-page "মা ও শিশুর সুরক্ষা কার্ড — সারসংক্ষেপ" (MCP-card
/// summary / ANC report) for a single patient: identity + pregnancy summary,
/// a high-risk banner, the ANC visit table (from captured visit records), the
/// immunization table, and upcoming due items. Reuses the Bengali PDF pipeline.
class McpReportPdf {
  static Future<void> generate(
    PatientModel p, {
    Map<String, String> header = const {},
  }) async {
    // Pull the patient's schedule timeline (ANC / vaccine / HBNC events with the
    // record captured at each completed visit). Empty for a not-yet-synced row.
    final events = await ApiService.getScheduleForPatient(p.id);
    final data = _data(p, events, header);
    final regular = await PdfHelper.loadFontBytes(bold: false);
    final bold = await PdfHelper.loadFontBytes(bold: true);
    List<int> bytes;
    try {
      bytes = await Isolate.run(() => buildMcpReportPdf((regular, bold, data)))
          .timeout(const Duration(seconds: 60));
    } catch (_) {
      bytes = await buildMcpReportPdf((regular, bold, data))
          .timeout(const Duration(seconds: 45));
    }
    await PdfHelper.saveAndOpen(bytes, data['fileName']!.toString())
        .timeout(const Duration(seconds: 15));
  }

  /// Generates a focused report for a **single completed checkup** (any module —
  /// ANC / PNC / vaccine / HBNC / HBYC). Reuses the same builder so identity +
  /// the one visit's measurements are rendered consistently. Works dynamically:
  /// whichever kind the event is, only that section appears.
  static Future<void> generateForEvent(
    PatientModel p,
    Map<String, dynamic> event, {
    Map<String, String> header = const {},
  }) async {
    final data = _data(p, [event], header);
    final kind = (event['kind'] ?? '').toString();
    final label = (event['label'] ?? '').toString();
    data['title'] = '${_kindBn(kind)} রিপোর্ট${label.isNotEmpty ? ' — $label' : ''}';
    final dd = (event['dueDate'] ?? '').toString();
    final datePart = dd.length >= 10 ? dd.substring(0, 10).replaceAll('-', '') : '';
    data['fileName'] =
        'checkup_${kind.isEmpty ? 'visit' : kind}${datePart.isNotEmpty ? '_$datePart' : ''}.pdf';
    final regular = await PdfHelper.loadFontBytes(bold: false);
    final bold = await PdfHelper.loadFontBytes(bold: true);
    List<int> bytes;
    try {
      bytes = await Isolate.run(() => buildMcpReportPdf((regular, bold, data)))
          .timeout(const Duration(seconds: 60));
    } catch (_) {
      bytes = await buildMcpReportPdf((regular, bold, data))
          .timeout(const Duration(seconds: 45));
    }
    await PdfHelper.saveAndOpen(bytes, data['fileName']!.toString())
        .timeout(const Duration(seconds: 15));
  }

  static String _fmt(dynamic iso) {
    final s = (iso ?? '').toString().trim();
    if (s.isEmpty) return '';
    final d = DateTime.tryParse(s);
    if (d == null) return s;
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(d.day)}/${p(d.month)}/${d.year}';
  }

  static String _kindBn(String k) => switch (k) {
        'anc' => 'ANC',
        'pnc' => 'PNC',
        'vaccine' => 'টিকা',
        'hbnc' => 'নবজাতক',
        'hbyc' => 'শিশু',
        _ => k,
      };

  static String _caseBn(String t) => switch (t) {
        'Pregnancy' || 'pregnancy' => 'গর্ভবতী',
        'Newborn' || 'newborn' => 'নবজাতক',
        'Child' || 'child' => 'শিশু',
        _ => 'অন্যান্য',
      };

  static Map<String, dynamic> _data(
      PatientModel p, List<dynamic> events, Map<String, String> header) {
    final md = p.mcpDetails;
    String m(String k) => (md[k] ?? '').toString().trim();

    // ── Identity summary — adapts to the case (mother vs child) ───────────
    final t = p.type;
    final isChild =
        t == 'Newborn' || t == 'Child' || t == 'newborn' || t == 'child';
    final genderBn =
        switch (p.gender) { 'Female' => 'মেয়ে', 'Male' => 'ছেলে', _ => p.gender };
    final idRows = <List<String>>[
      ['নাম', p.name],
      ['বয়স', '${p.age} ${switch (p.ageUnit) { 'days' => 'দিন', 'months' => 'মাস', _ => 'বছর' }}'],
      ['কেস', _caseBn(t)],
      if (isChild && p.guardianName.isNotEmpty) ['মায়ের নাম', p.guardianName],
      if (!isChild && m('fatherName').isNotEmpty) ['স্বামী/বাবা', m('fatherName')],
      if (p.village.isNotEmpty && p.village != 'Unknown') ['গ্রাম', p.village],
      if (p.mobile.isNotEmpty) ['মোবাইল', p.mobile],
      // Child-specific identity
      if (isChild && p.dob != null) ['জন্ম তারিখ', _fmt(p.dob!.toIso8601String())],
      if (isChild && p.gender.isNotEmpty) ['লিঙ্গ', genderBn],
      if (isChild && m('birthWeight').isNotEmpty) ['জন্ম ওজন', '${m('birthWeight')} কেজি'],
      if (isChild && m('childRchId').isNotEmpty) ['শিশুর RCH', m('childRchId')],
      // Mother-specific identity
      if (!isChild && m('rchId').isNotEmpty) ['RCH/MCTS', m('rchId')],
      if (m('motherAadhaar').isNotEmpty) ['আধার', m('motherAadhaar')],
      if (m('bloodGroup').isNotEmpty) ['রক্তের গ্রুপ', m('bloodGroup')],
      if (!isChild && p.lmp != null) ['LMP', _fmt(p.lmp!.toIso8601String())],
      if (!isChild && p.edd != null) ['EDD', _fmt(p.edd!.toIso8601String())],
      if (!isChild && m('gravida').isNotEmpty)
        ['গর্ভ (G/P/L)', '${m('gravida')}/${m('para')}/${m('prevLiveBirths')}'],
    ];

    // ── ANC visits, immunization, upcoming ────────────────────────────────
    final anc = <List<String>>[];
    final vac = <List<String>>[];
    final hbnc = <List<String>>[];
    final hbyc = <List<String>>[];
    final pnc = <List<String>>[];
    final due = <List<String>>[];
    for (final e in events) {
      if (e is! Map) continue;
      final kind = (e['kind'] ?? '').toString();
      final status = (e['status'] ?? '').toString();
      final rec = (e['record'] is Map)
          ? (e['record'] as Map).cast<String, dynamic>()
          : const <String, dynamic>{};
      String r(String k) => (rec[k] ?? '').toString().trim();
      // Headline = scheduled date; for completed visits also show the day it
      // was actually recorded ("নির্ধারিত / সম্পন্ন").
      final sched = _fmt(e['dueDate']);
      final recd = status == 'done' ? _fmt(rec['completedAt'] ?? e['doneDate']) : '';
      final date = (status == 'done' && recd.isNotEmpty && recd != sched)
          ? '$sched\nসম্পন্ন $recd'
          : (status == 'done' && recd.isNotEmpty ? recd : sched);
      final label = (e['label'] ?? '').toString();

      if (status == 'pending') {
        final dd = DateTime.tryParse((e['dueDate'] ?? '').toString());
        final overdue = dd != null && dd.isBefore(DateTime.now());
        due.add([label, _kindBn(kind), _fmt(e['dueDate']), overdue ? 'বকেয়া' : 'আসন্ন']);
        continue;
      }
      if (status != 'done') continue;
      if (kind == 'anc') {
        final flags = <String>[
          ...((rec['dangerFlags'] as List?)?.map((e) => e.toString()) ?? const []),
          ...((rec['tbSymptoms'] as List?)?.map((e) => e.toString()) ?? const []),
        ];
        anc.add([
          label, date, r('weight'), r('bp'), r('hb'),
          '${r('urineAlbumin')}/${r('urineSugar')}',
          r('fundalHeight'),
          ((rec['supplementsGiven'] as List?)?.join(', ') ?? ''),
          flags.isEmpty ? '—' : flags.join(', '),
        ]);
      } else if (kind == 'vaccine') {
        vac.add([
          label, date,
          ((rec['givenVaccines'] as List?)?.join(', ') ?? ''),
          rec['allGiven'] == true ? 'সম্পূর্ণ' : 'আংশিক',
        ]);
      } else if (kind == 'hbnc') {
        final parts = <String>[];
        final w = rec['babyWeight']?.toString() ?? '';
        if (w.isNotEmpty) parts.add('ওজন $w কেজি');
        final t = rec['babyTemp']?.toString() ?? '';
        if (t.isNotEmpty) parts.add('তাপ $t°F');
        final bf = (rec['dangerFlags'] as List?)?.map((e) => e.toString()).toList() ?? const [];
        if (bf.isNotEmpty) parts.add('শিশু: ${bf.join(", ")}');
        final mp = rec['motherPnc'];
        if (mp is Map) {
          final mbp = mp['bp']?.toString() ?? '';
          if (mbp.isNotEmpty) parts.add('মা BP $mbp');
          final mf = (mp['dangerFlags'] as List?)?.map((e) => e.toString()).toList() ?? const [];
          if (mf.isNotEmpty) parts.add('মা: ${mf.join(", ")}');
        }
        hbnc.add([label, date, parts.isEmpty ? 'ঠিক আছে' : parts.join(' · ')]);
      } else if (kind == 'hbyc') {
        final parts = <String>[];
        final w = rec['weight']?.toString() ?? '';
        if (w.isNotEmpty) parts.add('ওজন $w কেজি');
        final muac = rec['muac']?.toString() ?? '';
        final ms = rec['muacStatus']?.toString() ?? '';
        if (muac.isNotEmpty) parts.add('MUAC $muac${ms.isNotEmpty ? " ($ms)" : ""}');
        final f = (rec['dangerFlags'] as List?)?.map((e) => e.toString()).toList() ?? const [];
        if (f.isNotEmpty) parts.add(f.join(', '));
        hbyc.add([label, date, parts.isEmpty ? 'ঠিক আছে' : parts.join(' · ')]);
      } else if (kind == 'pnc') {
        final parts = <String>[];
        final bp = rec['bp']?.toString() ?? '';
        if (bp.isNotEmpty) parts.add('BP $bp');
        final tp = rec['temp']?.toString() ?? '';
        if (tp.isNotEmpty) parts.add('তাপ $tp°F');
        // Lochia / bleeding (only flag the abnormal states).
        final lochia = rec['lochia']?.toString() ?? '';
        if (lochia == 'heavy') parts.add('বেশি রক্তস্রাব');
        if (lochia == 'foul') parts.add('দুর্গন্ধযুক্ত স্রাব');
        final bf = switch (rec['breastfeeding']?.toString() ?? '') {
          'exclusive' => 'শুধু বুকের দুধ',
          'partial' => 'আংশিক দুধ',
          'none' => 'স্তন্যপান হচ্ছে না',
          _ => '',
        };
        if (bf.isNotEmpty) parts.add(bf);
        if (rec['ifaGiven'] == true) parts.add('IFA ✓');
        if (rec['fpCounselled'] == true) parts.add('পরিবার পরিকল্পনা পরামর্শ ✓');
        if ((rec['depressionScreen'] as List?)?.isNotEmpty ?? false) {
          parts.add('মানসিক ঝুঁকি');
        }
        final pf = (rec['pncFlags'] as List?)?.map((e) => e.toString()).toList() ?? const [];
        if (pf.isNotEmpty) parts.add(pf.join(', '));
        pnc.add([label, date, parts.isEmpty ? 'ঠিক আছে' : parts.join(' · ')]);
      }
    }

    // Weight-gain across ANC visits (target 9–11 kg over pregnancy).
    final ws = anc.map((r) => double.tryParse(r[2])).whereType<double>().toList();
    final weightGain = ws.length >= 2
        ? 'মোট ওজন বৃদ্ধি: ${(ws.last - ws.first).toStringAsFixed(1)} কেজি (লক্ষ্য ৯–১১ কেজি)'
        : '';

    return {
      'fileName': 'mcp_report_${p.name.replaceAll(RegExp(r"\s+"), "_")}.pdf',
      'generatedAt': _fmt(DateTime.now().toIso8601String()),
      'title': 'মা ও শিশুর সুরক্ষা কার্ড — সারসংক্ষেপ',
      'header': {
        'asha': header['asha'] ?? '',
        'block': header['block'] ?? '',
        'district': header['district'] ?? '',
        'facility': header['facility'] ?? '',
      },
      'highRisk': md['highRisk'] == true,
      'highRiskReason': (md['highRiskReason'] ?? '').toString(),
      'idRows': idRows,
      'anc': anc,
      'weightGain': weightGain,
      'pnc': pnc,
      'vac': vac,
      'hbnc': hbnc,
      'hbyc': hbyc,
      'due': due,
    };
  }
}

/// Isolate-safe builder. Receives font bytes + a plain data map.
Future<List<int>> buildMcpReportPdf(
    (Uint8List, Uint8List, Map<String, dynamic>) args) async {
  final (regularBytes, boldBytes, data) = args;
  pw.Font makeFont(Uint8List b) =>
      b.isNotEmpty ? pw.Font.ttf(b.buffer.asByteData()) : pw.Font.helvetica();
  final theme = pw.ThemeData.withFont(
    base: makeFont(regularBytes),
    bold: makeFont(boldBytes),
    italic: makeFont(regularBytes),
    boldItalic: makeFont(boldBytes),
  );
  final doc = pw.Document(theme: theme);

  final header = (data['header'] as Map?)?.cast<String, dynamic>() ?? {};
  final idRows = (data['idRows'] as List?) ?? const [];
  final anc = (data['anc'] as List?) ?? const [];
  final vac = (data['vac'] as List?) ?? const [];
  final hbnc = (data['hbnc'] as List?) ?? const [];
  final hbyc = (data['hbyc'] as List?) ?? const [];
  final pnc = (data['pnc'] as List?) ?? const [];
  final due = (data['due'] as List?) ?? const [];

  List<List<String>> rows(List src) =>
      src.map((r) => (r as List).map((c) => c.toString()).toList()).toList();

  pw.Widget table(List<String> cols, List<List<String>> data) =>
      pw.TableHelper.fromTextArray(
        headers: cols,
        data: data,
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
        headerStyle: pw.TextStyle(
            fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey600),
        cellStyle: const pw.TextStyle(fontSize: 7.5),
        cellAlignment: pw.Alignment.centerLeft,
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2.5),
        oddRowDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
      );

  pw.Widget sectionTitle(String t) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 12, bottom: 4),
        child: pw.Text(t,
            style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey800)),
      );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('পৃষ্ঠা ${ctx.pageNumber}/${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
      ),
      build: (ctx) => [
        // Header
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text((data['title'] ?? '').toString(),
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.Text('AshaMitra', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
              ],
            ),
            pw.Text('তৈরি: ${(data['generatedAt'] ?? '').toString()}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          ],
        ),
        if ([header['asha'], header['block'], header['district'], header['facility']]
            .any((e) => (e ?? '').toString().isNotEmpty)) ...[
          pw.SizedBox(height: 4),
          pw.Text(
            [
              if ((header['asha'] ?? '').toString().isNotEmpty) 'আশা: ${header['asha']}',
              if ((header['facility'] ?? '').toString().isNotEmpty) 'কেন্দ্র: ${header['facility']}',
              if ((header['block'] ?? '').toString().isNotEmpty) 'ব্লক: ${header['block']}',
              if ((header['district'] ?? '').toString().isNotEmpty) 'জেলা: ${header['district']}',
            ].join('   |   '),
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
          ),
        ],
        pw.Divider(height: 10, thickness: 0.6),

        // High-risk banner
        if (data['highRisk'] == true)
          pw.Container(
            width: double.infinity,
            margin: const pw.EdgeInsets.only(bottom: 6),
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: pw.BoxDecoration(
                color: PdfColors.red50,
                border: pw.Border.all(color: PdfColors.red400, width: 0.8),
                borderRadius: pw.BorderRadius.circular(4)),
            child: pw.Text(
                'উচ্চ ঝুঁকি: ${(data['highRiskReason'] ?? '').toString().isNotEmpty ? data['highRiskReason'] : 'হ্যাঁ'}',
                style: pw.TextStyle(
                    fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
          ),

        // Identity
        sectionTitle('পরিচয় ও গর্ভাবস্থার তথ্য'),
        pw.Wrap(
          spacing: 18,
          runSpacing: 3,
          children: rows(idRows)
              .map((r) => pw.SizedBox(
                    width: 250,
                    child: pw.Row(children: [
                      pw.SizedBox(
                          width: 90,
                          child: pw.Text('${r[0]}:',
                              style: pw.TextStyle(
                                  fontSize: 9, fontWeight: pw.FontWeight.bold))),
                      pw.Expanded(
                          child: pw.Text(r.length > 1 ? r[1] : '',
                              style: const pw.TextStyle(fontSize: 9))),
                    ]),
                  ))
              .toList(),
        ),

        // ANC visits
        if (anc.isNotEmpty) ...[
          sectionTitle('ANC ভিজিট (পরিমাপ)'),
          table(const ['ভিজিট', 'তারিখ', 'ওজন', 'BP', 'Hb', 'মূত্র(A/S)', 'জরায়ু', 'দেওয়া হয়েছে', 'বিপদ/TB'], rows(anc)),
          if ((data['weightGain'] ?? '').toString().isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.Text(data['weightGain'].toString(),
                  style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blueGrey700)),
            ),
        ],

        // PNC (mother postnatal)
        if (pnc.isNotEmpty) ...[
          sectionTitle('প্রসব-পরবর্তী পরিচর্যা (PNC)'),
          table(const ['ভিজিট', 'তারিখ', 'পর্যবেক্ষণ'], rows(pnc)),
        ],

        // Immunization
        if (vac.isNotEmpty) ...[
          sectionTitle('টিকাকরণ'),
          table(const ['ভিজিট', 'তারিখ', 'যে টিকা দেওয়া হয়েছে', 'অবস্থা'], rows(vac)),
        ],

        // Newborn home visits (HBNC)
        if (hbnc.isNotEmpty) ...[
          sectionTitle('নবজাতক গৃহ পরিদর্শন (HBNC)'),
          table(const ['ভিজিট', 'তারিখ', 'পর্যবেক্ষণ'], rows(hbnc)),
        ],

        // Young-child home visits (HBYC)
        if (hbyc.isNotEmpty) ...[
          sectionTitle('শিশু গৃহ পরিদর্শন (HBYC)'),
          table(const ['ভিজিট', 'তারিখ', 'পর্যবেক্ষণ'], rows(hbyc)),
        ],

        // Upcoming
        if (due.isNotEmpty) ...[
          sectionTitle('আসন্ন / বকেয়া (টিকা ও পরীক্ষা)'),
          table(const ['কাজ', 'ধরন', 'তারিখ', 'অবস্থা'], rows(due)),
        ],

        if (anc.isEmpty && pnc.isEmpty && vac.isEmpty && hbnc.isEmpty && hbyc.isEmpty && due.isEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 10),
            child: pw.Text('— এখনও কোনো ভিজিট/সূচি নেই —',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
          ),

        pw.SizedBox(height: 14),
        pw.Text('AshaMitra দ্বারা স্বয়ংক্রিয়ভাবে তৈরি — তথ্য মিলিয়ে নিন।  আশা স্বাক্ষর: ____________________',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
      ],
    ),
  );

  return doc.save();
}
