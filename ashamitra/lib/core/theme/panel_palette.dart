import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../features/auth/controller/auth_controller.dart';
import 'app_colors.dart';

/// Role-resolved brand colour.
///
/// **Teal is the CMHO's alone.** Purple stays everywhere else — the ASHA worker
/// app, and the BMHO and ANM panels.
///
/// The reasoning is about distance from the field, not seniority. A BMHO and an
/// ANM still know their workers by name and still do clinical work; they belong
/// to the same warm register as the app those workers carry. A CMHO runs a
/// district: her screen is an instrument read standing up in a government
/// office, and it is the one place where a different register genuinely fits.
///
/// What does NOT change, at any level, is the clinical band — red, amber, green,
/// and grey for unknown. A worker and her CMHO discuss the same case; if red
/// meant one thing on her screen and another on his, the escalation chain would
/// break. Brand colour varies by panel. Safety colour never does.
///
/// Resolved statically rather than through Theme.of(context) because every
/// existing screen already references AppColors.* directly, and rewriting all of
/// them to thread a context would be a large change for no behavioural gain.
/// Role is fixed for the life of a session — a change re-routes the user anyway.
class PanelPalette {
  PanelPalette._();

  // ── CMHO only — "District Command" ─────────────────────────────────────────
  static const teal      = Color(0xFF0E5A6B); // primary
  static const tealDeep  = Color(0xFF08404E); // emphasis, gradient end
  static const tealMid   = Color(0xFF14788C); // charts, secondary series
  static const tealSoft  = Color(0xFFE1EFF3); // icon chips, quiet fills
  static const tealLine  = Color(0xFFCBDDE3); // borders, dividers

  static const mistBg    = Color(0xFFEDF3F5);
  static const mistBg2   = Color(0xFFE5EEF2);
  static const mistBg3   = Color(0xFFF5F9FB);
  static const slateText = Color(0xFF14252B);
  static const slateSub  = Color(0xFF5B6B72);
  static const slateLight= Color(0xFF94A6AD);

  /// True only for a CMHO. A BMHO or ANM gets the same purple as the worker app.
  static bool get isCmho {
    try {
      return Get.find<AuthController>().user.value?.panelRole == 'cmho';
    } catch (_) {
      // Called before AuthController is registered (e.g. a widget test).
      return false;
    }
  }

  static Color get primary     => isCmho ? teal : AppColors.primary;
  static Color get primaryDeep => isCmho ? tealDeep : AppColors.primaryDeep;
  static Color get primarySoft => isCmho ? tealSoft : AppColors.primarySoft;
  static Color get accent      => isCmho ? tealMid : AppColors.accent;
  static Color get line        => isCmho ? tealLine : AppColors.cardBorder;

  static Color get onBackground => isCmho ? slateText : AppColors.onBackground;
  static Color get textSecondary => isCmho ? slateSub : AppColors.textSecondary;
  static Color get textLight    => isCmho ? slateLight : AppColors.textLight;

  /// The page background. Cool mist for the CMHO, warm sage for everyone else.
  static LinearGradient get background => isCmho
      ? const LinearGradient(
          colors: [mistBg, mistBg2, mistBg3],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
      : const LinearGradient(
          colors: [Color(0xFFEAF3EC), Color(0xFFE3F0E8), Color(0xFFF1F8F3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );

  static LinearGradient get brand => isCmho
      ? const LinearGradient(
          colors: [teal, tealDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
      : const LinearGradient(
          colors: [Color(0xFF791C87), Color(0xFFBD3773)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
}
