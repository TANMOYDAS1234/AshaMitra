import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'pdf_helper.dart';

/// Renders PDFs via the platform HTML→PDF engine (Android print framework /
/// WebView) instead of the `pdf` package's widget tree.
///
/// WHY: the `pdf` package has no complex-script shaping, so Bengali/Hindi vowel
/// signs and conjuncts render mis-ordered ("রিপোর্ট" → "রপিোর্ট"). The platform
/// renderer shapes Indic scripts correctly, producing vector, selectable, small
/// PDFs — and it works offline (the device's Noto Bengali font is on-board).
///
/// Builders assemble plain HTML (escaped) and call [render]; shared CSS carries
/// the app palette so every report looks consistent.
class PdfHtml {
  PdfHtml._();

  /// HTML-escape a value (always use for any dynamic text).
  static String esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  /// Escape + turn newlines into <br> (for multi-line cells like dates).
  static String cell(String s) => esc(s).replaceAll('\n', '<br>');

  /// A bordered data table. [weights] are relative column widths (percent-ish);
  /// omit for equal columns.
  static String table(List<String> headers, List<List<String>> rows,
      {List<int>? weights}) {
    final colgroup = (weights != null && weights.length == headers.length)
        ? '<colgroup>${weights.map((w) => '<col style="width:$w%">').join()}</colgroup>'
        : '';
    final th = headers.map((h) => '<th>${cell(h)}</th>').join();
    final body = rows.isEmpty
        ? '<tr><td colspan="${headers.length}" class="empty">— তথ্য নেই —</td></tr>'
        : rows
            .map((r) => '<tr>${r.map((c) => '<td>${cell(c)}</td>').join()}</tr>')
            .join();
    return '<table>$colgroup<thead><tr>$th</tr></thead><tbody>$body</tbody></table>';
  }

  /// A two-column key/value identity grid from [rows] of [label, value].
  static String kvGrid(List<List<String>> rows) {
    final cells = rows
        .map((r) =>
            '<div class="kvrow"><span class="k">${cell(r[0])}:</span> '
            '<span class="v">${cell(r.length > 1 ? r[1] : '')}</span></div>')
        .join();
    return '<div class="kv">$cells</div>';
  }

  /// Standard report header (title + brand + generated time + asha/facility line).
  static String reportHeader({
    required String title,
    String generatedAt = '',
    Map<String, String> header = const {},
  }) {
    final sub = [
      if ((header['asha'] ?? '').isNotEmpty) 'আশা: ${esc(header['asha']!)}',
      if ((header['facility'] ?? '').isNotEmpty) 'কেন্দ্র: ${esc(header['facility']!)}',
      if ((header['block'] ?? '').isNotEmpty) 'ব্লক: ${esc(header['block']!)}',
      if ((header['district'] ?? '').isNotEmpty) 'জেলা: ${esc(header['district']!)}',
    ].join('  |  ');
    return '<div class="hd">'
        '<div><div class="title">${esc(title)}</div><div class="brand">AshaMitra</div></div>'
        '${generatedAt.isNotEmpty ? '<div class="meta">তৈরি: ${esc(generatedAt)}</div>' : ''}'
        '</div>'
        '${sub.isNotEmpty ? '<div class="sub">$sub</div>' : ''}'
        '<hr>';
  }

  static String section(String t) => '<div class="sec">${esc(t)}</div>';

  static String band(String text) => '<div class="band">${esc(text)}</div>';

  static String footer(String text) => '<div class="foot">${esc(text)}</div>';

  static const _css = '''
<style>
  @page { size: A4; margin: 14mm 10mm; }
  * { font-family: "Noto Sans Bengali","Noto Serif Bengali","Hind Siliguri","HindSiliguri",sans-serif; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
  body { color:#241726; font-size:12px; margin:0; }
  .hd { display:flex; justify-content:space-between; align-items:flex-start; }
  .title { font-size:17px; font-weight:700; color:#791C87; }
  .brand { font-size:10px; color:#6b7280; }
  .meta { font-size:9px; color:#6b7280; text-align:right; }
  .sub { font-size:9.5px; color:#4b5563; margin-top:3px; }
  hr { border:none; border-top:0.8px solid #d6cfdb; margin:9px 0; }
  .band { background:#fde8e8; border:1px solid #ef4444; color:#b91c1c; padding:7px 11px; border-radius:6px; font-weight:700; font-size:11px; margin:7px 0; }
  .sec { font-size:12.5px; font-weight:700; color:#791C87; margin:13px 0 5px; }
  .kv { font-size:0; }
  .kvrow { display:inline-block; width:49%; font-size:10px; padding:2px 0; vertical-align:top; }
  .kv .k { font-weight:700; }
  table { width:100%; border-collapse:collapse; margin-top:3px; }
  th { background:#791C87; color:#fff; font-size:8.5px; font-weight:700; padding:5px 4px; text-align:left; }
  td { border:0.4px solid #cbd5e1; font-size:8.5px; padding:3px 4px; vertical-align:top; }
  tbody tr:nth-child(odd) { background:#f7eefa; }
  .note { font-size:9.5px; font-weight:700; color:#5b0f69; margin-top:4px; }
  .empty { color:#6b7280; text-align:center; font-style:italic; }
  .foot { font-size:8.5px; color:#6b7280; margin-top:16px; }
</style>''';

  /// Wrap a HTML [body] in the document shell and render to a PDF, then save+open.
  static Future<void> render({required String body, required String fileName}) async {
    final html =
        '<!doctype html><html><head><meta charset="utf-8">$_css</head><body>$body</body></html>';
    // convertHtml is deprecated cross-platform but on Android routes through the
    // native WebView/print pipeline — which is exactly what shapes Bengali
    // correctly. The app is Android-only, so this is the intended path.
    // ignore: deprecated_member_use
    final bytes = await Printing.convertHtml(format: PdfPageFormat.a4, html: html);
    await PdfHelper.saveAndOpen(bytes, fileName);
  }
}
