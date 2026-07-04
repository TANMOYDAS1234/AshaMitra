import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_text_styles.dart';

/// One stat tile inside a [ModuleHero].
class ModuleStat {
  const ModuleStat(this.value, this.label,
      {this.emphasize = false, this.warn = false});

  final String value;
  final String label;

  /// Brighter, larger-weight tile — use for the headline (e.g. total).
  final bool emphasize;

  /// Attention tile — white outline + alert icon (e.g. open / high-risk count).
  final bool warn;
}

/// Gradient summary hero shared across the register/module list screens
/// (Referral, NCD, TB, Medicine, Birth & Death): a label chip, a trailing
/// icon and a row of evenly-spaced stat tiles.
class ModuleHero extends StatelessWidget {
  const ModuleHero({
    super.key,
    required this.chip,
    required this.icon,
    required this.stats,
  });

  final String chip;
  final IconData icon;
  final List<ModuleStat> stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDeep, AppColors.primary, AppColors.purple],
          stops: [0.0, 0.55, 1.0],
        ),
        boxShadow: AppShadows.tinted(AppColors.primary, strength: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(chip,
                      style: AppTextStyles.caption.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                ),
                const Spacer(),
                Icon(icon,
                    color: Colors.white.withValues(alpha: 0.85), size: 22),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                for (var i = 0; i < stats.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(child: _tile(stats[i])),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(ModuleStat s) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: s.emphasize ? 0.24 : 0.13),
        borderRadius: BorderRadius.circular(16),
        border: s.warn
            ? Border.all(color: Colors.white.withValues(alpha: 0.55), width: 1)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (s.warn) ...[
                const Icon(Icons.notifications_active_rounded,
                    color: Colors.white, size: 15),
                const SizedBox(width: 3),
              ],
              Text(s.value,
                  style: AppTextStyles.h2.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      height: 1.0)),
            ],
          ),
          const SizedBox(height: 3),
          Text(s.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption
                  .copyWith(color: Colors.white.withValues(alpha: 0.85))),
        ],
      ),
    );
  }
}

/// Accent-bar section header (matches home / report / referral).
class ModuleSectionHeader extends StatelessWidget {
  const ModuleSectionHeader(this.title, {super.key, this.count});

  final String title;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
      child: Row(
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
          Text(title,
              style: AppTextStyles.label.copyWith(
                  color: AppColors.onBackground,
                  fontWeight: FontWeight.w800,
                  fontSize: 14)),
          if (count != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('$count',
                  style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary, fontWeight: FontWeight.w800)),
            ),
          ],
        ],
      ),
    );
  }
}
