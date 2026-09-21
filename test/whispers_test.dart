import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/whispers.dart';

void main() {
  group('Anonim ad', () {
    test('Eyni açar həmişə eyni adı verir', () {
      expect(whisperAlias('abc123'), whisperAlias('abc123'));
    });

    test('Fərqli açarlar müxtəlif adlar verir', () {
      final names = {
        for (var i = 0; i < 40; i++) whisperAlias('id-$i'),
      };

      // Hamısı fərqli olmaya bilər, amma bir neçə ad çıxmalıdır.
      expect(names.length, greaterThan(3));
    });

    test('Ad boş olmur', () {
      expect(whisperAlias('').trim(), isNotEmpty);
      expect(whisperAlias('x').trim(), isNotEmpty);
    });
  });

  group('Anonim rəng', () {
    test('Eyni açar həmişə eyni rəngi verir', () {
      expect(whisperColor('abc123'), whisperColor('abc123'));
    });

    test('Boş açar da rəng alır', () {
      expect(whisperColor(''), isNotNull);
    });
  });

  group('Gizlətmə', () {
    test('Təzə yazı görünür', () {
      expect(whisperHidden({'reportCount': 0}), isFalse);
    });

    test('Üç şikayətdən sonra gizlənir', () {
      expect(whisperHidden({'reportCount': 2}), isFalse);
      expect(whisperHidden({'reportCount': 3}), isTrue);
      expect(whisperHidden({'reportCount': 10}), isTrue);
    });

    test('Moderator əl ilə gizlədə bilər', () {
      expect(whisperHidden({'hidden': true, 'reportCount': 0}), isTrue);
    });

    test('Sahəsi olmayan sənəd görünür', () {
      expect(whisperHidden(const {}), isFalse);
    });
  });
}
