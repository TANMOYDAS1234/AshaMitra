import 'package:flutter/material.dart';

/// Motion primitives for the officer panels.
///
/// Every animation here does a job. None loops, none spins, none costs frame
/// time after it has finished:
///
///   CountUp        the eye lands on the number that changed
///   RevealIn       staggered entry establishes reading order — the most urgent
///                  card arrives first, so the order is felt, not just read
///   GrowBar        a bar drawing to its length shows magnitude building
///   AttentionPulse ONE pulse on something critical, then still forever
///
/// Deliberately no 3D transforms. These run on 720x1600 budget Androids in
/// villages, often on battery, and a perspective transform costs real frame time
/// and heat on exactly the hardware that can least afford it. An officer scanning
/// for a stockout does not want a chart rotating at her.
///
/// All of it respects the platform's reduce-motion setting: when animation is
/// disabled system-wide, each of these renders its final state instantly rather
/// than a degraded animation.
class Motion {
  Motion._();

  static const fast = Duration(milliseconds: 220);
  static const base = Duration(milliseconds: 420);
  static const slow = Duration(milliseconds: 700);

  /// Stagger step between siblings. Long enough to read as a sequence, short
  /// enough that a six-item list is fully present in a quarter of a second.
  static const stagger = Duration(milliseconds: 45);

  static bool reduced(BuildContext c) =>
      MediaQuery.maybeOf(c)?.disableAnimations ?? false;
}

/// A number that counts up to its value.
///
/// Re-animates when [value] changes, so a refresh visibly moves the figure
/// rather than swapping it silently — on a dashboard read at a glance, a number
/// that changed without being seen to change may as well not have.
class CountUp extends StatelessWidget {
  final num value;
  final TextStyle? style;
  final String suffix;
  final int decimals;

  /// Rendered instead of the number when [value] is null — a metric with no
  /// denominator is unmeasured, and must never animate up to a confident zero.
  final bool isNull;

  const CountUp({
    super.key,
    required this.value,
    this.style,
    this.suffix = '',
    this.decimals = 0,
    this.isNull = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isNull) return Text('—', style: style);
    if (Motion.reduced(context)) {
      return Text('${value.toStringAsFixed(decimals)}$suffix', style: style);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: Motion.slow,
      curve: Curves.easeOutCubic,
      builder: (_, v, __) =>
          Text('${v.toStringAsFixed(decimals)}$suffix', style: style),
    );
  }
}

/// Fade + slight rise on first build. Pass [index] to stagger a list.
class RevealIn extends StatefulWidget {
  final Widget child;
  final int index;
  final double offsetY;

  const RevealIn({
    super.key,
    required this.child,
    this.index = 0,
    this.offsetY = 14,
  });

  @override
  State<RevealIn> createState() => _RevealInState();
}

class _RevealInState extends State<RevealIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: Motion.base);

  @override
  void initState() {
    super.initState();
    // Cap the stagger so a long list does not leave the last item arriving a
    // second and a half after the first. Past ~10 items the sequence has already
    // done its job.
    final delay = Motion.stagger * widget.index.clamp(0, 10);
    Future.delayed(delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return widget.child;
    final curved = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return AnimatedBuilder(
      animation: curved,
      builder: (_, child) => Opacity(
        opacity: curved.value,
        child: Transform.translate(
          offset: Offset(0, widget.offsetY * (1 - curved.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// A horizontal bar that grows to [fraction] of its track.
class GrowBar extends StatelessWidget {
  final double fraction; // 0..1
  final Color color;
  final double height;
  final Color? track;

  const GrowBar({
    super.key,
    required this.fraction,
    required this.color,
    this.height = 8,
    this.track,
  });

  @override
  Widget build(BuildContext context) {
    final f = fraction.clamp(0.0, 1.0);
    return LayoutBuilder(builder: (_, box) {
      final bar = Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(height / 2),
        ),
      );
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: track ?? Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(height / 2),
        ),
        alignment: Alignment.centerLeft,
        child: Motion.reduced(context)
            ? SizedBox(width: box.maxWidth * f, height: height, child: bar)
            : TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: f),
                duration: Motion.slow,
                curve: Curves.easeOutCubic,
                builder: (_, v, __) =>
                    SizedBox(width: box.maxWidth * v, height: height, child: bar),
              ),
      );
    });
  }
}

/// One pulse, then still. For a card that must be noticed on arrival.
///
/// Deliberately not a loop: a looping highlight on a clinical screen becomes
/// visual noise within seconds and trains the eye to ignore exactly the thing it
/// was meant to emphasise.
class AttentionPulse extends StatefulWidget {
  final Widget child;
  final bool active;

  const AttentionPulse({super.key, required this.child, this.active = true});

  @override
  State<AttentionPulse> createState() => _AttentionPulseState();
}

class _AttentionPulseState extends State<AttentionPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    if (widget.active) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active || Motion.reduced(context)) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        // Rise to 1 and settle back to 0 — a single breath.
        final t = _c.value;
        final s = 1 + 0.012 * (t < 0.5 ? t * 2 : (1 - t) * 2);
        return Transform.scale(scale: s, child: child);
      },
      child: widget.child,
    );
  }
}
