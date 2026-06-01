import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_colors.dart';

enum TriageOutcome { safe, attention, emergency }

class TriageResultCard extends StatelessWidget {
  final TriageOutcome outcome;
  final String reason;
  final String nextStep;

  const TriageResultCard({
    super.key,
    required this.outcome,
    required this.reason,
    required this.nextStep,
  });

  @override
  Widget build(BuildContext context) {
    final cfg = _config(outcome);

    // Entrance animation — card eases up + fades in on first render.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      builder: (_, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 16),
          child: Transform.scale(scale: 0.96 + 0.04 * t, child: child),
        ),
      ),
      // ── Outer band-coloured rounded container ─────────────────────────
      // Whole card wears the band colour so the worker can read the band
      // (RED / YELLOW / GREEN) at a glance even with the phone halfway
      // out of their bag. Inset cards inside this container carry the
      // reason + next step in higher-contrast white so the wording is
      // also legible.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Safe-band celebration ripples — kept from previous version.
            if (outcome == TriageOutcome.safe)
              const Positioned.fill(child: _CelebrationBurst()),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: cfg.color,
                boxShadow: [
                  BoxShadow(
                    color: cfg.color.withValues(alpha: 0.30),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header row: dot + title + subtitle + referral chip ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: outcome == TriageOutcome.emergency
                            ? const _PulseDot(color: Colors.white)
                            : outcome == TriageOutcome.safe
                                ? const _BouncyCheck()
                                : Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.9),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cfg.bandLabel,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.3,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              cfg.subtitle,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.92),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Referral level pill — top-right, matches design's
                      // rounded translucent badge ("FRU / SNCU / DH" etc).
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.55),
                              width: 1.2),
                        ),
                        child: Text(
                          cfg.referralLevel,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // ── Reason inset card ──────────────────────────────────
                  _InsetCard(
                    icon: Icons.info_outline_rounded,
                    label: 'result_reason'.tr,
                    value: reason,
                    color: cfg.color,
                  ),
                  const SizedBox(height: 10),
                  // ── Next-step inset card ───────────────────────────────
                  _InsetCard(
                    icon: Icons.arrow_forward_ios_rounded,
                    label: 'result_next_step'.tr,
                    value: nextStep,
                    color: cfg.color,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static _BandConfig _config(TriageOutcome outcome) => switch (outcome) {
        TriageOutcome.safe => _BandConfig(
            color: AppColors.safeGreen,
            bg: const Color(0xFFECFDF5),
            bandLabel: '🟢 সবুজ — নিরাপদ',
            subtitle: 'result_safe_subtitle'.tr,
            referralLevel: 'result_safe_referral'.tr,
          ),
        TriageOutcome.attention => _BandConfig(
            color: const Color(0xFFD97706),
            bg: const Color(0xFFFFFBEB),
            bandLabel: '🟡 হলুদ — মনোযোগ দরকার',
            subtitle: 'result_attention_subtitle'.tr,
            referralLevel: 'result_attention_referral'.tr,
          ),
        TriageOutcome.emergency => _BandConfig(
            color: AppColors.emergencyRed,
            bg: const Color(0xFFFFEBEB),
            bandLabel: '🔴 লাল — জরুরি অবস্থা',
            subtitle: 'result_emergency_subtitle'.tr,
            referralLevel: 'FRU / SNCU / DH',
          ),
      };
}

class _BandConfig {
  final Color color;
  final Color bg;
  final String bandLabel;
  final String subtitle;
  final String referralLevel;
  const _BandConfig({
    required this.color,
    required this.bg,
    required this.bandLabel,
    required this.subtitle,
    required this.referralLevel,
  });
}

// ── Inset card — white panel inside the band-coloured outer card ────────────
// Carries the reason / next-step content. The icon sits in a tinted
// rounded box (lighter shade of the band colour) so it pops without
// fighting the outer band. Text inside is high-contrast dark on white,
// because comprehension matters more than aesthetics for a worker
// reading this in a poorly-lit hut.
class _InsetCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InsetCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        // Very light tint of the band colour — keeps the inset visually
        // connected to the band without obscuring the white-card feel
        // from the design.
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.onBackground,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Animated pulse dot for RED band ──────────────────────────────────────────
class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.8, end: 1.3).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 14, height: 14,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.6),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bouncy checkmark for SAFE band ───────────────────────────────────────────
// One-shot scale-in + tiny spring overshoot — celebratory but not distracting.
class _BouncyCheck extends StatefulWidget {
  const _BouncyCheck();

  @override
  State<_BouncyCheck> createState() => _BouncyCheckState();
}

class _BouncyCheckState extends State<_BouncyCheck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 22, height: 22,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.5),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: const Icon(Icons.check_rounded, size: 16, color: AppColors.safeGreen),
      ),
    );
  }
}

// ── Celebration burst — concentric rings rippling outward, behind GREEN banner.
// Drawn as a soft animated overlay; never covers text (uses alpha < 0.35).
class _CelebrationBurst extends StatefulWidget {
  const _CelebrationBurst();

  @override
  State<_CelebrationBurst> createState() => _CelebrationBurstState();
}

class _CelebrationBurstState extends State<_CelebrationBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _BurstPainter(progress: _ctrl.value),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  final double progress; // 0..1
  _BurstPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width * 0.18, size.height / 2);
    final maxR = math.max(size.width, size.height) * 0.9;

    // 3 staggered rings — each starts at a different phase.
    for (int i = 0; i < 3; i++) {
      final phase = (progress + i / 3) % 1.0;
      final r = phase * maxR;
      final alpha = (1 - phase) * 0.28;
      if (alpha <= 0.01) continue;
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(centre, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter old) => old.progress != progress;
}
