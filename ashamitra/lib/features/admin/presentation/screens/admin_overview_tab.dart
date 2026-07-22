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

                // ── Stats grid ───────────────────────────────────
                Obx(() {
                  final rTrend = ctrl.reportsTrend();
                  final redT = ctrl.bandTrend('RED');
                  final yelT = ctrl.bandTrend('YELLOW');
                  final grnT = ctrl.bandTrend('GREEN');
                  return GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.24, // room for the sparkline
                    children: [
                      _StatTile('admin_total_asha'.tr, '${ctrl.totalWorkers}',
                          Icons.people_alt_rounded, PanelPalette.primary),
                      _StatTile(
                          'admin_total_patients'.tr, '${ctrl.totalPatients}',
                          Icons.groups_rounded, AppColors.sky),
                      _StatTile('admin_total_reports'.tr, '${ctrl.totalReports}',
                          Icons.analytics_rounded, AppColors.purple,
                          spark: rTrend, delta: ctrl.trendDelta(rTrend)),
                      // More emergencies is BAD → inverse, so a rise shows red.
                      _StatTile('admin_emergency_red'.tr, '${ctrl.redReports}',
                          Icons.gpp_bad_rounded, AppColors.emergencyRed,
                          spark: redT,
                          delta: ctrl.trendDelta(redT),
                          inverse: true),
                      _StatTile(
                          'admin_warning_yellow'.tr, '${ctrl.yellowReports}',
                          Icons.warning_amber_rounded, AppColors.warningYellow,
                          spark: yelT,
                          delta: ctrl.trendDelta(yelT),
                          inverse: true),
                      _StatTile('admin_safe_green'.tr, '${ctrl.greenReports}',
                          Icons.check_circle_rounded, AppColors.safeGreen,
                          spark: grnT, delta: ctrl.trendDelta(grnT)),
                    ],
                  );
                }),
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
                Text('admin_recent_reports'.tr, style: AppTextStyles.label),
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
                  return Column(
                    children: recent
                        .map((r) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _RecentReportCard(r: r),
                            ))
                        .toList(),
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

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  /// Optional 14-day micro-trend drawn under the number.
  final List<int>? spark;

  /// Percent change (last 7 days vs the 7 before). Null = no baseline, so
  /// nothing is shown rather than a misleading figure.
  final double? delta;

  /// True when a RISE is bad (emergencies, referrals). The arrow always shows
  /// direction; the colour shows whether that direction is good — so a climbing
  /// RED count reads red, never a reassuring green.
  final bool inverse;

  const _StatTile(
    this.label,
    this.value,
    this.icon,
    this.color, {
    this.spark,
    this.delta,
    this.inverse = false,
  });

  @override
  Widget build(BuildContext context) {
    final d = delta;
    final rising = (d ?? 0) >= 0;
    final good = inverse ? !rising : rising;
    final deltaColor = good ? AppColors.safeGreen : AppColors.emergencyRed;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.xlR,
        boxShadow: AppShadows.tinted(color),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: AppRadius.smR),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
              if (d != null && d.abs() >= 1)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: deltaColor.withValues(alpha: 0.10),
                    borderRadius: AppRadius.smR,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                          rising
                              ? Icons.trending_up_rounded
                              : Icons.trending_down_rounded,
                          size: 11,
                          color: deltaColor),
                      const SizedBox(width: 2),
                      Text('${d.abs().round()}%',
                          style: AppTextStyles.overline.copyWith(
                              color: deltaColor, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
            ],
          ),
          const Spacer(),
          Text(value,
              style: AppTextStyles.h2.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                height: 1.1,
              )),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600)),
          if (spark != null && spark!.length > 1) ...[
            const SizedBox(height: 7),
            Sparkline(values: spark!, color: color),
          ],
        ],
      ),
    );
  }
}

class _RecentReportCard extends StatelessWidget {
  final Map<String, dynamic> r;
  const _RecentReportCard({required this.r});

  Color get _bandColor {
    final band = r['finalBand']?.toString().toUpperCase() ?? '';
    if (band == 'RED') return AppColors.emergencyRed;
    if (band == 'YELLOW') return AppColors.warningYellow;
    return AppColors.safeGreen;
  }

  @override
  Widget build(BuildContext context) {
    final color = _bandColor;
    final band = r['finalBand']?.toString().toUpperCase() ?? '-';
    final caseLabel = r['caseLabel']?.toString() ?? '';
    final patientName = r['patientName']?.toString() ?? '';
    String fmtDate = '';
    try {
      fmtDate = DateFormat('dd MMM, HH:mm')
          .format(DateTime.parse(r['createdAt']?.toString() ?? ''));
    } catch (_) {}

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgR,
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Center(
              child: Text(band.isNotEmpty ? band[0] : '?',
                  style: AppTextStyles.label.copyWith(color: color)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (caseLabel.isNotEmpty)
                  Text(caseLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.label),
                if (patientName.isNotEmpty)
                  Text(patientName, style: AppTextStyles.caption),
              ],
            ),
          ),
          Text(fmtDate, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}
