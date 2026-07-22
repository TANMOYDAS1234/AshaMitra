import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../auth/controller/auth_controller.dart';
import '../../../admin/controller/admin_controller.dart';
import '../../../readiness/controller/readiness_controller.dart';
import '../../controller/programmes_controller.dart';
import '../../controller/operations_controller.dart';
import '../widgets/district_charts.dart';
import '../../../../app/routes.dart';
import '../../services/district_report_pdf.dart';

/// The district dashboard — what a CMHO (and a BMHO, for their block) actually
/// manages on.
///
/// Ordering is deliberate: **escalations first**. A CMHO opens this to find out
/// what is on fire — a maternal death, a referral that never reached a facility,
/// a vaccine stockout, an ASHA who has gone quiet — not to admire coverage
/// percentages. Indicators and block ranking come after.
///
/// Every percentage follows MoHFW's HMIS formula and may be null when there is
/// no denominator; those render "—", never a confident, wrong 0%.
class AdminDistrictTab extends StatefulWidget {
  const AdminDistrictTab({super.key});

  @override
  State<AdminDistrictTab> createState() => _AdminDistrictTabState();
}

class _AdminDistrictTabState extends State<AdminDistrictTab> {
  int _months = 12;

  /// Supply/equipment readiness. Kept as its own controller and its own request:
  /// the district route is already heavy, and this answers a different question
  /// ("is the kit there NOW") from every indicator on this screen ("what did the
  /// numbers do last quarter").
  final _readiness = Get.put(ReadinessController(), tag: 'readiness');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.find<AdminController>().loadDistrict(months: _months);
      _readiness.loadSummary();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<AdminController>();
    final me = Get.find<AuthController>().user.value;
    final role = me?.roleShort ?? 'ANM';
    // The level directly below this officer — who they are accountable for.
    final child = me?.manages ?? 'ASHA';
    // A CMHO reads this as the district; a BMHO as their block.
    final scope = switch (role) {
      'CMHO' => 'জেলা',
      'BMHO' => 'ব্লক',
      _ => 'এলাকা',
    };

