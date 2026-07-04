import 'package:flutter/material.dart';

/// A hero photo whose edges melt softly into the page background instead of
/// sitting in a hard rounded-rectangle frame. Two stacked [ShaderMask]s fade
/// the alpha on all four edges (via [BlendMode.dstIn]): a gentle side fade and
/// a vertical fade that is soft up top and deep at the bottom, so the image
/// dissolves smoothly into the content below.
class BlendedHeroImage extends StatelessWidget {
  const BlendedHeroImage({
    super.key,
    required this.asset,
    this.height = 196,
    this.errorBuilder,
  });

  final String asset;
  final double height;
  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      asset,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: errorBuilder ?? (_, __, ___) => const SizedBox.shrink(),
    );
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      // Soft left/right edge fade.
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.transparent,
          Colors.white,
          Colors.white,
          Colors.transparent,
        ],
        stops: [0.0, 0.06, 0.94, 1.0],
      ).createShader(rect),
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        // Gentle top fade, deep bottom fade → flows into the text below.
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.white,
            Colors.white,
            Colors.transparent,
          ],
          stops: [0.0, 0.10, 0.64, 1.0],
        ).createShader(rect),
        child: image,
      ),
    );
  }
}
