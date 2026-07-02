import '../../../core/utils/pdf_html.dart';
import '../data/models/referral_model.dart';

/// Renders + opens the ASHA "Form 3" referral slip PDF for one referral, via the
/// platform HTML→PDF pipeline so Bengali shapes correctly.
class ReferralPdf {
  static Future<void> generate(
    ReferralModel r, {
    Map<String, String> header = const {},
  }) async {
    final data = _data(r, header);
    await PdfHtml.render(body: _html(data), fileName: data['fileName']!.toString());
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
      'createdDate': _fmtDate(r.createdAt),
      'band': r.band,
      'header': {
        'asha': header['asha'] ?? '',
        'block': header['block'] ?? '',
        'district': header['district'] ?? '',
        'facility': header['facility'] ?? '',
      },
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
      'status': r.status,
      'statusLabel': _statusLabel(r.status),
      'reachedDate': _fmtDate(r.reachedDate),
      'admittedBy': r.admittedBy,
      'relation': r.relation,
      'outcome': r.outcome,
      'facilityNotes': r.facilityNotes,
    };
  }

  static String _html(Map<String, dynamic> data) {
    String g(String k) => (data[k] ?? '').toString();
    final header = ((data['header'] as Map?) ?? const {})
        .map((k, v) => MapEntry(k.toString(), v.toString()));
    final band = g('band');
    final isRed = band == 'RED';
    final bandColor = isRed ? '#b91c1c' : (band == 'YELLOW' ? '#c2410c' : '#791C87');
    final bandText = isRed
        ? 'জরুরি রেফার (RED) — ৩০ মিনিটের মধ্যে স্থানান্তর করুন'
        : (band == 'YELLOW' ? 'রেফার (YELLOW) — ২৪ ঘণ্টার মধ্যে' : 'রেফার');
    final patientRows = ((data['patientRows'] as List?) ?? const [])
        .map((row) => (row as List).map((e) => e.toString()).toList())
        .toList();
    final isChild = data['isChild'] == true;
    final hasOutcome = g('status') != 'pending' ||
        g('admittedBy').isNotEmpty ||
        g('outcome').isNotEmpty;

    final b = StringBuffer();
    b.write(PdfHtml.reportHeader(
        title: 'আশা রেফারেল স্লিপ (Form 3)',
        generatedAt: g('createdDate'),
        header: header));
    b.write(
        '<div style="background:$bandColor;color:#fff;font-weight:700;font-size:11px;'
        'padding:8px 11px;border-radius:6px;margin:2px 0 6px;">${PdfHtml.esc(bandText)}</div>');

    b.write(PdfHtml.section('রোগীর তথ্য'));
    b.write(PdfHtml.kvGrid(patientRows));

    b.write(PdfHtml.section('অসুস্থতার লক্ষণ ও কারণ'));
    if (g('symptoms').isNotEmpty) b.write('<div>${PdfHtml.cell(g('symptoms'))}</div>');
    if (g('reason').isNotEmpty) b.write('<div class="note">${PdfHtml.esc(g('reason'))}</div>');

    if (isChild && (g('currentWeight').isNotEmpty || g('imnci').isNotEmpty)) {
      b.write(PdfHtml.kvGrid([
        if (g('currentWeight').isNotEmpty) ['বর্তমান ওজন', '${g('currentWeight')} কেজি'],
        if (g('imnci').isNotEmpty) ['IMNCI শ্রেণি', g('imnci')],
      ]));
    }

    if (g('medicinesGiven').isNotEmpty) {
      b.write(PdfHtml.section('ওষুধ দেওয়া হয়েছে'));
      b.write('<div>${PdfHtml.cell(g('medicinesGiven'))}</div>');
    }

    b.write(PdfHtml.section('রেফার করা হয়েছে'));
    b.write('<div><b>স্বাস্থ্যকেন্দ্র:</b> ${PdfHtml.esc(g('referredTo'))}</div>');
    b.write('<div style="margin-top:12px;font-size:10px;">আশা কর্মীর স্বাক্ষর: ____________________</div>');

    // Facility-fills-in outcome box.
    final ob = StringBuffer();
    ob.write('<div style="font-weight:700;font-size:11px;color:#241726;">স্বাস্থ্যকেন্দ্র পূরণ করবেন (Outcome)</div>');
    if (hasOutcome) {
      ob.write(PdfHtml.kvGrid([
        ['অবস্থা', g('statusLabel')],
        if (g('reachedDate').isNotEmpty) ['পৌঁছানোর তারিখ', g('reachedDate')],
        if (g('admittedBy').isNotEmpty) ['কে ভর্তি করেছেন', g('admittedBy')],
        if (g('relation').isNotEmpty) ['সম্পর্ক', g('relation')],
        if (g('outcome').isNotEmpty) ['ফলাফল', g('outcome')],
        if (g('facilityNotes').isNotEmpty) ['মন্তব্য', g('facilityNotes')],
      ]));
    } else {
      ob.write('<div style="font-size:10px;line-height:2.4;">ভর্তির তারিখ ও সময়: '
          '________________<br>কে ভর্তি করেছেন: ________________<br>'
          'সম্পর্ক: ________________<br>ফলাফল: ________________</div>');
    }
    ob.write('<div style="margin-top:8px;font-size:10px;">কর্মকর্তার স্বাক্ষর ও স্ট্যাম্প: ____________________</div>');
    b.write('<div style="border:0.6px solid #888;border-radius:6px;padding:10px;margin-top:12px;">$ob</div>');

    b.write(PdfHtml.footer(
        'AshaMitra দ্বারা তৈরি — তিনটি কপি: আশা ১টি রাখবেন, ২টি রোগীর সঙ্গে যাবে।'));
    return b.toString();
  }
}
