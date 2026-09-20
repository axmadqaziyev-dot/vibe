import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/moments.dart';
import 'package:flutter_application_1/user_profile.dart';
import 'package:flutter_application_1/voice/moment_voice.dart';

const me = UserProfile(
  uid: 'u-me',
  name: 'Mən',
  age: 25,
  city: 'Bakı',
  email: 'me@vibe.az',
  about: '',
);

Future<void> pumpCard(WidgetTester tester, Map<String, dynamic> data) async {
  tester.view.physicalSize = const Size(390, 1200);
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
            database: FakeFirebaseFirestore(),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('Səsli an oynadıcı ilə göstərilir', (tester) async {
    await pumpCard(tester, {
      'ownerUid': 'u-me',
      'ownerName': 'Mən',
      'caption': 'Bunu dinlə',
      'audioUrl': 'https://example.com/a.wav',
      'audioMs': 12000,
      'audioWave': [10, 50, 90, 30],
    });

    expect(find.byType(MomentVoice), findsOneWidget);
    expect(find.text('Səsli an'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
  });

  testWidgets('Səs yoxdursa oynadıcı qurulmur', (tester) async {
    await pumpCard(tester, {
      'ownerUid': 'u-me',
      'ownerName': 'Mən',
      'caption': 'Sadə mətn',
    });

    expect(find.byType(MomentVoice), findsNothing);
  });

  testWidgets('Dalğası olmayan köhnə səs də açılır', (tester) async {
    // Köhnə sənəddə audioWave olmaya bilər — ekran sınmamalıdır.
    await pumpCard(tester, {
      'ownerUid': 'u-me',
      'ownerName': 'Mən',
      'audioUrl': 'https://example.com/a.wav',
      'audioMs': 5000,
    });

    expect(find.byType(MomentVoice), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Müddət göstərilir', (tester) async {
    await pumpCard(tester, {
      'ownerUid': 'u-me',
      'ownerName': 'Mən',
      'audioUrl': 'https://example.com/a.wav',
      'audioMs': 75000,
    });

    // 75 saniyə = 1:15
    expect(find.text('1:15'), findsOneWidget);
  });
}
