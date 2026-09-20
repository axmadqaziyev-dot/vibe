import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart';

/// Qeydiyyat ekranının görünüşünü yoxlayır və şəklini çıxarır.
void main() {
  testWidgets('Qeydiyyat ekranı çəkilir', (tester) async {
    final font = File('C:/Windows/Fonts/segoeui.ttf');
    if (font.existsSync()) {
      final loader = FontLoader('PreviewFont')
        ..addFont(Future.value(ByteData.sublistView(font.readAsBytesSync())));
      await loader.load();
    }

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final key = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          fontFamily: font.existsSync() ? 'PreviewFont' : null,
        ),
        home: RepaintBoundary(key: key, child: const RegisterPage()),
      ),
    );

    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);

    // Bütün sahələr yerindədir.
    for (final label in [
      'Ad',
      'Yaş',
      'Şəhər',
      'Haqqımda',
      'E-poçt',
      'Şifrə',
      'Səni tanıyaq',
      'Giriş məlumatları',
      'Qeydiyyatdan keç',
    ]) {
      expect(find.text(label), findsWidgets, reason: '$label tapılmadı');
    }

    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('artifacts').createSync(recursive: true);
      File('artifacts/qeydiyyat.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Şərtlər qutusuna basanda işarə dəyişir', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: RegisterPage()),
    );
    await tester.pump();

    // Kiçik kvadratı yox, bütün qutunu basmaq kifayət etməlidir.
    await tester.tap(find.textContaining('18 yaşım tamamdır'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });
}
