import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../app/routes.dart';
import '../../../../features/auth/controller/auth_controller.dart';

/// Warm, meaningful maternal splash: a full-screen mother-and-newborn photo with
/// a slow Ken-Burns zoom, a plum scrim, gentle rising light-motes, and the brand
/// name fading up. (When a splash video is available, swap the image layer for a
/// VideoPlayer — the rest can stay.)
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Slow zoom (Ken Burns) on the photo.
  late final AnimationController _zoom = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3400))
    ..forward();
  late final Animation<double> _scale =
      Tween(begin: 1.0, end: 1.10).animate(
          CurvedAnimation(parent: _zoom, curve: Curves.easeOut));
  // Continuous drift for the light-motes.
  late final AnimationController _motes = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3600))
    ..repeat();
  late final List<_Mote> _moteList;

  @override
  void initState() {
    super.initState();
    final r = math.Random(11);
    _moteList = List.generate(
      12,
      (_) => _Mote(
        x: r.nextDouble(),
        y: r.nextDouble(),
        rad: 1.5 + r.nextDouble() * 3.0,
        speed: 0.2 + r.nextDouble() * 0.4,
        phase: r.nextDouble(),
      ),
    );
    Future.delayed(const Duration(milliseconds: 2900), () {
      final auth = Get.find<AuthController>();
      final hasSession = auth.restoreSession();
      if (hasSession) {
        Get.offAllNamed(
            auth.user.value?.isAdmin == true ? AppRoutes.adminDashboard : AppRoutes.home);
      } else {
        Get.offNamed(AppRoutes.language);
      }
    });
  }

  @override
  void dispose() {
    _zoom.dispose();
    _motes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: const Color(0xFF2A0E33),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Photo with slow Ken-Burns zoom ──
          ScaleTransition(
            scale: _scale,
            child: Image.asset(
              'assets/images/splash_mother.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const DecoratedBox(
                decoration: BoxDecoration(gradient: LinearGradient(
                  colors: [Color(0xFF5B0F69), Color(0xFFBD3773)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight)),
              ),
            ),
          ),

          // ── Plum scrim: darken top (status bar) + bottom (title) ──
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x66300E3A),
                  Color(0x00000000),
                  Color(0x11000000),
                  Color(0xE6260C30),
                ],
                stops: [0.0, 0.32, 0.55, 1.0],
              ),
            ),
          ),

          // ── Gentle rising light-motes ──
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _motes,
              builder: (_, __) =>
                  CustomPaint(painter: _MotePainter(_motes.value, _moteList)),
            ),
          ),

          // ── Brand name + tagline, fading up from the bottom ──
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 54),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Reveal(
                      delay: const Duration(milliseconds: 500),
                      child: Text(
                        'আশামিত্র',
                        style: AppTextStyles.display.copyWith(
                          fontSize: 40,
                          color: Colors.white,
                          letterSpacing: 1.0,
                          shadows: const [
                            Shadow(color: Colors.black45, blurRadius: 12),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _Reveal(
                      delay: const Duration(milliseconds: 850),
                      child: Text(
                        'splash_subtitle'.tr,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyLg.copyWith(
                          color: Colors.white.withValues(alpha: 0.92),
                          letterSpacing: 0.5,
                          shadows: const [
                            Shadow(color: Colors.black45, blurRadius: 10),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Mote {
  final double x, y, rad, speed, phase;
  const _Mote({
    required this.x,
    required this.y,
    required this.rad,
    required this.speed,
    required this.phase,
  });
}

class _MotePainter extends CustomPainter {
  final double t;
  final List<_Mote> motes;
  _MotePainter(this.t, this.motes);

  @override
  void paint(Canvas canvas, Size size) {
    for (final m in motes) {
      final prog = (m.phase + t * m.speed) % 1.0;
      final py = (m.y - prog) % 1.0; // drift upward, wrap
      final fade = math.sin(prog * math.pi).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(m.x * size.width, py * size.height),
        m.rad,
        Paint()..color = const Color(0xFFFCE7F3).withValues(alpha: 0.06 + fade * 0.26),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MotePainter old) => old.t != t;
}

/// Fades + slides its child up after `delay` ms.
class _Reveal extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const _Reveal({required this.child, required this.delay});

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
    return AnimatedOpacity(
      opacity: _visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, 0.4),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
