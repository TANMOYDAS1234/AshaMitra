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
      const Duration(milliseconds: 2400),
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
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),

                // Orb — fades in, then gently breathes (continuous pulse)
                _Reveal(
                  delay: const Duration(milliseconds: 0),
                  child: const _BreathingOrb(child: VoiceOrb(size: 160)),
                ),
                const SizedBox(height: 40),

                // Title — slides up after orb settles
                _Reveal(
                  delay: const Duration(milliseconds: 350),
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
                  delay: const Duration(milliseconds: 600),
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
                  delay: const Duration(milliseconds: 1000),
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
      ),
    );
  }
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
  late final Animation<double> _scale =
      Tween(begin: 0.94, end: 1.06).animate(
          CurvedAnimation(parent: _c, curve: Curves.easeInOut));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _scale, child: widget.child);
}

/// Internal helper — fades + slides its child in after `delay` ms.
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
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, 0.15),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
