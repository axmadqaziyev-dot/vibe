import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'vibe_design.dart';

/// Xoş gəldin ekranının illüstrasiyası — səsli otaq səhnəsi.
///
/// Tamamilə koddan çəkilir: şəkil faylı yoxdur, ona görə tətbiqin ölçüsü
/// artmır və hər ekran sıxlığında kəskin görünür.
class VibeWelcomeArt extends StatefulWidget {
  const VibeWelcomeArt({super.key, this.height = 300});

  final double height;

  @override
  State<VibeWelcomeArt> createState() => _VibeWelcomeArtState();
}

class _VibeWelcomeArtState extends State<VibeWelcomeArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          painter: _WelcomeArtPainter(_c.value),
          isComplex: true,
        ),
      ),
    );
  }
}

const Size _design = Size(320, 300);

class _WelcomeArtPainter extends CustomPainter {
  _WelcomeArtPainter(this.t);

  /// 0..1 arası təkrarlanan animasiya vaxtı.
  final double t;

  double _bob(double phase, [double amount = 6]) =>
      math.sin((t + phase) * 2 * math.pi) * amount;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / _design.width, size.height / _design.height);
    canvas.save();
    canvas.translate(
      (size.width - _design.width * scale) / 2,
      (size.height - _design.height * scale) / 2,
    );
    canvas.scale(scale);

    _rings(canvas);
    _stage(canvas);

    // Arxa sıradakı iki nəfər — daha kiçik, daha sakit.
    _person(canvas,
        head: Offset(92, 92 + _bob(.15, 5)),
        r: 13,
        body: const Color(0xff22a7ff),
        skin: const Color(0xfff0c9a4),
        hair: const Color(0xff2a1f3d));
    _person(canvas,
        head: Offset(230, 86 + _bob(.55, 5)),
        r: 13,
        body: const Color(0xffffd458),
        skin: const Color(0xff8d5a3b),
        hair: const Color(0xff1d1526));

    // Yanlardakı dinləyicilər.
    _person(canvas,
        head: Offset(56, 170 + _bob(.35, 7)),
        r: 17,
        body: const Color(0xff2de28a),
        skin: const Color(0xffc98d63),
        hair: const Color(0xff241a33));
    _person(canvas,
        head: Offset(264, 166 + _bob(.75, 7)),
        r: 17,
        body: const Color(0xffff657b),
        skin: const Color(0xfff2d2b6),
        hair: const Color(0xff3a2418));

    // Mərkəzdəki danışan — qulaqlıq və səs halqası ilə.
    final mainDy = _bob(0, 8);
    _speakingRing(canvas, Offset(160, 150 + mainDy));
    _person(canvas,
        head: Offset(160, 138 + mainDy),
        r: 27,
        body: const Color(0xff8b5cff),
        skin: const Color(0xffe8b98f),
        hair: const Color(0xff211732),
        headphones: true);

    _chatBubble(canvas, Offset(250, 202 + _bob(.45, 5)));
    _heart(canvas, Offset(60, 108 + _bob(.65, 6)), 13);
    _note(canvas, Offset(256, 126 + _bob(.25, 6)));
    _coin(canvas, Offset(30, 192 + _bob(.85, 5)), 11);
    _sparkle(canvas, const Offset(122, 40), 7 + math.sin(t * 2 * math.pi) * 2.5);
    _sparkle(canvas, const Offset(232, 258), 6 + math.cos(t * 2 * math.pi) * 2.5,
        vPink);
    _sparkle(canvas, const Offset(30, 60), 5);
    _confetti(canvas);

    canvas.restore();
  }

  void _rings(Canvas canvas) {
    const center = Offset(160, 148);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (final r in const [72.0, 104.0, 136.0]) {
      stroke.color = vPurple.withValues(alpha: r == 72 ? .30 : .14);
      canvas.drawCircle(center, r, stroke);
    }
    canvas.drawCircle(
      center,
      118,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x448b5cff), Color(0x00000000)],
        ).createShader(Rect.fromCircle(center: center, radius: 118)),
    );
  }

  void _stage(Canvas canvas) {
    final rect = Rect.fromCenter(
      center: const Offset(160, 236),
      width: 216,
      height: 26,
    );
    canvas.drawOval(
      rect,
      Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12)
        ..shader = const LinearGradient(colors: [
          Color(0x0022a7ff),
          Color(0x99ff2bd6),
          Color(0x008b5cff),
        ]).createShader(rect),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(160, 236), width: 122, height: 6),
      Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
        ..color = vPink.withValues(alpha: .34),
    );
  }

  void _speakingRing(Canvas canvas, Offset center) {
    // İki halqa növbə ilə genişlənib sönür — mikrofonun aktiv olduğunu göstərir.
    for (var i = 0; i < 2; i++) {
      final p = ((t + i * .5) % 1.0);
      final radius = 44 + p * 34;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = vPink.withValues(alpha: (1 - p) * .45),
      );
    }
  }

  void _person(
    Canvas canvas, {
    required Offset head,
    required double r,
    required Color body,
    required Color skin,
    required Color hair,
    bool headphones = false,
  }) {
    final bodyTop = head.dy + r * .5;
    final bodyRect = RRect.fromLTRBAndCorners(
      head.dx - r * 1.12,
      bodyTop,
      head.dx + r * 1.12,
      bodyTop + r * 1.95,
      topLeft: Radius.circular(r * .9),
      topRight: Radius.circular(r * .9),
      bottomLeft: Radius.circular(r * .45),
      bottomRight: Radius.circular(r * .45),
    );
    canvas.drawRRect(
      bodyRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [body, Color.lerp(body, Colors.black, .35)!],
        ).createShader(bodyRect.outerRect),
    );

    canvas.drawCircle(head, r, Paint()..color = skin);

    // Saç — yalnız başın üst hissəsini örtən qapaq (üz açıq qalır).
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: head, radius: r)));
    canvas.drawCircle(
      head.translate(0, -r * 1.02),
      r,
      Paint()..color = hair,
    );
    canvas.restore();

    // Üz — iki göz və təbəssüm.
    final eye = Paint()..color = const Color(0xff2a1f3d);
    canvas.drawCircle(head.translate(-r * .34, r * .16), r * .11, eye);
    canvas.drawCircle(head.translate(r * .34, r * .16), r * .11, eye);
    canvas.drawArc(
      Rect.fromCenter(
        center: head.translate(0, r * .4),
        width: r * .66,
        height: r * .46,
      ),
      .25,
      math.pi - .5,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = r * .1
        ..color = const Color(0xff2a1f3d),
    );

    if (headphones) {
      final band = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * .17
        ..strokeCap = StrokeCap.round
        ..color = vInk;
      canvas.drawArc(
        Rect.fromCircle(center: head, radius: r * 1.16),
        math.pi + .35,
        math.pi - .7,
        false,
        band,
      );
      final pad = Paint()..color = vPink;
      for (final dx in [-r * 1.16, r * 1.16]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: head.translate(dx, 0),
              width: r * .3,
              height: r * .6,
            ),
            Radius.circular(r * .15),
          ),
          pad,
        );
      }
      // Mikrofon qolu.
      canvas.drawLine(
        head.translate(r * 1.16, r * .2),
        head.translate(r * .55, r * .62),
        Paint()
          ..strokeWidth = r * .12
          ..strokeCap = StrokeCap.round
          ..color = vInk,
      );
      canvas.drawCircle(
        head.translate(r * .5, r * .66),
        r * .15,
        Paint()..color = vPink,
      );
    }
  }

  void _chatBubble(Canvas canvas, Offset center) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: 52, height: 34),
      const Radius.circular(14),
    );
    canvas.drawRRect(rect, Paint()..color = vPanelHigh);
    canvas.drawRRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = vLine,
    );
    canvas.drawPath(
      Path()
        ..moveTo(center.dx - 12, center.dy + 15)
        ..lineTo(center.dx - 4, center.dy + 24)
        ..lineTo(center.dx - 2, center.dy + 15)
        ..close(),
      Paint()..color = vPanelHigh,
    );
    final dot = Paint()..color = vMuted;
    for (var i = -1; i <= 1; i++) {
      canvas.drawCircle(center.translate(i * 11, 0), 3, dot);
    }
  }

  void _heart(Canvas canvas, Offset center, double size) {
    final path = Path()
      ..moveTo(center.dx, center.dy + size * .8)
      ..cubicTo(
        center.dx - size * 1.4,
        center.dy - size * .2,
        center.dx - size * .5,
        center.dy - size * 1.1,
        center.dx,
        center.dy - size * .35,
      )
      ..cubicTo(
        center.dx + size * .5,
        center.dy - size * 1.1,
        center.dx + size * 1.4,
        center.dy - size * .2,
        center.dx,
        center.dy + size * .8,
      );
    canvas.drawPath(path, Paint()..color = vRose);
  }

  void _note(Canvas canvas, Offset center) {
    final stem = Paint()
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..color = vBlue;
    canvas.drawLine(center, center.translate(0, -18), stem);
    canvas.drawLine(
      center.translate(0, -18),
      center.translate(10, -22),
      stem,
    );
    canvas.drawCircle(center.translate(-3, 1), 4.6, Paint()..color = vBlue);
  }

  void _sparkle(Canvas canvas, Offset center, double size, [Color? color]) {
    final w = size * .28;
    final path = Path()
      ..moveTo(center.dx, center.dy - size)
      ..quadraticBezierTo(center.dx + w, center.dy - w, center.dx + size, center.dy)
      ..quadraticBezierTo(center.dx + w, center.dy + w, center.dx, center.dy + size)
      ..quadraticBezierTo(center.dx - w, center.dy + w, center.dx - size, center.dy)
      ..quadraticBezierTo(center.dx - w, center.dy - w, center.dx, center.dy - size)
      ..close();
    canvas.drawPath(path, Paint()..color = (color ?? vGold).withValues(alpha: .9));
  }

  /// Fırlanan rəngli konfetti — səhnəyə canlılıq verir.
  void _confetti(Canvas canvas) {
    const spots = [
      (Offset(44, 62), vPink),
      (Offset(286, 54), vBlue),
      (Offset(20, 148), vGold),
      (Offset(300, 210), vMint),
      (Offset(108, 262), vPurple),
      (Offset(268, 268), vRose),
      (Offset(150, 28), vBlue),
    ];
    for (var i = 0; i < spots.length; i++) {
      final (pos, color) = spots[i];
      final phase = (t + i / spots.length) % 1.0;
      canvas.save();
      canvas.translate(pos.dx, pos.dy + math.sin(phase * 2 * math.pi) * 5);
      canvas.rotate(phase * 2 * math.pi);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: 7, height: 3.4),
          const Radius.circular(2),
        ),
        Paint()..color = color.withValues(alpha: .75),
      );
      canvas.restore();
    }
  }

  /// Qızıl sikkə — tətbiqin sikkə iqtisadiyyatına işarə.
  void _coin(Canvas canvas, Offset center, double r) {
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xffffe89a), vGold, Color(0xffe0951f)],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );
    canvas.drawCircle(
      center,
      r * .72,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * .12
        ..color = const Color(0xffb9740f).withValues(alpha: .7),
    );
    final v = Path()
      ..moveTo(center.dx - r * .3, center.dy - r * .3)
      ..lineTo(center.dx, center.dy + r * .34)
      ..lineTo(center.dx + r * .3, center.dy - r * .3);
    canvas.drawPath(
      v,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * .18
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xff7a4a06),
    );
  }

  @override
  bool shouldRepaint(covariant _WelcomeArtPainter old) => old.t != t;
}
