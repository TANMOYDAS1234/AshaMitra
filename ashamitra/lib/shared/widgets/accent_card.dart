import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/panel_palette.dart';

/// A white card with a solid colour bar down its leading edge.
///
/// This is the structural motif of the officer panels — the thing that lets a
/// CMHO scan a screen for severity without reading a word. It beats a tinted
/// outline for the same job: a 4px solid block survives sunlight, a scratched
/// screen protector, and the washed-out panel of a cheap handset, where a 22%
/// alpha border simply disappears.
///
/// The bar carries MEANING, never decoration. Red for danger, amber for warning,
/// green for clear, grey for unknown, brand for neutral. Anything that sets an
/// arbitrary colour here is misusing it.
class AccentCard extends StatelessWidget {
  final Color accent;
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final EdgeInsets margin;

  /// Draws a hairline border in the accent colour too. Reserved for the most
  /// urgent state, so that a screen full of cards still has a clear worst item.
  final bool emphasised;

  const AccentCard({
    super.key,
    required this.accent,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.fromLTRB(14, 14, 14, 14),
    this.margin = const EdgeInsets.only(bottom: 12),
    this.emphasised = false,
  });

  @override
  Widget build(BuildContext context) {
    final body = Container(
      decoration: BoxDecoration(
        borderRadius: AppRadius.lgR,
        boxShadow: AppShadows.low,
        border: emphasised
            ? Border.all(color: accent.withValues(alpha: 0.30))
            : null,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: accent),
            Expanded(child: Padding(padding: padding, child: child)),
          ],
        ),
      ),
    );

    return Container(
      margin: margin,
      child: Material(
        color: AppColors.surface,
        borderRadius: AppRadius.lgR,
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? body
            : InkWell(onTap: onTap, child: body),
      ),
    );
  }
}

/// The standard header row inside an [AccentCard]: tinted icon chip, title,
/// optional subtitle, an optional count badge, and a chevron or expander.
class AccentCardHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color accent;
  final int badge;
  final Widget? trailing;

  const AccentCardHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.accent,
    this.subtitle,
    this.badge = 0,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: AppRadius.mdR,
            ),
            child: Icon(icon, size: 20, color: accent),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTextStyles.h3
                        .copyWith(color: PanelPalette.onBackground)),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(subtitle!,
                      style: AppTextStyles.caption
                          .copyWith(color: PanelPalette.textSecondary)),
              ],
            ),
          ),
          if (badge > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.emergencyRed,
                borderRadius: AppRadius.smR,
              ),
              child: Text('$badge',
                  style: AppTextStyles.caption.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          if (trailing != null) ...[const SizedBox(width: 6), trailing!],
        ],
      );
}
