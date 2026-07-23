import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import "../../../../core/theme/app_text_styles.dart";
import "../../../../core/theme/panel_palette.dart";
import '../../../../features/auth/controller/auth_controller.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../admin/controller/admin_controller.dart';
import '../widgets/analytics_charts.dart';
import '../widgets/action_queue.dart';
import '../widgets/dashboard_blocks.dart';
import '../../../../shared/widgets/motion.dart';
import '../../../../app/routes.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../../../shared/widgets/empty_state.dart';

class AdminOverviewTab extends StatefulWidget {
  const AdminOverviewTab({super.key});
  @override
  State<AdminOverviewTab> createState() => _AdminOverviewTabState();
}

class _AdminOverviewTabState extends State<AdminOverviewTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctrl = Get.find<AdminController>();
      ctrl.loadStats();
      ctrl.loadReports();
      // The action queue reads district alerts (deaths, stranded referrals,
      // silent workers, defaulters). Without this it silently renders half its
      // sources as empty — worse than not showing them, because an incomplete
      // "today's work" list reads as a complete one.
      if (ctrl.district.value == null) ctrl.loadDistrict();
    });
  }

  /// The hero band. Reads the same ranked list the queue below renders, so the
  /// headline count and the cards under it can never contradict each other.
  Widget _hero() {
    ensureActionSources();
    return Obx(() {
      final items = buildActionItems();
      // Name the two or three biggest contributors rather than a bare total —
      // "7" alone tells her to look; "3 ওষুধ · 2 টিকা" tells her what she is
      // about to be looking at.
      final byKind = <String, int>{};
      for (final i in items) {
        final k = switch (i.rank) {
          1 => 'রোগ',
          2 => 'ওষুধ',
          3 => 'মৃত্যু',
          4 => 'কোল্ড চেইন',
          5 => 'প্রাদুর্ভাব',
          6 => 'রেফারেল',
          7 => 'কর্মসূচি',
          8 => 'নিষ্ক্রিয় ASHA',
          9 => 'টিকা',
          _ => 'খবর নেই',
        };
        byKind[k] = (byKind[k] ?? 0) + 1;
      }
      final parts = byKind.entries.take(3).map((e) => '${e.value} ${e.key}');
      return DashboardHero(
        count: items.length,
        breakdown: parts.join(' · '),
        onTap: items.isEmpty
            ? null
            : () => Get.find<AdminController>().goToTab(1),
      );
    });
  }

  /// The risk donut, sized to fill the right half of the asymmetric block.
  Widget _riskCard(AdminController ctrl) => Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.lgR,
          boxShadow: AppShadows.low,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('ঝুঁকির ভাগ',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption
                    .copyWith(color: PanelPalette.textSecondary)),
            const SizedBox(height: 8),
            Center(
              child: BandDonut(
                red: ctrl.redReports.value,
                yellow: ctrl.yellowReports.value,
                green: ctrl.greenReports.value,
                size: 104,
              ),
            ),
            const SizedBox(height: 10),
            _bandLegend('RED', ctrl.redReports.value, AppColors.emergencyRed),
            const SizedBox(height: 3),
            _bandLegend('YELLOW', ctrl.yellowReports.value, AppColors.warningYellow),
            const SizedBox(height: 3),
            _bandLegend('GREEN', ctrl.greenReports.value, AppColors.safeGreen),
          ],
        ),
      );

  Widget _bandLegend(String label, int n, Color c) => Row(
        children: [
          Container(width: 7, height: 7,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption
                    .copyWith(color: PanelPalette.textSecondary)),
          ),
          Text('$n',
              style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w800,
                  color: PanelPalette.onBackground)),
        ],
      );

  /// Direct routes into the three detail screens. These used to be buried below
  /// the HMIS indicator grid on the analytics tab, which meant a CMHO had to
  /// already know they existed to find them.
  Widget _quickLinks() => Row(
        children: [
          _link(Icons.medication_liquid_rounded, 'ওষুধ ও\nপ্রস্তুতি',
              AppRoutes.readinessSummary, AppColors.emergencyRed),
          const SizedBox(width: 10),
          _link(Icons.health_and_safety_rounded, 'স্বাস্থ্য\nকর্মসূচি',
              AppRoutes.adminProgrammes, PanelPalette.primary),
          const SizedBox(width: 10),
          _link(Icons.apartment_rounded, 'জেলা\nপরিচালনা',
              AppRoutes.adminOperations, AppColors.sky),
        ],
      );

  Widget _link(IconData icon, String label, String route, Color col) => Expanded(
        child: Material(
          color: AppColors.surface,
          borderRadius: AppRadius.lgR,
          child: InkWell(
            borderRadius: AppRadius.lgR,
            onTap: () => Get.toNamed(route),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              decoration: BoxDecoration(
                borderRadius: AppRadius.lgR,
                boxShadow: AppShadows.low,
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: col.withValues(alpha: 0.10),
                      borderRadius: AppRadius.mdR,
                    ),
                    child: Icon(icon, size: 19, color: col),
                  ),
                  const SizedBox(height: 7),
                  Text(label,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.w700,
                          color: PanelPalette.onBackground)),
                ],
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<AdminController>();
    final auth = Get.find<AuthController>();

    return Container(
      decoration: BoxDecoration(gradient: PanelPalette.background),
      child: SafeArea(
        child: RefreshIndicator(
          color: PanelPalette.primary,
          onRefresh: () async {
            await ctrl.loadStats();
            await ctrl.loadReports();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────────
                Row(
                  children: [
                    Obx(() => UserAvatar(
                          user: auth.user.value,
                          size: 44,
                          backgroundColor: PanelPalette.primary.withValues(alpha: 0.12),
                          textColor: PanelPalette.primary,
                        )),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Obx(() => Text(
                                '${auth.user.value?.roleShort ?? 'ANM'} প্যানেল',
                                style: AppTextStyles.h3,
                              )),
                          Obx(() => Text(
                                auth.user.value?.name ?? 'Admin',
                                style: AppTextStyles.caption,
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // ── Hero ─────────────────────────────────────────
                // The mockup's focal band, carrying the one number that is both
                // real and actionable. It reads from the SAME list the queue
                // below renders, so the two can never disagree.
                _hero(),
                const SizedBox(height: 20),

                // ── What needs a decision today ──────────────────
                // This LEADS. The dashboard used to open on four totals and a
                // sparkline while every escalation lived one tab over — an
                // officer with ninety seconds between meetings should not have
                // to go looking for the thing that is on fire.
                const ActionQueue(),
                const SizedBox(height: 20),

                // ── Straight into the detail screens ─────────────
                _quickLinks(),
                const SizedBox(height: 24),

                // ── The asymmetric stat block ────────────────────
                // The mockup's shape: two narrow cards stacked on the left, the
                // risk donut filling the right. IntrinsicHeight so both columns
                // match whichever is taller — that holds when the system font is
                // scaled up and the Bengali labels grow, where fixed heights
                // would clip.
                Obx(() => IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 47,
                            child: Column(
                              children: [
                                Expanded(
                                  child: MiniStat(
                                    label: 'মোট ASHA',
                                    value: ctrl.totalWorkers.value,
                                    icon: Icons.people_alt_rounded,
                                    accent: PanelPalette.primary,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Expanded(
                                  child: MiniStat(
                                    label: 'মোট রোগী',
                                    value: ctrl.totalPatients.value,
                                    icon: Icons.groups_rounded,
                                    accent: AppColors.sky,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(flex: 53, child: _riskCard(ctrl)),
                        ],
                      ),
                    )),
                const SizedBox(height: 10),
                Obx(() => Row(
                      children: [
                        Expanded(
                          child: MiniStat(
                            label: 'মোট রিপোর্ট',
                            value: ctrl.totalReports.value,
                            icon: Icons.analytics_rounded,
                            accent: AppColors.purple,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: MiniStat(
                            label: 'জরুরি (RED)',
                            value: ctrl.redReports.value,
                            icon: Icons.gpp_bad_rounded,
                            accent: AppColors.emergencyRed,
                          ),
                        ),
                      ],
                    )),
                const SizedBox(height: 28),

                // ── Analytics — the server scopes these numbers to this
                // supervisor's own subtree, so a CMHO sees the district curve
                // and an ANM sees only her ASHAs. ─────────────────
                Obx(() {
                  final trend = ctrl.reportsTrend(days: 14);
                  final last14 = trend.fold(0, (a, b) => a + b);
                  final red = ctrl.redReports.value;
                  final yellow = ctrl.yellowReports.value;
                  final green = ctrl.greenReports.value;
                  return Container(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppRadius.xxlR,
                      boxShadow: AppShadows.low,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('রিপোর্টের ধারা',
                                      style: AppTextStyles.label),
                                  const SizedBox(height: 2),
                                  Text('গত ১৪ দিনে $last14 টি',
                                      style: AppTextStyles.caption),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: PanelPalette.primary.withValues(alpha: 0.08),
                                borderRadius: AppRadius.smR,
                              ),
                              child: Text('১৪ দিন',
                                  style: AppTextStyles.overline
                                      .copyWith(color: PanelPalette.primary)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TrendAreaChart(values: trend, color: AppColors.purple),
                        const SizedBox(height: 18),
                        const Divider(height: 1),
                        const SizedBox(height: 16),
                        Text('ঝুঁকির ভাগ', style: AppTextStyles.label),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            BandDonut(
                                red: red,
                                yellow: yellow,
                                green: green,
                                size: 116),
                            const SizedBox(width: 18),
                            Expanded(
                              child: BandLegend(
                                  red: red, yellow: yellow, green: green),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 28),

                // ── Recent reports ───────────────────────────────
                SectionHead(
                  title: 'admin_recent_reports'.tr,
                  actionLabel: 'সব দেখুন',
                  onAction: () => ctrl.goToTab(3),
                ),
                const SizedBox(height: 12),
                Obx(() {
                  if (ctrl.isLoading.value) {
                    // A Column (not SkeletonList) — this sits inside a scrolling
                    // Column, where a nested ListView would be unbounded.
                    return Column(
                      children: List.generate(
                        3,
                        (_) => const Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: SkeletonReportCard(),
                        ),
                      ),
                    );
                  }
                  if (ctrl.reports.isEmpty) {
                    return EmptyState(
                      icon: Icons.inbox_rounded,
                      title: 'admin_no_reports'.tr,
                      subtitle: 'নতুন চেকআপ হলে এখানে দেখা যাবে',
                    );
                  }
                  final recent = ctrl.reports.take(5).toList();
                  // One card holding rows, rather than five separate cards. With
                  // a caseload that is three-quarters RED, five full red-striped
                  // cards becomes a wall of alarm — and a wall of alarm gets read
                  // as wallpaper. The band survives as a dot.
                  return Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppRadius.xlR,
                      boxShadow: AppShadows.low,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: List.generate(recent.length, (i) {
                        final r = recent[i];
                        final band = (r['finalBand'] ?? '').toString();
                        final when = DateTime.tryParse(
                            (r['createdAt'] ?? '').toString());
                        return RevealIn(
                          index: i,
                          offsetY: 6,
                          child: DocRow(
                            title: (r['caseLabel'] ?? r['caseType'] ?? '—')
                                .toString(),
                            subtitle: (r['patientName'] ?? '—').toString(),
                            trailing: when == null
                                ? ''
                                : DateFormat('d MMM, HH:mm').format(when),
                            band: switch (band) {
                              'RED' => AppColors.emergencyRed,
                              'YELLOW' => AppColors.warningYellow,
                              'GREEN' => AppColors.safeGreen,
                              // An unbanded report is unknown, not safe.
                              _ => PanelPalette.textLight,
                            },
                            icon: Icons.description_outlined,
                            last: i == recent.length - 1,
                          ),
                        );
                      }),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

