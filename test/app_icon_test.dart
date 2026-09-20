// Tətbiq ikonunu PNG kimi ixrac edir.
//
//   flutter test test/app_icon_test.dart
//   dart run flutter_launcher_icons
//
// İkinci əmr bu PNG-dən bütün iOS/Android ölçülərini yaradır.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/ui/vibe_icon.dart';

Future<void> _export(
  WidgetTester tester, {
  required String path,
  required bool withBackground,
}) async {
  const size = 1024.0;
  final key = GlobalKey();

  tester.view.physicalSize = const Size(size, size);
  tester.view.devicePixelRatio = 1;

  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: RepaintBoundary(
        key: key,
        child: VibeIconMark(size: size, withBackground: withBackground),
      ),
    ),
  );
  await tester.pump();

  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  testWidgets('VIBE ikonu PNG kimi yaradılır', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _export(
      tester,
      path: 'assets/icon/vibe_icon.png',
      withBackground: true,
    );
    await _export(
      tester,
      path: 'assets/icon/vibe_icon_foreground.png',
      withBackground: false,
    );

    expect(File('assets/icon/vibe_icon.png').existsSync(), isTrue);
    expect(File('assets/icon/vibe_icon_foreground.png').existsSync(), isTrue);
  });
}
