import '../../../core/utils/pdf_html.dart';

/// The CMHO's monthly HMIS review report.
///
/// The monthly review meeting is the ritual that structures a district health
/// officer's month, and it runs off HMIS numbers. This prints exactly what the
/// District tab shows — same formulas, same denominators — so the officer can
/// carry it into the meeting and reconcile it against the HMIS portal without
/// finding two different truths.
///
/// A "—" in this document means the indicator had no denominator (e.g. no births
/// recorded yet), NOT zero. That distinction is stated on the page, because a
/// reader who mistakes "—" for 0% would conclude a block is failing when it has
/// simply not reported.
class DistrictReportPdf {
  static Future<void> generate({
    required Map<String, dynamic> indicators,
    required List<Map<String, dynamic>> blocks,
    required Map<String, dynamic> alerts,
    required String role, // CMHO / BMHO / ANM
    required String scope, // জেলা / ব্লক / এলাকা
    required String officer,
    required String district,
    required int months,
  }) async {
    String pct(String k) {
      final v = indicators[k];
      return v == null ? '—' : '${(v as num).toStringAsFixed(1)}%';
    }

    String num_(String k) => '${(indicators[k] as num?)?.toInt() ?? 0}';

    List<Map<String, dynamic>> alert(String k) => ((alerts[k] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final b = StringBuffer();

    b.write(PdfHtml.reportHeader(
      title: '$scope HMIS পর্যালোচনা — গত $months মাস',
      generatedAt: _today(),
      header: {'asha': officer, 'district': district},
    ));

    // Headline: the four numbers the review meeting opens on.
    b.write(PdfHtml.statChips([
      ('প্রাতিষ্ঠানিক প্রসব', pct('institutionalDeliveryPct'), '#DCFCE7'),
      ('টিকা কভারেজ', pct('immunizationCoveragePct'), '#DBEAFE'),
      ('মাতৃমৃত্যু', num_('maternalDeaths'), '#FEE2E2'),
      ('শিশুমৃত্যু', num_('infantDeaths'), '#FEE2E2'),
    ]));

    // ── HMIS key indicators ────────────────────────────────────────────────
    b.write(PdfHtml.section('HMIS মূল সূচক (সরকারি ফর্মুলা)'));
    b.write(PdfHtml.table(
      const ['সূচক', 'মান'],
      [
        ['প্রসূতি নথিভুক্ত', num_('pregnanciesRegistered')],
        ['১ম ত্রৈমাসিকে ANC নথিভুক্তি', pct('ancFirstTrimesterPct')],
        ['৪+ ANC ভিজিট', pct('anc4PlusPct')],
        ['উচ্চ ঝুঁকির প্রসূতি', num_('highRiskPregnancies')],
        ['মোট জন্ম', num_('births')],
        ['প্রাতিষ্ঠানিক প্রসব', pct('institutionalDeliveryPct')],
        ['সিজার', pct('cSectionPct')],
        ['দক্ষ কর্মী দ্বারা প্রসব (SBA)', pct('sbaAttendedPct')],
        ['কম ওজনের শিশু (<২.৫ কেজি)', pct('lbwPct')],
        ['টিকা কভারেজ', pct('immunizationCoveragePct')],
        ['টিকা বাকি (Overdue)', num_('immunizationDefaulters')],
        ['রেফারেল সম্পন্ন', pct('referralClosurePct')],
        ['মাতৃমৃত্যু (MDSR)', num_('maternalDeaths')],
        ['শিশুমৃত্যু (CDR)', num_('infantDeaths')],
      ],
      weights: const [62, 38],
    ));
    b.write('<div class="note">শতকরা হিসাব সরকারি HMIS ফর্মুলা অনুযায়ী। '
        'কম ওজনের শিশুর হিসাব শুধু <b>যেসব শিশুর ওজন লেখা আছে</b> তাদের উপর। '
        '<b>"—" মানে হিসাবের ভিত্তি নেই — শূন্য নয়।</b></div>');

    // ── Block-wise accountability ──────────────────────────────────────────
    if (blocks.length > 1) {
      b.write(PdfHtml.section('ব্লক অনুযায়ী পারফরম্যান্স'));
      b.write(PdfHtml.table(
        const [
          'ব্লক', 'ASHA', 'জন্ম', 'প্রাতিষ্ঠানিক প্রসব', 'টিকা', 'মৃত্যু', 'রিপোর্ট'
        ],
        blocks.map((bl) {
          final inst = bl['institutionalPct'] as num?;
          final imm = bl['immunizationPct'] as num?;
          final deaths = ((bl['maternalDeaths'] as num?)?.toInt() ?? 0) +
              ((bl['infantDeaths'] as num?)?.toInt() ?? 0);
          return [
            '${bl['block']}',
            '${(bl['ashas'] as num?)?.toInt() ?? 0}',
            '${(bl['births'] as num?)?.toInt() ?? 0}',
            inst == null ? '—' : '${inst.toStringAsFixed(0)}%',
            imm == null ? '—' : '${imm.toStringAsFixed(0)}%',
            '$deaths',
            '${(bl['reports'] as num?)?.toInt() ?? 0}',
          ];
        }).toList(),
        weights: const [22, 10, 10, 20, 12, 12, 14],
      ));
    }

    // ── Escalations — the action list the meeting closes on ────────────────
    final md = alert('maternalDeaths');
    final idth = alert('infantDeaths');
    final stock = alert('stockouts');
    final silent = alert('silentAshas');
    final refs = alert('overdueReferrals');

    if (md.isNotEmpty ||
        idth.isNotEmpty ||
        stock.isNotEmpty ||
        silent.isNotEmpty ||
        refs.isNotEmpty) {
      b.write(PdfHtml.section('জরুরি বিষয় — ব্যবস্থা নিতে হবে'));

      if (md.isNotEmpty) {
        b.write(PdfHtml.band('মাতৃমৃত্যু: ${md.length} — ডেথ রিভিউ (MDSR) বাধ্যতামূলক'));
        b.write(PdfHtml.table(
          const ['নাম', 'ব্লক', 'গ্রাম', 'কারণ'],
          md
              .map((m) => [
                    '${m['name']}',
                    '${m['block']}',
                    '${m['village'] ?? ''}',
                    '${m['cause'] ?? ''}'
                  ])
              .toList(),
          weights: const [28, 22, 22, 28],
        ));
      }
      if (idth.isNotEmpty) {
        b.write(PdfHtml.band('শিশুমৃত্যু: ${idth.length} — শিশু ডেথ রিভিউ (CDR)'));
        b.write(PdfHtml.table(
          const ['নাম', 'ব্লক', 'গ্রাম', 'বয়স'],
          idth
              .map((m) => [
                    '${m['name']}',
                    '${m['block']}',
                    '${m['village'] ?? ''}',
                    '${m['age'] ?? ''}'
                  ])
              .toList(),
          weights: const [28, 22, 22, 28],
        ));
      }
      if (refs.isNotEmpty) {
        b.write(PdfHtml.section('রেফারেল হাসপাতালে পৌঁছয়নি (৭+ দিন)'));
        b.write(PdfHtml.table(
          const ['রোগী', 'ব্লক', 'গ্রাম', 'দিন'],
          refs
              .map((r) => [
                    '${r['patientName']}',
                    '${r['block']}',
                    '${r['village'] ?? ''}',
                    '${r['days']}'
                  ])
              .toList(),
          weights: const [32, 24, 24, 20],
        ));
      }
      if (stock.isNotEmpty) {
        b.write(PdfHtml.section('ওষুধ শেষের পথে'));
        b.write(PdfHtml.table(
          const ['ওষুধ', 'বাকি', 'ব্লক', 'ASHA'],
          stock
              .map((s) => [
                    '${s['medicine']}',
                    '${s['left']}',
                    '${s['block']}',
                    '${s['asha']}'
                  ])
              .toList(),
          weights: const [32, 14, 24, 30],
        ));
      }
      if (silent.isNotEmpty) {
        b.write(PdfHtml.section('৩০ দিন কোনো ভিজিট নেই (zero-reporting)'));
        b.write(PdfHtml.table(
          const ['ASHA', 'ব্লক'],
          silent.map((s) => ['${s['name']}', '${s['block']}']).toList(),
          weights: const [60, 40],
        ));
      }
    }

    b.write(PdfHtml.signatures(['$role স্বাক্ষর', 'তারিখ']));
    b.write(PdfHtml.footer(
        'AshaMitra দ্বারা স্বয়ংক্রিয়ভাবে তৈরি — HMIS পোর্টালের সাথে মিলিয়ে নিন।'));

    await PdfHtml.render(
      body: b.toString(),
      fileName: 'hmis_review_${months}m.pdf',
      landscape: blocks.length > 1, // the block table needs the width
    );
  }

  static String _today() {
    final d = DateTime.now();
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(d.day)}/${p(d.month)}/${d.year}';
  }
}
