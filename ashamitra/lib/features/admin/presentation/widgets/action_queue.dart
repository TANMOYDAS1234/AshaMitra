import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/panel_palette.dart';
import '../../../../shared/widgets/motion.dart';
import '../../../readiness/controller/readiness_controller.dart';
import '../../controller/admin_controller.dart';
import '../../controller/operations_controller.dart';
import '../../controller/programmes_controller.dart';

/// One item that needs a decision.
class ActionItem {
  final int rank; // lower = more urgent
  final IconData icon;
  final String title;
  final String detail;
  final Color color;
  final String route;

  const ActionItem(this.rank, this.icon, this.title, this.detail, this.color, this.route);
}

/// "আজ যা করতে হবে" — everything across the whole district that needs the
/// officer's attention, in one ranked list.
///
/// This exists because the dashboard used to open on four vanity totals and a
/// 14-day sparkline, while every actual escalation — supply stockouts, disease
/// clusters, maternal deaths, silent workers — lived one tab over. An officer who
/// has ninety seconds between meetings should not have to go looking.
///
/// Charts deliberately stay on the analytics tab. A chart tells you how you are
/// doing; this tells you what to do. They answer different questions and mixing
/// them pushes the actionable things below the fold.
///
/// Ranking is by how fast the thing kills someone, not by which module it came
/// from:
///   1  disease cluster        — still preventable, moves in days
///   2  missing life-saving supply
///   3  maternal / infant death — review already mandatory
///   4  cold chain failure     — spoils a block's vaccines silently
///   5  open outbreak
///   6  stranded referral
///   7  programme defaulters   — TB doses missed, high-risk NCD
///   8  silent worker
///   9  immunisation defaulters
///  10  unknown / not reported — never rendered as "fine"
/// Kicks off the four requests the queue draws from. Lazy on purpose: the
/// dashboard paints immediately and fills in, rather than blocking on all four.
void ensureActionSources() {
  final readiness = Get.put(ReadinessController(), tag: 'readiness');
  final progs = Get.put(ProgrammesController(), tag: 'programmes');
  final ops = Get.put(OperationsController(), tag: 'operations');
  if (readiness.blocks.isEmpty && !readiness.loadingSummary.value) {
    readiness.loadSummary();
  }
  if (progs.programmes.isEmpty && !progs.loading.value) progs.load();
  if (ops.data.isEmpty && !ops.loading.value) ops.loadAll();
}

/// The single ranked list of things needing a decision.
///
/// Hoisted out of the widget so the dashboard hero and the queue below it read
/// the SAME list. Two independent counts of "what needs doing" would eventually
/// disagree, and a hero number that contradicts the list beneath it is worse
/// than no hero at all.
///
/// Must be called inside an Obx to stay reactive.
List<ActionItem> buildActionItems() {
      final admin = Get.find<AdminController>();
      final readiness = Get.put(ReadinessController(), tag: 'readiness');
      final progs = Get.put(ProgrammesController(), tag: 'programmes');
      final ops = Get.put(OperationsController(), tag: 'operations');
      final items = <ActionItem>[];

      // 1 — disease clusters
      for (final k in ops.clusters.take(3)) {
        items.add(ActionItem(
          1,
          Icons.coronavirus_rounded,
          '${k['village']} — রোগ বাড়ছে',
          '${k['last7']} জন আক্রান্ত · ${k['block']}',
          AppColors.emergencyRed,
          AppRoutes.adminOperations,
        ));
      }

      // 2 — life-saving supply gaps
      for (final g in readiness.critical.take(3)) {
        items.add(ActionItem(
          2,
          Icons.medication_liquid_rounded,
          '${g.label} নেই',
          '${g.count} জায়গায় — ${g.places.map((p) => p.block).toSet().join(', ')}',
          AppColors.emergencyRed,
          AppRoutes.readinessSummary,
        ));
      }

      // 3 — deaths requiring review
      final mat = admin.dAlert('maternalDeaths');
      final inf = admin.dAlert('infantDeaths');
      if (mat.isNotEmpty) {
        items.add(ActionItem(3, Icons.female_rounded, '${mat.length} টি মাতৃমৃত্যু',
            'ডেথ রিভিউ (MDSR) দরকার', AppColors.emergencyRed, ''));
      }
      if (inf.isNotEmpty) {
        items.add(ActionItem(3, Icons.child_care_rounded, '${inf.length} টি শিশুমৃত্যু',
            'শিশু ডেথ রিভিউ (CDR) দরকার', AppColors.emergencyRed, ''));
      }

      // 4 — cold chain
      final cold = ops.section('coldChain');
      final coldFail = ((cold['failures'] as List?) ?? []).length;
      if (coldFail > 0) {
        items.add(ActionItem(4, Icons.ac_unit_rounded, 'কোল্ড চেইনে সমস্যা ($coldFail)',
            'টিকা নষ্ট হতে পারে', AppColors.emergencyRed,
            AppRoutes.adminOperations));
      }

      // 5 — open outbreaks
      final open = ((ops.section('outbreaks')['open'] as List?) ?? []).length;
      if (open > 0) {
        items.add(ActionItem(5, Icons.emergency_rounded, '$open টি প্রাদুর্ভাব চলছে',
            'ব্যবস্থা কতদূর — দেখুন', AppColors.emergencyRed,
            AppRoutes.adminOperations));
      }

      // 6 — stranded referrals
      final refs = admin.dAlert('overdueReferrals');
      if (refs.isNotEmpty) {
        items.add(ActionItem(6, Icons.local_shipping_rounded,
            '${refs.length} টি রেফারেল আটকে আছে', '৭ দিনের বেশি',
            AppColors.warning, ''));
      }

      // 7 — programme defaulters, by name where it matters most
      for (final p in progs.programmes) {
        for (final a in p.liveActions.where((a) => a.severity == 'high')) {
          items.add(ActionItem(7, Icons.health_and_safety_rounded, a.title,
              '${a.rows.length} জন · ${p.name}', AppColors.emergencyRed,
              AppRoutes.adminProgrammes));
        }
      }

      // 8 — silent workers
      final silent = admin.dAlert('silentAshas');
      if (silent.isNotEmpty) {
        items.add(ActionItem(8, Icons.person_off_rounded,
            '${silent.length} জন ASHA ৩০ দিন নিষ্ক্রিয়',
            silent.take(2).map((s) => s['name']).join(', '),
            AppColors.sky, ''));
      }

      // 9 — immunisation defaulters
      final def = (admin.district.value?['defaultersTotal'] as num?)?.toInt() ?? 0;
      if (def > 0) {
        items.add(ActionItem(9, Icons.vaccines_rounded, '$def টি টিকা বাকি',
            'নাম ধরে তালিকা আছে', AppColors.warning, ''));
      }

      // 10 — what we simply do not know. Ranked last but never omitted: a
      // sub-centre that has not reported is not a sub-centre that is fine, and
      // dropping it here would let silence read as health.
      final unknown = readiness.unknownCount;
      if (unknown > 0) {
        items.add(ActionItem(10, Icons.help_outline_rounded,
            '$unknown জায়গা থেকে ওষুধের খবর নেই',
            '"খবর নেই" মানে "ঠিক আছে" নয়', AppColors.textSecondary,
            AppRoutes.readinessSummary));
      }

      items.sort((a, b) => a.rank.compareTo(b.rank));
      return items;
}

