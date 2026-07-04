import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_text_styles.dart';

/// Shared list card for the register-style module screens (NCD/CBAC, TB,
/// Medicine Stock). Matches the new patient-list card language: rounded 18,
/// soft shadow, a thin coloured status rail on the left, a tinted round icon
/// avatar, name + one-line meta, and a status pill on the right. High-priority
/// rows (high-risk / presumptive / low-stock) flip to a light-red danger skin.
class ModuleListCard extends StatelessWidget {
  const ModuleListCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.badge,
    required this.onTap,
    this.danger = false,
    this.badgeColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  /// Status colour — drives the left rail and the icon avatar tint (and the
  /// pill, unless [badgeColor] overrides it).
  final Color accent;
  final String badge;
  final VoidCallback onTap;

  /// When true the card uses the light-red attention skin (red border + tint).
  final bool danger;

  /// Optional distinct colour for the status pill (e.g. rail = clinical band,
  /// pill = tracking status). Falls back to [accent].
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: danger ? const Color(0xFFFEF2F2) : AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: AppShadows.low,
              border: danger
                  ? Border.all(color: AppColors.emergencyRed, width: 1.2)
                  : null,
              // Coloured status rail on the left edge.
              gradient: LinearGradient(
                colors: [accent, accent.withValues(alpha: 0)],
                stops: const [0.014, 0.014],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: accent, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.h3.copyWith(
                                color: danger
                                    ? AppColors.emergencyRed
                                    : AppColors.onBackground)),
                        const SizedBox(height: 3),
                        Text(subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodySm
                                .copyWith(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (badgeColor ?? accent).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(badge,
                            style: AppTextStyles.caption.copyWith(
                                color: badgeColor ?? accent,
                                fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(height: 6),
                      Icon(Icons.chevron_right_rounded,
                          size: 18,
                          color: AppColors.textSecondary.withValues(alpha: 0.7)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
