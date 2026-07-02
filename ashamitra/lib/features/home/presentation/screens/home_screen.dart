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
            childAspectRatio: 1.5,
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 46, height: 46,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 23),
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
                const SizedBox(height: 8),
                Text(title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.label.copyWith(
                        fontWeight: FontWeight.w700, height: 1.15)),
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
