import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../app/routes.dart';
import '../../../../shared/widgets/voice_orb.dart';
import '../../../../features/auth/controller/auth_controller.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(
      const Duration(milliseconds: 2800),
      () {
        final auth = Get.find<AuthController>();
        final hasSession = auth.restoreSession();
        if (hasSession) {
          if (auth.user.value?.isAdmin == true) {
            Get.offAllNamed(AppRoutes.adminDashboard);
          } else {
            Get.offAllNamed(AppRoutes.home);
          }
        } else {
          Get.offNamed(AppRoutes.language);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.splash),
        child: Stack(
          children: [
            // Animated backdrop: heartbeat ripple rings + drifting particles.
            const Positioned.fill(child: _SplashBackdrop()),
            SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),

                    // Orb — elastic pop-in, then a continuous breathing pulse.
                    _Reveal(
                      delay: const Duration(milliseconds: 0),
                      scaleIn: true,
                      child: const _BreathingOrb(child: VoiceOrb(size: 160)),
                    ),
                    const SizedBox(height: 40),

                    // Title — slides up after orb settles
                    _Reveal(
                      delay: const Duration(milliseconds: 400),
                      child: Text(
                        'ASHA Mitra',
                        style: AppTextStyles.display.copyWith(
                          fontSize: 38,
                          color: Colors.white,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Subtitle — lags title slightly
                    _Reveal(
                      delay: const Duration(milliseconds: 650),
                      child: Text(
                        'splash_subtitle'.tr,
                        style: AppTextStyles.bodyLg.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Tagline — appears last
                    _Reveal(
                      delay: const Duration(milliseconds: 1050),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 32),
                        child: Text(
                          'splash_tagline'.tr,
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
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

/// Full-bleed animated backdrop — expanding heartbeat rings from the centre
/// plus a field of slowly drifting light particles. One controller drives both.
class _SplashBackdrop extends StatefulWidget {
  const _SplashBackdrop();
  @override
  State<_SplashBackdrop> createState() => _SplashBackdropState();
}

class _SplashBackdropState extends State<_SplashBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3200))
    ..repeat();
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    final r = math.Random(7);
    _particles = List.generate(
      16,
      (_) => _Particle(
        x: r.nextDouble(),
        y: r.nextDouble(),
        r: 1.5 + r.nextDouble() * 3.5,
        speed: 0.25 + r.nextDouble() * 0.55,
        drift: (r.nextDouble() - 0.5) * 0.05,
        phase: r.nextDouble(),
      ),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, __) =>
            CustomPaint(painter: _BackdropPainter(_c.value, _particles)),
      );
}

class _Particle {
  final double x, y, r, speed, drift, phase;
  const _Particle({
    required this.x,
    required this.y,
    required this.r,
    required this.speed,
    required this.drift,
    required this.phase,
  });
}

class _BackdropPainter extends CustomPainter {
  final double t; // 0..1 repeating
  final List<_Particle> particles;
  _BackdropPainter(this.t, this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final centre = Offset(w * 0.5, h * 0.40);
    final maxR = math.max(w, h) * 0.55;

    // Heartbeat ripple rings — 3 rings staggered by 1/3 phase.
    for (int i = 0; i < 3; i++) {
      final p = (t + i / 3) % 1.0;
      final radius = maxR * (0.15 + p * 0.85);
      final alpha = (1.0 - p) * 0.22;
      if (alpha <= 0) continue;
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..color = Colors.white.withValues(alpha: alpha),
      );
    }

    // Drifting light particles (wrap vertically).
    for (final pt in particles) {
      final prog = (pt.phase + t * pt.speed) % 1.0;
      final py = (pt.y - prog) % 1.0; // upward drift, wraps
      final px = (pt.x + math.sin((t + pt.phase) * math.pi * 2) * pt.drift) % 1.0;
      final fade = (math.sin(prog * math.pi)).clamp(0.0, 1.0); // fade in/out over life
      canvas.drawCircle(
        Offset(px * w, py * h),
        pt.r,
        Paint()..color = Colors.white.withValues(alpha: 0.10 + fade * 0.28),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter old) => old.t != t;
}

/// Continuous gentle "breathing" pulse (scale) — gives the splash orb life.
class _BreathingOrb extends StatefulWidget {
  final Widget child;
  const _BreathingOrb({required this.child});
  @override
  State<_BreathingOrb> createState() => _BreathingOrbState();
}

class _BreathingOrbState extends State<_BreathingOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800))
    ..repeat(reverse: true);
  late final Animation<double> _scale = Tween(begin: 0.94, end: 1.06)
      .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _scale, child: widget.child);
}

/// Internal helper — fades + slides (and optionally elastically scales) its
/// child in after `delay` ms.
class _Reveal extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final bool scaleIn;
  const _Reveal({required this.child, required this.delay, this.scaleIn = false});

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget child = widget.child;
    if (widget.scaleIn) {
      child = AnimatedScale(
        scale: _visible ? 1.0 : 0.5,
        duration: const Duration(milliseconds: 750),
        curve: Curves.elasticOut,
        child: child,
      );
    }
    return AnimatedOpacity(
      opacity: _visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, 0.15),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        child: child,
      ),
    );
  }
}
