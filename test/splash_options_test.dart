import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Açılış ekranı üçün variantlar.
///
/// Mövcud açılış (qulaqlıqlı ayı) uşaq tətbiqinə oxşayır. Burada dörd
/// yetkin variant çəkilir ki, seçim gözlə edilsin.
void main() {
  testWidgets('Açılış variantları çəkilir', (tester) async {
    // Şrift yüklənməsə yazılar kvadrat çıxır — nəticəni qiymətləndirmək
    // mümkün olmur, ona görə açıq yoxlanılır.
    var fontReady = false;

    for (final name in ['segoeui.ttf', 'arial.ttf', 'tahoma.ttf']) {
      final file = File('C:/Windows/Fonts/$name');
      if (!file.existsSync()) continue;

      final loader = FontLoader('PreviewFont')
        ..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
      await loader.load();
      fontReady = true;
      break;
    }

    expect(fontReady, isTrue, reason: 'Önizləmə şrifti tapılmadı');

    tester.view.physicalSize = const Size(1120, 620);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final key = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          fontFamily: fontReady ? 'PreviewFont' : null,
        ),
        home: RepaintBoundary(
          key: key,
          child: const ColoredBox(
            color: Color(0xff101014),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _Option(title: '1 — Monoqram', child: _Monogram()),
                  _Option(title: '2 — Şəfəq', child: _Aurora()),
                  _Option(title: '3 — Səs dalğası', child: _Pulse()),
                  _Option(title: '4 — Şüşə', child: _Glass()),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);

    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('artifacts').createSync(recursive: true);
      File('artifacts/acilis_variantlari.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });

    await tester.pumpWidget(const SizedBox());
  });
}

class _Option extends StatelessWidget {
  const _Option({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: SizedBox(width: 244, height: 520, child: child),
          ),
        ],
      );
}

/// 1 — qradiyent halqa içində monoqram.
class _Monogram extends StatelessWidget {
  const _Monogram();

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: const Color(0xff07040f),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 130,
              height: 130,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [
                    Color(0xff22a7ff),
                    Color(0xff7b3cff),
                    Color(0xffff2bd6),
                    Color(0xff22a7ff),
                  ],
                ),
                boxShadow: [
                  BoxShadow(color: Color(0x59ff2bd6), blurRadius: 50),
                ],
              ),
              child: Center(
                child: Container(
                  width: 116,
                  height: 116,
                  decoration: const BoxDecoration(
                    color: Color(0xff07040f),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'V',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 52,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 26),
            const Text(
              'VIBE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 25,
                fontWeight: FontWeight.w900,
                letterSpacing: 7,
              ),
            ),
            const SizedBox(height: 9),
            const Text(
              'TƏK DEYİLSƏN',
              style: TextStyle(
                color: Color(0xff6f6683),
                fontSize: 10.5,
                letterSpacing: 3,
              ),
            ),
          ],
        ),
      );
}

/// 2 — şəfəq ləkələri.
class _Aurora extends StatelessWidget {
  const _Aurora();

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xff0a0616)),
          CustomPaint(painter: _AuroraPainter()),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text(
                'VIBE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 9,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 30)],
                ),
              ),
              SizedBox(height: 12),
              Text(
                'TƏK DEYİLSƏN',
                style: TextStyle(
                  color: Color(0xffd8d0e7),
                  fontSize: 11,
                  letterSpacing: 4,
                ),
              ),
            ],
          ),
        ],
      );
}

class _AuroraPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    void blob(Offset centre, double radius, Color color) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: centre, radius: radius))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);

      canvas.drawCircle(centre, radius, paint);
    }

    blob(Offset(size.width * .3, size.height * .3), size.width * .55,
        const Color(0xd97b3cff));
    blob(Offset(size.width * .75, size.height * .46), size.width * .5,
        const Color(0xc0ff2bd6));
    blob(Offset(size.width * .45, size.height * .78), size.width * .55,
        const Color(0x8c22a7ff));
  }

  @override
  bool shouldRepaint(_AuroraPainter old) => false;
}

/// 3 — səs dalğası halqaları.
class _Pulse extends StatelessWidget {
  const _Pulse();

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -.2),
            radius: .9,
            colors: [Color(0xff2a1150), Color(0xff07040f)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 190,
              height: 190,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  for (final item in const [
                    [190.0, 0x80ff2bd6],
                    [138.0, 0x99a85aff],
                    [86.0, 0x8c22a7ff],
                  ])
                    Container(
                      width: item[0] as double,
                      height: item[0] as double,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Color(item[1] as int),
                          width: 1.4,
                        ),
                      ),
                    ),
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xff7b3cff), Color(0xffff2bd6)],
                      ),
                      boxShadow: [
                        BoxShadow(color: Color(0x99ff2bd6), blurRadius: 34),
                      ],
                    ),
                    child: const Text(
                      'V',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'VIBE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 7,
              ),
            ),
            const SizedBox(height: 9),
            const Text(
              'TƏK DEYİLSƏN',
              style: TextStyle(
                color: Color(0xff8a80a0),
                fontSize: 10.5,
                letterSpacing: 3,
              ),
            ),
          ],
        ),
      );
}

/// 4 — şüşə kart.
class _Glass extends StatelessWidget {
  const _Glass();

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xff0b0718)),
          CustomPaint(painter: _GlassPainter()),
          Center(
            child: Container(
              width: 186,
              padding: const EdgeInsets.fromLTRB(0, 30, 0, 26),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .09),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        colors: [Color(0xff7b3cff), Color(0xffff2bd6)],
                      ),
                      boxShadow: const [
                        BoxShadow(color: Color(0x73ff2bd6), blurRadius: 26),
                      ],
                    ),
                    child: const Text(
                      'V',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 29,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'VIBE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 6,
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'Tək deyilsən',
                    style: TextStyle(
                      color: Color(0xffbfb6d0),
                      fontSize: 11,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
}

class _GlassPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    void glow(Offset centre, double radius, Color color) {
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: centre, radius: radius))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26),
      );
    }

    glow(Offset(size.width * .18, size.height * .16), size.width * .7,
        const Color(0xcc5b2fd6));
    glow(Offset(size.width * .88, size.height * .82), size.width * .62,
        const Color(0xb3ff2bd6));

    // Yüngül toz hissəcikləri — kart tək qalmasın.
    final dot = Paint()..color = Colors.white.withValues(alpha: .16);
    for (var i = 0; i < 26; i++) {
      final angle = i * 2.399963;
      final r = (i % 7) * 34.0 + 30;
      canvas.drawCircle(
        Offset(
          size.width / 2 + math.cos(angle) * r,
          size.height / 2 + math.sin(angle) * r * 1.3,
        ),
        1.6,
        dot,
      );
    }
  }

  @override
  bool shouldRepaint(_GlassPainter old) => false;
}
