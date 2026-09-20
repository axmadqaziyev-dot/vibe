import 'dart:io';
import 'dart:ui' as ui;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/social_ui.dart';
import 'package:flutter_application_1/ui/vibe_design.dart';
import 'package:flutter_application_1/user_profile.dart';

/// Yenilənmiş Ayarlar ekranının görünüşünü yazır və dar ekranda
/// daşma olmadığını yoxlayır.
void main() {
  testWidgets('Ayarlar ekranı dar ekranda da düzgün yerləşir', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 780 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    const profile = UserProfile(
      uid: 'me',
      name: 'Aysel Məmmədova',
      age: 24,
      city: 'Bakı',
      email: 'aysel@vibe.az',
      about: '',
    );

    SharedPreferences.setMockInitialValues({});

    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('me').set({
      'uid': 'me',
      'name': 'Aysel Məmmədova',
      'avatarEmoji': '🌸',
    });

    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
        home: RepaintBoundary(
          key: key,
          child: ColoredBox(
            color: vBg,
            child: SocialSettings(profile: profile, database: db),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);

    // Bölmə başlıqları və əsas sətirlər yerindədir.
    expect(find.text('GÖRÜNÜŞ'), findsOneWidget);
    expect(find.text('HESAB'), findsOneWidget);
    expect(find.text('Dostlarını dəvət et'), findsOneWidget);

    // Siyahının sonuna qədər sürüşdürmək daşma olmadığını da yoxlayır.
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.text('Hesabdan çıxış'), findsOneWidget);

    // Şəkli yuxarıdan çəkmək üçün geri qaldırırıq.
    await tester.drag(find.byType(ListView), const Offset(0, 900));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('artifacts').createSync(recursive: true);
      File('artifacts/settings.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });

    await tester.pumpWidget(const SizedBox());
  });
}
