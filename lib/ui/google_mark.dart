import 'package:flutter/material.dart';

/// Google-ın rəsmi "G" nişanı.
///
/// Giriş düymələrində Google öz loqosunun işlənməsini tələb edir,
/// ona görə hərf yox, əsl nişan çəkilir.
class GoogleMark extends StatelessWidget {
  const GoogleMark({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: GoogleMarkPainter()),
      );
}

class GoogleMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * .22;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    final arcRect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );

    void arc(Color color, double start, double sweep) {
      paint.color = color;
      canvas.drawArc(arcRect, start, sweep, false, paint);
    }

    arc(const Color(0xff4285F4), -0.78, 2.20);
    arc(const Color(0xff34A853), 1.42, 1.20);
    arc(const Color(0xffFBBC05), 2.62, .88);
    arc(const Color(0xffEA4335), 3.50, 1.25);

    final blue = Paint()
      ..color = const Color(0xff4285F4)
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(
        size.width * .50,
        size.height * .43,
        size.width * .43,
        stroke,
      ),
      blue,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * .72,
        size.height * .43,
        stroke,
        size.height * .29,
      ),
      blue,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
