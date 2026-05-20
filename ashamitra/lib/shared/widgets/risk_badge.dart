import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

enum RiskLevel { safe, moderate, high, emergency }

class RiskBadge extends StatelessWidget {
  final RiskLevel level;
  const RiskBadge({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (level) {
      RiskLevel.safe => ('Safe', AppColors.safeGreen, Icons.check_circle_outline_rounded),
      RiskLevel.moderate => ('Moderate', AppColors.warningYellow, Icons.warning_amber_outlined),
      RiskLevel.high => ('High Risk', const Color(0xFFF97316), Icons.error_outline_rounded),
      RiskLevel.emergency => ('Emergency', AppColors.emergencyRed, Icons.emergency_outlined),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
