import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/services/case_detection_service.dart';
import '../../../../core/services/api_service.dart';
import '../../../../shared/components/bottom_nav.dart';
import '../../../referrals/controller/referral_controller.dart';
import '../../../patients/controller/patient_controller.dart';
import '../../../ncd_cbac/controller/ncd_cbac_controller.dart';
import '../../../tb_cases/controller/tb_case_controller.dart';
import '../../../medicine_stock/controller/medicine_stock_controller.dart';
import '../../../vital_events/controller/vital_event_controller.dart';
import '../widgets/greeting_header.dart';
import '../widgets/patient_context_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _svc = CaseDetectionService();
  int _dueCount = 0;

  /// The actual worklist — due/overdue visits, most urgent first.
  List<Map<String, dynamic>> _work = [];

  /// Honest activity, not vanity: visits completed in the last 7 days, and a
  /// run of consecutive days worked.
  int _weekVisits = 0;
  int _streak = 0;

  String _query = '';

  @override
  void initState() {
    super.initState();
    _svc.loadCases(); // pre-warm cache
    _loadDueCount();
    _loadActivity();
  }

  /// Count of UNIQUE patients with a due/overdue item (within 14 days) — the
  /// banner reads "X জন রোগীর", so it must count patients, not events (one
  /// patient with ANC + 2 vaccines due is one person, not three).
  /// Also builds the worklist, ordered by urgency.
  /// Best-effort: 0 when offline or logged out.
  Future<void> _loadDueCount() async {
    final due = await ApiService.getScheduleDue(withinDays: 14);
    final items = due
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final patients = items
        .map((e) => (e['patientId'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toSet();

    // Urgency = how many days past the clinical window. Overdue items sort
    // first (most overdue at the top), then items due now, then upcoming.
    final t0 = _today();
    int overdueBy(Map<String, dynamic> e) {
      final end = DateTime.tryParse((e['windowEnd'] ?? '').toString()) ??
          DateTime.tryParse((e['dueDate'] ?? '').toString());
      if (end == null) return -9999;
      return t0.difference(DateTime(end.year, end.month, end.day)).inDays;
    }

    items.sort((a, b) => overdueBy(b).compareTo(overdueBy(a)));

    if (mounted) {
      setState(() {
        _dueCount = patients.isNotEmpty ? patients.length : items.length;
        _work = items;
      });
    }
  }

  /// Streak + this week's visits, computed from her own completed visits.
  ///
  /// Deliberately forgiving: the streak is counted from YESTERDAY when nothing
  /// is done yet today, so simply opening the app in the morning cannot appear
  /// to "break" a run she hasn't had a chance to continue. It is only shown at
  /// 2+ days — a "1-day streak" is not an achievement, it's noise.
  Future<void> _loadActivity() async {
    try {
      final all = await ApiService.getAllSchedule();
      final done = all
          .whereType<Map>()
          .where((e) => (e['status'] ?? '') == 'done')
          .map((e) => DateTime.tryParse((e['doneDate'] ?? '').toString()))
          .whereType<DateTime>()
          .toList();

      final t0 = _today();
      final days = done.map((d) => DateTime(d.year, d.month, d.day)).toSet();

      final week = done.where((d) {
        final dd = DateTime(d.year, d.month, d.day);
        return !dd.isAfter(t0) && t0.difference(dd).inDays < 7;
      }).length;

      var cursor = days.contains(t0) ? t0 : t0.subtract(const Duration(days: 1));
      var streak = 0;
      while (days.contains(cursor)) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      }

      if (mounted) {
        setState(() {
          _weekVisits = week;
          _streak = streak;
        });
      }
    } catch (_) {
      // Offline — leave the strip empty rather than showing a wrong zero.
    }
  }

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  /// Polished "due reminders" banner — soft gradient card, circular glassy
  /// icon, count pill, gentle shadow.
  Widget _dueBanner() {
    final hasDue = _dueCount > 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () async {
            await Get.toNamed(AppRoutes.dueList);
            _loadDueCount(); // refresh after returning (items may be done)
          },
          child: Container(
            height: 160,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              boxShadow: AppShadows.tinted(AppColors.primary, strength: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Hero photo — kept visible on the right; the scrim fades so the
                  // ASHA image shows while the left text stays legible.
                  Image.asset('assets/images/hero_asha.png',
                      fit: BoxFit.cover,
                      alignment: Alignment.centerRight,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.96),
                          AppColors.primary.withValues(alpha: 0.84),
                          AppColors.accent.withValues(alpha: 0.38),
                        ],
                        stops: const [0.0, 0.55, 1.0],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('home_due_chip'.tr,
                              style: AppTextStyles.caption.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(height: 8),
                        Text('home_due_banner_title'.tr,
                            style: AppTextStyles.h2.copyWith(
                                color: Colors.white, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text('$_dueCount',
                                style: AppTextStyles.display.copyWith(
                                    color: Colors.white,
                                    fontSize: 34,
                                    fontWeight: FontWeight.w900,
                                    height: 1.0)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                hasDue
                                    ? 'home_due_people'.tr
                                    : 'home_due_banner_empty'.tr,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodySm.copyWith(
                                    color: Colors.white.withValues(alpha: 0.92)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 9),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Text('home_due_cta'.tr,
                                    style: AppTextStyles.label.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w800)),
                                const SizedBox(width: 4),
                                const Icon(Icons.arrow_forward_rounded,
                                    color: AppColors.primary, size: 16),
                              ]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Register generator entry — turns the app's schedule into the official
  /// monthly due-list register (PDF/CSV). Solves the #1 field pain: paperwork.
  /// Compact "registers & records" group — the periodic/occasional entries
  /// (registers, referral, family-planning, birth/death) as 2-per-row tiles so
  /// they don't each claim a hero banner and the daily case grid stays near the
  /// top. The referral tile carries the open-count badge.
  // ── Quick search ────────────────────────────────────────────────────────
  // Finding one mother used to mean: leave home → patient list → scroll/search.
  // From here it is two taps.
  Widget _quickSearch() {
    final pc = Get.find<PatientController>();
    final q = _query.trim().toLowerCase();
    final results = q.isEmpty
        ? const []
        : pc.patients
            .where((p) =>
                p.name.toLowerCase().contains(q) ||
                p.village.toLowerCase().contains(q) ||
                p.mobile.contains(q))
            .take(5)
            .toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          TextField(
            onChanged: (v) => setState(() => _query = v),
            style: AppTextStyles.body,
            decoration: InputDecoration(
              hintText: 'রোগী খুঁজুন — নাম, গ্রাম বা মোবাইল',
              hintStyle: AppTextStyles.caption,
              prefixIcon: const Icon(Icons.search_rounded,
                  color: AppColors.primary, size: 20),
              suffixIcon: q.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => setState(() => _query = ''),
                    ),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5)),
            ),
          ),
          if (q.isNotEmpty) ...[
            const SizedBox(height: 8),
            if (results.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text('"$q" — কেউ পাওয়া যায়নি',
                    style: AppTextStyles.caption),
              )
            else
              ...results.map((p) => Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        setState(() => _query = '');
                        Get.toNamed(AppRoutes.patientProfile, arguments: p);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            const Icon(Icons.person_rounded,
                                size: 16, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(p.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.label),
                            ),
                            Text(p.village, style: AppTextStyles.caption),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right_rounded,
                                size: 16, color: AppColors.textSecondary),
                          ],
                        ),
                      ),
                    ),
                  )),
          ],
        ],
      ),
    );
  }

  // ── Activity: streak + this week ────────────────────────────────────────
  // Kept honest. A 1-day "streak" is noise, so it only appears at 2+. And the
  // week count is visits actually completed — not tasks pending, which would
  // reward having a backlog.
  Widget _activityStrip() {
    if (_weekVisits == 0 && _streak < 2) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          if (_streak >= 2) ...[
            _statPill(Icons.local_fire_department_rounded,
                '$_streak দিন টানা', const Color(0xFFF97316)),
            const SizedBox(width: 10),
          ],
          _statPill(Icons.task_alt_rounded, 'এই সপ্তাহে $_weekVisits টি ভিজিট',
              AppColors.safeGreen),
        ],
      ),
    );
  }

  Widget _statPill(IconData icon, String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Text(text,
                style: AppTextStyles.caption
                    .copyWith(color: color, fontWeight: FontWeight.w700)),
          ],
        ),
      );

  // ── The REAL worklist ───────────────────────────────────────────────────
  // The case grid below sits under a heading that claims to be "today's tasks",
  // but it is a launcher menu — it never told her WHO needs visiting. This does:
  // most-overdue first, one tap to the mother.
  Widget _worklist() {
    if (_work.isEmpty) return const SizedBox.shrink();
    final t0 = _today();
    final top = _work.take(4).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 22,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.accent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 10),
              Text('আজকের কাজ', style: AppTextStyles.h3),
              const Spacer(),
              if (_work.length > top.length)
                GestureDetector(
                  onTap: () async {
                    await Get.toNamed(AppRoutes.dueList);
                    _loadDueCount();
                  },
                  child: Text('সব দেখুন (${_work.length})',
                      style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ...top.map((e) => _workRow(e, t0)),
        ],
      ),
    );
  }

  Widget _workRow(Map<String, dynamic> e, DateTime t0) {
    final end = DateTime.tryParse((e['windowEnd'] ?? '').toString()) ??
        DateTime.tryParse((e['dueDate'] ?? '').toString());
    final due = DateTime.tryParse((e['dueDate'] ?? '').toString());
    final lateBy = end == null
        ? 0
        : t0.difference(DateTime(end.year, end.month, end.day)).inDays;
    final startsIn = due == null
        ? 0
        : DateTime(due.year, due.month, due.day).difference(t0).inDays;

    final (String status, Color color) = lateBy > 0
        ? ('$lateBy দিন Overdue', AppColors.emergencyRed)
        : startsIn <= 0
            ? ('আজই করুন', AppColors.primary)
            : ('$startsIn দিন বাকি', AppColors.textSecondary);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openWorkItem(e),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 34,
                  decoration: BoxDecoration(
                      color: color, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text((e['patientName'] ?? '—').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.label
                              .copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text((e['label'] ?? '').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(status,
                    style: AppTextStyles.caption.copyWith(
                        color: color, fontWeight: FontWeight.w700)),
                const Icon(Icons.chevron_right_rounded,
                    size: 16, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Open the mother this task belongs to. Falls back to the full due list if
  /// her record isn't cached locally (e.g. first run after a fresh install).
  void _openWorkItem(Map<String, dynamic> e) {
    final pid = (e['patientId'] ?? '').toString();
    final matches =
        Get.find<PatientController>().patients.where((p) => p.id == pid).toList();
    if (matches.isNotEmpty) {
      Get.toNamed(AppRoutes.patientProfile, arguments: matches.first);
    } else {
      Get.toNamed(AppRoutes.dueList)?.then((_) => _loadDueCount());
    }
  }

  Widget _recordsSection() {
    final refCtrl = Get.isRegistered<ReferralController>()
        ? Get.find<ReferralController>()
        : Get.put(ReferralController(), permanent: true);
    final patientCtrl = Get.isRegistered<PatientController>()
        ? Get.find<PatientController>()
        : Get.put(PatientController(), permanent: true);
    final ncdCtrl = Get.isRegistered<NcdCbacController>()
        ? Get.find<NcdCbacController>()
        : Get.put(NcdCbacController(), permanent: true);
    final tbCtrl = Get.isRegistered<TbCaseController>()
        ? Get.find<TbCaseController>()
        : Get.put(TbCaseController(), permanent: true);
    final msCtrl = Get.isRegistered<MedicineStockController>()
        ? Get.find<MedicineStockController>()
        : Get.put(MedicineStockController(), permanent: true);
    final vitalCtrl = Get.isRegistered<VitalEventController>()
        ? Get.find<VitalEventController>()
        : Get.put(VitalEventController(), permanent: true);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.accent],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text('home_records_section'.tr,
                    style: AppTextStyles.label.copyWith(
                        color: AppColors.onBackground,
                        fontWeight: FontWeight.w800,
                        fontSize: 14)),
              ],
            ),
          ),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: [
              Obx(() => _recordTile(
                    icon: Icons.auto_stories_rounded,
                    color: AppColors.primary,
                    title: 'home_record_registers'.tr,
                    route: AppRoutes.registers,
                    count: patientCtrl.patients.length,
                  )),
              Obx(() => _recordTile(
                    icon: Icons.local_hospital_rounded,
                    color: AppColors.emergencyRed,
                    title: 'home_record_referrals'.tr,
                    route: AppRoutes.referralList,
                    count: refCtrl.openCount,
                    countColor: AppColors.emergencyRed,
                  )),
              Obx(() => _recordTile(
                    icon: Icons.menu_book_rounded,
                    color: AppColors.sky,
                    title: 'home_record_vital_events'.tr,
                    route: AppRoutes.vitalEvents,
                    count: vitalCtrl.items.length,
                  )),
              Obx(() => _recordTile(
                    icon: Icons.health_and_safety_rounded,
                    color: const Color(0xFF0D9488), // teal
                    title: 'home_record_ncd_cbac'.tr,
                    route: AppRoutes.ncdCbac,
                    count: ncdCtrl.items.length,
                  )),
              Obx(() => _recordTile(
                    icon: Icons.coronavirus_rounded,
                    color: const Color(0xFFEA580C), // orange
                    title: 'home_record_tb'.tr,
                    route: AppRoutes.tbCases,
                    count: tbCtrl.items.length,
                  )),
              Obx(() => _recordTile(
                    icon: Icons.inventory_2_rounded,
                    color: const Color(0xFF7C3AED), // violet
                    title: 'home_record_medicine_stock'.tr,
                    route: AppRoutes.medicineStock,
                    count: msCtrl.items.length,
                    // Low-stock lines flag red; otherwise the module colour.
                    countColor: msCtrl.lowStockCount > 0 ? AppColors.emergencyRed : null,
                  )),
              // Not the monthly stock ledger above — this is "is the life-saving
              // kit here TODAY". A missing MgSO4 or a dead BP machine goes
              // straight to her ANM/BMHO's phone.
              _recordTile(
                icon: Icons.medication_liquid_rounded,
                color: const Color(0xFF0EA5E9), // sky
                title: 'ওষুধ ও যন্ত্রপাতি',
                route: AppRoutes.readinessCheck,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _recordTile({
    required IconData icon,
    required Color color,
    required String title,
    required String route,
    int count = 0,
    Color? countColor,
  }) {
    final badgeColor = countColor ?? color;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Get.toNamed(route),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            // Soft colour-wash card — light in the top-left, fading out.
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.16),
                color.withValues(alpha: 0.05),
              ],
            ),
            border: Border.all(color: color.withValues(alpha: 0.14)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.10),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Filled icon badge with a soft coloured glow.
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.38),
                            blurRadius: 9,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(icon, color: Colors.white, size: 22),
                    ),
                    const Spacer(),
                    if (count > 0)
                      Container(
                        constraints: const BoxConstraints(minWidth: 26),
                        height: 26,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(13),
                          boxShadow: AppShadows.low,
                        ),
                        child: Text('$count',
                            style: AppTextStyles.caption.copyWith(
                                color: badgeColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 13)),
                      ),
                  ],
                ),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.label.copyWith(
                            color: AppColors.onBackground,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                            fontSize: 12.5)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// One small circular case chip (icon + short label) for the vertical grid.
  Widget _caseChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 6),
          Text(label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w600, height: 1.1, fontSize: 10.5)),
        ],
      ),
    );
  }

  /// Short single-word case label for the chip (language-aware).
  String _shortLabel(String caseId) => switch (caseId) {
        'pregnancy' => 'home_chip_pregnancy'.tr,
        'postpartum' => 'home_chip_postpartum'.tr,
        'newborn' => 'home_chip_newborn'.tr,
        'infant' => 'home_chip_infant'.tr,
        'child' => 'home_chip_child'.tr,
        'immunization' => 'home_chip_immunization'.tr,
        'development' => 'home_chip_development'.tr,
        'emergency' => 'home_chip_emergency'.tr,
        _ => caseId,
      };

  /// Emergency goes straight through — urgency overrides patient context.
  /// Every other case opens the [PatientContextSheet] which nudges the
  /// worker to pick / add a patient first (or proceed anonymously).
  Future<void> _openCase(
    String caseId,
    String title, {
    required IconData icon,
    required Color color,
  }) async {
    if (caseId == 'emergency') {
      Get.toNamed(AppRoutes.emergency);
      return;
    }
    // Resolve canonical title from the clinical engine in case the
    // dashboard's Bengali label diverges from the case definition.
    final cases = await _svc.loadCases();
    final caseModel = cases.firstWhere(
      (c) => c.id == caseId,
      orElse: () => cases.first,
    );
    if (!mounted) return;
    await PatientContextSheet.show(
      context,
      caseId: caseModel.id,
      caseTitle: caseModel.title,
      caseIcon: icon,
      caseColor: color,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Emoji removed from titles — the Material icon already conveys the case.
    final cards = [
      (Icons.pregnant_woman_rounded,         'case_pregnancy_title'.tr,          'case_pregnancy_sub'.tr,   AppColors.primary,         'pregnancy'),
      (Icons.child_care_rounded,             'case_postpartum_title'.tr,           'case_postpartum_sub'.tr,  AppColors.purple,          'postpartum'),
      (Icons.baby_changing_station_rounded,  'case_newborn_title'.tr,      'case_newborn_sub'.tr,     AppColors.sky,             'newborn'),
      (Icons.child_friendly_rounded,         'case_infant_title'.tr,         'case_infant_sub'.tr,    const Color(0xFF10B981),   'infant'),
      (Icons.face_rounded,                   'case_child_title'.tr,          'case_child_sub'.tr,const Color(0xFFF59E0B),  'child'),
      (Icons.vaccines_rounded,               'case_immunisation_title'.tr,    'case_immunisation_sub'.tr,     const Color(0xFF6366F1),   'immunization'),
      (Icons.emoji_people_rounded,           'home_card_development_title'.tr, 'home_card_development_sub'.tr, const Color(0xFFEC4899),   'development'),
      (Icons.emergency_rounded,              'case_emergency_title'.tr,           'case_emergency_sub'.tr,     AppColors.emergencyRed,    'emergency'),
    ];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          child: Column(
            children: [
              const GreetingHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 4),
                      _dueBanner(),
                      _activityStrip(),
                      // Her actual work — who needs visiting, most overdue
                      // first. This is what "আজকের কাজ" always should have been.
                      _worklist(),
                      _quickSearch(),
                      _recordsSection(),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 22,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [AppColors.primary, AppColors.accent],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Honest label: this grid is a LAUNCHER, not a task
                            // list. Calling it "today's tasks" told her she had
                            // work to pick from when it was just a menu.
                            Text('নতুন চেকআপ শুরু করুন',
                                style: AppTextStyles.h3),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Case chips — small circular icons in a vertical-scrolling
                      // grid (reference style). Count is dynamic (list-driven) and
                      // every label follows the selected language (.tr).
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 6,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.74,
                        ),
                        itemCount: cards.length,
                        itemBuilder: (_, i) {
                          final (icon, title, _, color, caseId) = cards[i];
                          return _caseChip(
                            icon: icon,
                            label: _shortLabel(caseId),
                            color: color,
                            onTap: caseId == 'development'
                                ? () => Get.toNamed(AppRoutes.development)
                                : () => _openCase(caseId, title, icon: icon, color: color),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 0),
    );
  }
}
