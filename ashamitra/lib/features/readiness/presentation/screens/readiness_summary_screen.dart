import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/components/app_header.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../auth/controller/auth_controller.dart';
import '../../controller/readiness_controller.dart';

/// What is missing, where, and who has told us nothing at all.
///
/// The geography is named by PANEL: a CMHO reads জেলা → ব্লক → উপকেন্দ্র, a BMHO
/// reads her block, an ANM reads her sub-centre and her ASHAs. Same rollup, same
/// subtree scoping on the server — only the labels move.
class ReadinessSummaryScreen extends StatefulWidget {
  const ReadinessSummaryScreen({super.key});

  @override
  State<ReadinessSummaryScreen> createState() => _ReadinessSummaryScreenState();
}

class _ReadinessSummaryScreenState extends State<ReadinessSummaryScreen> {
  final c = Get.put(ReadinessController(), tag: 'readiness');
  final _auth = Get.find<AuthController>();
  final _open = <String>{}.obs;

  @override
  void initState() {
    super.initState();
    c.loadSummary();
  }

  String get _panel => _auth.user.value?.roleShort ?? '';

  /// The two geography levels this panel actually owns.
  ({String top, String mid, String leaf}) get _levels =>
      switch (_auth.user.value?.panelRole) {
        'cmho' => (top: 'জেলা', mid: 'ব্লক', leaf: 'উপকেন্দ্র / ASHA'),
        'bmho' => (top: 'ব্লক', mid: 'উপকেন্দ্র', leaf: 'ANM / ASHA'),
        _ => (top: 'উপকেন্দ্র', mid: 'এলাকা', leaf: 'ASHA'),
      };

