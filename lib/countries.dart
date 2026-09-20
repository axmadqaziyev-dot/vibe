/// ÖLKƏ SİYAHISI.
///
/// Qeydiyyatda və profildə istifadə olunur. Bayraqlar emoji ilə göstərilir —
/// telefonlarda düzgün görünür; Windows brauzerində iki hərf kimi çıxır,
/// ona görə siyahıda ölkə kodu da saxlanılır.
library;

class Country {
  const Country(this.code, this.name, this.flag);

  /// ISO kodu — bazada bunu saxlayırıq ki, ad dəyişsə də qırılmasın.
  final String code;

  final String name;
  final String flag;
}

/// Ən çox gözlənilən ölkələr — siyahının başında göstərilir.
const List<String> popularCountryCodes = [
  'AZ', 'TR', 'RU', 'GE', 'IR', 'KZ', 'UA', 'AE', 'DE', 'US',
];

/// Bütün ölkələr (Azərbaycan dilində, əlifba sırası ilə).
const List<Country> allCountries = [
  Country('AF', 'Əfqanıstan', '🇦🇫'),
  Country('AL', 'Albaniya', '🇦🇱'),
  Country('DZ', 'Əlcəzair', '🇩🇿'),
  Country('AR', 'Argentina', '🇦🇷'),
  Country('AM', 'Ermənistan', '🇦🇲'),
  Country('AU', 'Avstraliya', '🇦🇺'),
  Country('AT', 'Avstriya', '🇦🇹'),
  Country('AZ', 'Azərbaycan', '🇦🇿'),
  Country('BH', 'Bəhreyn', '🇧🇭'),
  Country('BD', 'Banqladeş', '🇧🇩'),
  Country('BY', 'Belarus', '🇧🇾'),
  Country('BE', 'Belçika', '🇧🇪'),
  Country('BA', 'Bosniya və Herseqovina', '🇧🇦'),
  Country('BR', 'Braziliya', '🇧🇷'),
  Country('BG', 'Bolqarıstan', '🇧🇬'),
  Country('CA', 'Kanada', '🇨🇦'),
  Country('CN', 'Çin', '🇨🇳'),
  Country('HR', 'Xorvatiya', '🇭🇷'),
  Country('CY', 'Kipr', '🇨🇾'),
  Country('CZ', 'Çexiya', '🇨🇿'),
  Country('DK', 'Danimarka', '🇩🇰'),
  Country('EG', 'Misir', '🇪🇬'),
  Country('EE', 'Estoniya', '🇪🇪'),
  Country('FI', 'Finlandiya', '🇫🇮'),
  Country('FR', 'Fransa', '🇫🇷'),
  Country('GE', 'Gürcüstan', '🇬🇪'),
  Country('DE', 'Almaniya', '🇩🇪'),
  Country('GR', 'Yunanıstan', '🇬🇷'),
  Country('HU', 'Macarıstan', '🇭🇺'),
  Country('IN', 'Hindistan', '🇮🇳'),
  Country('ID', 'İndoneziya', '🇮🇩'),
  Country('IR', 'İran', '🇮🇷'),
  Country('IQ', 'İraq', '🇮🇶'),
  Country('IE', 'İrlandiya', '🇮🇪'),
  Country('IL', 'İsrail', '🇮🇱'),
  Country('IT', 'İtaliya', '🇮🇹'),
  Country('JP', 'Yaponiya', '🇯🇵'),
  Country('JO', 'İordaniya', '🇯🇴'),
  Country('KZ', 'Qazaxıstan', '🇰🇿'),
  Country('KW', 'Küveyt', '🇰🇼'),
  Country('KG', 'Qırğızıstan', '🇰🇬'),
  Country('LV', 'Latviya', '🇱🇻'),
  Country('LB', 'Livan', '🇱🇧'),
  Country('LY', 'Liviya', '🇱🇾'),
  Country('LT', 'Litva', '🇱🇹'),
  Country('MY', 'Malayziya', '🇲🇾'),
  Country('MD', 'Moldova', '🇲🇩'),
  Country('MA', 'Mərakeş', '🇲🇦'),
  Country('NL', 'Hollandiya', '🇳🇱'),
  Country('NZ', 'Yeni Zelandiya', '🇳🇿'),
  Country('NG', 'Nigeriya', '🇳🇬'),
  Country('NO', 'Norveç', '🇳🇴'),
  Country('OM', 'Oman', '🇴🇲'),
  Country('PK', 'Pakistan', '🇵🇰'),
  Country('PS', 'Fələstin', '🇵🇸'),
  Country('PL', 'Polşa', '🇵🇱'),
  Country('PT', 'Portuqaliya', '🇵🇹'),
  Country('QA', 'Qətər', '🇶🇦'),
  Country('RO', 'Rumıniya', '🇷🇴'),
  Country('RU', 'Rusiya', '🇷🇺'),
  Country('SA', 'Səudiyyə Ərəbistanı', '🇸🇦'),
  Country('RS', 'Serbiya', '🇷🇸'),
  Country('SG', 'Sinqapur', '🇸🇬'),
  Country('SK', 'Slovakiya', '🇸🇰'),
  Country('ZA', 'Cənubi Afrika', '🇿🇦'),
  Country('KR', 'Cənubi Koreya', '🇰🇷'),
  Country('ES', 'İspaniya', '🇪🇸'),
  Country('SE', 'İsveç', '🇸🇪'),
  Country('CH', 'İsveçrə', '🇨🇭'),
  Country('SY', 'Suriya', '🇸🇾'),
  Country('TJ', 'Tacikistan', '🇹🇯'),
  Country('TH', 'Tailand', '🇹🇭'),
  Country('TN', 'Tunis', '🇹🇳'),
  Country('TR', 'Türkiyə', '🇹🇷'),
  Country('TM', 'Türkmənistan', '🇹🇲'),
  Country('UA', 'Ukrayna', '🇺🇦'),
  Country('AE', 'BƏƏ', '🇦🇪'),
  Country('GB', 'Böyük Britaniya', '🇬🇧'),
  Country('US', 'ABŞ', '🇺🇸'),
  Country('UZ', 'Özbəkistan', '🇺🇿'),
  Country('VN', 'Vyetnam', '🇻🇳'),
  Country('YE', 'Yəmən', '🇾🇪'),
];

