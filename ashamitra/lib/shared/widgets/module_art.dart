import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Friendly, flat-vector illustration drawn in code (no image assets) for each
/// visit module / case — a pregnant mother, mother+baby, newborn, young child,
/// or a vaccine. Renders instantly and dynamically; a real PNG dropped at
/// `assets/illustrations/<kind>.png` still takes priority where it's wired.
///
/// `kind` accepts the schedule kinds (anc/pnc/hbnc/hbyc/vaccine) OR the
/// registration case types (Pregnancy/Newborn/Child/Other) — both are mapped.
class ModuleArt extends StatelessWidget {
  final String kind;
  final double height;
  const ModuleArt({super.key, required this.kind, this.height = 150});

  /// Maps a schedule kind OR a registration case type to the canonical asset
  /// key (anc/pnc/hbnc/hbyc/vaccine/other) used for the PNG filename + figure.
  static String kindKey(String k) => switch (k) {
        'Pregnancy' || 'pregnancy' || 'anc' => 'anc',
        'pnc' || 'postpartum' => 'pnc',
        'Newborn' || 'newborn' || 'hbnc' => 'hbnc',
        'Child' || 'child' || 'infant' || 'hbyc' => 'hbyc',
        'vaccine' || 'immunization' => 'vaccine',
        _ => 'other',
      };

  static String _label(String k) => switch (k) {
        'anc' => 'গর্ভবতী মা',
        'pnc' => 'প্রসব-পরবর্তী মা',
        'hbnc' => 'নবজাতক',
        'hbyc' => 'শিশু',
        'vaccine' => 'টিকা',
        _ => 'রোগী',
      };