class ActionQueue extends StatelessWidget {
  const ActionQueue({super.key});

  @override
  Widget build(BuildContext context) {
    ensureActionSources();
    return Obx(() {
      final items = buildActionItems();

      if (items.isEmpty) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.safeGreen.withValues(alpha: 0.08),
            borderRadius: AppRadius.xlR,
            border:
                Border.all(color: AppColors.safeGreen.withValues(alpha: 0.30)),
          ),
          child: Row(
            children: [
              const Icon(Icons.verified_rounded,
                  color: AppColors.safeGreen, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text('এখন জরুরি কিছু নেই',
                    style: AppTextStyles.label
                        .copyWith(color: AppColors.safeGreen)),
              ),
            ],
          ),
        );
      }

      final shown = items.take(6).toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded,
                  size: 18, color: AppColors.emergencyRed),
              const SizedBox(width: 6),
              Text('আজ যা করতে হবে (${items.length})',
                  style: AppTextStyles.label
                      .copyWith(color: AppColors.emergencyRed)),
            ],
          ),
          const SizedBox(height: 10),
          // Staggered so the reading order is FELT, not just laid out — the most
          // urgent card arrives first. The severity is carried by a solid bar on
          // the leading edge rather than a tinted outline: it survives at a
          // glance, in sunlight, on a cheap panel.
          ...shown.asMap().entries.map((e) {
            final i = e.value;
            final card = Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: AppColors.surface,
                borderRadius: AppRadius.lgR,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: i.route.isEmpty ? null : () => Get.toNamed(i.route),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: AppRadius.lgR,
                      boxShadow: AppShadows.low,
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        children: [
                          Container(width: 4, color: i.color),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(11, 13, 12, 13),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: i.color.withValues(alpha: 0.10),
                                      borderRadius: AppRadius.mdR,
                                    ),
                                    child:
                                        Icon(i.icon, size: 17, color: i.color),
                                  ),
                                  const SizedBox(width: 11),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(i.title,
                                            style: AppTextStyles.bodySm.copyWith(
                                                fontWeight: FontWeight.w700,
                                                color:
                                                    PanelPalette.onBackground)),
                                        Text(i.detail,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTextStyles.caption
                                                .copyWith(
                                                    color: PanelPalette
                                                        .textSecondary)),
                                      ],
                                    ),
                                  ),
                                  if (i.route.isNotEmpty)
                                    Icon(Icons.chevron_right_rounded,
                                        color: PanelPalette.textSecondary,
                                        size: 20),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
            // Only the single most urgent card breathes, and only once. More than
            // that and the emphasis cancels itself out.
            return RevealIn(
              index: e.key,
              child: e.key == 0 && i.rank <= 2
                  ? AttentionPulse(child: card)
                  : card,
            );
          }),
          if (items.length > shown.length)
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 4),
              child: Text('+ আরও ${items.length - shown.length} টি বিষয়',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary)),
            ),
        ],
      );
    });
  }
}
