import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'risk_badge.dart';

class PatientCard extends StatelessWidget {
  final String name;
  final String caseType;
  final String village;
  final String lastVisit;
  final RiskLevel riskLevel;
  final VoidCallback? onTap;

  const PatientCard({
    super.key,
    required this.name,
    required this.caseType,
    required this.village,
    required this.lastVisit,
    this.riskLevel = RiskLevel.safe,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primary.withOpacity(0.1),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E1B4B))),
                  const SizedBox(height: 3),
                  Text(
                    '$caseType · Village: $village',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Last visit: $lastVisit',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
            ),
            RiskBadge(level: riskLevel),
          ],
        ),
      ),
    );
  }
}
