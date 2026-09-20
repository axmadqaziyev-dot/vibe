import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/games/domino_engine.dart';
import 'package:flutter_application_1/games/domino_page.dart';
import 'package:flutter_application_1/user_profile.dart';

/// Oyun ekranı və iki oyunçu arasındakı sinxronizasiya.
void main() {
  const me = UserProfile(
    uid: 'aysel',
    name: 'Aysel',
    age: 24,
    city: 'Bakı',
    email: '',
    about: '',
  );

  testWidgets('Oyun yaradılır və ekran açılır', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 780 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final db = FakeFirebaseFirestore();

    final matchId = await createDominoMatch(
      myUid: 'aysel',
      myName: 'Aysel',
      opponentUid: 'murad',
      opponentName: 'Murad',
      database: db,
    );

    final saved = await db.collection('dominoMatches').doc(matchId).get();
    final state = DominoState.fromMap(
      Map<String, dynamic>.from(saved.data()!['state']),
    );

    // Paylama düzgündür.
    expect(state.handOf('aysel').length, 7);
    expect(state.handOf('murad').length, 7);
    expect(state.boneyard.length, 14);

    await tester.pumpWidget(
      MaterialApp(
        home: DominoPage(matchId: matchId, profile: me, database: db),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(find.text('Domino'), findsOneWidget);
    expect(find.text('Murad'), findsOneWidget);
    expect(find.text('Masa boşdur — istənilən daşı qoy.'), findsOneWidget);
  });

  testWidgets('Rəqibin hərəkəti ekranda dərhal görünür', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 780 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final db = FakeFirebaseFirestore();

    // Vəziyyəti özümüz qururuq ki, nəticə təxmin edilə bilsin.
    final start = DominoState(
      players: const ['aysel', 'murad'],
      hands: {
        'aysel': [const PlacedTile(1, 2)],
        'murad': [const PlacedTile(6, 6), const PlacedTile(3, 3)],
      },
      board: const [],
      boneyard: const [],
      turn: 'murad',
      passes: 0,
    );

    await db.collection('dominoMatches').doc('m1').set({
      'id': 'm1',
      'players': ['aysel', 'murad'],
      'names': {'aysel': 'Aysel', 'murad': 'Murad'},
      'state': start.toMap(),
    });

    await tester.pumpWidget(
      MaterialApp(
        home: DominoPage(matchId: 'm1', profile: me, database: db),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Rəqibin növbəsi'), findsOneWidget);

    // Rəqib daşı qoyur — biz heç nə etmirik, ekran özü yenilənməlidir.
    final afterMove =
        start.play('murad', const PlacedTile(6, 6), DominoSide.right);
    await db.collection('dominoMatches').doc('m1').set({
      'state': afterMove.toMap(),
    }, SetOptions(merge: true));

    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Növbə səndədir'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
