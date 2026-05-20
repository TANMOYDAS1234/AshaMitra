import 'package:flutter/material.dart';

class AppGradients {
  static const primary = LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const primaryVertical = LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED), Color(0xFF06B6D4)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const background = LinearGradient(
    colors: [Color(0xFFF7F8FF), Color(0xFFEEF2FF), Color(0xFFF0FEFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const splash = LinearGradient(
    colors: [Color(0xFF312E81), Color(0xFF4F46E5), Color(0xFF0E7490)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const emergency = LinearGradient(
    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const safe = LinearGradient(
    colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const attention = LinearGradient(
    colors: [Color(0xFFFACC15), Color(0xFFEAB308)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const orb = RadialGradient(
    colors: [Color(0xFFA5B4FC), Color(0xFF4F46E5), Color(0xFF06B6D4)],
    center: Alignment.center,
    radius: 0.85,
  );

  // Legacy alias
  static const success = safe;
}
