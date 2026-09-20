import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/tonight.dart';

void main() {
  group('Niyyət', () {
    test('Hər niyyətin adı, işarəsi və izahı var', () {
      for (final item in Tonight.values) {
        expect(item.label.trim(), isNotEmpty);
        expect(item.emoji.trim(), isNotEmpty);
        expect(item.hint.trim(), isNotEmpty);
      }
    });

    test('Açardan niyyət tapılır', () {
      expect(tonightFrom('vent'), Tonight.vent);
      expect(tonightFrom('sing'), Tonight.sing);
    });

    test('Tanınmayan açar boş qayıdır', () {
      expect(tonightFrom('kohne'), isNull);
      expect(tonightFrom(null), isNull);
    });
  });

  group('Uyğunluq', () {
    test('Danışan ilə dinləyən mükəmməl cütdür', () {
      expect(tonightMatch(Tonight.talk, Tonight.listen), 1);
      expect(tonightMatch(Tonight.listen, Tonight.talk), 1);
    });

    test('Dərdləşən ilə dinləyən mükəmməl cütdür', () {
      expect(tonightMatch(Tonight.vent, Tonight.listen), 1);
    });

    test('İki danışan bir-birindən yaxşı cüt deyil', () {
      // İkisi də danışmaq istəyirsə heç kim dinləməyəcək.
      expect(
        tonightMatch(Tonight.talk, Tonight.talk),
        lessThan(tonightMatch(Tonight.talk, Tonight.listen)),
      );
    });

    test('İki dinləyici ən pis cütdür', () {
      expect(
        tonightMatch(Tonight.listen, Tonight.listen),
        lessThan(tonightMatch(Tonight.talk, Tonight.talk)),
      );
    });

    test('Birlikdə edilən işlərdə eyni niyyət düzgündür', () {
      expect(tonightMatch(Tonight.game, Tonight.game), 1);
      expect(tonightMatch(Tonight.meet, Tonight.meet), 1);
      expect(tonightMatch(Tonight.sing, Tonight.sing), 1);
    });

    test('Dərdləşənə oyun təklifi ən aşağı baldır', () {
      expect(tonightMatch(Tonight.vent, Tonight.game), lessThan(0.2));
    });

    test('Bal həmişə 0 ilə 1 arasındadır', () {
      for (final a in Tonight.values) {
        for (final b in Tonight.values) {
          final score = tonightMatch(a, b);
          expect(score, inInclusiveRange(0, 1), reason: '$a + $b');
        }
      }
    });
  });

  group('Vaxt', () {
    final now = DateTime(2026, 9, 21, 22);

    test('Təzə niyyət keçərlidir', () {
      expect(tonightAlive(now.subtract(const Duration(hours: 1)), now: now),
          isTrue);
    });

    test('Səkkiz saatdan köhnə niyyət sönür', () {
      expect(tonightAlive(now.subtract(const Duration(hours: 9)), now: now),
          isFalse);
    });

    test('Tarix yoxdursa keçərli deyil', () {
      expect(tonightAlive(null, now: now), isFalse);
    });
  });

  group('Sənəddən oxuma', () {
    final now = DateTime(2026, 9, 21, 22);

    test('Təzə niyyət oxunur', () {
      final raw = {
        'intent': 'talk',
        'at': now.subtract(const Duration(hours: 2)),
      };

      expect(tonightOf(raw, now: now), Tonight.talk);
    });

    test('Vaxtı keçmiş niyyət göstərilmir', () {
      final raw = {
        'intent': 'talk',
        'at': now.subtract(const Duration(hours: 20)),
      };

      expect(tonightOf(raw, now: now), isNull);
    });

    test('Xarab sənəd ekranı sındırmır', () {
      expect(tonightOf(null, now: now), isNull);
      expect(tonightOf('mətn', now: now), isNull);
      expect(tonightOf({'intent': 'talk'}, now: now), isNull);
      expect(tonightOf({'at': now, 'intent': 'yoxdur'}, now: now), isNull);
    });
  });
}
