import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/countries.dart';

void main() {
  group('Siyahı', () {
    test('Kodlar təkrarlanmır', () {
      final codes = allCountries.map((c) => c.code).toList();
      expect(codes.toSet().length, codes.length);
    });

    test('Hər ölkənin adı və bayrağı var', () {
      for (final country in allCountries) {
        expect(country.name.trim(), isNotEmpty, reason: country.code);
        expect(country.flag.trim(), isNotEmpty, reason: country.code);
        expect(country.code.length, 2, reason: country.name);
      }
    });

    test('Populyar siyahıdakı hər kod əsas siyahıda var', () {
      expect(popularCountries.length, popularCountryCodes.length);
      expect(popularCountries.first.code, 'AZ');
    });
  });

  group('Axtarış', () {
    test('Ada görə tapır', () {
      final result = searchCountries('Türkiyə');
      expect(result.map((c) => c.code), contains('TR'));
    });

    test('Azərbaycan hərfləri olmadan da tapır', () {
      // "Turkiye" yazsa da tapmalıdır.
      expect(searchCountries('turkiye').map((c) => c.code), contains('TR'));
      expect(searchCountries('azerbaycan').map((c) => c.code), contains('AZ'));
    });

    test('Koda görə də tapır', () {
      expect(searchCountries('ae').map((c) => c.code), contains('AE'));
    });

    test('Boş axtarış hamısını qaytarır', () {
      expect(searchCountries('').length, allCountries.length);
      expect(searchCountries('   ').length, allCountries.length);
    });

    test('Tapılmayan söz boş nəticə verir', () {
      expect(searchCountries('zzzqqq'), isEmpty);
    });
  });

  group('Koda görə tapmaq', () {
    test('Böyük-kiçik hərf fərq etmir', () {
      expect(countryByCode('az')?.name, 'Azərbaycan');
      expect(countryByCode('AZ')?.name, 'Azərbaycan');
    });

    test('Naməlum kod null qaytarır', () {
      expect(countryByCode('XX'), isNull);
      expect(countryByCode(''), isNull);
      expect(countryByCode(null), isNull);
    });
  });
}
