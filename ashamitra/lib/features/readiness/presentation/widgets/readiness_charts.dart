import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../controller/readiness_controller.dart';

/// Colours shared by every readiness visual, so a red square means the same
/// thing on the heatmap, the bar and the drill-down list.
///
/// `unknown` is GREY, never green. A cell we have no report for is not a cell
/// that is fine — that single choice is the difference between a dashboard that
/// tells the truth and one that flatters a district into complacency.
class RColors {
  static const out = AppColors.emergencyRed;
  static const low = AppColors.warning;
  static const ok = AppColors.safeGreen;
  static Color get unknown => AppColors.onBackground.withValues(alpha: 0.10);
}

/// Item × block heatmap — the district in one glance.
///
/// Rows are supplies (critical first), columns are blocks. A CMHO should be able
/// to see "MgSO4 is red across three blocks" without reading a single number,
/// which is something no list of counts has ever achieved.
class SupplyHeatmap extends StatelessWidget {
  final List<ReadinessItem> items;
  final List<ReadinessMatrixRow> matrix;
  final void Function(String block)? onBlockTap;

  const SupplyHeatmap({
    super.key,
    required this.items,
    required this.matrix,
    this.onBlockTap,
  });

  static const double _labelW = 132;
  static const double _cell = 44;
  static const double _rowH = 34;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty || matrix.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Wide grids must scroll inside themselves, never push the page sideways.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Block names across the top.
              Row(
                children: [
                  const SizedBox(width: _labelW),
                  ...matrix.map((m) => SizedBox(
                        width: _cell,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            m.block,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      )),
                ],
              ),
              ...items.map((it) => _row(it)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const _Legend(),
      ],
    );
  }

  Widget _row(ReadinessItem it) => SizedBox(
        height: _rowH,
        child: Row(
          children: [
            SizedBox(
              width: _labelW,
              child: Row(
                children: [
                  if (it.critical)
                    Container(
                      width: 3,
                      height: 16,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: AppColors.emergencyRed,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    )
                  else
                    const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      it.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        fontWeight: it.critical ? FontWeight.w800 : FontWeight.w500,
                        color: it.critical
                            ? AppColors.onBackground
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ...matrix.map((m) => _cellFor(m, it.code)),
          ],
        ),
      );

  Widget _cellFor(ReadinessMatrixRow m, String code) {
    final c = m.cells[code];
    // No report → unknown. Not "ok".
    final Color col = c == null
        ? RColors.unknown
        : c.out > 0
            ? RColors.out
            : c.low > 0
                ? RColors.low
                : c.ok > 0
                    ? RColors.ok
                    : RColors.unknown;
    final n = c == null ? 0 : (c.out > 0 ? c.out : c.low > 0 ? c.low : 0);

    return SizedBox(
      width: _cell,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Material(
          color: col,
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: onBlockTap == null ? null : () => onBlockTap!(m.block),
            child: Center(
              child: n > 0
                  ? Text('$n',
                      style: AppTextStyles.caption.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w800))
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 14,
        runSpacing: 6,
        children: [
          _swatch(RColors.out, 'নেই'),
          _swatch(RColors.low, 'কম'),
          _swatch(RColors.ok, 'আছে'),
          _swatch(RColors.unknown, 'খবর নেই'),
        ],
      );

  Widget _swatch(Color c, String t) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration:
                BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: 5),
          Text(t,
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary)),
        ],
      );
}

/// Coverage donut — who has actually told us anything.
///
/// Deliberately three slices, not two. "Reported" alone would let a district
/// where nobody reports look identical to one where everything is fine.
class CoverageDonut extends StatelessWidget {
  final int reported, stale, never;
  final double size;

  const CoverageDonut({
    super.key,
    required this.reported,
    required this.stale,
    required this.never,
    this.size = 116,
  });

  @override
  Widget build(BuildContext context) {
    final total = reported + stale + never;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DonutPainter(
          slices: [
            (reported.toDouble(), RColors.ok),
            (stale.toDouble(), RColors.low),
            (never.toDouble(), AppColors.textSecondary.withValues(alpha: 0.45)),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(total == 0 ? '—' : '$reported/$total',
                  style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w800)),
              Text('খবর দিয়েছে',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<(double, Color)> slices;
  _DonutPainter({required this.slices});

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<double>(0, (s, e) => s + e.$1);
    final rect = Rect.fromLTWH(0, 0, size.width, size.height).deflate(9);
    final stroke = 14.0;

    if (total <= 0) {
      canvas.drawArc(
        rect,
        0,
        math.pi * 2,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = RColors.unknown,
      );
      return;
    }

    var start = -math.pi / 2;
    for (final (v, c) in slices) {
      if (v <= 0) continue;
      final sweep = (v / total) * math.pi * 2;
      canvas.drawArc(
        rect,
        start,
        sweep - 0.02, // hairline gap so adjacent slices stay legible
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.butt
          ..color = c,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.slices != slices;
}

/// One stacked bar per block — the geography at a glance, worst on top.
class BlockBars extends StatelessWidget {
  final List<ReadinessBlock> blocks;
  final void Function(String block)? onTap;

  const BlockBars({super.key, required this.blocks, this.onTap});

  @override
  Widget build(BuildContext context) => Column(
        children: blocks.map((b) {
          final out = b.criticalOut;
          final low = b.low;
          final unknown = b.unknown;
          // "OK" is what's left of the people who actually reported — never the
          // ones we've heard nothing from.
          final ok = math.max(0, b.reported - (out > 0 ? 1 : 0));
          final total = math.max(1, out + low + unknown + ok);

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              borderRadius: AppRadius.smR,
              onTap: onTap == null ? null : () => onTap!(b.block),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(b.block,
                            style: AppTextStyles.bodySm
                                .copyWith(fontWeight: FontWeight.w700)),
                      ),
                      if (out > 0)
                        Text('$out নেই',
                            style: AppTextStyles.caption.copyWith(
                                color: RColors.out,
                                fontWeight: FontWeight.w800)),
                      if (out == 0 && unknown > 0)
                        Text('$unknown খবর নেই',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 8,
                      child: Row(
                        children: [
                          if (out > 0) Expanded(flex: out * 100 ~/ total + 1, child: Container(color: RColors.out)),
                          if (low > 0) Expanded(flex: low * 100 ~/ total + 1, child: Container(color: RColors.low)),
                          if (ok > 0) Expanded(flex: ok * 100 ~/ total + 1, child: Container(color: RColors.ok)),
                          if (unknown > 0) Expanded(flex: unknown * 100 ~/ total + 1, child: Container(color: RColors.unknown)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      );
}
