import 'package:flutter/material.dart';
import '../../core/theme/app_gradients.dart';

class GradientBackground extends StatelessWidget {
  final Widget child;
  final LinearGradient? gradient;

  const GradientBackground({super.key, required this.child, this.gradient});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: gradient ?? AppGradients.background),
      child: child,
    );
  }
}
