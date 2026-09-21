/// Danışıq dili — otaqlarda və profillərdə.
///
/// Tətbiqin interfeys dili (`app/i18n.dart`) ilə eyni şey deyil.
/// Adam tətbiqi ingiliscə işlədib otaqda rusca danışa bilər. Ona görə
/// bunlar ayrı saxlanılır.
///
/// Niyə lazımdır: dil nişanı olmayanda türk azərbaycanca otağa girir,
/// danışa bilmir, çıxır. Əksi də belə. Çoxdilli tətbiq bir-birini başa
/// düşməyən adamlarla dolur və hamı bezir.
library;

/// Otaqlarda danışıla bilən dillər.
enum Spoken { az, tr, en, ru }

extension SpokenInfo on Spoken {
  String get id => name;

  /// Ad öz dilində yazılır — adam öz dilini tanısın deyə.
  String get label => switch (this) {
        Spoken.az => 'Azərbaycan',
        Spoken.tr => 'Türkçe',
        Spoken.en => 'English',
        Spoken.ru => 'Русский',
      };

  String get flag => switch (this) {
        Spoken.az => '🇦🇿',
        Spoken.tr => '🇹🇷',
        Spoken.en => '🌍',
        Spoken.ru => '🇷🇺',
      };

  /// Siyahıda qısa göstərmək üçün.
  String get short => switch (this) {
        Spoken.az => 'AZ',
        Spoken.tr => 'TR',
        Spoken.en => 'EN',
        Spoken.ru => 'RU',
      };
}

Spoken? spokenFrom(Object? value) {
  final id = '$value'.toLowerCase();
  for (final item in Spoken.values) {
    if (item.id == id) return item;
  }
  return null;
}

/// Ölkə kodundan ehtimal olunan dili tapır.
///
/// Qeydiyyatda adam dil seçmirsə, ölkəsinə görə ağlabatan dəyər
/// qoyulur — boş nişan heç kimə fayda vermir.
Spoken spokenForCountry(String countryCode) => switch (countryCode.toUpperCase()) {
      'AZ' => Spoken.az,
      'TR' || 'CY' => Spoken.tr,
      'RU' || 'BY' || 'KZ' || 'KG' || 'UA' => Spoken.ru,
      _ => Spoken.en,
    };

/// Azərbaycan və türk dilləri bir-birinə yaxındır.
///
/// Bu cütü tamamilə ayırmaq səhv olardı: iki tərəf bir-birini başa
/// düşür və otaqlar birlikdə daha canlı olur. Ona görə "tam uyğun"
/// deyil, amma "uyğun" sayılır.
bool spokenClose(Spoken a, Spoken b) {
  if (a == b) return true;
  const pair = {Spoken.az, Spoken.tr};
  return pair.contains(a) && pair.contains(b);
}

/// Sıralama balı: eyni dil ən yuxarı, yaxın dil ortada, qalanı aşağı.
double spokenScore(Spoken? mine, Spoken? theirs) {
  if (mine == null || theirs == null) return 0.3;
  if (mine == theirs) return 1;
  if (spokenClose(mine, theirs)) return 0.7;

  // İngilis dili beynəlxalq körpüdür — tam yad sayılmır.
  if (mine == Spoken.en || theirs == Spoken.en) return 0.5;

  return 0;
}
