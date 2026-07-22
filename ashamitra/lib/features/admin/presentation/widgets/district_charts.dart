import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/panel_palette.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/motion.dart';

/// A real monthly series with month labels.
///
/// [TrendAreaChart] in analytics_charts.dart draws a bare shape from whatever
/// list it is given. This one is for the district screen, where the CMHO needs
/// to know WHICH month things fell apart. Two series can be overlaid — typically
/// all reports against RED reports — so the ratio is visible rather than
/// computed in the reader's head.
class MonthlySeriesChart extends StatelessWidget {
  final List<String> months; // 'YYYY-MM', oldest to newest
  final List<int> primary;
  final List<int>? secondary; // drawn on top, usually the alarming subset
  /// Null falls back to the panel's brand colour, resolved at build time. It
  /// cannot be a default parameter: the palette is role-dependent, so it is a
  /// getter, and a getter is not a compile-time constant.
  final Color? primaryColor;
  final Color secondaryColor;
  final double height;

  const MonthlySeriesChart({
    super.key,
    required this.months,
    required this.primary,
    this.secondary,
    this.primaryColor,
    this.secondaryColor = AppColors.emergencyRed,
    this.height = 128,
  });

  static const _bn = [
    'জানু', 'ফেব', 'মার্চ', 'এপ্রি', 'মে', 'জুন',
    'জুলা', 'আগ', 'সেপ', 'অক্টো', 'নভে', 'ডিসে',
  ];

  String _label(String ym) {
    final p = ym.split('-');
    if (p.length != 2) return ym;
    final m = int.tryParse(p[1]) ?? 0;
    return (m >= 1 && m <= 12) ? _bn[m - 1] : ym;
  }

  @override
  Widget build(BuildContext context) {
    if (months.isEmpty || primary.isEmpty) return const SizedBox.shrink();
    final maxV = [...primary, ...(secondary ?? const <int>[])]
        .fold<int>(1, math.max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: height,
          width: double.infinity,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Motion.slow,
            curve: Curves.easeOutCubic,
            builder: (ctx, t, _) => CustomPaint(
              painter: _MonthlyPainter(
                primary: primary,
                secondary: secondary,
                primaryColor: primaryColor ?? PanelPalette.primary,
                secondaryColor: secondaryColor,
                maxV: maxV,
                t: Motion.reduced(ctx) ? 1 : t,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Label only the ends and the middle. Twelve labels across a 720px phone
        // is a smear, not an axis.
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_label(months.first),
                style: AppTextStyles.caption
                    .copyWith(color: PanelPalette.textSecondary)),
            if (months.length > 2)
              Text(_label(months[months.length ~/ 2]),
                  style: AppTextStyles.caption
                      .copyWith(color: PanelPalette.textSecondary)),
            Text(_label(months.last),
                style: AppTextStyles.caption
                    .copyWith(color: PanelPalette.textSecondary)),
          ],
        ),
      ],
    );
  }
}

class _MonthlyPainter extends CustomPainter {
  final List<int> primary;
  final List<int>? secondary;
  final Color primaryColor;
  final Color secondaryColor;
  final int maxV;

  /// 0..1 — bars grow up from the baseline. Growth reads as accumulation, which
  /// is what a monthly count IS; fading in would read as "appearing", which is
  /// not the same idea.
  final double t;

  _MonthlyPainter({
    required this.primary,
    required this.secondary,
    required this.primaryColor,
    required this.secondaryColor,
    required this.maxV,
    this.t = 1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final n = primary.length;
    if (n == 0) return;
    final barW = size.width / n;

    final grid = Paint()
      ..color = PanelPalette.onBackground.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final y = size.height * (i / 2);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // Bars, not a smoothed line. These are monthly COUNTS — a curve drawn
    // between two months implies intermediate values that were never measured.
    for (var i = 0; i < n; i++) {
      final w = barW * 0.56;
      final cx = i * barW + (barW - w) / 2;

      final hP = (primary[i] / maxV) * (size.height - 4) * t;
      if (hP > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(cx, size.height - hP, w, hP),
            const Radius.circular(3),
          ),
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                primaryColor.withValues(alpha: 0.42),
                primaryColor.withValues(alpha: 0.16),
              ],
            ).createShader(Rect.fromLTWH(cx, size.height - hP, w, hP)),
        );
      }
      final s = secondary;
      if (s != null && i < s.length) {
        final hS = (s[i] / maxV) * (size.height - 4) * t;
        if (hS > 0) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(cx, size.height - hS, w, hS),
              const Radius.circular(3),
            ),
            Paint()..color = secondaryColor,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MonthlyPainter old) =>
      old.primary != primary || old.secondary != secondary || old.t != t;
}

