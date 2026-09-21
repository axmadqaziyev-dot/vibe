import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/room_contributors.dart';

void main() {
  group('dövr açarları', () {
    test('gün açarı sıfırla doldurulur', () {
      expect(dayKey(DateTime(2026, 9, 7)), 'd_2026-09-07');
    });

    test('eyni həftənin günləri eyni açarı verir', () {
      // 2026-09-21 bazar ertəsi, 2026-09-27 bazar.
      expect(
        weekKey(DateTime(2026, 9, 21)),
        weekKey(DateTime(2026, 9, 27)),
      );
    });

    test('növbəti həftə başqa açardır', () {
      expect(
        weekKey(DateTime(2026, 9, 27)),
        isNot(weekKey(DateTime(2026, 9, 28))),
      );
    });

    test('il sərhədi həftəni pozmur', () {
      // Dekabrın son günləri ilə yanvarın ilk günləri eyni ISO
      // həftəsinə düşür. Sadə "gün / 7" bölgüsü burada sıçrayırdı.
      expect(
        weekKey(DateTime(2025, 12, 31)),
        weekKey(DateTime(2026, 1, 1)),
      );
    });
  });

  group('hədiyyə yazısı', () {
    test('üç sayğac birdən artır', () {
      final now = DateTime(2026, 9, 21, 14);
      final update = contributorUpdate(
        name: 'Asif',
        photo: '',
        amount: 500,
        now: now,
      );

      expect(update.containsKey('total'), isTrue);
      expect(update.containsKey(dayKey(now)), isTrue);
      expect(update.containsKey(weekKey(now)), isTrue);
      expect(update['name'], 'Asif');
    });

    test('şəkil boşdursa yazılmır', () {
      // Boş dəyər köhnə şəkli silərdi.
      final update = contributorUpdate(name: 'A', photo: '', amount: 1);
      expect(update.containsKey('photo'), isFalse);
    });
  });

  group('sıralama', () {
    final now = DateTime(2026, 9, 21);

    final docs = [
      (id: 'a', data: <String, dynamic>{'name': 'A', 'total': 100, dayKey(now): 10}),
      (id: 'b', data: <String, dynamic>{'name': 'B', 'total': 50, dayKey(now): 40}),
      (id: 'c', data: <String, dynamic>{'name': 'C', 'total': 900}),
    ];

    test('ümumi üzrə sıralanır', () {
      final ranked = rankContributors(docs, GiftPeriod.all, now: now);
      expect(ranked.map((c) => c.uid), ['c', 'a', 'b']);
    });

    test('günlük üzrə sıralama başqadır', () {
      // "C" bu gün heç nə verməyib — günlük siyahıda olmamalıdır.
      final ranked = rankContributors(docs, GiftPeriod.day, now: now);
      expect(ranked.map((c) => c.uid), ['b', 'a']);
    });

    test('sıfır töhfə siyahıya düşmür', () {
      final ranked = rankContributors(
        [(id: 'x', data: <String, dynamic>{'name': 'X', 'total': 0})],
        GiftPeriod.all,
        now: now,
      );
      expect(ranked, isEmpty);
    });

    test('sahəsi olmayan sənəd tətbiqi qırmır', () {
      final ranked = rankContributors(
        [(id: 'x', data: <String, dynamic>{})],
        GiftPeriod.all,
        now: now,
      );
      expect(ranked, isEmpty);
    });
  });
}
