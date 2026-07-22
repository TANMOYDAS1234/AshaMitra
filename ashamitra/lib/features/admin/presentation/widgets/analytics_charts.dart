import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/panel_palette.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/motion.dart';

/// Lightweight, dependency-free charts for the supervisor panels.
///
/// Hand-painted rather than pulling in a charting package: keeps the APK lean
/// and lets the visuals match the app's own palette exactly. Every chart is
/// fed data the panel has already loaded (subtree-scoped), so no extra server
/// round-trip is needed.

// ── Trend: smooth area chart of a daily series ──────────────────────────────
class TrendAreaChart extends StatelessWidget {
  final List<int> values; // oldest → newest
  final Color? color;
  final double height;

  /// Null falls back to the panel's brand colour, resolved at build time.
  /// It cannot be a default parameter: the palette is role-dependent, so it is a
  /// getter, and a getter is not a compile-time constant.
  const TrendAreaChart({
    super.key,
    required this.values,
    this.color,
    this.height = 96,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
            painter: _TrendPainter(values, color ?? PanelPalette.primary)),
      );
}

class _TrendPainter extends CustomPainter {
  final List<int> v;
  final Color color;
  _TrendPainter(this.v, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (v.isEmpty) return;
    final maxV = math.max(1, v.reduce(math.max));
    final dx = v.length > 1 ? size.width / (v.length - 1) : size.width;

    // Baseline grid (3 faint rules) — gives the eye a scale without clutter.
    final grid = Paint()
      ..color = PanelPalette.textSecondary.withValues(alpha: 0.10)
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final y = size.height * (i / 2);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    Offset pt(int i) => Offset(
          i * dx,
          size.height - (v[i] / maxV) * (size.height - 6) - 3,
        );

    // Smooth the polyline with midpoint quadratics — reads as a premium curve.
    final line = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 0; i < v.length - 1; i++) {
      final p = pt(i), n = pt(i + 1);
      final mid = Offset((p.dx + n.dx) / 2, (p.dy + n.dy) / 2);
      line.quadraticBezierTo(p.dx, p.dy, mid.dx, mid.dy);
    }
    if (v.length > 1) line.lineTo(pt(v.length - 1).dx, pt(v.length - 1).dy);

    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0.02)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Emphasise "today" — the point the supervisor actually acts on.
    final last = pt(v.length - 1);
    canvas.drawCircle(last, 5.5, Paint()..color = color.withValues(alpha: 0.20));
    canvas.drawCircle(last, 3.2, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
      old.v != v || old.color != color;
}

// ── Band mix: donut of RED / YELLOW / GREEN ─────────────────────────────────
class BandDonut extends StatelessWidget {
  final int red, yellow, green;
  final double size;

  const BandDonut({
    super.key,
    required this.red,
    required this.yellow,
    required this.green,
    this.size = 120,
  });

  @override
  Widget build(BuildContext context) {
    final total = red + yellow + green;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Motion.slow,
            curve: Curves.easeOutCubic,
            builder: (ctx, t, _) => CustomPaint(
              size: Size(size, size),
              painter: _DonutPainter(
                red: red, yellow: yellow, green: green,
                t: Motion.reduced(ctx) ? 1 : t,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CountUp(
                  value: total,
                  style: AppTextStyles.h2.copyWith(fontWeight: FontWeight.w800)),
              Text('মোট', style: AppTextStyles.caption),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final int red, yellow, green;

  /// 0..1 — the ring sweeps in from 12 o'clock. Red is drawn first, so the
  /// segment that matters is also the one that arrives first.
  final double t;

  _DonutPainter({required this.red, required this.yellow, required this.green,
      this.t = 1});

  @override
  void paint(Canvas canvas, Size size) {
    final total = red + yellow + green;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height).deflate(9);
    const stroke = 14.0;

    if (total == 0) {
      canvas.drawArc(rect, 0, math.pi * 2, false,
          Paint()
            ..color = PanelPalette.textSecondary.withValues(alpha: 0.12)
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke);
      return;
    }

    final full = math.pi * 2 * t.clamp(0.0, 1.0);
    var start = -math.pi / 2; // start at 12 o'clock
    var drawn = 0.0;
    void seg(int value, Color c) {
      if (value <= 0) return;
      final sweep = (value / total) * math.pi * 2;
      final visible = math.min(sweep, math.max(0, full - drawn));
      if (visible > 0) {
        canvas.drawArc(
          rect,
          start,
          math.max(0, visible - 0.03), // tiny gap so segments read as distinct
          false,
          Paint()
            // A sweep gradient gives the ring depth without a perspective
            // transform — dimension that costs nothing once it has settled.
            ..shader = SweepGradient(
              startAngle: start,
              endAngle: start + sweep,
              colors: [c.withValues(alpha: 0.72), c],
            ).createShader(rect)
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..strokeCap = StrokeCap.round,
        );
      }
      start += sweep;
      drawn += sweep;
    }

    // Most urgent first, clockwise — red is what the eye should hit.
    seg(red, AppColors.emergencyRed);
    seg(yellow, AppColors.warningYellow);
    seg(green, AppColors.safeGreen);
  }

  @override
  bool shouldRepaint(covariant _DonutPainter o) =>
      o.red != red || o.yellow != yellow || o.green != green || o.t != t;
}

// ── Sparkline: a mini trend for stat tiles ──────────────────────────────────
class Sparkline extends StatelessWidget {
  final List<int> values;
  final Color? color;
  const Sparkline({super.key, required this.values, required this.color});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 22,
        width: double.infinity,
        child: CustomPaint(painter: _SparkPainter(values, color ?? PanelPalette.primary)),
      );
}

class _SparkPainter extends CustomPainter {
  final List<int> v;
  final Color color;
  _SparkPainter(this.v, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (v.length < 2) return;
    final maxV = math.max(1, v.reduce(math.max));
    final dx = size.width / (v.length - 1);
    final path = Path();
    for (var i = 0; i < v.length; i++) {
      final y = size.height - (v[i] / maxV) * (size.height - 3) - 1.5;
      i == 0 ? path.moveTo(0, y) : path.lineTo(i * dx, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SparkPainter o) => o.v != v || o.color != color;
}

// ── Legend row for the donut ────────────────────────────────────────────────
class BandLegend extends StatelessWidget {
  final int red, yellow, green;
  const BandLegend(
      {super.key, required this.red, required this.yellow, required this.green});

  @override
  Widget build(BuildContext context) {
    Widget row(Color c, String label, int n) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Text(label, style: AppTextStyles.caption)),
              Text('$n',
                  style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row(AppColors.emergencyRed, 'জরুরি (RED)', red),
        row(AppColors.warningYellow, 'রেফার (YELLOW)', yellow),
        row(AppColors.safeGreen, 'স্বাভাবিক (GREEN)', green),
      ],
    );
  }
}