/// An indicator drawn against its reference level — as a GAP.
///
/// The point is not the value, it's the distance. A CMHO reporting to the state
/// is asked "why is immunization 79 points below reference", never "what is
/// immunization". A null value renders as an empty track with an em-dash: an
/// unmeasured indicator has no gap, and pretending it sits at zero would invent
/// the largest gap on the screen.
class BenchmarkBar extends StatelessWidget {
  final String label;
  final num? value;
  final num? target;
  final num? min; // range indicators (C-section)
  final num? max;
  final String dir; // up | down | range

  const BenchmarkBar({
    super.key,
    required this.label,
    required this.value,
    this.target,
    this.min,
    this.max,
    this.dir = 'up',
  });

  bool get _meets {
    final v = value;
    if (v == null) return false;
    if (dir == 'range') return v >= (min ?? 0) && v <= (max ?? 100);
    if (dir == 'down') return v <= (target ?? 0);
    return v >= (target ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    final v = value;
    final col = v == null
        ? PanelPalette.textLight
        : _meets
            ? AppColors.safeGreen
            : AppColors.emergencyRed;
    final frac = v == null ? 0.0 : (v / 100).clamp(0.0, 1.0).toDouble();
    final refFrac = dir == 'range'
        ? ((min ?? 0) / 100).clamp(0.0, 1.0).toDouble()
        : ((target ?? 0) / 100).clamp(0.0, 1.0).toDouble();
    final refText = dir == 'range' ? 'লক্ষ্য $min–$max%' : 'লক্ষ্য $target%';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label,
                    style: AppTextStyles.bodySm
                        .copyWith(fontWeight: FontWeight.w600)),
              ),
              Text(v == null ? '—' : '$v%',
                  style: AppTextStyles.label.copyWith(color: col)),
              const SizedBox(width: 8),
              Text(refText,
                  style: AppTextStyles.caption
                      .copyWith(color: PanelPalette.textLight)),
            ],
          ),
          const SizedBox(height: 5),
          LayoutBuilder(builder: (_, box) {
            final w = box.maxWidth;
            return SizedBox(
              height: 10,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: PanelPalette.onBackground.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  if (v != null)
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: frac),
                      duration: Motion.slow,
                      curve: Curves.easeOutCubic,
                      builder: (ctx, f, __) => Container(
                        width: w * (Motion.reduced(ctx) ? frac : f),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            col.withValues(alpha: 0.70),
                            col,
                          ]),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  // The reference marker — the whole reason this widget exists.
                  Positioned(
                    left: (w * refFrac).clamp(0.0, w - 2),
                    child: Container(
                      width: 2,
                      height: 10,
                      color: PanelPalette.onBackground.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Blocks ranked on one metric, worst first, as a horizontal bar chart.
///
/// The district tab already has a ranked table; this is the same data seen
/// rather than read. A CMHO scanning for "which block do I visit on Monday"
/// finds it faster in a shape than in a column of numbers.
class BlockRankChart extends StatelessWidget {
  final List<({String block, num? value, int n})> rows;
  final String suffix;
  final bool higherIsBetter;
  final void Function(String block)? onTap;

  const BlockRankChart({
    super.key,
    required this.rows,
    this.suffix = '%',
    this.higherIsBetter = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final maxV = rows
        .map((r) => r.value ?? 0)
        .fold<num>(1, (a, b) => a > b ? a : b);

    return Column(
      children: rows.map((r) {
        final v = r.value;
        // No denominator is not a score of zero. Grey, and no bar at all.
        final col = v == null
            ? PanelPalette.textLight
            : higherIsBetter
                ? (v >= maxV * 0.75 ? AppColors.safeGreen : AppColors.emergencyRed)
                : (v <= maxV * 0.25 ? AppColors.safeGreen : AppColors.emergencyRed);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: onTap == null ? null : () => onTap!(r.block),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(r.block,
                          style: AppTextStyles.bodySm
                              .copyWith(fontWeight: FontWeight.w600)),
                    ),
                    Text(v == null ? '—' : '$v$suffix',
                        style: AppTextStyles.label.copyWith(color: col)),
                    if (r.n > 0) ...[
                      const SizedBox(width: 6),
                      Text('n=${r.n}',
                          style: AppTextStyles.caption
                              .copyWith(color: PanelPalette.textLight)),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                LayoutBuilder(builder: (_, box) {
                  return Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: PanelPalette.onBackground.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    alignment: Alignment.centerLeft,
                    child: v == null
                        ? null
                        : TweenAnimationBuilder<double>(
                            tween: Tween(
                                begin: 0.0,
                                end: (v / maxV).clamp(0.0, 1.0).toDouble()),
                            duration: Motion.slow,
                            curve: Curves.easeOutCubic,
                            builder: (ctx, f, __) => Container(
                              width: box.maxWidth *
                                  (Motion.reduced(ctx)
                                      ? (v / maxV).clamp(0.0, 1.0).toDouble()
                                      : f),
                              height: 8,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [
                                  col.withValues(alpha: 0.70),
                                  col,
                                ]),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                  );
                }),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