  @override
  Widget build(BuildContext context) {
    final lv = _levels;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          child: Column(
            children: [
              AppHeader(
                title: 'ওষুধ ও প্রস্তুতি',
                subtitle: '$_panel · ${lv.top} → ${lv.mid} → ${lv.leaf}',
                actions: [
                  IconButton(
                    onPressed: c.loadSummary,
                    icon: const Icon(Icons.refresh_rounded),
                    color: AppColors.primary,
                  ),
                ],
              ),
              Expanded(
                child: Obx(() {
                  if (c.loadingSummary.value && c.blocks.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (c.summaryError.isNotEmpty && c.blocks.isEmpty) {
                    return EmptyState(
                      icon: Icons.cloud_off_rounded,
                      title: 'তথ্য পাওয়া যায়নি',
                      subtitle: c.summaryError.value,
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: c.loadSummary,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                      children: [
                        _coverageStrip(),
                        const SizedBox(height: 14),
                        if (c.critical.isNotEmpty) ...[
                          _criticalPanel(),
                          const SizedBox(height: 18),
                        ],
                        _geoTitle(lv),
                        const SizedBox(height: 8),
                        ...c.blocks.map(_blockCard),
                        if (c.blocks.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 40),
                            child: EmptyState(
                              icon: Icons.inventory_2_rounded,
                              title: 'এখনও কেউ রিপোর্ট করেনি',
                              subtitle: 'কর্মীদের ওষুধ ও যন্ত্রপাতির খবর পাঠাতে বলুন',
                            ),
                          ),
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

  // ── Coverage. "Unknown" is shown as loudly as "out", on purpose ─────────────
  //
  // A sub-centre that has never reported is not a sub-centre that is fine. If
  // this strip only counted stockouts, a district where nobody reports would
  // read as a perfect district — the most dangerous possible lie.
  Widget _coverageStrip() {
    final cov = c.coverage;
    final expected = cov['expected'] ?? 0;
    final reported = cov['reported'] ?? 0;
    final unknown = c.unknownCount;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.xlR,
        boxShadow: AppShadows.low,
      ),
      child: Row(
        children: [
          _stat('$reported/$expected', 'খবর দিয়েছে',
              reported == expected && expected > 0
                  ? AppColors.safeGreen
                  : AppColors.primary),
          _divider(),
          _stat('${c.criticalCount}', 'জরুরি ঘাটতি',
              c.criticalCount > 0 ? AppColors.emergencyRed : AppColors.safeGreen),
          _divider(),
          _stat('$unknown', 'খবর নেই',
              unknown > 0 ? AppColors.warning : AppColors.safeGreen),
        ],
      ),
    );
  }

  Widget _stat(String v, String l, Color col) => Expanded(
        child: Column(
          children: [
            Text(v,
                style: AppTextStyles.h2
                    .copyWith(color: col, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(l,
                textAlign: TextAlign.center,
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary)),
          ],
        ),
      );

  Widget _divider() => Container(
      width: 1, height: 34, color: AppColors.onBackground.withValues(alpha: 0.06));

  // ── What's missing, worst first ────────────────────────────────────────────
  Widget _criticalPanel() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.emergencyRed.withValues(alpha: 0.05),
          borderRadius: AppRadius.xlR,
          border: Border.all(color: AppColors.emergencyRed.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.priority_high_rounded,
                    color: AppColors.emergencyRed, size: 20),
                const SizedBox(width: 6),
                Text('প্রাণরক্ষাকারী জিনিস নেই',
                    style: AppTextStyles.h3
                        .copyWith(color: AppColors.emergencyRed)),
              ],
            ),
            const SizedBox(height: 4),
            Text('একদিনে ঠিক করা যায় — এবং করলে জীবন বাঁচে',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            ...c.critical.map((g) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.emergencyRed,
                              borderRadius: AppRadius.smR,
                            ),
                            child: Text('${g.count}',
                                style: AppTextStyles.caption.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(g.label,
                                style: AppTextStyles.body.copyWith(
                                    fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      // Names, not a number. A supervisor acts on a place and a
                      // person; she cannot act on "3".
                      Padding(
                        padding: const EdgeInsets.only(left: 32, top: 2),
                        child: Text(
                          g.places
                              .map((p) => [
                                    p.name,
                                    if (p.subCentre.isNotEmpty) p.subCentre,
                                  ].join(' · '))
                              .join('\n'),
                          style: AppTextStyles.bodySm
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      );

  Widget _geoTitle(({String top, String mid, String leaf}) lv) => Row(
        children: [
          Text('${lv.mid} অনুযায়ী',
              style: AppTextStyles.h3),
          const SizedBox(width: 8),
          Expanded(
            child: Text('— ট্যাপ করে ভিতরে দেখুন',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary)),
          ),
        ],
      );

  // ── Drill-down: block → the people inside it ───────────────────────────────
  Widget _blockCard(ReadinessBlock b) {
    return Obx(() {
      final open = _open.contains(b.block);
      final bad = b.criticalOut > 0;
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.lgR,
          boxShadow: AppShadows.low,
          border: bad
              ? Border.all(color: AppColors.emergencyRed.withValues(alpha: 0.3))
              : null,
        ),
        child: Column(
          children: [
            InkWell(
              borderRadius: AppRadius.lgR,
              onTap: () => open ? _open.remove(b.block) : _open.add(b.block),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b.block,
                              style: AppTextStyles.body
                                  .copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          // The health of a place in one line: what's missing,
                          // what's running low, and what we simply don't know.
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (b.criticalOut > 0)
                                _pill('${b.criticalOut} জরুরি ঘাটতি',
                                    AppColors.emergencyRed),
                              if (b.low > 0)
                                _pill('${b.low} কম', AppColors.warning),
                              if (b.unknown > 0)
                                _pill('${b.unknown} খবর নেই',
                                    AppColors.textSecondary),
                              if (b.criticalOut == 0 &&
                                  b.low == 0 &&
                                  b.unknown == 0)
                                _pill('সব ঠিক আছে', AppColors.safeGreen),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                        color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
            if (open)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Column(children: b.units.map(_unitRow).toList()),
              ),
          ],
        ),
      );
    });
  }

  Widget _unitRow(ReadinessUnit u) {
    final (Color col, String status) = switch (u.state) {
      'never' => (AppColors.textSecondary, 'কখনও খবর দেয়নি'),
      'stale' => (AppColors.warning, '${u.daysAgo} দিন আগের খবর'),
      _ => u.criticalOut.isNotEmpty
          ? (AppColors.emergencyRed, '${u.criticalOut.length} টি জরুরি জিনিস নেই')
          : u.low.isNotEmpty
              ? (AppColors.warning, '${u.low.length} টি কম')
              : (AppColors.safeGreen, 'সব ঠিক আছে'),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: col, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [u.name, if (u.subCentre.isNotEmpty) u.subCentre].join(' · '),
                  style: AppTextStyles.bodySm
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                Text(status,
                    style: AppTextStyles.caption.copyWith(color: col)),
              ],
            ),
          ),
          Text(u.role.toUpperCase().replaceAll('_WORKER', ''),
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

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
}
