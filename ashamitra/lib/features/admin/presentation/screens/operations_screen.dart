import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import "../../../../core/theme/app_text_styles.dart";
import "../../../../core/theme/panel_palette.dart";
import '../../../../shared/components/app_header.dart';
import '../../../../shared/widgets/accent_card.dart';
import '../../../../shared/widgets/motion.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../auth/controller/auth_controller.dart';
import '../../controller/operations_controller.dart';

/// District operations — the administrative half of a CMHO's job.
///
/// Ordered by how fast the thing kills someone, not by how the org chart is
/// drawn: disease clusters and open outbreaks first, then cold chain (a failed
/// ILR spoils a block's vaccines silently), then facilities and staffing, then
/// QA, training, meetings and budget.
class OperationsScreen extends StatefulWidget {
  const OperationsScreen({super.key});

  @override
  State<OperationsScreen> createState() => _OperationsScreenState();
}

class _OperationsScreenState extends State<OperationsScreen> {
  final c = Get.put(OperationsController(), tag: 'operations');
  final _auth = Get.find<AuthController>();
  final _open = <String>{}.obs;

  @override
  void initState() {
    super.initState();
    if (c.data.isEmpty) c.loadAll();
  }

  static const _synBn = {
    'fever': 'জ্বর',
    'diarrhoea': 'ডায়রিয়া',
    'ari': 'শ্বাসকষ্ট (ARI)',
    'rash': 'র‍্যাশ',
    'jaundice': 'জন্ডিস',
    'other': 'অন্যান্য',
  };

  static const _actionBn = {
    'rrtDeployed': 'RRT পাঠানো',
    'waterTested': 'জল পরীক্ষা',
    'foodSampled': 'খাবার নমুনা',
    'chlorination': 'ক্লোরিনেশন',
    'orsCamp': 'ORS ক্যাম্প',
    'medicalCamp': 'মেডিকেল ক্যাম্প',
    'ambulanceOnSite': 'অ্যাম্বুলেন্স',
    'awarenessDrive': 'সচেতনতা',
    'vectorControl': 'মশা নিয়ন্ত্রণ',
  };

