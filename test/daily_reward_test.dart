import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/daily_reward.dart';

void main() {
  final today = DateTime(2026, 9, 20, 14, 30);
  final yesterday = DateTime(2026, 9, 19, 9, 0);
  final twoDaysAgo = DateTime(2026, 9, 18, 23, 59);

  group('Mükafat cədvəli', () {
    test('Seriya günü 1-dən 7-yə qədər dövr edir', () {
      expect(dayInCycle(1), 1);
      expect(dayInCycle(7), 7);
      expect(dayInCycle(8), 1);
      expect(dayInCycle(15), 1);
      expect(dayInCycle(0), 1);
    });

    test('Mükafat günlə birlikdə artır', () {
      expect(rewardForStreak(1), 20);
      expect(rewardForStreak(7), 200);
      // Yeni dövrə yenidən kiçikdən başlayır.
      expect(rewardForStreak(8), 20);
    });
  });

  group('Alına bilərmi', () {
    test('Heç vaxt almayıbsa alınır', () {
      expect(canClaimToday(null, today), isTrue);
    });

    test('Bu gün artıq alıbsa alınmır', () {
      expect(canClaimToday(DateTime(2026, 9, 20, 1, 0), today), isFalse);
    });

    test('Dünən alıbsa bu gün yenidən alınır', () {
      expect(canClaimToday(yesterday, today), isTrue);
    });
  });

  group('Seriya', () {
    test('İlk dəfə birinci gündür', () {
      expect(nextStreak(null, 0, today), 1);
    });

    test('Dünən alıbsa seriya davam edir', () {
      expect(nextStreak(yesterday, 3, today), 4);
    });

    test('Bir gün buraxılıbsa seriya sıfırlanır', () {
      expect(nextStreak(twoDaysAgo, 6, today), 1);
    });

    test('Bu gün alınıbsa seriya dəyişmir', () {
      expect(nextStreak(DateTime(2026, 9, 20, 2), 5, today), 5);
    });
  });

  group('Firestore ilə', () {
    test('Mükafat verilir və seriya yazılır', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('users').doc('u1').set({'coins': 100});

      final reward = await claimDailyReward(
        uid: 'u1',
        database: db,
        now: today,
      );

      expect(reward, 20);

      final saved = (await db.collection('users').doc('u1').get()).data()!;
      expect(saved['dailyStreak'], 1);
      expect(saved['coins'], 120);
    });

    test('Eyni gün ikinci dəfə verilmir', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('users').doc('u1').set({'coins': 100});

      await claimDailyReward(uid: 'u1', database: db, now: today);
      final second = await claimDailyReward(uid: 'u1', database: db, now: today);

      expect(second, isNull);

      final saved = (await db.collection('users').doc('u1').get()).data()!;
      expect(saved['coins'], 120, reason: 'balans ikinci dəfə artmamalıdır');
    });

    test('Ardıcıl gün daha böyük mükafat verir', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('users').doc('u1').set({
        'coins': 0,
        'dailyStreak': 2,
        'dailyClaimAt': Timestamp.fromDate(yesterday),
      });

      final reward = await claimDailyReward(
        uid: 'u1',
        database: db,
        now: today,
      );

      // 3-cü gün → 40 coin.
      expect(reward, 40);
      final saved = (await db.collection('users').doc('u1').get()).data()!;
      expect(saved['dailyStreak'], 3);
    });
  });
}
