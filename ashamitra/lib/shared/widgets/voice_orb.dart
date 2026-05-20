import 'dart:math';
import 'package:flutter/material.dart';

enum OrbState { idle, listening, processing }

class VoiceOrb extends StatefulWidget {
  final OrbState state;
  final double size;

  const VoiceOrb({super.key, this.state = OrbState.idle, this.size = 140});

  @override
  State<VoiceOrb> createState() => _VoiceOrbState();
}

class _VoiceOrbState extends State<VoiceOrb> with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _rotateCtrl;
  late AnimationController _glowCtrl;
  late Animation<double> _pulseAnim;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _rotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.93, end: 1.07).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _glowAnim = Tween<double>(begin: 0.25, end: 0.55).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _rotateCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  Color get _orbColor => switch (widget.state) {
        OrbState.listening => const Color(0xFF22C55E),
        OrbState.processing => const Color(0xFF06B6D4),
        OrbState.idle => const Color(0xFF4F46E5),
      };

  IconData get _orbIcon => switch (widget.state) {
        OrbState.listening => Icons.graphic_eq,
        OrbState.processing => Icons.psychology_alt,
        OrbState.idle => Icons.mic,
      };

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnim, _rotateCtrl, _glowAnim]),
      builder: (_, __) {
        return SizedBox(
          width: s * 1.4,
          height: s * 1.4,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow ring
              Container(
                width: s * 1.3,
                height: s * 1.3,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _orbColor.withOpacity(_glowAnim.value),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
              ),
              // Pulsing outer ring
              Transform.scale(
                scale: _pulseAnim.value,
                child: Container(
                  width: s * 1.15,
                  height: s * 1.15,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _orbColor.withOpacity(0.25),
                      width: 2,
                    ),
                  ),
                ),
              ),
              // Rotating sweep gradient ring
              Transform.rotate(
                angle: _rotateCtrl.value * 2 * pi,
                child: Container(
                  width: s,
                  height: s,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        _orbColor.withOpacity(0.0),
                        _orbColor.withOpacity(0.5),
                        _orbColor.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ),
              // Inner core orb
              Transform.scale(
                scale: _pulseAnim.value,
                child: Container(
                  width: s * 0.80,
                  height: s * 0.80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withOpacity(0.95),
                        _orbColor.withOpacity(0.75),
                        _orbColor,
                      ],
                      center: const Alignment(-0.3, -0.4),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _orbColor.withOpacity(0.45),
                        blurRadius: 24,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(_orbIcon, color: Colors.white, size: s * 0.30),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
