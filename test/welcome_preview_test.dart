import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/ui/vibe_design.dart';
import 'package:flutter_application_1/ui/welcome_art.dart';

/// Xoş gəldin illüstrasiyasının görüntüsünü `artifacts/` qovluğuna yazır —
/// dizaynı gözlə yoxlamaq üçün.
void main() {
  testWidgets('Xoş gəldin illüstrasiyası çəkilir', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 300 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: key,
          child: const ColoredBox(
            color: vBg,
            child: AuroraBackground(
              strength: 1.2,
              child: VibeWelcomeArt(height: 300),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 900));
    expect(tester.takeException(), isNull);

    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('artifacts').createSync(recursive: true);
      File('artifacts/welcome_art.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Xoş gəldin ekranı çəkilir', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(key: key, child: const WelcomePage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 900));
    expect(tester.takeException(), isNull);

    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('artifacts/welcome_screen.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });

    await tester.pumpWidget(const SizedBox());
  });
}
