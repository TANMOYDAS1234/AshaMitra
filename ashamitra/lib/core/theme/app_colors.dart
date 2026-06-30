import 'package:flutter/material.dart';

/// Centralised color tokens. Two principles:
///
///   1. **Triage band colors are sacred** — `safeGreen`, `warningYellow`,
///      `emergencyRed` mean "Green / Yellow / Red band" and nothing else.
///      Never reuse them for decorative purposes.
///
///   2. **The primary scale** (primary / primaryDeep / primarySoft) and the
///      **accent scale** (accent / accentDeep / accentSoft) are the
///      app's identity. Use them for everything decorative or interactive.
///
/// Palette (2026 reskin): Primary purple #791C87, Secondary magenta #BD3773,
/// Tertiary orange #FC8155, Neutral sage #C1CFC5 → soft green page background.
class AppColors {
  AppColors._();

  // ── Primary scale (purple) ───────────────────────────────────────────────
  static const primary     = Color(0xFF791C87); // purple — buttons, links, active state
  static const primaryDeep = Color(0xFF5B0F69); // deep purple — emphasis on dark
  static const primarySoft = Color(0xFFF6E9F9); // purple-50 — quiet fills, focus halos

  // ── Accent scale (warm tertiary orange) ──────────────────────────────────
  static const accent     = Color(0xFFFC8155); // orange — warm highlights, callouts
  static const accentDeep = Color(0xFFC2410C); // orange-800 — emphasis
  static const accentSoft = Color(0xFFFFE8DC); // orange-100 — soft fills

  // ── Secondary tones (magenta + sky, used for differentiation) ─────────────
  static const purple = Color(0xFFBD3773); // secondary magenta (decorative)
  static const sky    = Color(0xFF0EA5B5); // teal — variety in case tiles

  // ── Triage band colors — DO NOT reuse outside clinical context ───────────
  static const safeGreen      = Color(0xFF22C55E);
  static const warningYellow  = Color(0xFFFACC15);
  static const emergencyRed   = Color(0xFFEF4444);

  // ── Neutrals / surfaces ──────────────────────────────────────────────────
  static const background     = Color(0xFFEAF3EC); // page background (soft sage-green)
  static const surface        = Color(0xFFFFFFFF); // cards, sheets
  static const surfaceMuted   = Color(0xFFF3F6F3); // nested surfaces (cool off-white)
  static const onPrimary      = Color(0xFFFFFFFF);
  static const onBackground   = Color(0xFF241726); // deep purple-near-black, soft on eyes
  static const textSecondary  = Color(0xFF6B7280);
  static const textLight      = Color(0xFF9CA3AF);
  static const cardBorder     = Color(0xFFE3DCE8);

  // ── Legacy aliases (kept so older code keeps compiling) ──────────────────
  static const secondary = safeGreen;
  static const error     = emergencyRed;
  static const warning   = warningYellow;
}
