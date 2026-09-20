import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/gifts.dart';

void main() {
  group('Mövsüm hesablaması', () {
    test('Yeni il ilin sonundan yanvara keçir', () {
      final gift = allGifts.firstWhere((g) => g.title == 'Şam ağacı');
      final season = gift.season!;

      expect(season.contains(DateTime(2026, 12, 20)), isTrue);
      expect(season.contains(DateTime(2026, 1, 5)), isTrue);
      expect(season.contains(DateTime(2026, 6, 1)), isFalse);
    });

    test('Novruz yalnız martın ortasındadır', () {
      final gift = allGifts.firstWhere((g) => g.title == 'Novruz tonqalı');
      final season = gift.season!;

      expect(season.contains(DateTime(2026, 3, 20)), isTrue);
      expect(season.contains(DateTime(2026, 3, 1)), isFalse);
      expect(season.contains(DateTime(2026, 4, 1)), isFalse);
    });
  });

  group('Siyahı', () {
    test('Mövsümdən kənarda yalnız adi hədiyyələr görünür', () {
      // 1 oktyabr — heç bir mövsüm aktiv deyil.
      final list = giftsFor(DateTime(2026, 10, 1));

      expect(list.every((g) => !g.isSeasonal), isTrue);
      expect(list.length, allGifts.where((g) => !g.isSeasonal).length);
    });

    test('Mövsümdə həmin hədiyyələr əvvələ keçir', () {
      final list = giftsFor(DateTime(2026, 3, 20));

      expect(list.first.isSeasonal, isTrue);
      expect(list.first.season!.name, 'Novruz');
      // Adi hədiyyələr də qalır.
      expect(list.any((g) => g.title == 'Gül'), isTrue);
    });

    test('Aktiv mövsümün adı qaytarılır', () {
      expect(activeSeasonName(DateTime(2026, 2, 12)), 'Sevgililər günü');
      expect(activeSeasonName(DateTime(2026, 10, 1)), isNull);
    });

    test('Qiymətlər müsbətdir və adlar boş deyil', () {
      for (final gift in allGifts) {
        expect(gift.price, greaterThan(0), reason: gift.title);
        expect(gift.title.trim(), isNotEmpty);
        expect(gift.emoji.trim(), isNotEmpty);
      }
    });
  });
}