    return Container(
      decoration: const BoxDecoration(gradient: AppGradients.background),
      child: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => ctrl.loadDistrict(months: _months),
          child: Obx(() {
            if (ctrl.isLoadingDistrict.value && ctrl.district.value == null) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                children: const [
                  SkeletonBox(width: 200, height: 26),
                  SizedBox(height: 20),
                  SkeletonBox(width: double.infinity, height: 96),
                  SizedBox(height: 12),
                  SkeletonBox(width: double.infinity, height: 180),
                  SizedBox(height: 12),
                  SkeletonBox(width: double.infinity, height: 160),
                ],
              );
            }
            if (ctrl.district.value == null) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  EmptyState(
                    icon: Icons.insights_rounded,
                    title: '$scope বিশ্লেষণ পাওয়া যায়নি',
                    subtitle: 'ইন্টারনেট দেখে আবার টানুন',
                    action: FilledButton.icon(
                      onPressed: () => ctrl.loadDistrict(months: _months),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('আবার দেখুন'),
                    ),
                  ),
                ],
              );
            }

            final ind = ctrl.dIndicators;
            final blocks = ctrl.dBlocks;
            final team = ctrl.dTeam;

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              children: [
                _header(scope, role, ctrl),
                const SizedBox(height: 18),

                // ── 1. ESCALATIONS — what needs the CMHO today ────────────
                _alerts(ctrl),

                // ── 2. HMIS key indicators ───────────────────────────────
                const SizedBox(height: 22),
                _sectionTitle('HMIS মূল সূচক', 'সরকারি HMIS ফর্মুলা অনুযায়ী'),
                const SizedBox(height: 12),
                _indicatorGrid(ind, ctrl.dPrev),

                // ── 2a. Direction, not level ─────────────────────────────
                // The tiles above are a snapshot. These answer the question a
                // snapshot cannot: is it getting worse, and since when.
                if (ctrl.dTrendMonths.length > 1) ...[
                  const SizedBox(height: 22),
                  _trendSection(ctrl),
                ],
                if (ctrl.dBenchmarks.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  _benchmarkSection(ctrl, ind),
                ],

                // ── 2b. The rest of the job ──────────────────────────────
                // Everything above is RCH. A CMHO also runs NTEP, NCD, family
                // planning and civil registration — roughly six sevenths of her
                // actual remit was missing from this screen.
                const SizedBox(height: 22),
                _programmesEntry(),
                const SizedBox(height: 10),
                _operationsEntry(),

                // ── 3. Accountability: rank the level directly below me ──
                // This is what makes the BMHO and ANM panels real. A BMHO's
                // whole subtree IS one block, so a block table tells him
                // nothing — he needs his ANMs ranked; an ANM needs her ASHAs.
                if (team.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _sectionTitle('$child অনুযায়ী পারফরম্যান্স',
                      'কে পিছিয়ে আছে — সেটাই এখানে দেখা যায়'),
                  const SizedBox(height: 12),
                  _rankTable(team, labelKey: 'name'),
                ],

                // ── 4. Geographic view — only a CMHO manages on this axis.
                if (blocks.length > 1) ...[
                  const SizedBox(height: 24),
                  _sectionTitle('ব্লক অনুযায়ী পারফরম্যান্স',
                      'ভৌগোলিক ভাগ — জেলা → ব্লক'),
                  const SizedBox(height: 12),
                  _rankTable(blocks, labelKey: 'block'),
                ],
              ],
            );
          }),
        ),
      ),
    );
  }

  // ── Monthly HMIS review report ─────────────────────────────────────────
  // The review meeting is the ritual that structures a district officer's
  // month, and it runs off HMIS numbers — so the export prints exactly what
  // this tab shows, same formulas, same denominators.
  Future<void> _exportPdf(
      AdminController ctrl, String role, String scope) async {
    final u = Get.find<AuthController>().user.value;
    Get.snackbar('রিপোর্ট তৈরি হচ্ছে', 'একটু অপেক্ষা করুন…',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        borderRadius: 12);
    try {
      await DistrictReportPdf.generate(
        indicators: ctrl.dIndicators,
        blocks: ctrl.dBlocks,
        alerts: ctrl.dAlerts,
        role: role,
        scope: scope,
        officer: u?.name ?? '',
        district: u?.district ?? '',
        months: _months,
      );
    } catch (e) {
      Get.snackbar('রিপোর্ট তৈরি ব্যর্থ', e.toString(),
          backgroundColor: AppColors.emergencyRed,
          colorText: AppColors.onPrimary,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16),
          borderRadius: 12);
    }
  }

  // ── Header + period selector ───────────────────────────────────────────
  Widget _header(String scope, String role, AdminController ctrl) => Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$scope বিশ্লেষণ', style: AppTextStyles.h2),
                const SizedBox(height: 2),
                Text('$role · গত $_months মাস', style: AppTextStyles.caption),
              ],
            ),
          ),
          // Monthly HMIS review report — carried into the review meeting.
          IconButton(
            onPressed: () => _exportPdf(ctrl, role, scope),
            tooltip: 'HMIS পর্যালোচনা রিপোর্ট (PDF)',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primary.withValues(alpha: 0.10),
              padding: const EdgeInsets.all(9),
            ),
            icon: const Icon(Icons.picture_as_pdf_rounded,
                color: AppColors.primary, size: 19),
          ),
          const SizedBox(width: 8),
          // Period switcher — a CMHO reviews monthly, but reads trends yearly.
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.mdR,
              boxShadow: AppShadows.low,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [3, 12].map((m) {
                final on = _months == m;
                return GestureDetector(
                  onTap: () {
                    setState(() => _months = m);
                    ctrl.loadDistrict(months: m);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: on ? AppColors.primary : Colors.transparent,
                      borderRadius: AppRadius.mdR,
                    ),
                    child: Text('$m মাস',
                        style: AppTextStyles.overline.copyWith(
                          color: on
                              ? AppColors.onPrimary
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        )),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      );

  /// Month-by-month activity. The indicator tiles are a snapshot; this answers
  /// the question a snapshot never can — is it getting worse, and since when.
  ///
  /// Reports and RED are overlaid on one chart deliberately: the ratio between
  /// them is the thing worth seeing, and putting them on separate charts makes
  /// the reader compute it.
  Widget _trendSection(AdminController ctrl) {
    final months = ctrl.dTrendMonths;
    final reports = ctrl.dSeries('reports');
    final red = ctrl.dSeries('redReports');
    final imm = ctrl.dSeries('immunization');
    final preg = ctrl.dSeries('pregnancies');

    // A district that has stopped reporting is the single most important thing
    // on this screen, and a chart alone will not say it out loud.
    final lastIdx = reports.length - 1;
    final quietNow = lastIdx >= 0 && reports[lastIdx] == 0;
    final everActive = reports.any((v) => v > 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('মাসে মাসে কাজ', 'কোন মাসে কী হয়েছে — নিচে নামছে কি না'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.xlR,
            boxShadow: AppShadows.low,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('রিপোর্ট ও জরুরি (RED)',
                        style: AppTextStyles.label),
                  ),
                  _legendDot(AppColors.primary.withValues(alpha: 0.30), 'মোট'),
                  const SizedBox(width: 10),
                  _legendDot(AppColors.emergencyRed, 'RED'),
                ],
              ),
              const SizedBox(height: 10),
              MonthlySeriesChart(
                  months: months, primary: reports, secondary: red),
              if (quietNow && everActive) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.trending_down_rounded,
                        size: 16, color: AppColors.emergencyRed),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'এই মাসে এখনও কোনও রিপোর্ট আসেনি — কর্মীদের সঙ্গে কথা বলুন',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.emergencyRed),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              Text('টিকা দেওয়া হয়েছে', style: AppTextStyles.label),
              const SizedBox(height: 10),
              MonthlySeriesChart(
                  months: months, primary: imm,
                  primaryColor: AppColors.sky, height: 96),
              const SizedBox(height: 18),
              Text('নতুন প্রসূতি নথিভুক্ত', style: AppTextStyles.label),
              const SizedBox(height: 10),
              MonthlySeriesChart(
                  months: months, primary: preg,
                  primaryColor: AppColors.purple, height: 96),
            ],
          ),
        ),
      ],
    );
  }

  Widget _legendDot(Color c, String t) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10,
              decoration: BoxDecoration(
                  color: c, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 4),
          Text(t,
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary)),
        ],
      );

  /// Indicators against their reference levels, worst gap first.
  ///
  /// This is what a CMHO is actually asked in a state review — not "what is
  /// immunization" but "why is it 79 points below reference". Sorting by gap
  /// puts the answer to the first question she'll be asked at the top.
  Widget _benchmarkSection(AdminController ctrl, Map<String, dynamic> ind) {
    const labels = {
      'immunizationCoveragePct': 'টিকা কভারেজ',
      'institutionalDeliveryPct': 'প্রাতিষ্ঠানিক প্রসব',
      'ancFirstTrimesterPct': '১ম ত্রৈমাসিকে ANC',
      'anc4PlusPct': '8+ ANC ভিজিট',
      'sbaAttendedPct': 'দক্ষ হাতে প্রসব (SBA)',
      'lbwPct': 'কম ওজনের শিশু',
      'referralClosurePct': 'রেফারেল সম্পন্ন',
      'cSectionPct': 'সিজার',
    };
    final bm = ctrl.dBenchmarks;

    num? gapOf(String k) {
      final b = Map<String, dynamic>.from(bm[k] as Map);
      final v = ind[k] as num?;
      if (v == null) return null; // unmeasured sorts last, not worst
      final dir = b['dir']?.toString() ?? 'up';
      if (dir == 'range') {
        final lo = (b['min'] as num?) ?? 0, hi = (b['max'] as num?) ?? 100;
        return v < lo ? lo - v : (v > hi ? v - hi : 0);
      }
      final t = (b['target'] as num?) ?? 0;
      return dir == 'down' ? v - t : t - v;
    }

    final keys = bm.keys.where(labels.containsKey).toList()
      ..sort((a, b) {
        final ga = gapOf(a), gb = gapOf(b);
        if (ga == null && gb == null) return 0;
        if (ga == null) return 1;   // unmeasured to the bottom
        if (gb == null) return -1;
        return gb.compareTo(ga);    // biggest shortfall first
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('লক্ষ্যের তুলনায়', 'সবচেয়ে বেশি পিছিয়ে যেটা — সেটা আগে'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.xlR,
            boxShadow: AppShadows.low,
          ),
          child: Column(
            children: keys.map((k) {
              final b = Map<String, dynamic>.from(bm[k] as Map);
              return BenchmarkBar(
                label: labels[k]!,
                value: ind[k] as num?,
                target: b['target'] as num?,
                min: b['min'] as num?,
                max: b['max'] as num?,
                dir: b['dir']?.toString() ?? 'up',
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  /// Entry to the National Health Programmes screen.
  ///
  /// Shows the live count of people needing action across NTEP, NCD, family
  /// planning and CRS — so it is a signal, not just a link. Loads lazily: the
  /// district tab must not wait on a second request to paint.
  Widget _programmesEntry() {
    final p = Get.put(ProgrammesController(), tag: 'programmes');
    if (p.programmes.isEmpty && !p.loading.value) p.load();
    return Obx(() {
      final urgent = p.totalUrgent;
      final tone = urgent > 0 ? AppColors.emergencyRed : AppColors.primary;
      return Material(
        color: AppColors.surface,
        borderRadius: AppRadius.xlR,
        child: InkWell(
          borderRadius: AppRadius.xlR,
          onTap: () => Get.toNamed(AppRoutes.adminProgrammes),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: AppRadius.xlR,
              boxShadow: AppShadows.low,
              border: Border.all(color: tone.withValues(alpha: 0.22)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: 0.10),
                    borderRadius: AppRadius.mdR,
                  ),
                  child: Icon(Icons.health_and_safety_rounded,
                      size: 20, color: tone),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('স্বাস্থ্য কর্মসূচি', style: AppTextStyles.h3),
                      const SizedBox(height: 2),
                      Text(
                        p.loading.value
                            ? 'দেখা হচ্ছে…'
                            : urgent > 0
                                ? '$urgent জনের জন্য এখনই ব্যবস্থা দরকার'
                                : 'যক্ষ্মা · NCD · পরিবার পরিকল্পনা · জন্ম-মৃত্যু নিবন্ধন',
                        style: AppTextStyles.caption.copyWith(
                            color: urgent > 0 ? tone : AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (urgent > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: tone, borderRadius: AppRadius.smR),
                    child: Text('$urgent',
                        style: AppTextStyles.caption.copyWith(
                            color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      );
    });
  }

  /// Entry to District Operations — the administrative half of the job:
  /// disease clusters, outbreaks, cold chain, facilities, staffing, QA,
  /// training, meetings, budget.
  ///
  /// Loads lazily and shows a live count, so the badge tells her whether it is
  /// worth opening before she taps.
  Widget _operationsEntry() {
    final o = Get.put(OperationsController(), tag: 'operations');
    if (o.data.isEmpty && !o.loading.value) o.loadAll();
    return Obx(() {
      final urgent = o.urgentCount;
      final tone = urgent > 0 ? AppColors.emergencyRed : AppColors.primary;
      final clusters = o.clusters.length;
      return Material(
        color: AppColors.surface,
        borderRadius: AppRadius.xlR,
        child: InkWell(
          borderRadius: AppRadius.xlR,
          onTap: () => Get.toNamed(AppRoutes.adminOperations),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: AppRadius.xlR,
              boxShadow: AppShadows.low,
              border: Border.all(color: tone.withValues(alpha: 0.22)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: 0.10),
                    borderRadius: AppRadius.mdR,
                  ),
                  child: Icon(Icons.apartment_rounded, size: 20, color: tone),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('জেলা পরিচালনা', style: AppTextStyles.h3),
                      const SizedBox(height: 2),
                      Text(
                        o.loading.value
                            ? 'দেখা হচ্ছে…'
                            // A disease cluster outranks everything else on this
                            // card — it is the only item that can still be
                            // stopped from becoming an outbreak.
                            : clusters > 0
                                ? '$clusters টি গ্রামে রোগ বাড়ছে — এখনই দেখুন'
                                : urgent > 0
                                    ? '$urgent টি বিষয়ে ব্যবস্থা দরকার'
                                    : 'কেন্দ্র · কোল্ড চেইন · কর্মী · পরিদর্শন · সভা',
                        style: AppTextStyles.caption.copyWith(
                            color: urgent > 0 ? tone : AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (urgent > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: tone, borderRadius: AppRadius.smR),
                    child: Text('$urgent',
                        style: AppTextStyles.caption.copyWith(
                            color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _sectionTitle(String t, String sub) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t, style: AppTextStyles.label),
          const SizedBox(height: 2),
          Text(sub, style: AppTextStyles.caption),
        ],
      );

  // ── Escalations ────────────────────────────────────────────────────────
  /// Missing life-saving supplies, above every indicator on this screen.
  ///
  /// The rest of the dashboard is a report card: it tells a CMHO how last quarter
  /// went. This tells her what to fix before tonight. A sub-centre with no MgSO4
  /// is a woman who will fit and not be treated — and it's a problem she can
  /// actually solve in a day, which is more than can be said for a coverage rate.
  Widget _readinessAlert() => Obx(() {
        final gaps = _readiness.critical;
        final unknown = _readiness.unknownCount;

        // Always rendered, even when everything is fine — otherwise a district in
        // good shape has no way into the supply screen at all, and the CMHO can
        // never go LOOK. An all-clear is a state worth showing, not a reason to
        // disappear.
        final Color tone = gaps.isNotEmpty
            ? AppColors.emergencyRed
            : unknown > 0
                ? AppColors.warning
                : AppColors.safeGreen;

        final worst = gaps.take(3).toList();
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: tone.withValues(alpha: 0.05),
            borderRadius: AppRadius.xlR,
            child: InkWell(
              borderRadius: AppRadius.xlR,
              onTap: () => Get.toNamed(AppRoutes.readinessSummary),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: AppRadius.xlR,
                  border: Border.all(color: tone.withValues(alpha: 0.28)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          gaps.isNotEmpty
                              ? Icons.medication_liquid_rounded
                              : unknown > 0
                                  ? Icons.help_outline_rounded
                                  : Icons.verified_rounded,
                          size: 20,
                          color: tone,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            gaps.isNotEmpty
                                ? 'প্রাণরক্ষাকারী ওষুধ/যন্ত্র নেই (${_readiness.criticalCount})'
                                : unknown > 0
                                    ? 'ওষুধ-যন্ত্রের খবর নেই ($unknown)'
                                    : 'ওষুধ ও যন্ত্রপাতি — সব ঠিক আছে',
                            style: AppTextStyles.label.copyWith(
                              color: tone,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: AppColors.textSecondary),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...worst.map((g) => Padding(
                          padding: const EdgeInsets.only(left: 28, top: 2),
                          child: Text(
                            '${g.label} — ${g.count} জায়গায় নেই'
                            '${g.places.isNotEmpty ? ' (${g.places.first.block})' : ''}',
                            style: AppTextStyles.bodySm
                                .copyWith(color: AppColors.onBackground),
                          ),
                        )),
                    // Silence is not safety. A sub-centre that never reports is
                    // exactly as dangerous as one reporting a stockout — and far
                    // easier to overlook — so it is stated, never omitted.
                    if (unknown > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 28, top: 4),
                        child: Text(
                          '$unknown জন কোনও খবর দেয়নি — "খবর নেই" মানে "ঠিক আছে" নয়',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      });

  Widget _alerts(AdminController ctrl) {
    final maternal = ctrl.dAlert('maternalDeaths');
    final infant = ctrl.dAlert('infantDeaths');
    final referrals = ctrl.dAlert('overdueReferrals');
    final stock = ctrl.dAlert('stockouts');
    final silent = ctrl.dAlert('silentAshas');

    if (ctrl.dAlertCount == 0) {
      return Obx(() {
        // Even with every clinical indicator clean, a missing MgSO4 means this
        // district is NOT "সব ঠিক আছে". The all-clear must not outrank an empty
        // drug shelf.
        final quiet = _readiness.critical.isEmpty && _readiness.unknownCount == 0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _readinessAlert(),
            if (quiet)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.safeGreen.withValues(alpha: 0.08),
                  borderRadius: AppRadius.xlR,
                  border: Border.all(
                      color: AppColors.safeGreen.withValues(alpha: 0.30)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_rounded,
                        color: AppColors.safeGreen, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('কোনো জরুরি বিষয় নেই — সব ঠিক আছে',
                          style: AppTextStyles.label
                              .copyWith(color: AppColors.safeGreen)),
                    ),
                  ],
                ),
              ),
          ],
        );
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.priority_high_rounded,
                size: 18, color: AppColors.emergencyRed),
            const SizedBox(width: 6),
            Text('জরুরি — এখনই দেখুন (${ctrl.dAlertCount})',
                style: AppTextStyles.label
                    .copyWith(color: AppColors.emergencyRed)),
          ],
        ),
        const SizedBox(height: 10),

        // Supplies lead. Every other card here reports something that has already
        // gone wrong; this one names something still preventable.
        _readinessAlert(),

        // Maternal death is the single hardest escalation a CMHO faces —
        // it triggers a formal death review (MDSR). It always leads.
        if (maternal.isNotEmpty)
          _alertCard(
            color: AppColors.emergencyRed,
            icon: Icons.female_rounded,
            title: '${maternal.length} টি মাতৃমৃত্যু',
            subtitle: 'ডেথ রিভিউ (MDSR) দরকার',
            lines: maternal
                .map((m) =>
                    '${m['name']} · ${m['block']}${(m['cause'] ?? '').toString().isNotEmpty ? ' · ${m['cause']}' : ''}')
                .toList(),
          ),
        if (infant.isNotEmpty)
          _alertCard(
            color: AppColors.emergencyRed,
            icon: Icons.child_care_rounded,
            title: '${infant.length} টি শিশুমৃত্যু',
            subtitle: 'শিশু ডেথ রিভিউ (CDR) দরকার',
            lines: infant
                .map((m) => '${m['name']} · ${m['block']} · ${m['age'] ?? ''}')
                .toList(),
          ),
        if (referrals.isNotEmpty)
          _alertCard(
            color: AppColors.warningYellow,
            icon: Icons.local_hospital_rounded,
            title: '${referrals.length} টি রেফারেল হাসপাতালে পৌঁছয়নি',
            subtitle: '৭ দিনের বেশি বাকি',
            lines: referrals
                .take(5)
                .map((r) =>
                    '${r['patientName']} · ${r['block']} · ${r['days']} দিন')
                .toList(),
          ),
        if (stock.isNotEmpty)
          _alertCard(
            color: AppColors.warningYellow,
            icon: Icons.inventory_2_rounded,
            title: '${stock.length} টি ওষুধ শেষের পথে',
            subtitle: 'স্টক পাঠাতে হবে',
            lines: stock
                .take(5)
                .map((s) =>
                    '${s['medicine']} · ${s['left']} বাকি · ${s['block']}')
                .toList(),
          ),
        if (silent.isNotEmpty)
          _alertCard(
            color: AppColors.sky,
            icon: Icons.person_off_rounded,
            title: '${silent.length} জন ASHA ৩০ দিন নিষ্ক্রিয়',
            subtitle: 'কোনো ভিজিট রেকর্ড হয়নি (zero-reporting)',
            lines: silent
                .take(5)
                .map((s) => '${s['name']} · ${s['block']}')
                .toList(),
          ),
      ],
    );
  }

  Widget _alertCard({
    required Color color,
    required IconData icon,
    required String title,
    required String subtitle,
    required List<String> lines,
  }) =>
      Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: AppRadius.xlR,
          border: Border.all(color: color.withValues(alpha: 0.30)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: AppTextStyles.label.copyWith(color: color)),
                      Text(subtitle, style: AppTextStyles.caption),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...lines.map((l) => Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 5, right: 6),
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.6),
                              shape: BoxShape.circle),
                        ),
                      ),
                      Expanded(
                          child: Text(l,
                              style: AppTextStyles.caption
                                  .copyWith(fontWeight: FontWeight.w600))),
                    ],
                  ),
                )),
          ],
        ),
      );

  // ── HMIS indicators ────────────────────────────────────────────────────
  Widget _indicatorGrid(Map<String, dynamic> i, Map<String, dynamic> prev) {
    // A null percentage means "no denominator" — show "—", never 0%.
    String p(String k) {
      final v = i[k];
      return v == null ? '—' : '${(v as num).toStringAsFixed(1)}%';
    }

    String n(String k) => '${(i[k] as num?)?.toInt() ?? 0}';

    // This window minus the one before it. Null when either side is missing, so
    // a tile with no baseline shows no arrow rather than inventing one.
    double? d(String k) {
      final a = i[k], b = prev[k];
      if (a is! num || b is! num) return null;
      return (a - b).toDouble();
    }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.32,
      children: [
        _kpiTile('প্রসূতি নথিভুক্ত', n('pregnanciesRegistered'),
            Icons.pregnant_woman_rounded, AppColors.primary,
            delta: d('pregnanciesRegistered'), polarity: 1),
        _kpiTile('১ম ত্রৈমাসিকে ANC', p('ancFirstTrimesterPct'),
            Icons.event_available_rounded, AppColors.sky,
            delta: d('ancFirstTrimesterPct'), polarity: 1),
        _kpiTile('৪+ ANC ভিজিট', p('anc4PlusPct'), Icons.checklist_rounded,
            AppColors.purple,
            delta: d('anc4PlusPct'), polarity: 1),
        // Finding MORE high-risk women can mean better screening OR worse
        // outcomes. The direction alone cannot tell you which, so it gets no
        // good/bad verdict — only the movement.
        _kpiTile('উচ্চ ঝুঁকি প্রসূতি', n('highRiskPregnancies'),
            Icons.warning_amber_rounded, AppColors.warningYellow,
            delta: d('highRiskPregnancies'), polarity: 0),
        _kpiTile('প্রাতিষ্ঠানিক প্রসব', p('institutionalDeliveryPct'),
            Icons.local_hospital_rounded, AppColors.safeGreen,
            delta: d('institutionalDeliveryPct'), polarity: 1),
        // C-section: too high signals overuse, too low signals unmet need.
        // Neither direction is simply "good" — colouring it would be a lie.
        _kpiTile('সিজার', p('cSectionPct'), Icons.medical_services_rounded,
            AppColors.sky,
            delta: d('cSectionPct'), polarity: 0),
        _kpiTile('কম ওজনের শিশু (<২.৫ কেজি)', p('lbwPct'),
            Icons.monitor_weight_rounded, AppColors.emergencyRed,
            delta: d('lbwPct'), polarity: -1), // rising = worse
        _kpiTile('টিকা কভারেজ', p('immunizationCoveragePct'),
            Icons.vaccines_rounded, AppColors.safeGreen,
            delta: d('immunizationCoveragePct'), polarity: 1),
        // Not a windowed figure — it is who is overdue RIGHT NOW, so a
        // period-over-period arrow would be meaningless. Tap it for the names.
        _kpiTile('টিকা বাকি (Overdue)', n('immunizationDefaulters'),
            Icons.event_busy_rounded, AppColors.emergencyRed,
            onTap: _showDefaulters, badge: 'এখন'),
        _kpiTile('রেফারেল সম্পন্ন', p('referralClosurePct'),
            Icons.assignment_turned_in_rounded, AppColors.purple,
            delta: d('referralClosurePct'), polarity: 1),
      ],
    );
  }

  /// [polarity]: 1 = a rise is good, -1 = a rise is bad, 0 = show the direction
  /// but pass no judgement. The ARROW shows movement; the COLOUR is the verdict
  /// — so a climbing low-birth-weight rate can never render a reassuring green.
  Widget _kpiTile(String label, String value, IconData icon, Color color,
      {VoidCallback? onTap, double? delta, int polarity = 0, String? badge}) {
    // A hair's movement is not a trend — don't dress noise up as signal.
    final show = delta != null && delta.abs() >= 0.5;
    final rising = (delta ?? 0) >= 0;
    final verdict = polarity == 0
        ? AppColors.textSecondary
        : (rising == (polarity == 1)
            ? AppColors.safeGreen
            : AppColors.emergencyRed);

    final tile = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.xlR,
        boxShadow: AppShadows.tinted(color),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: AppRadius.smR),
                child: Icon(icon, color: color, size: 17),
              ),
              const Spacer(),
              // "এখন" marks a figure that is a snapshot of NOW, not of the
              // selected window — so nobody reads it as a 12-month trend.
              if (badge != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: AppColors.textSecondary.withValues(alpha: 0.10),
                      borderRadius: AppRadius.smR),
                  child: Text(badge,
                      style: AppTextStyles.overline.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700)),
                )
              else if (show)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                        rising
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 11,
                        color: verdict),
                    Text(delta.abs().toStringAsFixed(1),
                        style: AppTextStyles.overline.copyWith(
                            color: verdict, fontWeight: FontWeight.w700)),
                  ],
                ),
              // Affordance — otherwise nobody discovers the tile is drillable.
              if (onTap != null)
                Icon(Icons.chevron_right_rounded,
                    size: 16, color: color.withValues(alpha: 0.55)),
            ],
          ),
          const Spacer(),
          Text(value,
              style: AppTextStyles.h2.copyWith(
                  color: color, fontWeight: FontWeight.w800, height: 1.1)),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style:
                  AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );

    if (onTap == null) return tile;
    return Material(
      color: Colors.transparent,
      borderRadius: AppRadius.xlR,
      child: InkWell(
          borderRadius: AppRadius.xlR, onTap: onTap, child: tile),
    );
  }

  // ── Defaulter drill-down ───────────────────────────────────────────────
  // Grouped BY ASHA, worst first: an officer chases the ASHA, not the child, so
  // that is the shape the work actually takes. Within each ASHA, the
  // longest-overdue child leads.
  void _showDefaulters() {
    final ctrl = Get.find<AdminController>();
    final groups = ctrl.dDefaultersByAsha;
    final shown = ctrl.dDefaulters.length;
    final total = ctrl.dDefaultersTotal;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (sheetCtx, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.xxl)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2))),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                child: Row(
                  children: [
                    const Icon(Icons.event_busy_rounded,
                        color: AppColors.emergencyRed, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$total টি টিকা বাকি',
                              style: AppTextStyles.h3),
                          Text(
                            shown < total
                                ? '$total টির মধ্যে $shown টি দেখানো হচ্ছে · বেশি দেরি আগে'
                                : 'যত দিন দেরি, তত উপরে',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: groups.isEmpty
                    ? EmptyState(
                        icon: Icons.verified_rounded,
                        title: 'কোনো টিকা বাকি নেই',
                        subtitle: 'সব শিশুর টিকা সময়মতো হয়েছে',
                      )
                    : ListView(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                        children: groups.map((g) {
                          final asha = g.key;
                          final rows = [...g.value]..sort((a, b) =>
                              ((b['daysOverdue'] as num?)?.toInt() ?? 0)
                                  .compareTo((a['daysOverdue'] as num?)?.toInt() ??
                                      0));
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.person_rounded,
                                        size: 15, color: AppColors.primary),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(asha,
                                          style: AppTextStyles.label.copyWith(
                                              fontWeight: FontWeight.w700)),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.emergencyRed
                                            .withValues(alpha: 0.10),
                                        borderRadius: AppRadius.smR,
                                      ),
                                      child: Text('${rows.length} টি বাকি',
                                          style: AppTextStyles.overline.copyWith(
                                              color: AppColors.emergencyRed,
                                              fontWeight: FontWeight.w700)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ...rows.map((d) => Container(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 9),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: AppRadius.mdR,
                                        border: Border.all(
                                            color: AppColors.emergencyRed
                                                .withValues(alpha: 0.18)),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                    '${d['patientName']}',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: AppTextStyles.label),
                                                Text(
                                                    '${d['label']} · ${d['block']}',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style:
                                                        AppTextStyles.caption),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text('${d['daysOverdue']} দিন',
                                              style: AppTextStyles.label.copyWith(
                                                  color: AppColors.emergencyRed,
                                                  fontWeight: FontWeight.w700)),
                                        ],
                                      ),
                                    )),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Accountability ranking ─────────────────────────────────────────────
  // Used twice: to rank the people directly below (labelKey 'name') and, for a
  // CMHO, to rank blocks geographically (labelKey 'block'). Same indicators,
  // same thresholds — so a BMHO judges his ANMs exactly as he is judged.
  Widget _rankTable(List<Map<String, dynamic>> rows,
      {required String labelKey}) {
    // Rank by institutional-delivery % — the indicator officers are judged on.
    // Rows with no births yet sort LAST rather than masquerading as 0%.
    final ranked = [...rows]..sort((a, b) {
        final x = (a['institutionalPct'] as num?)?.toDouble();
        final y = (b['institutionalPct'] as num?)?.toDouble();
        if (x == null && y == null) return 0;
        if (x == null) return 1;
        if (y == null) return -1;
        return y.compareTo(x);
      });

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.xxlR,
        boxShadow: AppShadows.low,
      ),
      child: Column(
        children: ranked.map((b) {
          final inst = (b['institutionalPct'] as num?)?.toDouble();
          final imm = (b['immunizationPct'] as num?)?.toDouble();
          final deaths = ((b['maternalDeaths'] as num?)?.toInt() ?? 0) +
              ((b['infantDeaths'] as num?)?.toInt() ?? 0);
          final ashas = (b['ashas'] as num?)?.toInt() ?? 0;
          // "Underperforming" isn't a vibe — it's a threshold an officer can
          // defend: institutional delivery under 80%, or any death.
          final lagging = (inst != null && inst < 80) || deaths > 0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text('${b[labelKey]}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.label
                                    .copyWith(fontWeight: FontWeight.w700)),
                          ),
                          if (lagging) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.emergencyRed
                                    .withValues(alpha: 0.10),
                                borderRadius: AppRadius.smR,
                              ),
                              child: Text('পিছিয়ে',
                                  style: AppTextStyles.overline.copyWith(
                                      color: AppColors.emergencyRed,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Text(
                      inst == null ? '—' : '${inst.toStringAsFixed(0)}%',
                      style: AppTextStyles.label.copyWith(
                        color: lagging
                            ? AppColors.emergencyRed
                            : AppColors.safeGreen,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                // Bar = institutional delivery. Grey when there's no denominator.
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (inst ?? 0) / 100,
                    minHeight: 6,
                    backgroundColor:
                        AppColors.textSecondary.withValues(alpha: 0.10),
                    valueColor: AlwaysStoppedAnimation(
                      inst == null
                          ? AppColors.textSecondary.withValues(alpha: 0.25)
                          : (lagging
                              ? AppColors.emergencyRed
                              : AppColors.safeGreen),
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    // A team-size chip only makes sense for a supervisor row —
                    // an ASHA leaf would otherwise read "1 ASHA".
                    if (ashas > 1) ...[
                      _chip(Icons.people_alt_rounded, '$ashas ASHA'),
                      const SizedBox(width: 10),
                    ],
                    _chip(Icons.child_friendly_rounded,
                        '${(b['births'] as num?)?.toInt() ?? 0} জন্ম'),
                    const SizedBox(width: 10),
                    _chip(Icons.vaccines_rounded,
                        imm == null ? '—' : '${imm.toStringAsFixed(0)}% টিকা'),
                    const SizedBox(width: 10),
                    _chip(Icons.analytics_rounded,
                        '${(b['reports'] as num?)?.toInt() ?? 0} রিপোর্ট'),
                    if (deaths > 0) ...[
                      const SizedBox(width: 10),
                      _chip(Icons.gpp_bad_rounded, '$deaths মৃত্যু',
                          color: AppColors.emergencyRed),
                    ],
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _chip(IconData i, String t, {Color? color}) {
    final c = color ?? AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(i, size: 12, color: c.withValues(alpha: 0.85)),
        const SizedBox(width: 3),
        Text(t,
            style: AppTextStyles.overline
                .copyWith(color: c, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
