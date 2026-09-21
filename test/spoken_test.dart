import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/spoken.dart';

void main() {
  group('Dillər', () {
    test('Hər dilin adı, bayrağı və qısa kodu var', () {
      for (final lang in Spoken.values) {
        expect(lang.label.trim(), isNotEmpty);
        expect(lang.flag.trim(), isNotEmpty);
        expect(lang.short.length, 2);
      }
    });

    test('Açardan dil tapılır, böyük-kiçik hərf fərq etmir', () {
      expect(spokenFrom('tr'), Spoken.tr);
      expect(spokenFrom('RU'), Spoken.ru);
    });

    test('Tanınmayan açar boş qayıdır', () {
      expect(spokenFrom('xx'), isNull);
      expect(spokenFrom(null), isNull);
    });
  });

  group('Ölkədən dil', () {
    test('Tanınan ölkələr öz dilini alır', () {
      expect(spokenForCountry('AZ'), Spoken.az);
      expect(spokenForCountry('TR'), Spoken.tr);
      expect(spokenForCountry('RU'), Spoken.ru);
      expect(spokenForCountry('KZ'), Spoken.ru);
    });

    test('Kiçik hərflə də işləyir', () {
      expect(spokenForCountry('az'), Spoken.az);
    });

    test('Tanınmayan ölkə ingilis dilinə düşür', () {
      expect(spokenForCountry('BR'), Spoken.en);
      expect(spokenForCountry(''), Spoken.en);
    });
  });

  group('Yaxınlıq', () {
    test('Eyni dil həmişə yaxındır', () {
      for (final lang in Spoken.values) {
        expect(spokenClose(lang, lang), isTrue);
      }
    });

    test('Azərbaycan və türk dilləri yaxın sayılır', () {
      expect(spokenClose(Spoken.az, Spoken.tr), isTrue);
      expect(spokenClose(Spoken.tr, Spoken.az), isTrue);
    });

    test('Rus və azərbaycan dilləri yaxın deyil', () {
      expect(spokenClose(Spoken.ru, Spoken.az), isFalse);
    });
  });

  group('Sıralama balı', () {
    test('Eyni dil ən yüksək baldır', () {
      expect(spokenScore(Spoken.az, Spoken.az), 1);
    });

    test('Yaxın dil ortadadır', () {
      final close = spokenScore(Spoken.az, Spoken.tr);
      expect(close, lessThan(1));
      expect(close, greaterThan(spokenScore(Spoken.az, Spoken.ru)));
    });

    test('İngilis dili körpü sayılır', () {
      expect(
        spokenScore(Spoken.ru, Spoken.en),
        greaterThan(spokenScore(Spoken.ru, Spoken.az)),
      );
    });

    test('Dil bilinmirsə orta bal verilir', () {
      // Nişanı olmayan köhnə profil siyahının sonuna atılmamalıdır.
      final unknown = spokenScore(Spoken.az, null);
      expect(unknown, greaterThan(spokenScore(Spoken.az, Spoken.ru)));
      expect(unknown, lessThan(spokenScore(Spoken.az, Spoken.az)));
    });

    test('Bal həmişə 0 ilə 1 arasındadır', () {
      final values = [...Spoken.values, null];
      for (final a in values) {
        for (final b in values) {
          expect(spokenScore(a, b), inInclusiveRange(0, 1));
        }
      }
    });
  });
}
