import 'dart:isolate';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../core/utils/pdf_helper.dart';
import '../data/models/referral_model.dart';

/// Renders + opens the ASHA "Form 3" referral slip PDF for one referral.
/// Mirrors the register PDF pipeline: load font bytes on the UI isolate, build
/// the document in a background isolate from plain data, then save + open.
class ReferralPdf {
  static Future<void> generate(
    ReferralModel r, {
    Map<String, String> header = const {},
  }) async {
    final data = _data(r, header);
    final regular = await PdfHelper.loadFontBytes(bold: false);
    final bold = await PdfHelper.loadFontBytes(bold: true);
    List<int> bytes;
    try {
      bytes = await Isolate.run(() => buildReferralSlipPdf((regular, bold, data)))
          .timeout(const Duration(seconds: 60));
    } catch (_) {
      bytes = await buildReferralSlipPdf((regular, bold, data))
          .timeout(const Duration(seconds: 45));
    }
    await PdfHelper.saveAndOpen(bytes, data['fileName']!.toString())
        .timeout(const Duration(seconds: 15));
  }

  static String _fmtDate(DateTime? d) {
    if (d == null) return '';
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(d.day)}/${p(d.month)}/${d.year}';
  }

  static String _caseLabel(String c) => switch (c) {
        'Pregnancy' || 'pregnancy' => 'গর্ভবতী',
        'Newborn' || 'newborn' => 'নবজাতক',
        'Child' || 'child' => 'শিশু',
        _ => 'অন্যান্য',
      };

  static String _genderLabel(String g) => switch (g) {
        'Female' => 'মহিলা',
        'Male' => 'পুরুষ',
        _ => g,
      };

  static String _statusLabel(String s) => switch (s) {
        'pending' => 'অপেক্ষমাণ',
        'reached' => 'কেন্দ্রে পৌঁছেছেন',
        'completed' => 'সম্পন্ন',
        'cancelled' => 'বাতিল',
        _ => s,
      };

  static Map<String, dynamic> _data(ReferralModel r, Map<String, String> header) {
    final isChild = r.caseType == 'Child' ||
        r.caseType == 'Newborn' ||
        r.caseType == 'child' ||
        r.caseType == 'newborn';
    return {
      'fileName': 'referral_${DateTime.now().millisecondsSinceEpoch}.pdf',
      'generatedAt': _fmtDate(DateTime.now()),
      'createdDate': _fmtDate(r.createdAt),
      'band': r.band,
      'header': {
        'asha': header['asha'] ?? '',
        'block': header['block'] ?? '',
        'district': header['district'] ?? '',
        'facility': header['facility'] ?? '',
      },
      // রোগীর তথ্য — label/value rows
      'patientRows': [
        ['নাম', r.patientName],
        ['বয়স', r.age],
        ['লিঙ্গ', _genderLabel(r.gender)],
        if (r.guardianName.isNotEmpty) ['অভিভাবক', r.guardianName],
        ['গ্রাম', r.village],
        if (r.mobile.isNotEmpty) ['মোবাইল', r.mobile],
        ['কেস', _caseLabel(r.caseType)],
      ],
      'symptoms': r.symptoms,
      'reason': r.reason,
      'isChild': isChild,
      'currentWeight': r.currentWeight,
      'imnci': r.imnci,
      'medicinesGiven': r.medicinesGiven,
      'referredTo': r.referredTo,
      // স্বাস্থ্যকেন্দ্র পূরণ করবেন — outcome (filled when known)
      'status': r.status,
      'statusLabel': _statusLabel(r.status),
      'reachedDate': _fmtDate(r.reachedDate),
      'admittedBy': r.admittedBy,
      'relation': r.relation,
      'outcome': r.outcome,
      'facilityNotes': r.facilityNotes,
    };
  }
}

