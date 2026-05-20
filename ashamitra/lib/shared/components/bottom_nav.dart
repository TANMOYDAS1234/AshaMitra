import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/routes.dart';
import '../../core/theme/app_colors.dart';

class BottomNav extends StatelessWidget {
  final int currentIndex;
  const BottomNav({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: 'home'.tr,
                selected: currentIndex == 0,
                onTap: () => Get.offAllNamed(AppRoutes.home),
              ),
              _NavItem(
                icon: Icons.people_rounded,
                label: 'patients'.tr,
                selected: currentIndex == 1,
                onTap: () => Get.toNamed(AppRoutes.patientList),
              ),
              _VoiceNavItem(onTap: () => Get.toNamed(AppRoutes.selectCase)),
              _NavItem(
                icon: Icons.bar_chart_rounded,
                label: 'reports'.tr,
                selected: currentIndex == 3,
                onTap: () => Get.toNamed(AppRoutes.reports),
              ),
              _NavItem(
                icon: Icons.person_rounded,
                label: 'profile'.tr,
                selected: currentIndex == 4,
                onTap: () => Get.toNamed(AppRoutes.profile),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: selected ? AppColors.primary : const Color(0xFF9CA3AF),
                size: 22),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 10,
                  color: selected ? AppColors.primary : const Color(0xFF9CA3AF),
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoiceNavItem extends StatelessWidget {
  final VoidCallback onTap;
  const _VoiceNavItem({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Center(
          child: Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.purple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                    color: Color(0x554F46E5),
                    blurRadius: 10,
                    offset: Offset(0, 3)),
              ],
            ),
            child: const Icon(Icons.mic_rounded, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}
