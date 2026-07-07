import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/services/language_controller.dart';
import '../../../../app/routes.dart';
import '../../../../features/auth/controller/auth_controller.dart';

/// Warm, meaningful maternal splash: a full-screen mother-and-newborn video
/// (muted, watermark removed) under a plum scrim with the brand name fading up.
/// Falls back to the still image if the video can't initialise. Held for a
/// minimum so the clip actually plays, then routes on.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  VideoPlayerController? _ctrl;
  bool _navigated = false;
  DateTime? _start;

  @override
  void initState() {
    super.initState();
    // Suppress the 401→login redirect while the splash plays (a startup sync
    // can reject an expired token before we finish) — this was what cut the
    // clip short before.
    AuthController.splashActive = true;
    _start = DateTime.now();
    final c = VideoPlayerController.asset('assets/video/splash.mp4');
    _ctrl = c;
    c.initialize().then((_) {
      if (!mounted) return;
      c
        ..setVolume(0)
        ..setLooping(false)
        ..play();
      // Navigate a beat after the clip finishes — measured from when it starts
      // playing (not from initState), so slow video-init on budget phones can't
      // cut it short.
      Timer(c.value.duration + const Duration(milliseconds: 500), _go);
      setState(() {});
    }).catchError((_) {
      // Video failed → show the still image and move on shortly.
      Timer(const Duration(milliseconds: 2800), _go);
    });
    // Absolute safety — only fires if the video never initialises at all.
    Timer(const Duration(milliseconds: 9000), _go);
  }

  void _go() {
    if (_navigated || !mounted) return;
    // Keep the splash up for at least ~2.8s so the clip actually plays, even
    // if the player reports "ended" early (decode/render hiccup).
    final elapsed = DateTime.now().difference(_start ?? DateTime.now());
    const minShow = Duration(milliseconds: 2800);
    if (elapsed < minShow) {
      Timer(minShow - elapsed, _go);
      return;
    }
    _navigated = true;
    AuthController.splashActive = false;
    final auth = Get.find<AuthController>();
    if (auth.restoreSession()) {
      Get.offAllNamed(auth.user.value?.isAdmin == true
          ? AppRoutes.adminDashboard
          : AppRoutes.home);
    } else {
      // Onboarded worker who's logged out → login; first-ever launch → language.
      Get.offAllNamed(
          LanguageController.hasChosen ? AppRoutes.login : AppRoutes.language);
    }
  }

  @override
  void dispose() {
    AuthController.splashActive = false;
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
                          shadows: const [
                            Shadow(color: Colors.black45, blurRadius: 12)
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
