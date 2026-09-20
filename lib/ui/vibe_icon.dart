// VIBE tətbiq ikonu — şrift tələb etmir, tamamilə çəkilir.
// `test/app_icon_test.dart` bunu PNG kimi ixrac edir.

import 'package:flutter/material.dart';

/// Tətbiq ikonunun rəsmi.
class VibeIconMark extends StatelessWidget {
  const VibeIconMark({
    super.key,
    this.size = 1024,
    this.withBackground = true,
  });

  final double size;

  /// Android adaptiv ikonun ön planı üçün fon söndürülür.
  final bool withBackground;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      painter: _VibeIconPainter(withBackground: withBackground),
    ),
  );
}

class _VibeIconPainter extends CustomPainter {
  const _VibeIconPainter({required this.withBackground});

  final bool withBackground;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final w = size.width;

    if (withBackground) {
      // Tünd baza — iOS ikonunda şəffaflıq olmamalıdır.
      canvas.drawRect(rect, Paint()..color = const Color(0xff0B0714));

      // Neon qradiyent ləkə
      canvas.drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xff7B3CFF), Color(0xffFF2BD6)],
          ).createShader(rect),
      );

      // Yuxarı sol küncdə işıq
      canvas.drawCircle(
        Offset(w * .22, w * .18),
        w * .38,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(alpha: .28),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromCircle(center: Offset(w * .22, w * .18), radius: w * .38),
          ),
      );
    }

    // "V" hərfi — iki qalın xətt, yumru uclarla
    final stroke = w * .115;
    final v = Path()
      ..moveTo(w * .30, w * .32)
      ..lineTo(w * .50, w * .70)
      ..lineTo(w * .70, w * .32);

    canvas.drawPath(
      v,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white,
    );

    // Səs dalğası nöqtəsi — "canlı söhbət" işarəsi
    canvas.drawCircle(
      Offset(w * .50, w * .245),
      stroke * .42,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_VibeIconPainter oldDelegate) =>
      oldDelegate.withBackground != withBackground;
}
