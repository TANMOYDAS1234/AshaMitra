import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../app/routes.dart';
import '../../../../features/auth/controller/auth_controller.dart';

/// Warm, meaningful maternal splash: the mother-and-newborn photo with a slow
/// Ken Burns push-in under a plum scrim, and the brand name fading up. Uses a
/// still image + transform (not video) so it renders reliably on every device
/// — video_player was black/glitchy on some budget MediaTek GPUs. Navigates
/// after a short hold.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ken;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    // Suppress the 401→login redirect while the splash plays (a startup sync
    // can reject an expired token before we finish).
    AuthController.splashActive = true;
    _ken = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..forward();
    // Hold the splash long enough for the reveal to read, then route on.
    Timer(const Duration(milliseconds: 3200), _go);
  }

  void _go() {
    if (_navigated || !mounted) return;
    _navigated = true;
    AuthController.splashActive = false;
    final auth = Get.find<AuthController>();
    if (auth.restoreSession()) {
      Get.offAllNamed(auth.user.value?.isAdmin == true
          ? AppRoutes.adminDashboard
          : AppRoutes.home);
    } else {
      Get.offNamed(AppRoutes.language);
    }
  }

  @override
  void dispose() {
    AuthController.splashActive = false;
    _ken.dispose();
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
          // Ken Burns: a slow zoom + upward drift on the maternal photo so the
          // splash feels alive without relying on video decoding.
          AnimatedBuilder(
            animation: _ken,
            builder: (_, child) {
              final t = Curves.easeInOut.transform(_ken.value);
              return Transform.translate(
                offset: Offset(0, -16 * t),
                child: Transform.scale(scale: 1.06 + 0.16 * t, child: child),
              );
            },
            child: Image.asset(
              'assets/images/splash_mother.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const DecoratedBox(
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [Color(0xFF5B0F69), Color(0xFFBD3773)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight)),
              ),
            ),
          ),

          // Plum scrim: darken top (status bar) + bottom (title).
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x55300E3A),
                  Color(0x00000000),
                  Color(0x11000000),
                  Color(0xE6260C30),
                ],
                stops: [0.0, 0.32, 0.55, 1.0],
              ),
            ),
          ),

          // Brand name + tagline, fading up from the bottom.
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 54),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Reveal(
                      delay: const Duration(milliseconds: 400),
                      child: Text(
                        'আশামিত্র',
                        style: AppTextStyles.display.copyWith(
                          fontSize: 40,
                          color: Colors.white,
                          letterSpacing: 1.0,
                          shadows: const [
                            Shadow(color: Colors.black45, blurRadius: 12)
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _Reveal(
                      delay: const Duration(milliseconds: 750),
                      child: Text(
                        'splash_subtitle'.tr,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyLg.copyWith(
                          color: Colors.white.withValues(alpha: 0.92),
                          letterSpacing: 0.5,
                          shadows: const [
                            Shadow(color: Colors.black45, blurRadius: 10)
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

/// Fades + slides its child up after `delay`.
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
