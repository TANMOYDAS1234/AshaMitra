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
import '../widgets/greeting_header.dart';
import '../widgets/dashboard_card.dart';
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

  /// Lightweight count of due/overdue ANC + immunization items for the banner.
  /// Best-effort: returns [] (count 0) when offline or logged out.
  Future<void> _loadDueCount() async {
    final due = await ApiService.getScheduleDue(withinDays: 14);
    if (mounted) setState(() => _dueCount = due.length);
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
          child: Ink(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: AppShadows.tinted(AppColors.primary, strength: 2),
            ),
            child: Padding(
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
                        Text('বকেয়া টিকা ও ANC',
                            style: AppTextStyles.h3.copyWith(
                                color: Colors.white, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 3),
                        Text(
                          hasDue
                              ? '$_dueCount জন রোগীর টিকা / পরীক্ষা বাকি আছে'
                              : 'টিকা ও পরীক্ষার তালিকা দেখুন',
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
          ),
        ),
      ),
    );
  }

  /// Register generator entry — turns the app's schedule into the official
  /// monthly due-list register (PDF/CSV). Solves the #1 field pain: paperwork.
  Widget _registersBanner() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Get.toNamed(AppRoutes.registers),
          child: Ink(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              boxShadow: AppShadows.low,
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_stories_rounded,
                        color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('রেজিস্টার তৈরি করুন',
                            style: AppTextStyles.h3
                                .copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text('বকেয়া ANC / টিকা / নবজাতক তালিকা — PDF',
                            style: AppTextStyles.bodySm
                                .copyWith(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.primary, size: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Referrals + outcome tracking entry. Shows a badge with the number of
  /// "open" referrals (pending/reached) so the worker remembers to follow up —
  /// the field-flagged gap of "patient vanishes after referral".
  Widget _referralsBanner() {
    final ctrl = Get.isRegistered<ReferralController>()
        ? Get.find<ReferralController>()
        : Get.put(ReferralController(), permanent: true);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Get.toNamed(AppRoutes.referralList),
          child: Ink(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              boxShadow: AppShadows.low,
              border: Border.all(color: AppColors.emergencyRed.withValues(alpha: 0.18)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.emergencyRed.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.local_hospital_rounded,
                        color: AppColors.emergencyRed, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('রেফারেল ও ট্র্যাকিং',
                            style: AppTextStyles.h3
                                .copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text('রোগী রেফার করুন ও ফলাফল ট্র্যাক করুন',
                            style: AppTextStyles.bodySm
                                .copyWith(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Obx(() {
                    final open = ctrl.openCount;
                    if (open == 0) {
                      return const Icon(Icons.chevron_right_rounded,
                          color: AppColors.emergencyRed, size: 24);
                    }
                    return Container(
                      constraints: const BoxConstraints(minWidth: 34),
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.emergencyRed,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text('$open',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.label.copyWith(
                              color: Colors.white, fontWeight: FontWeight.w800)),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Compact navigation banner (used by the family-planning + birth/death
  /// register entries). Same card language as the other home banners.
  Widget _navBanner({
    required IconData icon,
    required Color color,
    required String title,
    required String sub,
    required String route,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Get.toNamed(route),
          child: Ink(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              boxShadow: AppShadows.low,
              border: Border.all(color: color.withValues(alpha: 0.18)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(sub,
                            style: AppTextStyles.bodySm
                                .copyWith(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: color, size: 24),
                ],
              ),
            ),
          ),
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
      (Icons.emoji_people_rounded,           'শিশু বিকাশ',                    'মাইলস্টোন যাচাই',              const Color(0xFFEC4899),   'development'),
      (Icons.emergency_rounded,              'case_emergency_title'.tr,           'case_emergency_sub'.tr,     AppColors.emergencyRed,    'emergency'),
    ];

    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= 600 ? 3 : 2;

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
                      _registersBanner(),
                      _referralsBanner(),
                      _navBanner(
                        icon: Icons.favorite_rounded,
                        color: AppColors.purple,
                        title: 'যোগ্য দম্পতি (পরিবার পরিকল্পনা)',
                        sub: 'দম্পতি ও গর্ভনিরোধ ফলো-আপ',
                        route: AppRoutes.eligibleCouples,
                      ),
                      _navBanner(
                        icon: Icons.menu_book_rounded,
                        color: AppColors.sky,
                        title: 'জন্ম ও মৃত্যু নথি',
                        sub: 'CRS রিপোর্টিং — জন্ম/মৃত্যু লিপিবদ্ধ',
                        route: AppRoutes.vitalEvents,
                      ),
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
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 1.05,
                        ),
                        itemCount: cards.length,
                        itemBuilder: (_, i) {
                          final (icon, title, desc, color, caseId) = cards[i];
                          return DashboardCard(
                            icon: icon,
                            title: title,
                            description: desc,
                            color: color,
                            index: i,
                            // Development screening is a standalone flow (not a
                            // triage case), so it skips the patient-context sheet.
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
