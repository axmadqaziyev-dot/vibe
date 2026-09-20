import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/families.dart';

void main() {
  group('Yön', () {
    test('Hər yönün adı və işarəsi var', () {
      for (final kind in FamilyKind.values) {
        expect(kind.label.trim(), isNotEmpty);
        expect(kind.emoji.trim(), isNotEmpty);
      }
    });

    test('Açardan yön tapılır', () {
      expect(familyKindFrom('duel'), FamilyKind.duel);
      expect(familyKindFrom('wealth'), FamilyKind.wealth);
    });

    test('Tanınmayan açar sosial sayılır', () {
      // Köhnə sənəddə başqa dəyər ola bilər — ekran sınmamalıdır.
      expect(familyKindFrom('kohne-deyer'), FamilyKind.social);
      expect(familyKindFrom(null), FamilyKind.social);
    });
  });

  group('Səviyyə', () {
    test('Boş xəzinə birinci səviyyədir', () {
      expect(familyLevel(0), 1);
    });

    test('Hədd keçiləndə səviyyə artır', () {
      expect(familyLevel(9999), 1);
      expect(familyLevel(10000), 2);
      expect(familyLevel(25000), 3);
    });

    test('Çox böyük xəzinə ən yuxarı səviyyədə dayanır', () {
      expect(familyLevel(999999999), familyLevels.length);
    });

    test('Səviyyə heç vaxt azalmır', () {
      var last = 0;
      for (var treasure = 0; treasure < 1200000; treasure += 5000) {
        final level = familyLevel(treasure);
        expect(level, greaterThanOrEqualTo(last));
        last = level;
      }
    });
  });

  group('Səviyyə göstəricisi', () {
    test('Səviyyənin başında sıfıra yaxındır', () {
      expect(familyProgress(10000), closeTo(0, 0.001));
    });

    test('Ortada təxminən yarıdır', () {
      // 2-ci səviyyə 10000-25000 arasıdır, ortası 17500.
      expect(familyProgress(17500), closeTo(0.5, 0.01));
    });

    test('Ən yuxarı səviyyədə tamdır', () {
      expect(familyProgress(999999999), 1);
      expect(familyToNextLevel(999999999), 0);
    });

    test('Qalan məsafə düzgün hesablanır', () {
      expect(familyToNextLevel(0), 10000);
      expect(familyToNextLevel(9000), 1000);
    });
  });

  group('Ad yoxlanışı', () {
    test('Boş ad qəbul edilmir', () {
      expect(familyNameError(''), isNotNull);
      expect(familyNameError('    '), isNotNull);
    });

    test('Çox qısa ad qəbul edilmir', () {
      expect(familyNameError('AB'), isNotNull);
    });

    test('Çox uzun ad qəbul edilmir', () {
      expect(familyNameError('A' * 21), isNotNull);
    });

    test('Normal ad keçir', () {
      expect(familyNameError('VIBE Ailəsi'), isNull);
      expect(familyNameError('  Ulduzlar  '), isNull);
    });
  });

  group('Təsvir yoxlanışı', () {
    test('Boş təsvir olar', () {
      expect(familyAboutError(''), isNull);
    });

    test('200 hərfdən uzun təsvir keçmir', () {
      expect(familyAboutError('a' * 201), isNotNull);
      expect(familyAboutError('a' * 200), isNull);
    });
  });
}
