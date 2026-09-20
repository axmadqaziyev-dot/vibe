import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/rankings.dart';
import 'package:flutter_application_1/user_profile.dart';
import 'package:flutter_application_1/vibe_ranking.dart';

const me = UserProfile(
  uid: 'u-me',
  name: 'Mən',
  age: 25,
  city: 'Bakı',
  email: 'me@vibe.az',
  about: '',
);

final gun = DateTime(2026, 9, 21, 12);

/// Günlük lövhəyə bir neçə nəfər yazır.
Future<FakeFirebaseFirestore> seedDay() async {
  final db = FakeFirebaseFirestore();
  final users = db.collection('rankings').doc(dayKey(gun)).collection('users');

  await users.doc('u-1').set({'uid': 'u-1', 'name': 'Aygün', 'sent': 900});
  await users.doc('u-2').set({'uid': 'u-2', 'name': 'Elvin', 'sent': 500});
  await users.doc('u-3').set({'uid': 'u-3', 'name': 'Nigar', 'sent': 300});
  await users.doc('u-4').set({'uid': 'u-4', 'name': 'Tural', 'sent': 120});
  await users.doc('u-me').set({'uid': 'u-me', 'name': 'Mən', 'sent': 60});

  // Xalı sıfır olan lövhəyə düşməməlidir.
  await users.doc('u-0').set({'uid': 'u-0', 'name': 'Boş', 'sent': 0});

  return db;
}

Future<void> pump(WidgetTester tester, FakeFirebaseFirestore db) async {
  await tester.pumpWidget(
    MaterialApp(
      home: VibeRankingPage(profile: me, database: db, now: gun),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('Günlük lövhədə ilk üçlük podiumda görünür', (tester) async {
    await pump(tester, await seedDay());

    expect(find.text('Aygün'), findsOneWidget);
    expect(find.text('Elvin'), findsOneWidget);
    expect(find.text('Nigar'), findsOneWidget);

    // Podium nişanları.
    expect(find.text('🥇'), findsOneWidget);
    expect(find.text('🥈'), findsOneWidget);
    expect(find.text('🥉'), findsOneWidget);
  });

  testWidgets('Dördüncü yerdən aşağı sıra nömrəsi ilə gəlir', (tester) async {
    await pump(tester, await seedDay());

    expect(find.text('#4'), findsOneWidget);
    expect(find.text('Tural'), findsOneWidget);
  });

  testWidgets('Xalı sıfır olan lövhəyə düşmür', (tester) async {
    await pump(tester, await seedDay());

    expect(find.text('Boş'), findsNothing);
  });

  testWidgets('İstifadəçi öz yerini altda görür', (tester) async {
    await pump(tester, await seedDay());

    // Beşinci yer: 900, 500, 300, 120, 60.
    expect(find.textContaining('Sənin yerin: #5'), findsOneWidget);
  });

  testWidgets('Lövhədə olmayan istifadəçiyə izah göstərilir', (tester) async {
    final db = FakeFirebaseFirestore();
    await db
        .collection('rankings')
        .doc(dayKey(gun))
        .collection('users')
        .doc('u-1')
        .set({'uid': 'u-1', 'name': 'Aygün', 'sent': 900});

    await pump(tester, db);

    expect(find.textContaining('ilk 50-də deyilsən'), findsOneWidget);
  });

  testWidgets('Boş gün üçün izah mətni çıxır', (tester) async {
    await pump(tester, FakeFirebaseFirestore());

    expect(find.textContaining('Bu gün hələ hədiyyə göndərilməyib'),
        findsOneWidget);
  });

  testWidgets('Dövr düyməsinə basanda başqa lövhə açılır', (tester) async {
    final db = await seedDay();

    // Ümumi lövhə users kolleksiyasından oxunur, oradakı adlar başqadır.
    await db
        .collection('users')
        .doc('u-9')
        .set({'uid': 'u-9', 'name': 'Ümumi lider', 'giftSent': 5000});

    await pump(tester, db);
    expect(find.text('Aygün'), findsOneWidget);

    await tester.tap(find.text('Ümumi'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Ümumi lider'), findsOneWidget);
    expect(find.text('Aygün'), findsNothing);
  });
}
