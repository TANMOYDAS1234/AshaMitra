import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../app/routes.dart';
import '../../../../features/auth/controller/auth_controller.dart';

/// Warm, meaningful maternal splash: a full-screen mother-and-newborn video
/// (watermark removed, upscaled) under a plum scrim with the brand name fading
/// up. Falls back to the still image if the video can't initialise. Navigates
/// when the clip ends (with a safety timeout).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  VideoPlayerController? _ctrl;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    final c = VideoPlayerController.asset('assets/video/splash.mp4');
    _ctrl = c;
    c.initialize().then((_) {
      if (!mounted) return;
      c
        ..setVolume(0)
        ..setLooping(false)
        ..play();
      c.addListener(_watchEnd);
      setState(() {});
    }).catchError((_) {
      // Video failed → show the still image and move on shortly.
      Timer(const Duration(milliseconds: 2600), _go);
    });
    // Safety: never get stuck on the splash.
    Timer(const Duration(milliseconds: 6300), _go);
  }

  void _watchEnd() {
    final c = _ctrl;
    if (c == null) return;
    final v = c.value;
    if (v.isInitialized &&
        v.duration > Duration.zero &&
        v.position >= v.duration - const Duration(milliseconds: 120)) {
      _go();
    }
  }

  void _go() {
    if (_navigated || !mounted) return;
    _navigated = true;
    final auth = Get.find<AuthController>();
    if (auth.restoreSession()) {
      Get.offAllNamed(
          auth.user.value?.isAdmin == true ? AppRoutes.adminDashboard : AppRoutes.home);
    } else {
      Get.offNamed(AppRoutes.language);
    }
  }

  @override
  void dispose() {
    _ctrl?.removeListener(_watchEnd);
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));

    final c = _ctrl;
    final ready = c != null && c.value.isInitialized;

    return Scaffold(
      backgroundColor: const Color(0xFF2A0E33),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Video (or still-image fallback), full-screen cover.
          if (ready)
            FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: c.value.size.width,
                height: c.value.size.height,
                child: VideoPlayer(c),
              ),
            )
          else
            Image.asset(
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
                      delay: const Duration(milliseconds: 500),
                      child: Text(
                        'আশামিত্র',
                        style: AppTextStyles.display.copyWith(
                          fontSize: 40,
                          color: Colors.white,
                          letterSpacing: 1.0,
                          shadows: const [Shadow(color: Colors.black45, blurRadius: 12)],
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
                          shadows: const [Shadow(color: Colors.black45, blurRadius: 10)],
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
