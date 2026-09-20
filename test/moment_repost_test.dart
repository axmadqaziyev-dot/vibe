import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/moments.dart';
import 'package:flutter_application_1/user_profile.dart';

const me = UserProfile(
  uid: 'u-me',
  name: 'Mən',
  age: 25,
  city: 'Bakı',
  email: 'me@vibe.az',
  about: '',
);

Future<void> pumpCard(
  WidgetTester tester,
  Map<String, dynamic> data, {
  FakeFirebaseFirestore? db,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: MomentCard(
            momentId: 'm-1',
            data: data,
            profile: me,
            database: db ?? FakeFirebaseFirestore(),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('Yenidən paylaşılan anda üstdə sətir görünür', (tester) async {
    await pumpCard(tester, {
      'ownerUid': 'u-me',
      'ownerName': 'Mən',
      'caption': 'Gözəl axşam',
      'repostOf': 'orijinal-1',
      'repostOwnerName': 'Aygün',
    });

    expect(find.textContaining('yenidən paylaşdı'), findsOneWidget);
    expect(find.byIcon(Icons.repeat_rounded), findsWidgets);
  });

  testWidgets('Adi anda o sətir olmur', (tester) async {
    await pumpCard(tester, {
      'ownerUid': 'u-me',
      'ownerName': 'Mən',
      'caption': 'Salam',
    });

    expect(find.textContaining('yenidən paylaşdı'), findsNothing);
  });

  testWidgets('Sitat qutusu orijinalın adını və mətnini göstərir',
      (tester) async {
    await pumpCard(tester, {
      'ownerUid': 'u-me',
      'ownerName': 'Mən',
      'caption': 'Buna baxın',
      'quoted': {
        'momentId': 'orijinal-1',
        'ownerName': 'Aygün',
        'caption': 'Bu gün hava çox gözəldir',
      },
    });

    // Həm öz sözü, həm sitat görünür.
    expect(find.text('Buna baxın'), findsOneWidget);
    expect(find.text('Aygün'), findsOneWidget);
    expect(find.text('Bu gün hava çox gözəldir'), findsOneWidget);
  });

  testWidgets('Sitat gətirilən an silinsə də mətn qalır', (tester) async {
    // Orijinalın nüsxəsi sitatın içindədir, ona görə baza boş olsa da işləyir.
    await pumpCard(tester, {
      'ownerUid': 'u-me',
      'ownerName': 'Mən',
      'caption': 'Sitat',
      'quoted': {
        'momentId': 'silinmis',
        'ownerName': 'Yoxdur',
        'caption': 'Köhnə mətn',
      },
    });

    expect(find.text('Köhnə mətn'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Yenidən paylaşım sayı düymədə görünür', (tester) async {
    final db = FakeFirebaseFirestore();
    await db.collection('moments').doc('m-1').set({'repostCount': 7});

    await pumpCard(tester, {
      'ownerUid': 'u-me',
      'ownerName': 'Mən',
      'caption': 'Salam',
    }, db: db);

    // Axın bir neçə kadr sonra gəlir.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }

    expect(find.text('7'), findsOneWidget);
  });
}
