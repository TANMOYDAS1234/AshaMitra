import 'package:flutter/material.dart';

class AppGradients {
  // Purple → magenta — the app's hero gradient (banners, splash brand).
  static const primary = LinearGradient(
    colors: [Color(0xFF791C87), Color(0xFFBD3773)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const primaryVertical = LinearGradient(
    colors: [Color(0xFF791C87), Color(0xFFA8277E), Color(0xFFBD3773)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Soft sage-green page background.
  static const background = LinearGradient(
    colors: [Color(0xFFEAF3EC), Color(0xFFE3F0E8), Color(0xFFF1F8F3)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const splash = LinearGradient(
    colors: [Color(0xFF5B0F69), Color(0xFF791C87), Color(0xFFBD3773)],
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
    colors: [Color(0xFFD98FE0), Color(0xFF791C87), Color(0xFFBD3773)],
    center: Alignment.center,
    radius: 0.85,
  );

  // Legacy alias
  static const success = safe;
}
