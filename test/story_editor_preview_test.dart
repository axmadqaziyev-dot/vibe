import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/story_editor.dart';
import 'package:flutter_application_1/story_overlay.dart';
import 'package:flutter_application_1/user_profile.dart';

/// Stori redaktorunun görünüşünü çəkir.
void main() {
  testWidgets('Stori redaktoru çəkilir', (tester) async {
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
        home: RepaintBoundary(
          key: key,
          child: StoryEditorPage(
            profile: const UserProfile(
              uid: 'u1',
              name: 'Əhməd',
              age: 25,
              city: 'Bakı',
              about: '',
              email: '',
            ),
            // Ad günü şablonu ilə açılır.
            template: storyTemplates.first,
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);

    // Şablonun mətni ekrandadır.
    expect(find.text('Ad günün mübarək!'), findsOneWidget);
    expect(find.text('Paylaş'), findsOneWidget);

    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('artifacts').createSync(recursive: true);
      File('artifacts/stori_redaktoru.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });

    await tester.pumpWidget(const SizedBox());
  });
}
