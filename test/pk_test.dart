import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/party_rooms.dart';

void main() {
  group('PK komanda bölgüsü', () {
    test('Cüt sayda kürsü yarı-yarı bölünür', () {
      // 8 kürsü: 0-3 mavi, 4-7 qırmızı.
      expect([for (var i = 0; i < 8; i++) pkTeamOf(i, 8)],
          [0, 0, 0, 0, 1, 1, 1, 1]);
    });

    test('Tək sayda kürsüdə artıq nəfər mavi tərəfə düşür', () {
      // 5 kürsü: 0-2 mavi (3 nəfər), 3-4 qırmızı (2 nəfər).
      expect([for (var i = 0; i < 5; i++) pkTeamOf(i, 5)], [0, 0, 0, 1, 1]);
    });

    test('İki kürsüdə hər tərəfdə bir nəfər olur', () {
      expect(pkTeamOf(0, 2), 0);
      expect(pkTeamOf(1, 2), 1);
    });

    test('Hər kürsü mütləq bir komandaya düşür', () {
      for (final count in const [2, 3, 6, 9, 12, 20]) {
        final teams = [for (var i = 0; i < count; i++) pkTeamOf(i, count)];

        expect(teams.every((t) => t == 0 || t == 1), isTrue,
            reason: '$count kürsüdə komanda nömrəsi 0 və ya 1 olmalıdır');

        // Heç bir tərəf boş qalmamalıdır, yoxsa yarış mənasız olur.
        expect(teams.contains(0), isTrue, reason: '$count kürsü: mavi boşdur');
        expect(teams.contains(1), isTrue,
            reason: '$count kürsü: qırmızı boşdur');
      }
    });

    test('Bölgü sırasına görədir — mavi həmişə soldadır', () {
      // Bir dəfə qırmızıya keçəndən sonra geri maviyə qayıtmamalıdır.
      final teams = [for (var i = 0; i < 12; i++) pkTeamOf(i, 12)];
      final firstRed = teams.indexOf(1);

      expect(teams.sublist(firstRed).every((t) => t == 1), isTrue);
    });
  });
}
