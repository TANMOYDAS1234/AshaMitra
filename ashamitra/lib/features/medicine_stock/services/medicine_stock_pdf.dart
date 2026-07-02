import '../../../core/utils/pdf_html.dart';

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
/// form. Rendered via the platform HTML→PDF pipeline so Bengali shapes right.
class MedicineStockPdf {
  static Future<void> generate({
    required String month,
    required List<Map<String, dynamic>> rows,
    Map<String, String> header = const {},
  }) async {
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
    if (table.isNotEmpty) {
      table.add([
        '', 'মোট', '$totOpen', '$totRecv', '${totOpen + totRecv}',
        '$totIssued', '$totExpired', '$totClose', ''
      ]);
    }

    final b = StringBuffer();
    b.write(PdfHtml.reportHeader(
      title: 'ASHA-র মাসিক ওষুধপত্রের হিসেব (ফর্ম ২)',
      generatedAt: _stamp(),
      header: header,
    ));
    b.write('<div class="sub">মাস: ${PdfHtml.esc(month)}</div>');
    b.write(PdfHtml.table(
      const [
        'ক্রমিক', 'ওষুধের নাম', 'মাসের শুরুতে স্টক', 'এই মাসে পাওয়া (তারিখ)',
        'মোট', 'বিতরণ/খরচ', 'বাতিল/মেয়াদ', 'মাসের শেষে স্টক', 'মন্তব্য'
      ],
      table,
      weights: const [6, 22, 11, 15, 8, 10, 10, 11, 17],
    ));
    b.write(PdfHtml.signatures(
        ['ASHA-র স্বাক্ষর', 'এ.এন.এম / উপস্বাস্থ্যকেন্দ্রের স্বাক্ষর']));
    b.write(PdfHtml.footer('AshaMitra দ্বারা স্বয়ংক্রিয়ভাবে তৈরি।'));

    final safeMonth = month.replaceAll(RegExp(r'\s+'), '_');
    await PdfHtml.render(
        body: b.toString(), fileName: 'form2_$safeMonth.pdf', landscape: true);
  }

  static String _stamp() {
    final n = DateTime.now();
    String p(int v) => v.toString().padLeft(2, '0');
    return '${p(n.day)}/${p(n.month)}/${n.year} ${p(n.hour)}:${p(n.minute)}';
  }
}
