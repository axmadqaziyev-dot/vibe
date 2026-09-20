import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Giriş ekranının fonundakı səhnələr.
///
/// Hamısı koddan çəkilir — şəkil faylı yoxdur, ona görə tətbiqin ölçüsü
/// artmır və hər ekran sıxlığında kəskin görünür. Səhnələr növbə ilə
/// dəyişir və yavaş hərəkət edir.
class WelcomeSceneArt extends StatelessWidget {
  const WelcomeSceneArt({
    super.key,
    required this.scene,
    required this.time,
  });

  /// 0 — mikrofonda oxuyan, 1 — söhbət edən iki nəfər, 2 — məclis.
  final int scene;

  /// 0..1 arası təkrarlanan animasiya vaxtı.
  final double time;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _ScenePainter(scene: scene, time: time),
        isComplex: true,
        child: const SizedBox.expand(),
      );
}

const Size _design = Size(320, 420);

class _ScenePainter extends CustomPainter {
  _ScenePainter({required this.scene, required this.time});

  final int scene;
  final double time;

  double _wave(double phase, [double amount = 6]) =>
      math.sin((time + phase) * 2 * math.pi) * amount;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(
      size.width / _design.width,
      size.height / _design.height,
    );

    canvas.save();
    canvas.translate(
      (size.width - _design.width * scale) / 2,
      (size.height - _design.height * scale) / 2,
    );
    canvas.scale(scale);

    switch (scene % 3) {
      case 0:
        _singer(canvas);
      case 1:
        _talking(canvas);
      default:
        _party(canvas);
    }

