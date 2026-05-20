import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_gradients.dart';
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
      const Duration(seconds: 2),
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
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.splash),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                const VoiceOrb(size: 160),
                const SizedBox(height: 40),
                const Text(
                  'ASHA Mitra',
                  style: TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Voice AI for Safer Care',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.80),
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: Text(
                    'Powered by AI · Works Offline · Bangla First',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.45),
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
