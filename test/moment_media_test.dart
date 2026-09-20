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
  testWidgets('Yalnız şəkil olanda sayğac şəkil sayını göstərir',
      (tester) async {
    await pumpCard(tester, {
      'ownerUid': 'u-me',
      'ownerName': 'Mən',
      'images': ['a.jpg', 'b.jpg', 'c.jpg'],
    });

    expect(find.text('1/3'), findsOneWidget);
  });

  testWidgets('Video və şəkil birlikdə olanda video da sayılır',
      (tester) async {
    // Video birinci səhifədir, ona görə cəmi dörd olur.
    await pumpCard(tester, {
      'ownerUid': 'u-me',
      'ownerName': 'Mən',
      'videoUrl': 'v.mp4',
      'images': ['a.jpg', 'b.jpg', 'c.jpg'],
    });

    expect(find.text('1/4'), findsOneWidget);
  });

  testWidgets('Tək şəkildə sayğac görünmür', (tester) async {
    await pumpCard(tester, {
      'ownerUid': 'u-me',
      'ownerName': 'Mən',
      'images': ['a.jpg'],
    });

    expect(find.text('1/1'), findsNothing);
  });

  testWidgets('Media yoxdursa karusel qurulmur', (tester) async {
    await pumpCard(tester, {
      'ownerUid': 'u-me',
      'ownerName': 'Mən',
      'caption': 'Sadəcə mətn',
    });

    expect(find.byType(PageView), findsNothing);
    expect(find.text('Sadəcə mətn'), findsOneWidget);
  });
}
