import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/rankings.dart';

void main() {
  group('Gün açarı', () {
    test('Rəqəmlər iki xanaya tamamlanır', () {
      expect(dayKey(DateTime(2026, 9, 5)), 'd2026-09-05');
      expect(dayKey(DateTime(2026, 12, 31)), 'd2026-12-31');
    });

    test('Eyni günün fərqli saatları eyni açarı verir', () {
      expect(
        dayKey(DateTime(2026, 9, 21, 0, 1)),
        dayKey(DateTime(2026, 9, 21, 23, 59)),
      );
    });

    test('Gecə yarısı açar dəyişir', () {
      expect(
        dayKey(DateTime(2026, 9, 21, 23, 59)),
        isNot(dayKey(DateTime(2026, 9, 22, 0, 0))),
      );
    });
  });

  group('Həftə açarı', () {
    test('Həftənin bütün günləri eyni açardadır', () {
      // 2026-09-21 bazar ertəsi, 2026-09-27 bazar.
      final keys = {
        for (var day = 21; day <= 27; day++)
          weekKey(DateTime(2026, 9, day)),
      };

      expect(keys.length, 1, reason: 'bir həftə bir açar olmalıdır');
    });

    test('Növbəti bazar ertəsi yeni həftədir', () {
      expect(
        weekKey(DateTime(2026, 9, 27)),
        isNot(weekKey(DateTime(2026, 9, 28))),
      );
    });

    test('İlin ilk həftəsi 4 yanvarın düşdüyü həftədir', () {
      // ISO qaydası: 4 yanvar həmişə 1-ci həftədədir.
      expect(weekKey(DateTime(2026, 1, 4)), 'w2026-01');
    });

    test('Dekabrın sonu növbəti ilin həftəsinə düşə bilər', () {
      // 2025-12-29 bazar ertəsidir və ISO ilə 2026-cı ilin 1-ci həftəsidir.
      expect(weekKey(DateTime(2025, 12, 29)), 'w2026-01');
    });

    test('Yanvarın əvvəli keçən ilin son həftəsində qala bilər', () {
      // 2027-01-01 cümədir, ISO ilə hələ 2026-cı ilin 53-cü həftəsidir.
      expect(weekKey(DateTime(2027, 1, 1)), 'w2026-53');
    });

    test('Həftə nömrəsi həmişə iki xanadır', () {
      for (var month = 1; month <= 12; month++) {
        final key = weekKey(DateTime(2026, month, 15));
        expect(key, matches(RegExp(r'^w\d{4}-\d{2}$')), reason: key);
      }
    });
  });

  group('Dövr açarı', () {
    test('Ümumi lövhənin açarı olmur', () {
      expect(periodKey(RankingPeriod.all, DateTime(2026, 9, 21)), isNull);
    });

    test('Günlük və həftəlik öz açarını verir', () {
      final now = DateTime(2026, 9, 21);
      expect(periodKey(RankingPeriod.today, now), 'd2026-09-21');
      expect(periodKey(RankingPeriod.week, now), weekKey(now));
    });
  });
}
