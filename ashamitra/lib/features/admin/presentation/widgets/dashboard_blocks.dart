import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/panel_palette.dart';
import '../../../../shared/widgets/motion.dart';

/// The dashboard's visual architecture, built to the mockup: a hero band, an
/// asymmetric stat block, and document-style report rows.
///
/// The LAYOUT is taken wholesale from the design — it is better than what was
/// there, and the rhythm of a wide hero over an off-balance grid gives the eye a
/// place to land. What is NOT taken is the mockup's content: its hero read
/// "DISTRICT HEALTH PULSE 84%" and its tiles counted admissions, discharges and
/// lab queues, none of which exist in a field-worker app. Those slots carry real
/// numbers instead. Same shape, no fiction.
///
/// Everything here is written for a 360dp-wide phone and holds at 320dp with the
/// system font scaled up: no fixed heights, long Bengali labels wrap or ellipse,
/// and the big figures shrink to fit rather than overflowing.

/// The hero band.
///
/// Occupies the position the mockup gave to a composite "health score". A single
/// invented percentage is the most dangerous object on a clinical dashboard —
/// authoritative-looking, unauditable, and in this district it would have
/// rendered a calm green 84% above a caseload that is three-quarters RED. The
/// slot instead carries the count of things needing a decision today: same
/// weight, same focal point, and tapping it goes somewhere.
class DashboardHero extends StatelessWidget {
  final int count;
  final String breakdown;
  final VoidCallback? onTap;

  const DashboardHero({
    super.key,
    required this.count,
    required this.breakdown,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final clear = count == 0;
    final tone = clear ? AppColors.safeGreen : AppColors.emergencyRed;

    return Material(
      color: Colors.transparent,
      borderRadius: AppRadius.xxlR,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.xxlR,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
          decoration: BoxDecoration(
            gradient: PanelPalette.brand,
            borderRadius: AppRadius.xxlR,
            boxShadow: AppShadows.tinted(PanelPalette.primary, strength: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(clear ? Icons.verified_rounded : Icons.bolt_rounded,
                      size: 15, color: Colors.white.withValues(alpha: 0.85)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      clear ? 'জেলার অবস্থা' : 'আজ ব্যবস্থা দরকার',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.overline.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  if (onTap != null)
                    Icon(Icons.chevron_right_rounded,
                        color: Colors.white.withValues(alpha: 0.75), size: 20),
                ],
              ),
              const SizedBox(height: 10),
              // Shrinks rather than overflows when the system font is scaled up.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    CountUp(
                      value: count,
                      style: AppTextStyles.display.copyWith(
                        color: Colors.white,
                        fontSize: 46,
                        fontWeight: FontWeight.w800,
                        height: 1.0,
                      ),
                    ),
                    if (!clear) ...[
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('টি বিষয়',
                            style: AppTextStyles.bodyLg.copyWith(
                                color: Colors.white.withValues(alpha: 0.80))),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                clear ? 'এখন জরুরি কিছু নেই' : breakdown,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySm
                    .copyWith(color: Colors.white.withValues(alpha: 0.82)),
              ),
              if (clear) ...[
                const SizedBox(height: 2),
                Text('সব রিপোর্ট ও সরবরাহ ঠিক আছে',
                    style: AppTextStyles.caption
                        .copyWith(color: Colors.white.withValues(alpha: 0.60))),
              ],
              // A hairline strip echoing the band mix, so the hero is not a flat
              // block of colour and the split is legible before the donut below.
              if (!clear) ...[
                const SizedBox(height: 16),
                _HeroSpark(tone: tone),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroSpark extends StatelessWidget {
  final Color tone;
  const _HeroSpark({required this.tone});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: SizedBox(
          height: 5,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Motion.slow,
            curve: Curves.easeOutCubic,
            builder: (ctx, t, child) => Align(
              alignment: Alignment.centerLeft,
              widthFactor: Motion.reduced(ctx) ? 1 : t,
              child: child,
            ),
            child: Container(color: Colors.white.withValues(alpha: 0.28)),
          ),
        ),
      );
}

/// A compact stat card for the asymmetric block.
class MiniStat extends StatelessWidget {
  final String label;
  final num? value;
  final IconData icon;
  final Color accent;
  final String suffix;

  const MiniStat({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    this.suffix = '',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgR,
        boxShadow: AppShadows.low,
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: accent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(icon, size: 14, color: accent),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption
                                  .copyWith(color: PanelPalette.textSecondary)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: CountUp(
                        value: value ?? 0,
                        isNull: value == null,
                        suffix: suffix,
                        style: AppTextStyles.h1.copyWith(
                          color: value == null
                              ? PanelPalette.textLight
                              : PanelPalette.onBackground,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A document-style row for the recent-reports list — the mockup's treatment,
/// which reads calmer than a stack of full cards.
///
/// The band still shows, as a coloured dot rather than a whole stripe: a list of
/// mostly-RED rows drawn as full red cards becomes a wall of alarm, and a wall of
/// alarm is read as wallpaper.
class DocRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String trailing;
  final Color band;
  final IconData icon;
  final VoidCallback? onTap;
  final bool last;

  const DocRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.band,
    required this.icon,
    this.onTap,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: last
                  ? null
                  : Border(
                      bottom: BorderSide(
                          color: PanelPalette.line.withValues(alpha: 0.55))),
            ),
            child: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(color: band, shape: BoxShape.circle),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body.copyWith(
                              fontWeight: FontWeight.w600,
                              color: PanelPalette.onBackground)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption
                              .copyWith(color: PanelPalette.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(trailing,
                    style: AppTextStyles.caption
                        .copyWith(color: PanelPalette.textLight)),
                const SizedBox(width: 8),
                Icon(icon, size: 18, color: PanelPalette.textSecondary),
              ],
            ),
          ),
        ),
      );
}

/// Section heading with an optional trailing action ("সব দেখুন").
class SectionHead extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHead({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.h3
                    .copyWith(color: PanelPalette.onBackground)),
          ),
          if (actionLabel != null)
            InkWell(
              onTap: onAction,
              borderRadius: AppRadius.smR,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(actionLabel!,
                    style: AppTextStyles.label
                        .copyWith(color: PanelPalette.primary)),
              ),
            ),
        ],
      );
}
