import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/party_rooms.dart';

void main() {
  group('İki tərəf', () {
    test('Kürsülər yarı-yarı bölünür', () {
      expect([for (var i = 0; i < 8; i++) pkSideOf(i, 8, 2)],
          [0, 0, 0, 0, 1, 1, 1, 1]);
    });

    test('Köhnə pkTeamOf eyni nəticəni verir', () {
      for (var count = 2; count <= 20; count++) {
        for (var i = 0; i < count; i++) {
          expect(pkTeamOf(i, count), pkSideOf(i, count, 2),
              reason: '$count kürsü, $i-ci');
        }
      }
    });
  });

  group('Dörd tərəf', () {
    test('Səkkiz kürsü dörd cütə bölünür', () {
      expect([for (var i = 0; i < 8; i++) pkSideOf(i, 8, 4)],
          [0, 0, 1, 1, 2, 2, 3, 3]);
    });

    test('Dörd kürsüdə hər kəs öz tərəfindədir', () {
      expect([for (var i = 0; i < 4; i++) pkSideOf(i, 4, 4)], [0, 1, 2, 3]);
    });

    test('Kürsü sayı tərəfdən azdırsa sərhəd aşılmır', () {
      // 3 kürsü, 4 tərəf: bəzi tərəflər boş qalır, amma nömrə düzgündür.
      for (var i = 0; i < 3; i++) {
        final side = pkSideOf(i, 3, 4);
        expect(side, inInclusiveRange(0, 3));
      }
    });
  });

  group('Sərhəd halları', () {
    test('Kürsü yoxdursa sıfır qayıdır', () {
      expect(pkSideOf(0, 0, 2), 0);
    });

    test('Tək tərəf olanda hamı birdədir', () {
      expect(pkSideOf(5, 8, 1), 0);
    });

    test('Nömrə heç vaxt tərəf sayını keçmir', () {
      for (final sides in [2, 4]) {
        for (var count = 1; count <= 20; count++) {
          for (var i = 0; i < count; i++) {
            expect(pkSideOf(i, count, sides), lessThan(sides));
          }
        }
      }
    });

    test('Bölgü sıraya görədir — geri qayıtma olmur', () {
      for (final sides in [2, 4]) {
        var last = 0;
        for (var i = 0; i < 12; i++) {
          final side = pkSideOf(i, 12, sides);
          expect(side, greaterThanOrEqualTo(last));
          last = side;
        }
      }
    });
  });

  group('Rənglər və adlar', () {
    test('Hər tərəf üçün rəng və ad var', () {
      expect(pkSideColors.length, greaterThanOrEqualTo(4));
      expect(pkSideNames.length, greaterThanOrEqualTo(4));
    });

    test('Adlar təkrarlanmır', () {
      expect(pkSideNames.toSet().length, pkSideNames.length);
    });
  });
}
