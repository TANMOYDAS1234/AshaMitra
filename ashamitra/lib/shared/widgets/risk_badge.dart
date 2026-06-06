import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';

enum RiskLevel { safe, moderate, high, emergency }

/// Pill-shaped triage band indicator. Pulses gently on `emergency` to draw
/// attention without being distracting.
class RiskBadge extends StatefulWidget {
  final RiskLevel level;
  const RiskBadge({super.key, required this.level});

  @override
  State<RiskBadge> createState() => _RiskBadgeState();
}

class _RiskBadgeState extends State<RiskBadge> with SingleTickerProviderStateMixin {
  AnimationController? _pulseCtrl;
  Animation<double>? _pulseAnim;

  @override
  void initState() {
    super.initState();
    if (widget.level == RiskLevel.emergency) _startPulse();
  }

  @override
  void didUpdateWidget(covariant RiskBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.level == RiskLevel.emergency && _pulseCtrl == null) {
      _startPulse();
    } else if (widget.level != RiskLevel.emergency && _pulseCtrl != null) {
      _pulseCtrl?.dispose();
      _pulseCtrl = null;
      _pulseAnim = null;
    }
  }

  void _startPulse() {
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseCtrl!, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _pulseCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (widget.level) {
      RiskLevel.safe => ('risk_safe'.tr, AppColors.safeGreen, Icons.check_circle_outline_rounded),
      RiskLevel.moderate => ('risk_moderate'.tr, AppColors.warningYellow, Icons.warning_amber_outlined),
      RiskLevel.high => ('risk_high'.tr, const Color(0xFFF97316), Icons.error_outline_rounded),
      RiskLevel.emergency => ('risk_emergency'.tr, AppColors.emergencyRed, Icons.emergency_outlined),
    };

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.pillR,
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );

    if (_pulseAnim == null) return badge;

    return AnimatedBuilder(
      animation: _pulseAnim!,
      builder: (_, __) => Transform.scale(scale: _pulseAnim!.value, child: badge),
    );
  }
}
