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

  @override
  void initState() {
    super.initState();
    _svc.loadCases(); // pre-warm cache
    _loadDueCount();
  }

  /// Count of UNIQUE patients with a due/overdue item (within 14 days) — the
  /// banner reads "X জন রোগীর", so it must count patients, not events (one
  /// patient with ANC + 2 vaccines due is one person, not three).
  /// Best-effort: 0 when offline or logged out.
  Future<void> _loadDueCount() async {
    final due = await ApiService.getScheduleDue(withinDays: 14);
    final patients = due
        .whereType<Map>()
        .map((e) => (e['patientId'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toSet();
    if (mounted) {
      setState(() => _dueCount = patients.isNotEmpty ? patients.length : due.length);
    }
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
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              boxShadow: AppShadows.tinted(AppColors.primary, strength: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                children: [
                  // Faint hero photo behind a purple→orange scrim (text stays legible).
                  Positioned.fill(
                    child: Image.asset('assets/images/hero_asha.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withValues(alpha: 0.93),
                            AppColors.accent.withValues(alpha: 0.80),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                children: [
                  Container(
                    width: 50, height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                    ),
                    child: const Icon(Icons.notifications_active_rounded,
                        color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('home_due_banner_title'.tr,
                            style: AppTextStyles.h3.copyWith(
                                color: Colors.white, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 3),
                        Text(
                          hasDue
                              ? 'home_due_banner_count'.trParams({'count': '$_dueCount'})
                              : 'home_due_banner_empty'.tr,
                          style: AppTextStyles.bodySm
                              .copyWith(color: Colors.white.withValues(alpha: 0.92)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (hasDue)
                    Container(
                      constraints: const BoxConstraints(minWidth: 38),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text('$_dueCount',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.h3.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800)),
                    )
                  else
                    const Icon(Icons.chevron_right_rounded,
                        color: Colors.white, size: 26),
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
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text('home_records_section'.tr,
                style: AppTextStyles.label.copyWith(
                    color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
          ),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.15,
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
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Get.toNamed(route),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppShadows.low,
            border: Border.all(color: color.withValues(alpha: 0.18)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 54, height: 54,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 27),
                    ),
                    if (count > 0)
                      Positioned(
                        right: -6, top: -6,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 22),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.surface, width: 2),
                          ),
                          child: Text('$count',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.caption.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.label.copyWith(
                        fontWeight: FontWeight.w700, height: 1.2)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// One circular case chip (icon + short label) for the compact case strip.
  Widget _caseChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 54, height: 54,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 6),
            Text(label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption
                    .copyWith(fontWeight: FontWeight.w600, height: 1.1)),
          ],
        ),
      ),
    );
  }

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
                            Text('todays_tasks'.tr, style: AppTextStyles.h3),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Compact case row — circular chips in a soft container
                      // (matches the reference "আজকের স্বাস্থ্য কার্যক্রম" strip).
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: SizedBox(
                          height: 92,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            itemCount: cards.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 4),
                            itemBuilder: (_, i) {
                              final (icon, title, _, color, caseId) = cards[i];
                              return _caseChip(
                                icon: icon,
                                label: title,
                                color: color,
                                onTap: caseId == 'development'
                                    ? () => Get.toNamed(AppRoutes.development)
                                    : () => _openCase(caseId, title, icon: icon, color: color),
                              );
                            },
                          ),
                        ),
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
