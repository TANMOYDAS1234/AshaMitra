import '../../../core/services/api_service.dart';
import '../../../core/utils/pdf_html.dart';
import '../data/models/patient_model.dart';

/// Generates a one-/two-page "মা ও শিশুর সুরক্ষা কার্ড — সারসংক্ষেপ" (MCP-card
/// summary / ANC report) for a single patient: identity + pregnancy summary,
/// a high-risk banner, the ANC visit table (from captured visit records), the
/// immunization table, and upcoming due items.
///
/// Rendered via the platform HTML→PDF pipeline ([PdfHtml]) so Bengali shapes
/// correctly (the `pdf` package doesn't shape Indic scripts).
class McpReportPdf {
  static Future<void> generate(
    PatientModel p, {
    Map<String, String> header = const {},
  }) async {
    // Pull the patient's schedule timeline (ANC / vaccine / HBNC events with the
    // record captured at each completed visit). Empty for a not-yet-synced row.
    final events = await ApiService.getScheduleForPatient(p.id);
    final data = _data(p, events, header);
    await PdfHtml.render(body: _html(data), fileName: data['fileName']!.toString());
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
    await PdfHtml.render(body: _html(data), fileName: data['fileName']!.toString());
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
    final immGiven = <int, String>{}; // schedule band index → date the dose was given
    final aefiNotes = <String>[]; // adverse events following immunization
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
        due.add([label, _kindBn(kind), _fmt(e['dueDate']), overdue ? 'Due' : 'আসন্ন']);
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
        final status = <String>[rec['allGiven'] == true ? 'সম্পূর্ণ' : 'আংশিক'];
        if (rec['aefiSevere'] == true) {
          status.add('তীব্র AEFI');
        } else if ((rec['aefi'] as List?)?.isNotEmpty ?? false) {
          status.add('AEFI');
        }
        final batch = (rec['vaccineBatch'] ?? '').toString();
        if (batch.isNotEmpty) status.add('ব্যাচ $batch');
        vac.add([
          label, date,
          ((rec['givenVaccines'] as List?)?.join(', ') ?? ''),
          status.join(' · '),
        ]);
        // Place this dose on the schedule grid by the child's age at the visit.
        final dd = DateTime.tryParse((e['dueDate'] ?? '').toString());
        if (p.dob != null && dd != null) {
          final ageDays = dd.difference(p.dob!).inDays;
          var best = 0, bestDiff = 1 << 30;
          for (var i = 0; i < _immSchedule.length; i++) {
            final diff = (ageDays - (_immSchedule[i][2] as int)).abs();
            if (diff < bestDiff) {
              bestDiff = diff;
              best = i;
            }
          }
          immGiven[best] = _fmt(rec['completedAt'] ?? e['doneDate'] ?? e['dueDate']);
        }
        if (rec['aefiSevere'] == true) {
          aefiNotes.add('$label — তীব্র AEFI');
        } else if ((rec['aefi'] as List?)?.isNotEmpty ?? false) {
          aefiNotes.add('$label — AEFI');
        }
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
        if (rec['ifaGiven'] == true) parts.add('IFA');
        if (rec['fpCounselled'] == true) parts.add('পরিবার পরিকল্পনা পরামর্শ');
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

    // Immunization schedule + record grid — children only (the full national
    // schedule, with the date each dose was actually given).
    final imm = isChild
        ? [
            for (var i = 0; i < _immSchedule.length; i++)
              [
                _immSchedule[i][0] as String,
                _immSchedule[i][1] as String,
                immGiven[i] ?? '',
              ]
          ]
        : <List<String>>[];

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
      'imm': imm,
      'aefiNote': aefiNotes.join(' · '),
      // ── Raw fields for the official MCP-card form layout ──────────────────
      'isChild': isChild,
      'motherName': isChild ? p.guardianName : p.name,
      'motherAge': isChild
          ? ''
          : '${p.age} ${switch (p.ageUnit) { 'days' => 'দিন', 'months' => 'মাস', _ => 'বছর' }}',
      'fatherName': m('fatherName'),
      'address': (p.village.isNotEmpty && p.village != 'Unknown') ? p.village : '',
      'motherMobile': isChild ? '' : p.mobile,
      'fatherMobile': m('fatherMobile'),
      'rchMother': m('rchId'),
      'bankName': m('bankName'),
      'ifsc': m('ifsc'),
      'bankAccount': m('bankAccount'),
      'gravida': m('gravida'),
      'prevLive': m('prevLiveBirths'),
      'lmp': p.lmp != null ? _fmt(p.lmp!.toIso8601String()) : '',
      'edd': p.edd != null ? _fmt(p.edd!.toIso8601String()) : '',
      'childName': isChild ? p.name : '',
      'dob': p.dob != null ? _fmt(p.dob!.toIso8601String()) : '',
      'genderBn': isChild ? genderBn : '',
      'childRch': m('childRchId'),
      'childAadhaar': m('childAadhaar'),
      'motherAadhaar': m('motherAadhaar'),
      'anc': anc,
      'weightGain': weightGain,
      'pnc': pnc,
      'vac': vac,
      'hbnc': hbnc,
      'hbyc': hbyc,
      'due': due,
    };
  }

  /// Faithful reproduction of the West Bengal "মা ও শিশুর সুরক্ষা কার্ড"
  /// identity page (page 3 of the physical booklet), pre-filled with whatever
  /// the app knows; every other field prints as a blank line to fill by hand.
  static String _mcpCardForm(Map<String, dynamic> data) {
    final e = PdfHtml.esc;
    final h = ((data['header'] as Map?) ?? const {})
        .map((k, v) => MapEntry(k.toString(), v.toString()));
    String g(String k) => (data[k] ?? '').toString();

    // A labelled fill-field; `grow` sets its flex weight in the row.
    String f(String label, String value, {int grow = 3}) =>
        '<span class="fl">${e(label)}</span>'
        '<span class="fv" style="flex:$grow">${e(value)}</span>';
    // A checkbox + label; ticked when [on].
    String c(String label, {bool on = false}) =>
        '<span class="ck"><i class="${on ? 'b on' : 'b'}"></i>${e(label)}</span>';
    String row(String inner) => '<div class="frow">$inner</div>';
    String sec(String t) => '<div class="msec">${e(t)}</div>';

    final b = StringBuffer();
    b.write('''
<style>
  .mcp { color:#14210f; }
  .mcp .gov { text-align:center; border:1.4px solid #2f7d32; border-radius:6px;
    padding:6px 10px; margin-bottom:6px; background:#f0f7f0; }
  .mcp .gov b { color:#1b5e20; font-size:11.5px; line-height:1.55; }
  .mcp .ctop { display:flex; justify-content:space-between; align-items:center;
    margin:2px 0 4px; }
  .mcp .ctop .t { font-size:15px; font-weight:800; color:#1b5e20; }
  .mcp .ctop .hr { font-size:9.5px; font-weight:600; }
  .mcp .gen { font-size:8.5px; color:#6b7280; text-align:right; margin-top:2px; }
  .mcp .msec { font-size:11px; font-weight:800; color:#fff; background:#2f7d32;
    padding:3px 9px; border-radius:4px; margin:9px 0 3px; }
  .mcp .frow { display:flex; flex-wrap:wrap; align-items:flex-end; gap:2px 12px;
    padding:2.5px 2px; font-size:10px; }
  .mcp .fl { font-weight:700; white-space:nowrap; }
  .mcp .fv { border-bottom:1px dotted #7d7d7d; min-width:55px; padding:0 4px 1px;
    font-weight:600; color:#0b3d0b; }
  .mcp .ck { white-space:nowrap; font-weight:600; }
  .mcp .ck i.b { display:inline-block; width:11px; height:11px;
    border:1.2px solid #333; margin:0 3px -1px 0; }
  .mcp .ck i.b.on { background:#2f7d32; border-color:#2f7d32; }
</style>
<div class="mcp">
  <div class="gov"><b>স্বাস্থ্য ও পরিবার কল্যাণ দপ্তর, পশ্চিমবঙ্গ সরকার<br>
    নারী ও শিশু বিকাশ এবং সমাজ কল্যাণ দপ্তর, পশ্চিমবঙ্গ সরকার</b></div>
  <div class="ctop">
    <span class="t">মা ও শিশুর সুরক্ষা কার্ড</span>
    <span class="hr">গর্ভবতী উচ্চ ঝুঁকিপূর্ণ&nbsp;&nbsp;''');
    b.write(c('হ্যাঁ', on: data['highRisk'] == true));
    b.write(c('না', on: data['highRisk'] != true));
    b.write('</span></div>');
    b.write('<div class="gen">তৈরি: ${e(g('generatedAt'))}</div>');

    // ── পরিবারের পরিচয়পত্র ──
    b.write(sec('পরিবারের পরিচয়পত্র'));
    b.write(row(f('মায়ের নাম', g('motherName'), grow: 4) + f('বয়স', g('motherAge'), grow: 1)));
    b.write(row(f('বাবার নাম', g('fatherName'), grow: 6)));
    b.write(row(f('ঠিকানা', g('address'), grow: 6)));
    b.write(row(f('মায়ের মোবাইল', g('motherMobile')) + f('বাবার মোবাইল', g('fatherMobile'))));
    b.write(row(f('এম সি টি এস / আর সি এইচ / নিবন্ধন নং (মা)', g('rchMother'), grow: 6)));
    b.write(row('<span class="fl">PMMVY জন্য যোগ্য</span>'
        '${c('হ্যাঁ')}${c('না')}${f('ব্যাঙ্ক ও শাখা', g('bankName'), grow: 3)}'));
    b.write(row(f('IFSC', g('ifsc')) + f('অ্যাকাউন্ট নং', g('bankAccount'))));

    // ── গর্ভাবস্থার তথ্য ──
    b.write(sec('গর্ভাবস্থার তথ্য'));
    b.write(row(f('গর্ভসঞ্চার সংখ্যা', g('gravida'), grow: 1)
        + f('পূর্ববর্তী জীবিত শিশু', g('prevLive'), grow: 1)
        + f('সর্বশেষ প্রসবের স্থান', '', grow: 2)));
    b.write(row(f('শেষ মাসিকের তারিখ (LMP)', g('lmp')) + f('সম্ভাব্য প্রসবের তারিখ (EDD)', g('edd'))));
    b.write(row(f('নথিভুক্তকরণের তারিখ', '') + f('চিহ্নিত প্রসব কেন্দ্র', h['facility'] ?? '')));
    b.write(row('<span class="fl">গর্ভাবস্থার ফলাফল</span>'
        '${c('জীবিত শিশুর প্রসব')}${c('মৃত শিশুর প্রসব')}'));

    // ── জন্মের রেকর্ড ──
    b.write(sec('জন্মের রেকর্ড'));
    b.write(row(f('বাচ্চার নাম', g('childName'), grow: 4) + f('জন্মের তারিখ', g('dob'), grow: 2)));
    b.write(row('${f('জন্মের সময়', '', grow: 2)}<span class="fl">লিঙ্গ</span>'
        '${c('ছেলে', on: g('genderBn') == 'ছেলে')}${c('মেয়ে', on: g('genderBn') == 'মেয়ে')}'));
    b.write(row(f('বর্তমান প্রসবের স্থান', '', grow: 4) + f('জন্ম রেজিস্ট্রেশন নং', '', grow: 2)));
    b.write(row(f('নিবন্ধন নং (শিশু)', g('childRch'), grow: 6)));

    // ── প্রতিষ্ঠান সংক্রান্ত তথ্য ──
    b.write(sec('প্রতিষ্ঠান সংক্রান্ত তথ্য'));
    b.write(row(f('অঙ্গনওয়াড়ি কেন্দ্র', '') + f('LGD কোড', '', grow: 1)));
    b.write(row(f('গ্রাম / শহর', g('address'), grow: 3) + f('ওয়ার্ড', '', grow: 1)
        + f('ব্লক', h['block'] ?? '', grow: 2)));
    b.write(row(f('পোস্ট অফিস', '') + f('পোস্টাল কোড', '', grow: 1)));
    b.write(row(f('ASHA / HHW', h['asha'] ?? '') + f('ANM / FTS', '')));
    b.write(row(f('PHC / UPHC', '') + f('BPHC', '')));
    b.write(row(f('গ্রামীণ হাসপাতাল (RH)', '', grow: 2) + f('জেলা', h['district'] ?? '', grow: 1)
        + f('উপস্বাস্থ্যকেন্দ্র', '', grow: 2)));
    b.write(row(f('রেফারেল হাসপাতাল', '', grow: 3) + f('স্থায়ী পুষ্টি দিবস', '', grow: 2)));
    b.write(row(f('শিশুর আধার নং', g('childAadhaar')) + f('মায়ের আধার নং', g('motherAadhaar'))));
    b.write(row(f('ASHA মোবাইল', '') + f('ANM / FTS মোবাইল', '')));
    b.write(row(f('অ্যাম্বুলেন্স টোল ফ্রি', '102 / 108', grow: 1)
        + f('রেফারেল হাসপাতালের ফোন', '', grow: 2)));
    b.write('</div>');
    return b.toString();
  }

  static const _ord = ['১ম', '২য়', '৩য়', '৪র্থ', '৫ম', '৬ষ্ঠ', '৭ম', '৮ম'];

  /// ANC exam grid in the MCP-card page-5 layout: measurements down the rows,
  /// each visit a column. [anc] rows are
  /// [label, date, weight, bp, hb, urine, fundal, given, flags].
  static String _ancExamGrid(List<List<String>> anc) {
    const mh =
        'style="background:#f3e8f9;font-weight:700;text-align:left;white-space:nowrap"';
    final measures = <List<dynamic>>[
      ['তারিখ', 1],
      ['ওজন (কেজি)', 2],
      ['রক্তচাপ', 3],
      ['Hb (গ্রাম)', 4],
      ['মূত্র (অ্যাল./সুগার)', 5],
      ['জরায়ুর উচ্চতা', 6],
      ['দেওয়া হয়েছে', 7],
      ['বিপদচিহ্ন / TB', 8],
    ];
    final b = StringBuffer('<table><thead><tr><th $mh>গর্ভকালীন পরীক্ষা</th>');
    for (var i = 0; i < anc.length; i++) {
      b.write('<th>${PdfHtml.esc(i < _ord.length ? _ord[i] : '${i + 1}')}</th>');
    }
    b.write('</tr></thead><tbody>');
    for (final m in measures) {
      final idx = m[1] as int;
      b.write('<tr><td $mh>${PdfHtml.esc(m[0] as String)}</td>');
      for (final r in anc) {
        b.write('<td>${PdfHtml.cell(idx < r.length ? r[idx] : '')}</td>');
      }
      b.write('</tr>');
    }
    b.write('</tbody></table>');
    return b.toString();
  }

  // WB UIP immunization schedule — mirrors assets/data/asha_engine.json →
  // immunization.schedule (WB NHM Safe Motherhood Book, pg 25–26).
  // [ageBn, vaccinesBn, offsetDays-from-birth] (offset used only to match a
  // completed visit to its band by the child's age; not clinical timing).
  static const List<List<dynamic>> _immSchedule = [
    ['জন্মের পরপরই', 'BCG · OPV-0 · হেপ B-0', 0],
    ['৬ সপ্তাহ', 'পেন্টা-1 · OPV-1 · রোটা-1 · fIPV-1', 42],
    ['১০ সপ্তাহ', 'পেন্টা-2 · OPV-2 · রোটা-2', 70],
    ['১৪ সপ্তাহ', 'পেন্টা-3 · OPV-3 · রোটা-3 · fIPV-2', 98],
    ['৯–১২ মাস', 'MR-1 · ভিটামিন A-1 · JE-1', 320],
    ['১৬–২৪ মাস', 'DPT বুস্টার-1 · MR-2 · OPV বুস্টার · ভিট A-2 · JE-2', 600],
    ['২–৫ বছর', 'ভিটামিন A (৩য়–৯ম ডোজ, ৬ মাস অন্তর)', 1095],
    ['৫–৬ বছর', 'DPT বুস্টার-2', 2007],
    ['১০ বছর', 'TD', 3652],
    ['১৬ বছর', 'TD', 5844],
  ];

  /// Immunization schedule + record grid (MCP-card pg 25–26 / booklet pg 36–38):
  /// the full national schedule down the rows, the date each dose was actually
  /// given in the last column (blank box ▢ where still due). [rows] are
  /// [ageBn, vaccinesBn, givenDate].
  static String _immunizationGrid(List<List<String>> rows) {
    const mh =
        'style="background:#f3e8f9;font-weight:700;white-space:nowrap;text-align:left"';
    final b = StringBuffer(
        '<table><thead><tr><th $mh>বয়স</th><th style="text-align:left">নির্ধারিত টিকা</th>'
        '<th style="white-space:nowrap">দেওয়া হয়েছে<br>(তারিখ)</th></tr></thead><tbody>');
    for (final r in rows) {
      final given = r.length > 2 ? r[2] : '';
      b.write('<tr><td $mh>${PdfHtml.esc(r[0])}</td>'
          '<td style="text-align:left">${PdfHtml.esc(r[1])}</td>'
          '<td>${given.isEmpty ? '<span style="color:#c7c7c7">▢</span>' : PdfHtml.cell(given)}</td></tr>');
    }
    b.write('</tbody></table>');
    return b.toString();
  }

  /// Builds the report body HTML from the prepared [data] map.
  static String _html(Map<String, dynamic> data) {
    List<List<String>> rows(dynamic src) => ((src as List?) ?? const [])
        .map((r) => (r as List).map((c) => c.toString()).toList())
        .toList();
    final anc = rows(data['anc']);
    final pnc = rows(data['pnc']);
    final vac = rows(data['vac']);
    final imm = rows(data['imm']);
    final hbnc = rows(data['hbnc']);
    final hbyc = rows(data['hbyc']);
    final due = rows(data['due']);

    final b = StringBuffer();
    // Official MCP-card identity form (page-3 layout), pre-filled with app data.
    b.write(_mcpCardForm(data));
    if (data['highRisk'] == true) {
      final reason = (data['highRiskReason'] ?? '').toString();
      b.write(PdfHtml.band('উচ্চ ঝুঁকি: ${reason.isNotEmpty ? reason : 'হ্যাঁ'}'));
    }

    if (anc.isNotEmpty) {
      b.write(PdfHtml.section('গর্ভকালীন পরীক্ষা (ANC)'));
      b.write(_ancExamGrid(anc));
      final wg = (data['weightGain'] ?? '').toString();
      if (wg.isNotEmpty) b.write('<div class="note">${PdfHtml.esc(wg)}</div>');
    }
    if (pnc.isNotEmpty) {
      b.write(PdfHtml.section('প্রসব-পরবর্তী পরিচর্যা (PNC)'));
      b.write(PdfHtml.table(const ['ভিজিট', 'তারিখ', 'পর্যবেক্ষণ'], pnc,
          weights: const [22, 18, 60]));
    }
    if (imm.isNotEmpty) {
      // Child → the full national schedule as a grid, with doses given to date.
      b.write(PdfHtml.section('টিকাকরণ সূচি ও রেকর্ড'));
      b.write(_immunizationGrid(imm));
      final aefi = (data['aefiNote'] ?? '').toString();
      if (aefi.isNotEmpty) {
        b.write('<div class="note">টিকা-পরবর্তী প্রতিক্রিয়া (AEFI): ${PdfHtml.esc(aefi)}</div>');
      }
    } else if (vac.isNotEmpty) {
      // Mother → TT/Td doses as a simple record.
      b.write(PdfHtml.section('টিকাকরণ'));
      b.write(PdfHtml.table(const ['ভিজিট', 'তারিখ', 'যে টিকা দেওয়া হয়েছে', 'অবস্থা'], vac,
          weights: const [20, 16, 40, 24]));
    }
    if (hbnc.isNotEmpty) {
      b.write(PdfHtml.section('নবজাতক গৃহ পরিদর্শন (HBNC)'));
      b.write(PdfHtml.table(const ['ভিজিট', 'তারিখ', 'পর্যবেক্ষণ'], hbnc,
          weights: const [22, 18, 60]));
    }
    if (hbyc.isNotEmpty) {
      b.write(PdfHtml.section('শিশু গৃহ পরিদর্শন (HBYC)'));
      b.write(PdfHtml.table(const ['ভিজিট', 'তারিখ', 'পর্যবেক্ষণ'], hbyc,
          weights: const [22, 18, 60]));
    }
    if (due.isNotEmpty) {
      b.write(PdfHtml.section('আসন্ন / Due (টিকা ও পরীক্ষা)'));
      b.write(PdfHtml.table(const ['কাজ', 'ধরন', 'তারিখ', 'অবস্থা'], due,
          weights: const [40, 18, 22, 20]));
    }
    if (anc.isEmpty &&
        pnc.isEmpty &&
        vac.isEmpty &&
        imm.isEmpty &&
        hbnc.isEmpty &&
        hbyc.isEmpty &&
        due.isEmpty) {
      b.write('<div class="foot">— এখনও কোনো ভিজিট/সূচি নেই —</div>');
    }
    b.write(PdfHtml.footer(
        'AshaMitra দ্বারা স্বয়ংক্রিয়ভাবে তৈরি — তথ্য মিলিয়ে নিন।  আশা স্বাক্ষর: ____________________'));
    return b.toString();
  }
}