/// Isolate-safe builder. Receives only font bytes + a plain data map.
Future<List<int>> buildReferralSlipPdf(
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
  final band = (data['band'] ?? '').toString();
  final isRed = band == 'RED';
  final bandColor = isRed ? PdfColors.red700 : PdfColors.orange700;
  final bandText = isRed
      ? 'জরুরি রেফার (RED) — ৩০ মিনিটের মধ্যে স্থানান্তর করুন'
      : (band == 'YELLOW'
          ? 'রেফার (YELLOW) — ২৪ ঘণ্টার মধ্যে'
          : 'রেফার');

  pw.Widget labelValue(String label, String value, {bool underline = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 95,
              child: pw.Text('$label:',
                  style: pw.TextStyle(
                      fontSize: 10, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Expanded(
              child: pw.Container(
                decoration: underline
                    ? const pw.BoxDecoration(
                        border: pw.Border(
                            bottom: pw.BorderSide(
                                color: PdfColors.grey500, width: 0.5)))
                    : null,
                child: pw.Text(value.isEmpty ? ' ' : value,
                    style: const pw.TextStyle(fontSize: 10)),
              ),
            ),
          ],
        ),
      );

  pw.Widget sectionTitle(String t) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
        child: pw.Text(t,
            style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey800)),
      );

  final patientRows = (data['patientRows'] as List?) ?? const [];
  final isChild = data['isChild'] == true;
  final hasOutcome = (data['status']?.toString() ?? 'pending') != 'pending' ||
      (data['admittedBy']?.toString() ?? '').isNotEmpty ||
      (data['outcome']?.toString() ?? '').isNotEmpty;

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('আশা রেফারেল স্লিপ',
                      style: pw.TextStyle(
                          fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Form 3 • AshaMitra',
                      style: const pw.TextStyle(
                          fontSize: 9, color: PdfColors.grey700)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('তারিখ: ${(data['createdDate'] ?? '').toString()}',
                      style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          // Band banner
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: pw.BoxDecoration(
                color: bandColor, borderRadius: pw.BorderRadius.circular(4)),
            child: pw.Text(bandText,
                style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white)),
          ),
          // ASHA / facility line
          if ([
            header['asha'],
            header['block'],
            header['district'],
            header['facility']
          ].any((e) => (e ?? '').toString().isNotEmpty)) ...[
            pw.SizedBox(height: 6),
            pw.Text(
              [
                if ((header['asha'] ?? '').toString().isNotEmpty)
                  'আশা: ${header['asha']}',
                if ((header['facility'] ?? '').toString().isNotEmpty)
                  'কেন্দ্র: ${header['facility']}',
                if ((header['block'] ?? '').toString().isNotEmpty)
                  'ব্লক: ${header['block']}',
                if ((header['district'] ?? '').toString().isNotEmpty)
                  'জেলা: ${header['district']}',
              ].join('   |   '),
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
            ),
          ],
          pw.Divider(height: 12, thickness: 0.6),

          // রোগীর তথ্য
          sectionTitle('রোগীর তথ্য'),
          ...patientRows.map((row) {
            final r = (row as List).map((e) => e.toString()).toList();
            return labelValue(r[0], r.length > 1 ? r[1] : '');
          }),

          // অসুস্থতার লক্ষণ / কারণ
          sectionTitle('অসুস্থতার লক্ষণ ও কারণ'),
          if ((data['symptoms'] ?? '').toString().isNotEmpty)
            pw.Text(data['symptoms'].toString(),
                style: const pw.TextStyle(fontSize: 10)),
          if ((data['reason'] ?? '').toString().isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 2),
              child: pw.Text(data['reason'].toString(),
                  style: const pw.TextStyle(
                      fontSize: 9, color: PdfColors.grey700)),
            ),

          // Child-only: weight + IMNCI
          if (isChild &&
              ((data['currentWeight'] ?? '').toString().isNotEmpty ||
                  (data['imnci'] ?? '').toString().isNotEmpty)) ...[
            pw.SizedBox(height: 4),
            if ((data['currentWeight'] ?? '').toString().isNotEmpty)
              labelValue('বর্তমান ওজন', '${data['currentWeight']} কেজি'),
            if ((data['imnci'] ?? '').toString().isNotEmpty)
              labelValue('IMNCI শ্রেণি', data['imnci'].toString()),
          ],

          // ওষুধ ও রেফার
          if ((data['medicinesGiven'] ?? '').toString().isNotEmpty) ...[
            sectionTitle('ওষুধ দেওয়া হয়েছে'),
            pw.Text(data['medicinesGiven'].toString(),
                style: const pw.TextStyle(fontSize: 10)),
          ],
          sectionTitle('রেফার করা হয়েছে'),
          labelValue('স্বাস্থ্যকেন্দ্র', (data['referredTo'] ?? '').toString(),
              underline: true),

          pw.SizedBox(height: 14),
          pw.Text('আশা কর্মীর স্বাক্ষর: ____________________',
              style: const pw.TextStyle(fontSize: 10)),

          // স্বাস্থ্যকেন্দ্র পূরণ করবেন (outcome)
          pw.SizedBox(height: 12),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey500, width: 0.6),
                borderRadius: pw.BorderRadius.circular(4)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('স্বাস্থ্যকেন্দ্র পূরণ করবেন (Outcome)',
                    style: pw.TextStyle(
                        fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                if (hasOutcome) ...[
                  labelValue('অবস্থা', (data['statusLabel'] ?? '').toString()),
                  if ((data['reachedDate'] ?? '').toString().isNotEmpty)
                    labelValue('পৌঁছানোর তারিখ', data['reachedDate'].toString()),
                  if ((data['admittedBy'] ?? '').toString().isNotEmpty)
                    labelValue('কে ভর্তি করেছেন', data['admittedBy'].toString()),
                  if ((data['relation'] ?? '').toString().isNotEmpty)
                    labelValue('সম্পর্ক', data['relation'].toString()),
                  if ((data['outcome'] ?? '').toString().isNotEmpty)
                    labelValue('ফলাফল', data['outcome'].toString()),
                  if ((data['facilityNotes'] ?? '').toString().isNotEmpty)
                    labelValue('মন্তব্য', data['facilityNotes'].toString()),
                ] else ...[
                  labelValue('ভর্তির তারিখ ও সময়', '', underline: true),
                  labelValue('কে ভর্তি করেছেন', '', underline: true),
                  labelValue('সম্পর্ক', '', underline: true),
                  labelValue('ফলাফল', '', underline: true),
                ],
                pw.SizedBox(height: 10),
                pw.Text('কর্মকর্তার স্বাক্ষর ও স্ট্যাম্প: ____________________',
                    style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          ),
          pw.Spacer(),
          pw.Text(
              'AshaMitra দ্বারা তৈরি — তিনটি কপি: আশা ১টি রাখবেন, ২টি রোগীর সঙ্গে যাবে।',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        ],
      ),
    ),
  );

  return doc.save();
}