  @override
  Widget build(BuildContext context) {
    final k = kindKey(kind);
    final (bg1, bg2, fig) = _palette(k);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [bg1, bg2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _ModuleArtPainter(k, fig))),
            // Self-labelling caption so the picture itself names the case.
            Positioned(
              left: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 2)),
                  ],
                ),
                child: Text(
                  _label(k),
                  style: TextStyle(
                      color: fig,
                      fontWeight: FontWeight.w800,
                      fontSize: height < 130 ? 12 : 13.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static (Color, Color, Color) _palette(String k) => switch (k) {
        'anc' => (const Color(0xFFFDE7F0), const Color(0xFFF7CFE2), const Color(0xFFD6638F)),
        'pnc' => (const Color(0xFFF1EAFB), const Color(0xFFDFD0F4), const Color(0xFF8B5CF6)),
        'hbnc' => (const Color(0xFFE6F3FD), const Color(0xFFCAE5FA), const Color(0xFF3E8FD6)),
        'hbyc' => (const Color(0xFFE7F7EE), const Color(0xFFCCEFDC), const Color(0xFF10B981)),
        'vaccine' => (const Color(0xFFE9EAFB), const Color(0xFFD4D8F6), const Color(0xFF6366F1)),
        _ => (const Color(0xFFEEF1F6), const Color(0xFFDDE3EC), const Color(0xFF64748B)),
      };
}

class _ModuleArtPainter extends CustomPainter {
  final String kind;
  final Color fig;
  _ModuleArtPainter(this.kind, this.fig);

  static const _skin = Color(0xFFF3C9A2);
  static const _hair = Color(0xFF4A3B33);
  static const _ink = Color(0xFF3A2E2A);
  static const _cheek = Color(0x33E0607F);

  Paint _fill(Color c) => Paint()..color = c..style = PaintingStyle.fill;
  Paint _stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    _scene(canvas, w, h);
    final cx = w * 0.5;
    switch (kind) {
      case 'anc':
        _pregnant(canvas, cx, h);
        break;
      case 'pnc':
        _motherBaby(canvas, cx, h);
        break;
      case 'hbnc':
        _newborn(canvas, cx, h);
        break;
      case 'hbyc':
        _child(canvas, cx, h);
        break;
      case 'vaccine':
        _syringe(canvas, cx, h);
        break;
      default:
        _face(canvas, Offset(cx, h * 0.46), h * 0.16);
    }
  }

  // ── Warm scene: sun + rays, clouds, grass, sparkles ─────────────────────
  void _scene(Canvas canvas, double w, double h) {
    final soft = Colors.white.withValues(alpha: 0.55);
    // sun + rays (top-right)
    final sc = Offset(w * 0.86, h * 0.22);
    final sr = h * 0.12;
    final ray = _stroke(soft, 3);
    for (int i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(sc + d * (sr * 1.35), sc + d * (sr * 1.75), ray);
    }
    canvas.drawCircle(sc, sr, _fill(Colors.white.withValues(alpha: 0.7)));
    // cloud (top-left)
    _cloud(canvas, Offset(w * 0.20, h * 0.20), h * 0.05, Colors.white.withValues(alpha: 0.55));
    // grass hill
    final hill = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.82)
      ..quadraticBezierTo(w * 0.5, h * 0.66, w, h * 0.82)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(hill, _fill(Colors.white.withValues(alpha: 0.35)));
    final blade = _stroke(Colors.white.withValues(alpha: 0.5), 2.5);
    for (final fx in [0.10, 0.16, 0.86, 0.92]) {
      final bx = w * fx, by = h * 0.86;
      canvas.drawLine(Offset(bx, by), Offset(bx - 3, by - h * 0.07), blade);
      canvas.drawLine(Offset(bx, by), Offset(bx + 3, by - h * 0.07), blade);
    }
    // sparkles
    for (final s in [Offset(w * 0.30, h * 0.34), Offset(w * 0.72, h * 0.48)]) {
      canvas.drawCircle(s, 2.2, _fill(Colors.white.withValues(alpha: 0.8)));
    }
  }

  void _cloud(Canvas canvas, Offset c, double s, Color col) {
    canvas.drawCircle(c, s, _fill(col));
    canvas.drawCircle(c + Offset(s * 0.9, s * 0.15), s * 0.8, _fill(col));
    canvas.drawCircle(c + Offset(-s * 0.9, s * 0.2), s * 0.7, _fill(col));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(c.dx - s * 1.6, c.dy, s * 3.2, s), Radius.circular(s)),
        _fill(col));
  }

  // Friendly face: hair, skin, eyes, smile, cheeks.
  void _face(Canvas canvas, Offset c, double r,
      {bool sleeping = false, bool hair = true, bool bindi = false}) {
    if (hair) {
      canvas.drawCircle(c.translate(0, -r * 0.18), r * 1.14, _fill(_hair));
    }
    canvas.drawCircle(c, r, _fill(_skin));
    if (sleeping) {
      final p = _stroke(_ink, r * 0.12);
      canvas.drawArc(
          Rect.fromCenter(center: c.translate(-r * 0.35, -r * 0.02), width: r * 0.45, height: r * 0.45),
          0.3, 2.5, false, p);
      canvas.drawArc(
          Rect.fromCenter(center: c.translate(r * 0.35, -r * 0.02), width: r * 0.45, height: r * 0.45),
          0.3, 2.5, false, p);
    } else {
      canvas.drawCircle(c.translate(-r * 0.32, -r * 0.05), r * 0.10, _fill(_ink));
      canvas.drawCircle(c.translate(r * 0.32, -r * 0.05), r * 0.10, _fill(_ink));
    }
    canvas.drawArc(
        Rect.fromCenter(center: c.translate(0, r * 0.20), width: r * 0.6, height: r * 0.5),
        0.35, 2.45, false, _stroke(const Color(0xFFB05C5C), r * 0.10));
    canvas.drawCircle(c.translate(-r * 0.55, r * 0.18), r * 0.14, _fill(_cheek));
    canvas.drawCircle(c.translate(r * 0.55, r * 0.18), r * 0.14, _fill(_cheek));
    if (bindi) {
      canvas.drawCircle(c.translate(0, -r * 0.45), r * 0.07, _fill(const Color(0xFFD6638F)));
    }
  }

  // Pregnant mother — dress + belly + hand resting on belly + face.
  void _pregnant(Canvas canvas, double cx, double h) {
    final p = _fill(fig);
    final dress = Path()
      ..moveTo(cx - 11, h * 0.42)
      ..quadraticBezierTo(cx, h * 0.36, cx + 11, h * 0.42)
      ..lineTo(cx + 26, h * 0.88)
      ..lineTo(cx - 22, h * 0.88)
      ..close();
    canvas.drawPath(dress, p);
    canvas.drawCircle(Offset(cx + 17, h * 0.62), h * 0.135, p); // belly
    canvas.drawCircle(Offset(cx + 30, h * 0.66), h * 0.035, _fill(_skin)); // hand
    _face(canvas, Offset(cx, h * 0.28), h * 0.105, bindi: true);
  }

  // Mother holding a swaddled baby.
  void _motherBaby(Canvas canvas, double cx, double h) {
    final p = _fill(fig);
    final dress = Path()
      ..moveTo(cx - 13, h * 0.42)
      ..quadraticBezierTo(cx - 3, h * 0.36, cx + 7, h * 0.42)
      ..lineTo(cx + 24, h * 0.88)
      ..lineTo(cx - 25, h * 0.88)
      ..close();
    canvas.drawPath(dress, p);
    _face(canvas, Offset(cx - 4, h * 0.28), h * 0.10, bindi: true);
    // baby bundle in arms
    canvas.drawCircle(Offset(cx + 16, h * 0.60), h * 0.115, _fill(Color.lerp(fig, Colors.white, 0.45)!));
    _face(canvas, Offset(cx + 16, h * 0.555), h * 0.05, sleeping: true, hair: false);
  }

  // Swaddled newborn with a cap + sleeping face.
  void _newborn(Canvas canvas, double cx, double h) {
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, h * 0.64), width: h * 0.34, height: h * 0.46),
      Radius.circular(h * 0.17),
    );
    canvas.drawRRect(body, _fill(fig));
    // little folded-arm hint
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(cx, h * 0.60), width: h * 0.22, height: h * 0.10),
            Radius.circular(h * 0.05)),
        _fill(Color.lerp(fig, Colors.white, 0.25)!));
    _face(canvas, Offset(cx, h * 0.36), h * 0.125, sleeping: true, hair: false);
    // cap
    final cap = Path()
      ..moveTo(cx - h * 0.13, h * 0.33)
      ..arcToPoint(Offset(cx + h * 0.13, h * 0.33), radius: Radius.circular(h * 0.13))
      ..close();
    canvas.drawPath(cap, _fill(fig));
    canvas.drawCircle(Offset(cx, h * 0.22), h * 0.022, _fill(Color.lerp(fig, Colors.white, 0.5)!)); // pom
  }

  // Young child — head, shirt, shorts, arms, legs.
  void _child(Canvas canvas, double cx, double h) {
    final shirt = _fill(fig);
    final skin = _fill(_skin);
    final shorts = _fill(Color.lerp(fig, _ink, 0.35)!);
    // legs
    for (final dx in [-h * 0.08, h * 0.01]) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(cx + dx, h * 0.74, h * 0.07, h * 0.16),
              Radius.circular(h * 0.035)), skin);
    }
    // shorts
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(cx, h * 0.70), width: h * 0.26, height: h * 0.14),
            Radius.circular(h * 0.04)),
        shorts);
    // arms
    for (final dx in [-h * 0.18, h * 0.18]) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset(cx + dx, h * 0.56), width: h * 0.06, height: h * 0.20),
              Radius.circular(h * 0.03)), skin);
    }
    // shirt
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(cx, h * 0.58), width: h * 0.30, height: h * 0.32),
            Radius.circular(h * 0.10)),
        shirt);
    _face(canvas, Offset(cx, h * 0.32), h * 0.12);
  }

  // Vaccine: a friendly syringe with gradations + a smiling droplet + sparkles.
  void _syringe(Canvas canvas, double cx, double h) {
    final light = Color.lerp(fig, Colors.white, 0.45)!;
    canvas.save();
    canvas.translate(cx - h * 0.05, h * 0.5);
    canvas.rotate(-math.pi / 5);
    // barrel
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: h * 0.5, height: h * 0.21),
            Radius.circular(h * 0.04)),
        _fill(light));
    // gradation marks
    final mk = _stroke(fig.withValues(alpha: 0.7), 2);
    for (int i = -1; i <= 2; i++) {
      final x = i * h * 0.08;
      canvas.drawLine(Offset(x, -h * 0.04), Offset(x, h * 0.04), mk);
    }
    // plunger
    canvas.drawRect(Rect.fromLTWH(-h * 0.42, -h * 0.055, h * 0.16, h * 0.11), _fill(fig));
    canvas.drawRect(Rect.fromLTWH(-h * 0.48, -h * 0.10, h * 0.05, h * 0.20), _fill(fig));
    // needle hub + needle
    canvas.drawRect(Rect.fromLTWH(h * 0.25, -h * 0.02, h * 0.05, h * 0.04), _fill(fig));
    canvas.drawRect(Rect.fromLTWH(h * 0.30, -h * 0.008, h * 0.16, h * 0.016), _fill(fig));
    canvas.restore();
    // smiling droplet
    final dc = Offset(cx + h * 0.34, h * 0.30);
    final dr = h * 0.07;
    final drop = Path()
      ..moveTo(dc.dx, dc.dy - dr * 1.6)
      ..quadraticBezierTo(dc.dx + dr * 1.3, dc.dy + dr * 0.4, dc.dx, dc.dy + dr)
      ..quadraticBezierTo(dc.dx - dr * 1.3, dc.dy + dr * 0.4, dc.dx, dc.dy - dr * 1.6)
      ..close();
    canvas.drawPath(drop, _fill(fig));
    canvas.drawCircle(dc.translate(-dr * 0.3, -dr * 0.1), dr * 0.12, _fill(Colors.white));
    canvas.drawCircle(dc.translate(dr * 0.3, -dr * 0.1), dr * 0.12, _fill(Colors.white));
  }

  @override
  bool shouldRepaint(covariant _ModuleArtPainter old) =>
      old.kind != kind || old.fig != fig;
}
