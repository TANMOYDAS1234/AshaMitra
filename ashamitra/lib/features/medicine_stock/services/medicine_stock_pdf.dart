import 'dart:isolate';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../core/utils/pdf_helper.dart';

int _i(dynamic v) => (v is num) ? v.toInt() : int.tryParse('$v') ?? 0;

String _fmtDate(dynamic iso) {
  final d = DateTime.tryParse((iso ?? '').toString());
  if (d == null) return '';
  String p(int n) => n.toString().padLeft(2, '0');
  return '${p(d.day)}/${p(d.month)}/${d.year}';
}

/// Generates the ASHA monthly medicine account — "Form 2" — for one month: a
/// table of every medicine line with opening / received(+date) / total /
/// issued / expired / closing balance, plus the signature block from the paper
/// form. The screen passes the month label + that month's records.
class MedicineStockPdf {
  static Future<void> generate({
    required String month,
    required List<Map<String, dynamic>> rows,
    Map<String, String> header = const {},
  }) async {
    final regular = await PdfHelper.loadFontBytes(bold: false);
    final bold = await PdfHelper.loadFontBytes(bold: true);

    // Build plain-string table rows here (avoids passing .tr into the isolate).
    final table = <List<String>>[];
    var totOpen = 0, totRecv = 0, totIssued = 0, totExpired = 0, totClose = 0;
    for (var idx = 0; idx < rows.length; idx++) {
      final r = rows[idx];
      final open = _i(r['openingStock']);
      final recv = _i(r['receivedQty']);
      final issued = _i(r['issuedQty']);
      final expired = _i(r['expiredQty']);
      final close = open + recv - issued - expired;
      totOpen += open;
      totRecv += recv;
      totIssued += issued;
      totExpired += expired;
      totClose += close;
      final recvCell = recv == 0
          ? '0'
          : (_fmtDate(r['receivedDate']).isEmpty
              ? '$recv'
              : '$recv\n(${_fmtDate(r['receivedDate'])})');
      table.add([
        '${idx + 1}',
        (r['medicineName'] ?? '').toString(),
        '$open',
        recvCell,
        '${open + recv}',
        '$issued',
        '$expired',
        '$close',
        (r['notes'] ?? '').toString(),
      ]);
    }
    final totals = [
      '', 'মোট', '$totOpen', '$totRecv', '${totOpen + totRecv}',
      '$totIssued', '$totExpired', '$totClose', ''
    ];

    final labels = {
      'title': 'ASHA-র মাসিক ওষুধপত্রের হিসেব (ফর্ম ২)',
      'month': month,
      'asha': header['asha'] ?? '',
      'block': header['block'] ?? '',
      'district': header['district'] ?? '',
      'facility': header['facility'] ?? '',
      'sign_asha': 'ASHA-র স্বাক্ষর',
      'sign_anm': 'এ.এন.এম / উপস্বাস্থ্যকেন্দ্রের স্বাক্ষর',
      'cols': [
        'ক্রমিক', 'ওষুধের নাম', 'মাসের শুরুতে স্টক', 'এই মাসে পাওয়া (তারিখ)',
        'মোট', 'বিতরণ/খরচ', 'বাতিল/মেয়াদ', 'মাসের শেষে স্টক', 'মন্তব্য'
      ],
      'empty': '— কোনো ওষুধের হিসেব নেই —',
      'auto': 'AshaMitra দ্বারা স্বয়ংক্রিয়ভাবে তৈরি।',
      'generatedAt': _stamp(),
    };

    final data = <String, dynamic>{
      'rows': table,
      'totals': totals,
      'labels': labels,
    };

    List<int> bytes;
    try {
      bytes = await Isolate.run(() => buildMedicineStockPdf((regular, bold, data)))
          .timeout(const Duration(seconds: 60));
    } catch (_) {
      bytes = await buildMedicineStockPdf((regular, bold, data))
          .timeout(const Duration(seconds: 45));
    }
    final safeMonth = month.replaceAll(RegExp(r'\s+'), '_');
    await PdfHelper.saveAndOpen(bytes, 'form2_$safeMonth.pdf')
        .timeout(const Duration(seconds: 15));
  }

  static String _stamp() {
    final n = DateTime.now();
    String p(int v) => v.toString().padLeft(2, '0');
    return '${p(n.day)}/${p(n.month)}/${n.year} ${p(n.hour)}:${p(n.minute)}';
  }
}

Future<List<int>> buildMedicineStockPdf(
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
  final labels = (data['labels'] as Map).cast<String, dynamic>();
  final cols = (labels['cols'] as List).map((e) => e.toString()).toList();
  final rows = ((data['rows'] as List?) ?? const [])
      .map((r) => (r as List).map((c) => c.toString()).toList())
      .toList();
  final totals = ((data['totals'] as List?) ?? const []).map((e) => e.toString()).toList();

  final dataRows = [...rows, if (rows.isNotEmpty) totals];

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4.landscape,
    margin: const pw.EdgeInsets.all(20),
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
            pw.Text('${labels['title']}',
                style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
            pw.Text('মাস: ${labels['month']}',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
          ]),
          pw.Text('তৈরি: ${labels['generatedAt'] ?? ''}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        ],
      ),
      if ([labels['asha'], labels['facility'], labels['block'], labels['district']]
          .any((e) => (e ?? '').toString().isNotEmpty)) ...[
        pw.SizedBox(height: 4),
        pw.Text(
          [
            if ((labels['asha'] ?? '').toString().isNotEmpty) 'আশা: ${labels['asha']}',
            if ((labels['facility'] ?? '').toString().isNotEmpty) 'কেন্দ্র: ${labels['facility']}',
            if ((labels['block'] ?? '').toString().isNotEmpty) 'ব্লক: ${labels['block']}',
            if ((labels['district'] ?? '').toString().isNotEmpty) 'জেলা: ${labels['district']}',
          ].join('   |   '),
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
        ),
      ],
      pw.Divider(height: 12, thickness: 0.6),
      pw.TableHelper.fromTextArray(
        headers: cols,
        data: dataRows,
        border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.4),
        headerStyle: pw.TextStyle(
            fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
        headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF4F46E5)),
        cellStyle: const pw.TextStyle(fontSize: 8),
        cellAlignment: pw.Alignment.center,
        cellAlignments: {1: pw.Alignment.centerLeft, 8: pw.Alignment.centerLeft},
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF0F0FF)),
        columnWidths: {
          0: const pw.FlexColumnWidth(0.7),
          1: const pw.FlexColumnWidth(2.4),
          2: const pw.FlexColumnWidth(1.1),
          3: const pw.FlexColumnWidth(1.4),
          4: const pw.FlexColumnWidth(0.9),
          5: const pw.FlexColumnWidth(1.1),
          6: const pw.FlexColumnWidth(1.1),
          7: const pw.FlexColumnWidth(1.2),
          8: const pw.FlexColumnWidth(2.0),
        },
      ),
      if (rows.isEmpty)
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 10),
          child: pw.Text('${labels['empty']}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        ),
      pw.SizedBox(height: 28),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _signBlock('${labels['sign_asha']}'),
          _signBlock('${labels['sign_anm']}'),
        ],
      ),
      pw.SizedBox(height: 10),
      pw.Text('${labels['auto']}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
    ],
  ));
  return doc.save();
}

pw.Widget _signBlock(String label) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(width: 160, height: 0.6, color: PdfColors.grey700),
        pw.SizedBox(height: 4),
        pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
      ],
    );
