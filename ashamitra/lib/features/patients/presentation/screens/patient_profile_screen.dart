import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/risk_badge.dart';

class PatientProfileScreen extends StatelessWidget {
  const PatientProfileScreen({super.key});

  List<(bool, bool, String, String)> _timelineFor(String type) {
    switch (type) {
      case 'Pregnancy':
        return [
          (true, false, 'ANC Visit 1', '14 Jan 2025'),
          (true, false, 'HRP Screening', '20 Jan 2025'),
          (true, false, 'Iron-Folic Supplement', '20 Jan 2025'),
          (false, true, 'PHC Referral Pending', 'Due: 5 Feb 2025'),
          (false, false, 'ANC Visit 3', 'Scheduled: 10 Feb 2025'),
        ];
      case 'Newborn':
        return [
          (true, false, 'Birth Registration', '2 Jan 2025'),
          (true, false, 'BCG + OPV Vaccine', '3 Jan 2025'),
          (false, true, 'Weight Check Pending', 'Due: 16 Jan 2025'),
          (false, false, 'Pentavalent Vaccine', 'Scheduled: 1 Feb 2025'),
        ];
      case 'Child':
        return [
          (true, false, 'Growth Monitoring', '5 Jan 2025'),
          (true, false, 'Vitamin A Supplement', '5 Jan 2025'),
          (false, true, 'Follow-up Visit Pending', 'Due: 20 Jan 2025'),
          (false, false, 'Deworming', 'Scheduled: 1 Mar 2025'),
        ];
      default:
        return [
          (true, false, 'Initial Assessment', 'Today'),
          (false, false, 'Follow-up Scheduled', 'In 3 days'),
        ];
    }
  }

  String _caseIcon(String type) => switch (type) {
        'Pregnancy' => '🤰',
        'Newborn' => '👶',
        'Child' => '🧒',
        _ => '🏥',
      };

  String _monthLabel(String type) => switch (type) {
        'Pregnancy' => '7th Month',
        'Newborn' => '28 Days',
        'Child' => '2.5 Years',
        _ => 'N/A',
      };

  @override
  Widget build(BuildContext context) {
    final args = (Get.arguments as Map<String, dynamic>?) ?? {};
    final name = args['name'] as String? ?? 'Unknown';
    final type = args['type'] as String? ?? 'Other';
    final village = args['village'] as String? ?? '';
    final risk = args['risk'] as RiskLevel? ?? RiskLevel.safe;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final timeline = _timelineFor(type);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Get.back(),
                      child: Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)]),
                        child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text('Patient Profile',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.onBackground)),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white, borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4))],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 60, height: 60,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [AppColors.primary, AppColors.purple],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Center(
                                child: Text(initial,
                                    style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.onBackground)),
                                  Text('Village: $village',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                  const SizedBox(height: 6),
                                  RiskBadge(level: risk),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _InfoCard('${_caseIcon(type)} Case', type, Icons.assignment_rounded, AppColors.primary),
                          const SizedBox(width: 10),
                          _InfoCard('Duration', _monthLabel(type), Icons.calendar_month_rounded, AppColors.sky),
                          const SizedBox(width: 10),
                          _InfoCard('Status', risk.label, Icons.warning_amber_rounded,
                              risk == RiskLevel.emergency ? AppColors.emergencyRed
                              : risk == RiskLevel.high ? AppColors.warningYellow
                              : AppColors.safeGreen),
                        ],
                      ),
                      const SizedBox(height: 20),
                      AppButton(
                        label: 'Start Voice Checkup',
                        onPressed: () => Get.toNamed(AppRoutes.selectCase),
                        icon: Icons.mic_rounded,
                        width: double.infinity,
                      ),
                      const SizedBox(height: 24),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Care Timeline',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.onBackground)),
                      ),
                      const SizedBox(height: 16),
                      ...timeline.map((entry) {
                        final (done, pending, label, date) = entry;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 32, height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: done
                                      ? AppColors.safeGreen.withOpacity(0.12)
                                      : pending
                                          ? AppColors.warningYellow.withOpacity(0.12)
                                          : Colors.grey.withOpacity(0.08),
                                ),
                                child: Icon(
                                  done ? Icons.check_rounded : pending ? Icons.warning_amber_rounded : Icons.schedule_rounded,
                                  size: 16,
                                  color: done ? AppColors.safeGreen : pending ? AppColors.warningYellow : Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(label,
                                        style: TextStyle(
                                          fontSize: 14, fontWeight: FontWeight.w600,
                                          color: done ? AppColors.onBackground : pending ? AppColors.warningYellow : AppColors.textSecondary,
                                        )),
                                    Text(date, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension on RiskLevel {
  String get label => switch (this) {
        RiskLevel.safe => 'Safe',
        RiskLevel.moderate => 'Moderate',
        RiskLevel.high => 'High Risk',
        RiskLevel.emergency => 'Emergency',
      };
}

class _InfoCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _InfoCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 5),
            Text(value,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.onBackground),
                textAlign: TextAlign.center),
            Text(label,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