    canvas.restore();
  }

  // ----------------------------------------------------------
  // ORTAQ HİSSƏLƏR
  // ----------------------------------------------------------

  /// Sadə, düz üslubda insan fiquru.
  void _person(
    Canvas canvas, {
    required Offset head,
    required double r,
    required Color skin,
    required Color hair,
    required Color clothes,
    _HairStyle style = _HairStyle.short,
    bool headphones = false,
  }) {
    final bodyTop = head.dy + r * .55;

    // Uzun saç bədənin arxasından görünür.
    if (style == _HairStyle.long) {
      final back = RRect.fromLTRBAndCorners(
        head.dx - r * 1.25,
        head.dy - r * .2,
        head.dx + r * 1.25,
        bodyTop + r * 1.5,
        topLeft: Radius.circular(r),
        topRight: Radius.circular(r),
        bottomLeft: Radius.circular(r * .8),
        bottomRight: Radius.circular(r * .8),
      );
      canvas.drawRRect(back, Paint()..color = hair);
    }

    // Gövdə.
    final body = RRect.fromLTRBAndCorners(
      head.dx - r * 1.05,
      bodyTop,
      head.dx + r * 1.05,
      bodyTop + r * 2.1,
      topLeft: Radius.circular(r * .85),
      topRight: Radius.circular(r * .85),
      bottomLeft: Radius.circular(r * .35),
      bottomRight: Radius.circular(r * .35),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [clothes, Color.lerp(clothes, Colors.black, .35)!],
        ).createShader(body.outerRect),
    );

    // Baş.
    canvas.drawCircle(head, r, Paint()..color = skin);

    // Saç qapağı.
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: head, radius: r)));
    canvas.drawCircle(
      head.translate(0, -r * (style == _HairStyle.long ? .88 : 1.02)),
      r,
      Paint()..color = hair,
    );
    canvas.restore();

    // Üz.
    final ink = Paint()..color = const Color(0xff2a1f3d);
    canvas.drawCircle(head.translate(-r * .33, r * .12), r * .1, ink);
    canvas.drawCircle(head.translate(r * .33, r * .12), r * .1, ink);
    canvas.drawArc(
      Rect.fromCenter(
        center: head.translate(0, r * .36),
        width: r * .6,
        height: r * .44,
      ),
      .25,
      math.pi - .5,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = r * .095
        ..color = const Color(0xff2a1f3d),
    );

    // Yanaq.
    final blush = Paint()..color = const Color(0x66ff8fb4);
    canvas.drawCircle(head.translate(-r * .62, r * .26), r * .16, blush);
    canvas.drawCircle(head.translate(r * .62, r * .26), r * .16, blush);

    if (headphones) {
      canvas.drawArc(
        Rect.fromCircle(center: head, radius: r * 1.2),
        math.pi + .3,
        math.pi - .6,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * .16
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xfff7f3ff),
      );
      final pad = Paint()..color = const Color(0xffff2bd6);
      for (final dx in [-r * 1.2, r * 1.2]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: head.translate(dx, 0),
              width: r * .3,
              height: r * .62,
            ),
            Radius.circular(r * .15),
          ),
          pad,
        );
      }
    }
  }

  void _note(Canvas canvas, Offset center, Color color, double scale) {
    final stem = Paint()
      ..strokeWidth = 2.6 * scale
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawLine(center, center.translate(0, -20 * scale), stem);
    canvas.drawLine(
      center.translate(0, -20 * scale),
      center.translate(11 * scale, -24 * scale),
      stem,
    );
    canvas.drawCircle(center.translate(-3 * scale, 1), 5 * scale,
        Paint()..color = color);
  }

  void _bubble(Canvas canvas, Offset center, double w, Color color,
      {bool left = true}) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: w, height: w * .62),
      Radius.circular(w * .28),
    );
    canvas.drawRRect(rect, Paint()..color = color);

    final tailX = left ? center.dx - w * .22 : center.dx + w * .22;
    canvas.drawPath(
      Path()
        ..moveTo(tailX, center.dy + w * .28)
        ..lineTo(tailX + (left ? -w * .12 : w * .12), center.dy + w * .48)
        ..lineTo(tailX + (left ? w * .08 : -w * .08), center.dy + w * .28)
        ..close(),
      Paint()..color = color,
    );

    final dot = Paint()..color = Colors.white.withValues(alpha: .85);
    for (var i = -1; i <= 1; i++) {
      canvas.drawCircle(center.translate(i * w * .2, 0), w * .055, dot);
    }
  }

  void _confetti(Canvas canvas, List<(Offset, Color)> spots) {
    for (var i = 0; i < spots.length; i++) {
      final (pos, color) = spots[i];
      final phase = (time + i / spots.length) % 1.0;
      canvas.save();
      canvas.translate(pos.dx, pos.dy + math.sin(phase * 2 * math.pi) * 6);
      canvas.rotate(phase * 2 * math.pi);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: 8, height: 3.6),
          const Radius.circular(2),
        ),
        Paint()..color = color.withValues(alpha: .8),
      );
      canvas.restore();
    }
  }

  void _glow(Canvas canvas, Offset center, double radius, Color color) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: .45), color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  // ----------------------------------------------------------
  // SƏHNƏ 1 — MİKROFONDA OXUYAN
  // ----------------------------------------------------------

  void _singer(Canvas canvas) {
    _glow(canvas, const Offset(160, 190), 150, const Color(0xffff2bd6));

    // Səs dalğaları.
    for (var i = 0; i < 3; i++) {
      final p = ((time + i * .33) % 1.0);
      canvas.drawCircle(
        const Offset(160, 190),
        70 + p * 60,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xffff2bd6).withValues(alpha: (1 - p) * .4),
      );
    }

    _person(
      canvas,
      head: Offset(160, 176 + _wave(0, 5)),
      r: 44,
      skin: const Color(0xffe8b98f),
      hair: const Color(0xff2b1a3f),
      clothes: const Color(0xff8b5cff),
      style: _HairStyle.long,
      headphones: true,
    );

    // Mikrofon.
    final dy = _wave(0, 5);
    final micTop = Offset(228, 196 + dy);
    canvas.drawLine(
      micTop,
      micTop.translate(18, 52),
      Paint()
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xffd8cff0),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: micTop, width: 26, height: 38),
        const Radius.circular(13),
      ),
      Paint()..color = const Color(0xfff7f3ff),
    );
    canvas.drawCircle(micTop, 8, Paint()..color = const Color(0xffff2bd6));

    _note(canvas, Offset(70, 130 + _wave(.3, 8)), const Color(0xff22a7ff), 1);
    _note(canvas, Offset(262, 120 + _wave(.6, 8)), const Color(0xffffd458), .8);
    _note(canvas, Offset(96, 300 + _wave(.15, 6)), const Color(0xff2de28a), .7);

    _confetti(canvas, const [
      (Offset(44, 86), Color(0xffff2bd6)),
      (Offset(280, 240), Color(0xff22a7ff)),
      (Offset(58, 360), Color(0xffffd458)),
    ]);
  }

  // ----------------------------------------------------------
  // SƏHNƏ 2 — İKİ NƏFƏR SÖHBƏT EDİR
  // ----------------------------------------------------------

  void _talking(Canvas canvas) {
    _glow(canvas, const Offset(160, 210), 150, const Color(0xff22a7ff));

    _person(
      canvas,
      head: Offset(96, 214 + _wave(0, 5)),
      r: 36,
      skin: const Color(0xffc98d63),
      hair: const Color(0xff241a33),
      clothes: const Color(0xff2de28a),
    );

    _person(
      canvas,
      head: Offset(224, 206 + _wave(.5, 5)),
      r: 36,
      skin: const Color(0xfff2d2b6),
      hair: const Color(0xff5a2f1c),
      clothes: const Color(0xffff657b),
      style: _HairStyle.long,
    );

    _bubble(canvas, Offset(110, 112 + _wave(.2, 6)), 92,
        const Color(0xff8b5cff));
    _bubble(canvas, Offset(226, 128 + _wave(.7, 6)), 78,
        const Color(0xffff2bd6), left: false);

    // Ürək.
    final heartCenter = Offset(160, 316 + _wave(.4, 6));
    canvas.drawPath(
      Path()
        ..moveTo(heartCenter.dx, heartCenter.dy + 14)
        ..cubicTo(heartCenter.dx - 26, heartCenter.dy - 4,
            heartCenter.dx - 9, heartCenter.dy - 20, heartCenter.dx,
            heartCenter.dy - 6)
        ..cubicTo(heartCenter.dx + 9, heartCenter.dy - 20,
            heartCenter.dx + 26, heartCenter.dy - 4, heartCenter.dx,
            heartCenter.dy + 14),
      Paint()..color = const Color(0xffff657b),
    );

    _confetti(canvas, const [
      (Offset(40, 150), Color(0xffffd458)),
      (Offset(290, 300), Color(0xff2de28a)),
      (Offset(62, 356), Color(0xff8b5cff)),
    ]);
  }

  // ----------------------------------------------------------
  // SƏHNƏ 3 — MƏCLİS
  // ----------------------------------------------------------

  void _party(Canvas canvas) {
    _glow(canvas, const Offset(160, 210), 160, const Color(0xff8b5cff));

    _person(
      canvas,
      head: Offset(72, 236 + _wave(.2, 6)),
      r: 30,
      skin: const Color(0xfff0c9a4),
      hair: const Color(0xff2a1f3d),
      clothes: const Color(0xff22a7ff),
    );

    _person(
      canvas,
      head: Offset(160, 196 + _wave(0, 7)),
      r: 38,
      skin: const Color(0xffe8b98f),
      hair: const Color(0xff3a1f52),
      clothes: const Color(0xffff2bd6),
      style: _HairStyle.long,
    );

    _person(
      canvas,
      head: Offset(248, 240 + _wave(.6, 6)),
      r: 30,
      skin: const Color(0xff8d5a3b),
      hair: const Color(0xff1d1526),
      clothes: const Color(0xffffd458),
    );

    // Hədiyyə qutusu.
    final giftY = 330 + _wave(.35, 5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(160, giftY), width: 54, height: 44),
        const Radius.circular(8),
      ),
      Paint()..color = const Color(0xffff657b),
    );
    canvas.drawRect(
      Rect.fromCenter(center: Offset(160, giftY), width: 10, height: 44),
      Paint()..color = const Color(0xffffd458),
    );
    canvas.drawRect(
      Rect.fromCenter(center: Offset(160, giftY - 22), width: 54, height: 10),
      Paint()..color = const Color(0xffffd458),
    );

    _confetti(canvas, const [
      (Offset(48, 110), Color(0xffff2bd6)),
      (Offset(150, 84), Color(0xff22a7ff)),
      (Offset(266, 128), Color(0xffffd458)),
      (Offset(34, 316), Color(0xff2de28a)),
      (Offset(292, 330), Color(0xffff657b)),
      (Offset(200, 62), Color(0xff8b5cff)),
    ]);
  }

  @override
  bool shouldRepaint(covariant _ScenePainter old) =>
      old.time != time || old.scene != scene;
}

enum _HairStyle { short, long }
