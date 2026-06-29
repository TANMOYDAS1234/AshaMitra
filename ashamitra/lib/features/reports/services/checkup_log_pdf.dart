import 'dart:isolate';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../core/utils/pdf_helper.dart';

/// Generates a "চেকআপ লগ" (checkup log) PDF — every completed checkup across
/// patients as a single table, with a small stats header. The screen builds the
/// plain-string rows (it owns the kind/band/summary logic); this just renders.
class CheckupLogPdf {
  static Future<void> generate({
    required List<List<String>> rows, // [date, patient, kind, label, status, summary]
    required Map<String, String> stats, // total / month / danger
    Map<String, String> header = const {},
  }) async {
    final regular = await PdfHelper.loadFontBytes(bold: false);
    final bold = await PdfHelper.loadFontBytes(bold: true);
    final data = <String, dynamic>{
      'rows': rows,
      'stats': stats,
      'header': header,
      'generatedAt': _stamp(),
    };
    List<int> bytes;
    try {
      bytes = await Isolate.run(() => buildCheckupLogPdf((regular, bold, data)))
          .timeout(const Duration(seconds: 60));
    } catch (_) {
      bytes = await buildCheckupLogPdf((regular, bold, data))
          .timeout(const Duration(seconds: 45));
    }
    final now = DateTime.now();
    final fileName =
        'checkup_log_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.pdf';
    await PdfHelper.saveAndOpen(bytes, fileName).timeout(const Duration(seconds: 15));
  }

  static String _stamp() {
    final n = DateTime.now();
    String p(int v) => v.toString().padLeft(2, '0');
    return '${p(n.day)}/${p(n.month)}/${n.year} ${p(n.hour)}:${p(n.minute)}';
  }
}

Future<List<int>> buildCheckupLogPdf(
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
  final stats = (data['stats'] as Map?)?.cast<String, dynamic>() ?? {};
  final rows = ((data['rows'] as List?) ?? const [])
      .map((r) => (r as List).map((c) => c.toString()).toList())
      .toList();

  pw.Widget statBox(String label, String value, PdfColor color) => pw.Expanded(
        child: pw.Container(
          margin: const pw.EdgeInsets.symmetric(horizontal: 4),
          padding: const pw.EdgeInsets.symmetric(vertical: 8),
          decoration: pw.BoxDecoration(
              color: color,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
          child: pw.Column(children: [
            pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
            pw.SizedBox(height: 2),
            pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.white)),
          ]),
        ),
      );

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(24),
    footer: (ctx) => pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text('পৃষ্ঠা ${ctx.pageNumber}/${ctx.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
    ),
    build: (ctx) => [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('চেকআপ লগ',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Text('AshaMitra', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          ]),
          pw.Text('তৈরি: ${data['generatedAt'] ?? ''}',
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
      pw.Divider(height: 12, thickness: 0.6),
      pw.Row(children: [
        statBox('মোট', '${stats['total'] ?? rows.length}', const PdfColor.fromInt(0xFF4F46E5)),
        statBox('এই মাসে', '${stats['month'] ?? ''}', const PdfColor.fromInt(0xFF06B6D4)),
        statBox('বিপদচিহ্ন', '${stats['danger'] ?? ''}', const PdfColor.fromInt(0xFFDC2626)),
      ]),
      pw.SizedBox(height: 12),
      pw.TableHelper.fromTextArray(
        headers: const ['তারিখ', 'রোগী', 'ধরন', 'পরীক্ষা', 'অবস্থা', 'সারসংক্ষেপ'],
        data: rows,
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
        headerStyle: pw.TextStyle(
            fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
        headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF4F46E5)),
        cellStyle: const pw.TextStyle(fontSize: 8),
        cellAlignment: pw.Alignment.centerLeft,
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2.5),
        oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF0F0FF)),
        columnWidths: {
          0: const pw.FlexColumnWidth(1.3),
          1: const pw.FlexColumnWidth(1.6),
          2: const pw.FlexColumnWidth(1.0),
          3: const pw.FlexColumnWidth(2.0),
          4: const pw.FlexColumnWidth(1.4),
          5: const pw.FlexColumnWidth(2.2),
        },
      ),
      if (rows.isEmpty)
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 10),
          child: pw.Text('— কোনো চেকআপ নেই —',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        ),
      pw.SizedBox(height: 12),
      pw.Text('AshaMitra দ্বারা স্বয়ংক্রিয়ভাবে তৈরি।',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
    ],
  ));
  return doc.save();
}
