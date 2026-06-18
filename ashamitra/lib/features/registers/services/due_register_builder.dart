import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Top-level (isolate-safe) builder for the monthly "due-list" register PDF.
///
/// Receives ONLY plain data so it can run via `Isolate.run` — font bytes plus a
/// fully pre-formatted [data] map (the main isolate does all the joining and
/// formatting; GetX `.tr` / models don't cross the isolate boundary).
///
/// data shape:
/// ```
/// {
///   'title': String, 'generatedAt': String, 'monthLabel': String,
///   'header': { 'asha','block','district','facility','horizon' : String },
///   'sections': [ { 'title': String, 'columns': [String],
///                   'rows': [[String]], 'note': String? } ],
/// }
/// ```
Future<List<int>> buildDueRegisterPdf(
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
  final sections = (data['sections'] as List?) ?? const [];

  pw.Widget headerBlock() {
    String h(String k) => (header[k] ?? '').toString();
    final lines = <String>[
      if (h('asha').isNotEmpty) 'আশা: ${h('asha')}',
      if (h('block').isNotEmpty) 'ব্লক: ${h('block')}',
      if (h('district').isNotEmpty) 'জেলা: ${h('district')}',
      if (h('facility').isNotEmpty) 'কেন্দ্র: ${h('facility')}',
    ];
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text((data['title'] ?? 'মাসিক বকেয়া রেজিস্টার').toString(),
                    style: pw.TextStyle(
                        fontSize: 15, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 2),
                pw.Text(
                    'AshaMitra • ${(data['monthLabel'] ?? '').toString()}'
                    '${(header['horizon'] ?? '').toString().isNotEmpty ? ' • আগামী ${header['horizon']}' : ''}',
                    style: const pw.TextStyle(
                        fontSize: 9, color: PdfColors.grey700)),
              ],
            ),
            pw.Text('তৈরি: ${(data['generatedAt'] ?? '').toString()}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          ],
        ),
        if (lines.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Text(lines.join('   |   '),
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
        ],
        pw.Divider(height: 10, thickness: 0.6),
      ],
    );
  }

  pw.Widget sectionWidget(Map<String, dynamic> s) {
    final columns =
        (s['columns'] as List?)?.map((e) => e.toString()).toList() ?? const [];
    final rows = (s['rows'] as List?)
            ?.map((r) => (r as List).map((c) => c.toString()).toList())
            .toList() ??
        const [];
    final note = (s['note'] ?? '').toString();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 8),
        pw.Text(s['title']?.toString() ?? '',
            style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey800)),
        pw.SizedBox(height: 4),
        if (rows.isEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 6),
            child: pw.Text('— এই বিভাগে কোনো বকেয়া নেই —',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
          )
        else
          pw.TableHelper.fromTextArray(
            headers: columns,
            data: rows,
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
            headerStyle: pw.TextStyle(
                fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.blueGrey600),
            cellStyle: const pw.TextStyle(fontSize: 7.5),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding:
                const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2.5),
            oddRowDecoration:
                const pw.BoxDecoration(color: PdfColors.blueGrey50),
          ),
        if (note.isNotEmpty) ...[
          pw.SizedBox(height: 3),
          pw.Text(note,
              style: pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.blueGrey700,
                  fontStyle: pw.FontStyle.italic)),
        ],
      ],
    );
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(22),
      header: (ctx) => ctx.pageNumber == 1 ? pw.SizedBox() : pw.SizedBox(height: 6),
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('পৃষ্ঠা ${ctx.pageNumber}/${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
      ),
      build: (ctx) => [
        headerBlock(),
        ...sections.map((s) => sectionWidget((s as Map).cast<String, dynamic>())),
        pw.SizedBox(height: 14),
        pw.Text(
            'AshaMitra দ্বারা স্বয়ংক্রিয়ভাবে তৈরি — তথ্য মিলিয়ে নিন। স্বাক্ষর: ____________________',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
      ],
    ),
  );

  return doc.save();
}