  @override
  Widget build(BuildContext context) {
    final panel = _auth.user.value?.roleShort ?? '';
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: PanelPalette.background),
        child: SafeArea(
          child: Column(
            children: [
              AppHeader(
                title: 'জেলা পরিচালনা',
                subtitle: '$panel · রোগ নজরদারি · কেন্দ্র · কোল্ড চেইন · কর্মী',
                actions: [
                  IconButton(
                    onPressed: c.loadAll,
                    icon: const Icon(Icons.refresh_rounded),
                    color: PanelPalette.primary,
                  ),
                ],
              ),
              Expanded(
                child: Obx(() {
                  if (c.loading.value && c.data.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (c.error.isNotEmpty && c.data.isEmpty) {
                    return EmptyState(
                      icon: Icons.cloud_off_rounded,
                      title: 'তথ্য পাওয়া যায়নি',
                      subtitle: c.error.value,
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: c.loadAll,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                      children: [
                        _surveillance(),
                        _outbreaks(),
                        _coldChain(),
                        _facilities(),
                        _staffing(),
                        _inspections(),
                        _training(),
                        _meetings(),
                        _budget(),
                      ],
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 1. Disease clusters — the fastest-moving thing on the screen ───────────
  Widget _surveillance() {
    final t = c.survTotals;
    final cl = c.clusters;
    return _card(
      key: 'surv',
      icon: Icons.coronavirus_rounded,
      title: 'রোগ নজরদারি',
      subtitle: 'গ্রামে অস্বাভাবিক বাড়া ধরা পড়লে এখানে দেখাবে',
      alarm: cl.length,
      headline: [
        ('${(t['last7'] as num?)?.toInt() ?? 0}', '৭ দিনে কেস'),
        ('${cl.length}', 'ক্লাস্টার'),
        ('${(t['malariaPositive'] as num?)?.toInt() ?? 0}', 'ম্যালেরিয়া +'),
        ('${(t['dengueSuspect'] as num?)?.toInt() ?? 0}', 'ডেঙ্গু সন্দেহ'),
      ],
      body: cl.isEmpty
          ? _allClear('কোনও অস্বাভাবিক বাড়া ধরা পড়েনি')
          : Column(
              children: cl.map((k) {
                final novel = k['reason'] == 'novel';
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.emergencyRed.withValues(alpha: 0.05),
                    borderRadius: AppRadius.lgR,
                    border: Border.all(
                        color: AppColors.emergencyRed.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${_synBn[k['syndrome']] ?? k['syndrome']} — ${k['village']}',
                              style: AppTextStyles.label.copyWith(
                                  color: AppColors.emergencyRed,
                                  fontWeight: FontWeight.w800),
                            ),
                          ),
                          Text('${k['last7']} কেস',
                              style: AppTextStyles.label
                                  .copyWith(color: AppColors.emergencyRed)),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        // Say WHY it fired. An alert a supervisor cannot audit is
                        // an alert she will eventually stop trusting.
                        novel
                            ? 'আগে এই রোগ ছিল না — হঠাৎ ${k['last7']} জন · ${k['block']}'
                            : 'স্বাভাবিক ${k['baseline']} → এখন ${k['last7']} (${k['multiple']}× বেশি) · ${k['block']}',
                        style: AppTextStyles.caption
                            .copyWith(color: PanelPalette.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      ...((k['people'] as List?) ?? []).take(5).map((p) {
                        final m = Map<String, dynamic>.from(p as Map);
                        return _person(
                          m['name']?.toString() ?? '—',
                          m['village']?.toString() ?? '',
                          m['mobile']?.toString() ?? '',
                          danger: m['danger'] == true,
                        );
                      }),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  // ── 2. Open outbreaks and what has NOT been arranged ──────────────────────
  Widget _outbreaks() {
    final ob = c.section('outbreaks');
    final open = ((ob['open'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return _card(
      key: 'ob',
      icon: Icons.emergency_rounded,
      title: 'প্রাদুর্ভাব ও জরুরি অবস্থা',
      subtitle: 'যা এখনও করা হয়নি — সেটাই দেখানো হয়',
      alarm: open.length,
      headline: [
        ('${open.length}', 'চলমান'),
        ('${(ob['closedCount'] as num?)?.toInt() ?? 0}', 'বন্ধ হয়েছে'),
      ],
      body: open.isEmpty
          ? _allClear('কোনও চলমান প্রাদুর্ভাব নেই')
          : Column(
              children: open.map((o) {
                final pending = ((o['pending'] as List?) ?? [])
                    .map((e) => _actionBn[e.toString()] ?? e.toString())
                    .toList();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${o['title']} · ${o['village']}',
                          style: AppTextStyles.bodySm
                              .copyWith(fontWeight: FontWeight.w700)),
                      Text('${o['caseCount']} কেস · ${o['deaths']} মৃত্যু · ${o['block']}',
                          style: AppTextStyles.caption
                              .copyWith(color: PanelPalette.textSecondary)),
                      if (pending.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: pending
                              .map((p) => _pill(p, AppColors.emergencyRed))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  // ── 3. Cold chain ─────────────────────────────────────────────────────────
  Widget _coldChain() {
    final cc = c.section('coldChain');
    final fails = ((cc['failures'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final silent = ((cc['silent'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return _card(
      key: 'cold',
      icon: Icons.ac_unit_rounded,
      title: 'কোল্ড চেইন',
      subtitle: 'ILR ২–৮°C-এর বাইরে গেলে পুরো ব্লকের টিকা নষ্ট হয়',
      alarm: fails.length + silent.length,
      headline: [
        ('${(cc['points'] as num?)?.toInt() ?? 0}', 'পয়েন্ট'),
        ('${(cc['reported7d'] as num?)?.toInt() ?? 0}', '৭ দিনে খবর'),
        ('${fails.length}', 'সমস্যা'),
        ('${silent.length}', 'খবর নেই'),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (fails.isEmpty && silent.isEmpty)
            _allClear('সব ঠিক আছে')
          else ...[
            ...fails.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(f['facility']?.toString() ?? '—',
                                style: AppTextStyles.bodySm
                                    .copyWith(fontWeight: FontWeight.w600)),
                            Text(
                              [
                                if (f['working'] != true) 'কাজ করছে না',
                                if (f['tempAm'] != null) 'সকাল ${f['tempAm']}°',
                                if (f['tempPm'] != null) 'বিকাল ${f['tempPm']}°',
                                if ((f['powerCutHours'] as num?) != null &&
                                    (f['powerCutHours'] as num) > 0)
                                  '${f['powerCutHours']} ঘণ্টা বিদ্যুৎ ছিল না',
                                f['block']?.toString() ?? '',
                              ].where((s) => s.isNotEmpty).join(' · '),
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.emergencyRed),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
            // Silence is reported separately, and never folded into "fine".
            if (silent.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('৭ দিনে কোনও খবর দেয়নি — "খবর নেই" মানে "ঠিক আছে" নয়',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.warning)),
              const SizedBox(height: 4),
              Text(silent.map((s) => '${s['name']} · ${s['block']}').join('\n'),
                  style: AppTextStyles.caption
                      .copyWith(color: PanelPalette.textSecondary)),
            ],
          ],
        ],
      ),
    );
  }

  // ── 4. Facilities ─────────────────────────────────────────────────────────
  Widget _facilities() {
    final f = c.section('facilities');
    final list = ((f['list'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final night = ((f['noNightDelivery'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final byType = ((f['byType'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return _card(
      key: 'fac',
      icon: Icons.local_hospital_rounded,
      title: 'স্বাস্থ্য কেন্দ্র',
      subtitle: 'জেলার সব কেন্দ্র ও তাদের পরিষেবা',
      alarm: night.length,
      headline: [
        ('${(f['total'] as num?)?.toInt() ?? 0}', 'মোট কেন্দ্র'),
        ('${night.length}', 'রাতে প্রসব হয় না'),
      ],
      body: list.isEmpty
          ? _emptyHint('এখনও কোনও কেন্দ্র যোগ করা হয়নি')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: byType
                      .map((t) => _pill('${t['type']} ${t['count']}',
                          PanelPalette.primary))
                      .toList(),
                ),
                if (night.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text('রাতে প্রসব পরিষেবা নেই — জরুরি অবস্থায় মা কোথায় যাবেন?',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.emergencyRed)),
                  const SizedBox(height: 4),
                  Text(
                      night
                          .map((n) => '${n['name']} (${n['type']}) · ${n['block']}')
                          .join('\n'),
                      style: AppTextStyles.caption
                          .copyWith(color: PanelPalette.textSecondary)),
                ],
              ],
            ),
    );
  }

  // ── 5. Staffing ───────────────────────────────────────────────────────────
  Widget _staffing() {
    final s = c.section('staffing');
    final vac = ((s['vacancies'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final fill = s['fillRate'] as num?;
    return _card(
      key: 'staff',
      icon: Icons.badge_rounded,
      title: 'কর্মী ও শূন্যপদ',
      subtitle: 'অনুমোদিত পদের তুলনায় কতজন আছেন',
      alarm: ((s['vacant'] as num?)?.toInt() ?? 0) > 0 ? 1 : 0,
      headline: [
        ('${(s['sanctioned'] as num?)?.toInt() ?? 0}', 'অনুমোদিত'),
        ('${(s['inPost'] as num?)?.toInt() ?? 0}', 'কর্মরত'),
        ('${(s['vacant'] as num?)?.toInt() ?? 0}', 'শূন্য'),
        (fill == null ? '—' : '$fill%', 'পূরণ'),
      ],
      body: vac.isEmpty
          ? _emptyHint('কেন্দ্রে কর্মীর তথ্য যোগ করা হয়নি')
          : Column(
              children: vac.take(12).map((v) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('${v['cadre']} · ${v['facility']}',
                            style: AppTextStyles.bodySm),
                      ),
                      Text('${v['inPost']}/${v['sanctioned']}',
                          style: AppTextStyles.caption
                              .copyWith(color: PanelPalette.textSecondary)),
                      const SizedBox(width: 8),
                      _pill('${v['gap']} শূন্য', AppColors.emergencyRed),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  // ── 6. Inspections ────────────────────────────────────────────────────────
  Widget _inspections() {
    final i = c.section('inspections');
    final low = ((i['lowScore'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final never = ((i['neverInspected'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final avg = i['avgScore'] as num?;
    return _card(
      key: 'insp',
      icon: Icons.fact_check_rounded,
      title: 'পরিদর্শন ও মান',
      subtitle: 'গত ৬ মাসের পরিদর্শন',
      alarm: low.length,
      headline: [
        ('${(i['count'] as num?)?.toInt() ?? 0}', 'পরিদর্শন'),
        (avg == null ? '—' : '$avg%', 'গড় স্কোর'),
        ('${never.length}', 'কখনও হয়নি'),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (low.isEmpty && never.isEmpty)
            _emptyHint('পরিদর্শনের তথ্য নেই')
          else ...[
            ...low.map((l) => Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    children: [
                      Expanded(
                          child: Text('${l['facility']} · ${l['block']}',
                              style: AppTextStyles.bodySm)),
                      _pill('${l['score']}%', AppColors.emergencyRed),
                    ],
                  ),
                )),
            if (never.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('কখনও পরিদর্শন হয়নি: ${never.map((n) => n['name']).join(', ')}',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.warning)),
            ],
          ],
        ],
      ),
    );
  }

  // ── 7. Training ───────────────────────────────────────────────────────────
  Widget _training() {
    final t = c.section('training');
    final recent = ((t['recent'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return _card(
      key: 'train',
      icon: Icons.school_rounded,
      title: 'প্রশিক্ষণ',
      subtitle: 'গত ১২ মাস',
      alarm: 0,
      headline: [
        ('${(t['sessions'] as num?)?.toInt() ?? 0}', 'সেশন'),
        ('${(t['trained'] as num?)?.toInt() ?? 0}', 'প্রশিক্ষিত'),
        ('${(t['invited'] as num?)?.toInt() ?? 0}', 'ডাকা হয়েছিল'),
      ],
      body: recent.isEmpty
          ? _emptyHint('প্রশিক্ষণের তথ্য নেই')
          : Column(
              children: recent.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      children: [
                        Expanded(
                            child: Text(r['title']?.toString() ?? '—',
                                style: AppTextStyles.bodySm)),
                        Text('${r['attended']}/${r['invited']}',
                            style: AppTextStyles.caption
                                .copyWith(color: PanelPalette.textSecondary)),
                      ],
                    ),
                  )).toList(),
            ),
    );
  }

  // ── 8. Meetings — only the open action items matter ───────────────────────
  Widget _meetings() {
    final m = c.section('meetings');
    final open = ((m['openActions'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final overdue = (m['overdueActions'] as num?)?.toInt() ?? 0;
    return _card(
      key: 'meet',
      icon: Icons.groups_rounded,
      title: 'সভা ও সিদ্ধান্ত',
      subtitle: 'সিদ্ধান্তের কাজ কতটা এগোলো',
      alarm: overdue,
      headline: [
        ('${(m['count'] as num?)?.toInt() ?? 0}', 'সভা'),
        ('${open.length}', 'বাকি কাজ'),
        ('$overdue', 'সময় পেরিয়েছে'),
      ],
      body: open.isEmpty
          ? _emptyHint('কোনও বাকি সিদ্ধান্ত নেই')
          : Column(
              children: open.take(10).map((a) {
                final od = a['overdue'] == true;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                          od
                              ? Icons.error_outline_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: 14,
                          color: od
                              ? AppColors.emergencyRed
                              : PanelPalette.textSecondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a['what']?.toString() ?? '—',
                                style: AppTextStyles.bodySm),
                            Text(
                                [
                                  if ((a['who']?.toString() ?? '').isNotEmpty)
                                    a['who'].toString(),
                                  a['meeting']?.toString() ?? '',
                                ].where((s) => s.isNotEmpty).join(' · '),
                                style: AppTextStyles.caption.copyWith(
                                    color: od
                                        ? AppColors.emergencyRed
                                        : PanelPalette.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  // ── 9. Budget ─────────────────────────────────────────────────────────────
  Widget _budget() {
    final b = c.section('budget');
    final lines = ((b['lines'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final util = b['utilisationPct'] as num?;
    return _card(
      key: 'bud',
      icon: Icons.account_balance_wallet_rounded,
      title: 'বাজেট ব্যবহার',
      subtitle: 'বরাদ্দের তুলনায় খরচ — শুধু দেখার জন্য',
      alarm: 0,
      headline: [
        ('${(b['allocated'] as num?)?.toInt() ?? 0}', 'বরাদ্দ'),
        ('${(b['spent'] as num?)?.toInt() ?? 0}', 'খরচ'),
        (util == null ? '—' : '$util%', 'ব্যবহার'),
      ],
      body: lines.isEmpty
          ? _emptyHint('বাজেটের তথ্য যোগ করা হয়নি')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...lines.take(10).map((l) {
                  final u = l['utilisationPct'] as num?;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                            child: Text(l['head']?.toString() ?? '—',
                                style: AppTextStyles.bodySm)),
                        Text(u == null ? '—' : '$u%',
                            style: AppTextStyles.label.copyWith(
                                color: u == null
                                    ? PanelPalette.textLight
                                    : (u < 50
                                        ? AppColors.warning
                                        : AppColors.safeGreen))),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 8),
                // Say what this is NOT. A number that looks like a treasury
                // figure but has no audit trail behind it invites a decision it
                // cannot support.
                Text(
                  'এটি শুধু নজরদারির জন্য — কোনও অনুমোদন, অডিট বা পেমেন্ট এখানে হয় না।',
                  style: AppTextStyles.caption
                      .copyWith(color: PanelPalette.textLight),
                ),
              ],
            ),
    );
  }

  // ── shared pieces ─────────────────────────────────────────────────────────

  Widget _card({
    required String key,
    required IconData icon,
    required String title,
    required String subtitle,
    required int alarm,
    required List<(String, String)> headline,
    required Widget body,
  }) {
    return Obx(() {
      final open = _open.contains(key);
      final tone = alarm > 0 ? AppColors.emergencyRed : PanelPalette.primary;
      return AccentCard(
        accent: tone,
        emphasised: alarm > 0,
        padding: EdgeInsets.zero,
        onTap: () => open ? _open.remove(key) : _open.add(key),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AccentCardHeader(
                    icon: icon,
                    title: title,
                    subtitle: subtitle,
                    accent: tone,
                    badge: alarm,
                    trailing: AnimatedRotation(
                      turns: open ? 0.5 : 0,
                      duration: Motion.fast,
                      child: Icon(Icons.expand_more_rounded,
                          color: PanelPalette.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 18,
                    runSpacing: 10,
                    children: headline.map((h) => _stat(h.$1, h.$2)).toList(),
                  ),
                ],
              ),
            ),
            // Height animates so the list does not jump under the finger — you
            // keep your place in a nine-card screen.
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Column(
                children: [
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(15, 12, 15, 16),
                    child: body,
                  ),
                ],
              ),
              crossFadeState: open
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: Motion.fast,
              sizeCurve: Curves.easeOutCubic,
            ),
          ],
        ),
      );
    });
  }

  Widget _stat(String v, String l) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(v,
              style: AppTextStyles.h3.copyWith(
                  fontWeight: FontWeight.w800,
                  color: v == '—'
                      ? PanelPalette.textLight
                      : PanelPalette.onBackground)),
          Text(l,
              style: AppTextStyles.caption
                  .copyWith(color: PanelPalette.textSecondary)),
        ],
      );

  Widget _person(String name, String where, String mobile,
          {bool danger = false}) =>
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            if (danger)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.warning_amber_rounded,
                    size: 14, color: AppColors.emergencyRed),
              ),
            Expanded(
              child: Text([name, where].where((s) => s.isNotEmpty).join(' · '),
                  style: AppTextStyles.bodySm),
            ),
            if (mobile.isNotEmpty)
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => launchUrl(Uri.parse('tel:$mobile')),
                icon: Icon(Icons.phone_rounded,
                    size: 16, color: PanelPalette.primary),
              ),
          ],
        ),
      );

  Widget _pill(String t, Color col) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: col.withValues(alpha: 0.10),
          borderRadius: AppRadius.smR,
        ),
        child: Text(t,
            style: AppTextStyles.caption
                .copyWith(color: col, fontWeight: FontWeight.w700)),
      );

  Widget _allClear(String t) => Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              size: 18, color: AppColors.safeGreen),
          const SizedBox(width: 8),
          Expanded(
            child: Text(t,
                style: AppTextStyles.bodySm
                    .copyWith(color: AppColors.safeGreen)),
          ),
        ],
      );

  /// Distinct from [_allClear] on purpose: "no data entered" is not "all clear".
  Widget _emptyHint(String t) => Row(
        children: [
          Icon(Icons.info_outline_rounded,
              size: 16, color: PanelPalette.textLight),
          const SizedBox(width: 8),
          Expanded(
            child: Text(t,
                style: AppTextStyles.caption
                    .copyWith(color: PanelPalette.textLight)),
          ),
        ],
      );
}
