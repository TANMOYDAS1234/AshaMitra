import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Hero photo as a soft, premium rounded card: crisp rounded corners, a gentle
/// branded (plum) drop-shadow so it floats above the page, and a light gradient
/// scrim that melts the bottom edge into the sage background — so it reads as a
/// designed photo card rather than either a hard frame or a washed-out fade.
class BlendedHeroImage extends StatelessWidget {
  const BlendedHeroImage({
    super.key,
    required this.asset,
    this.height = 210,
    this.errorBuilder,
  });

  final String asset;
  final double height;
  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          // Soft plum glow — premium float on the sage background.
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.20),
            blurRadius: 34,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: AppColors.onBackground.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              asset,
              fit: BoxFit.cover,
              errorBuilder: errorBuilder ?? (_, __, ___) => const SizedBox.shrink(),
            ),
            // Gentle scrim: a hint of depth up top, and a melt into the page's
            // sage tone along the bottom so the card doesn't end on a hard line.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.06),
                    Colors.transparent,
                    Colors.transparent,
                    AppColors.background.withValues(alpha: 0.92),
                  ],
                  stops: const [0.0, 0.22, 0.68, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
