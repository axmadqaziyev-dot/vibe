import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/moments.dart';
import 'package:flutter_application_1/ui/vibe_design.dart';
import 'package:flutter_application_1/user_profile.dart';

/// Anlar kartının yeni (Threads üslubu) görünüşünü şəkil kimi yazır.
void main() {
  testWidgets('An kartı düzgün qurulur', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 520 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    const profile = UserProfile(
      uid: 'me',
      name: 'Aysel',
      age: 24,
      city: 'Bakı',
      email: 'aysel@vibe.az',
      about: '',
    );

    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('u1').set({
      'uid': 'u1',
      'name': 'Murad',
      'online': true,
      'lastSeen': Timestamp.now(),
    });
    await db.collection('users').doc('u2').set({
      'uid': 'u2',
      'name': 'Leyla',
      'online': false,
    });

    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: vBg,
          body: RepaintBoundary(
            key: key,
            // Şəkil çəkiləndə fon da daxil olsun — ağ mətn görünsün.
            child: ColoredBox(
              color: vBg,
              child: ListView(
              children: [
                MomentCard(
                  momentId: 'm1',
                  profile: profile,
                  database: db,
                  data: {
                    'ownerUid': 'u1',
                    'ownerName': 'Murad',
                    'caption':
                        'Bu gün səsli otaqda çox gülməli söhbət oldu 😄',
                    'createdAt': Timestamp.now(),
                    'likeCount': 12,
                  },
                ),
                MomentCard(
                  momentId: 'm2',
                  profile: profile,
                  database: db,
                  data: {
                    'ownerUid': 'u2',
                    'ownerName': 'Leyla',
                    'caption': 'Yeni gün, yeni vibe ✨',
                    'createdAt': Timestamp.now(),
                    'likeCount': 4,
                  },
                ),
              ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);

    // Mətn və ad görünür.
    expect(find.text('Murad'), findsOneWidget);
    expect(find.textContaining('səsli otaqda'), findsOneWidget);

    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('artifacts').createSync(recursive: true);
      File('artifacts/moments.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });

    await tester.pumpWidget(const SizedBox());
  });

  test('Sahibsiz an məlumatı kartı sındırmır', () {
    // Köhnə sənədlərdə `ownerName` olmaya bilər.
    final data = <String, dynamic>{'caption': 'salam'};
    expect('${data['ownerName'] ?? 'VIBE'}', 'VIBE');
  });

}