/// Koda görə ölkəni tapır.
Country? countryByCode(String? code) {
  if (code == null || code.isEmpty) return null;
  final upper = code.toUpperCase();
  for (final country in allCountries) {
    if (country.code == upper) return country;
  }
  return null;
}

/// Populyar ölkələr — verilmiş sıra ilə.
List<Country> get popularCountries {
  final result = <Country>[];
  for (final code in popularCountryCodes) {
    final country = countryByCode(code);
    if (country != null) result.add(country);
  }
  return result;
}

/// Ada görə axtarış. Azərbaycan hərfləri də nəzərə alınır.
List<Country> searchCountries(String query) {
  final text = _normalize(query);
  if (text.isEmpty) return allCountries;

  return allCountries
      .where((c) =>
          _normalize(c.name).contains(text) ||
          c.code.toLowerCase().contains(text))
      .toList();
}

/// Axtarışda "ə/e", "ı/i", "ş/s" fərqi maneə olmasın.
String _normalize(String value) {
  const map = {
    'ə': 'e',
    'ğ': 'g',
    'ı': 'i',
    'İ': 'i',
    'ö': 'o',
    'ş': 's',
    'ü': 'u',
    'ç': 'c',
  };

  final lower = value.toLowerCase().trim();
  final buffer = StringBuffer();
  for (final char in lower.split('')) {
    buffer.write(map[char] ?? char);
  }
  return buffer.toString();
}
