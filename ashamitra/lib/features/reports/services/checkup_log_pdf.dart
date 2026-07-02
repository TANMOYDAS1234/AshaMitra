import '../../../core/utils/pdf_html.dart';

/// Generates a "চেকআপ লগ" (checkup log) PDF — every completed checkup across
/// patients as a single table, with a small stats header. The screen builds the
/// plain-string rows (it owns the kind/band/summary logic); this renders them
/// via the platform HTML→PDF pipeline so Bengali shapes correctly.
class CheckupLogPdf {
  static Future<void> generate({
    required List<List<String>> rows, // [date, patient, kind, label, status, summary]
    required Map<String, String> stats, // total / month / danger
    Map<String, String> header = const {},
  }) async {
    final b = StringBuffer();
    b.write(PdfHtml.reportHeader(
        title: 'চেকআপ লগ', generatedAt: _stamp(), header: header));
    b.write(PdfHtml.statChips([
      ('মোট', stats['total'] ?? '${rows.length}', '#791C87'),
      ('এই মাসে', stats['month'] ?? '', '#0EA5B5'),
      ('বিপদচিহ্ন', stats['danger'] ?? '', '#DC2626'),
    ]));
    b.write(PdfHtml.table(
      const ['তারিখ', 'রোগী', 'ধরন', 'পরীক্ষা', 'অবস্থা', 'সারসংক্ষেপ'],
      rows,
      weights: const [13, 16, 10, 20, 15, 26],
    ));
    b.write(PdfHtml.footer('AshaMitra দ্বারা স্বয়ংক্রিয়ভাবে তৈরি।'));

    final now = DateTime.now();
    final fileName =
        'checkup_log_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.pdf';
    await PdfHtml.render(body: b.toString(), fileName: fileName);
  }

  static String _stamp() {
    final n = DateTime.now();
    String p(int v) => v.toString().padLeft(2, '0');
    return '${p(n.day)}/${p(n.month)}/${n.year} ${p(n.hour)}:${p(n.minute)}';
  }
}
