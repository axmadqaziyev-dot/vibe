import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/games/lucky_box.dart';

void main() {
  group('qutunun quruluşu', () {
    test('çəkilərin cəmi mindir — faiz birbaşa oxunsun', () {
      expect(boxWeightTotal, 1000);
    });

    test('hər nəticənin faizi hesablanır', () {
      expect(boxChance(boxPrizes.first), 42.0);
      expect(boxChance(boxPrizes.last), 0.1);
    });

    test('faizlərin cəmi yüzdür', () {
      final total = boxPrizes.fold<double>(0, (sum, p) => sum + boxChance(p));
      expect(total, closeTo(100, 0.001));
    });
  });

  group('qazanc payı', () {
    test('birdən kiçikdir — tətbiq uduzmur', () {
      expect(boxReturnRate, lessThan(1));
    });

    test('oyunçunu bezdirəcək qədər kiçik deyil', () {
      // Çox aşağı pay adamı bir neçə cəhddən sonra qovur.
      expect(boxReturnRate, greaterThan(0.75));
    });
  });

  group('açılış', () {
    test('nəticə həmişə siyahıdandır', () {
      final random = Random(7);
      for (var i = 0; i < 500; i++) {
        expect(boxPrizes.contains(openBox(random: random)), isTrue);
      }
    });

    test('eyni toxumla eyni nəticə', () {
      // Sınağın təkrarlana bilməsi üçün vacibdir.
      expect(
        openBox(random: Random(42)).label,
        openBox(random: Random(42)).label,
      );
    });

    test('çox açılışda orta pay hesablanana yaxındır', () {
      final random = Random(1);
      const bet = 1000;
      var spent = 0;
      var won = 0;

      for (var i = 0; i < 40000; i++) {
        spent += bet;
        won += boxPayout(bet, openBox(random: random));
      }

      expect(won / spent, closeTo(boxReturnRate, 0.06));
    });

    test('boş nəticə sıfır qaytarır', () {
      final empty = boxPrizes.firstWhere((p) => p.multiplier == 0);
      expect(boxPayout(1000, empty), 0);
    });

    test('cackpot yüz misli verir', () {
      final top = boxPrizes.last;
      expect(boxPayout(100, top), 10000);
    });
  });

  group('mərclər', () {
    test('hamısı müsbət və artan sıradadır', () {
      for (var i = 1; i < boxBets.length; i++) {
        expect(boxBets[i], greaterThan(boxBets[i - 1]));
      }
      expect(boxBets.first, greaterThan(0));
    });
  });
}
