/// HƏDİYYƏ KATALOQU.
///
/// Adi hədiyyələr həmişə açıqdır; mövsümi hədiyyələr isə yalnız öz
/// tarixlərində görünür — rəqib tətbiqlərdəki "bayram hədiyyələri" budur.
/// Kataloq bir yerdədir ki, otaq, söhbət və anlar eyni siyahını işlətsin.
library;

class VibeGift {
  const VibeGift({
    required this.emoji,
    required this.title,
    required this.price,
    this.season,
  });

  final String emoji;
  final String title;
  final int price;

  /// Yalnız bu mövsümdə görünür; `null` = həmişə.
  final GiftSeason? season;

  bool get isSeasonal => season != null;
}

/// Mövsüm — başlanğıc və son tarix (ay/gün).
class GiftSeason {
  const GiftSeason({
    required this.name,
    required this.fromMonth,
    required this.fromDay,
    required this.toMonth,
    required this.toDay,
  });

  final String name;
  final int fromMonth;
  final int fromDay;
  final int toMonth;
  final int toDay;

  /// Verilən tarix bu mövsümə düşürmü?
  ///
  /// İlin sonunu aşan mövsümlər (dekabr→yanvar) da düzgün işləyir.
  bool contains(DateTime date) {
    final value = date.month * 100 + date.day;
    final start = fromMonth * 100 + fromDay;
    final end = toMonth * 100 + toDay;

    if (start <= end) return value >= start && value <= end;
    return value >= start || value <= end;
  }
}

const _newYear = GiftSeason(
  name: 'Yeni il',
  fromMonth: 12,
  fromDay: 15,
  toMonth: 1,
  toDay: 10,
);

const _novruz = GiftSeason(
  name: 'Novruz',
  fromMonth: 3,
  fromDay: 15,
  toMonth: 3,
  toDay: 25,
);

const _love = GiftSeason(
  name: 'Sevgililər günü',
  fromMonth: 2,
  fromDay: 10,
  toMonth: 2,
  toDay: 15,
);

const _summer = GiftSeason(
  name: 'Yay',
  fromMonth: 6,
  fromDay: 1,
  toMonth: 8,
  toDay: 31,
);

/// Bütün hədiyyələr.
const List<VibeGift> allGifts = [
  // ---- adi ----
  VibeGift(emoji: '🌹', title: 'Gül', price: 10),
  VibeGift(emoji: '💜', title: 'Ürək', price: 25),
  VibeGift(emoji: '🍫', title: 'Şokolad', price: 50),
  VibeGift(emoji: '👑', title: 'Tac', price: 100),
  VibeGift(emoji: '🚗', title: 'Maşın', price: 250),
  VibeGift(emoji: '🚀', title: 'Raket', price: 500),
  VibeGift(emoji: '💎', title: 'Almaz', price: 1000),
  VibeGift(emoji: '🏰', title: 'Qala', price: 2500),
  VibeGift(emoji: '🛥️', title: 'Yaxta', price: 5000),

  // ---- mövsümi ----
  VibeGift(emoji: '🎄', title: 'Şam ağacı', price: 150, season: _newYear),
  VibeGift(emoji: '🎆', title: 'Atəşfəşanlıq', price: 400, season: _newYear),
  VibeGift(emoji: '🔥', title: 'Novruz tonqalı', price: 200, season: _novruz),
  VibeGift(emoji: '🥚', title: 'Boyalı yumurta', price: 60, season: _novruz),
  VibeGift(emoji: '💐', title: 'Buket', price: 120, season: _love),
  VibeGift(emoji: '💌', title: 'Məktub', price: 80, season: _love),
  VibeGift(emoji: '🍉', title: 'Qarpız', price: 40, season: _summer),
  VibeGift(emoji: '🏖️', title: 'Çimərlik', price: 300, season: _summer),
];

/// Hazırda göstəriləcək hədiyyələr: adi + mövsümdə olanlar.
///
/// Mövsümi hədiyyələr əvvəldə gəlir ki, gözə çarpsın.
List<VibeGift> giftsFor(DateTime now) {
  final seasonal = allGifts
      .where((g) => g.season != null && g.season!.contains(now))
      .toList();
  final regular = allGifts.where((g) => g.season == null).toList();
  return [...seasonal, ...regular];
}

/// Hazırda aktiv mövsümün adı; yoxdursa `null`.
String? activeSeasonName(DateTime now) {
  for (final gift in allGifts) {
    final season = gift.season;
    if (season != null && season.contains(now)) return season.name;
  }
  return null;
}

// ============================================================
// HƏDİYYƏ PİLLƏLƏRİ
// ============================================================

/// Hədiyyənin "ağırlığı".
///
/// Rəqib tətbiqlərdə 5000 sikkəlik hədiyyə göndərməyin səbəbi rəqəm
/// deyil — ekranı bürüyən animasiyadır. Hamısı eyni görünsə, bahalı
/// hədiyyə almağın mənası qalmır.
enum GiftTier {
  /// Adi — kiçik uçan işarə.
  simple,

  /// Nadir — rəngli lent.
  rare,

  /// Epik — ekranın yarısı.
  epic,

  /// Əfsanəvi — tam ekran, uzun animasiya.
  legendary,
}

GiftTier tierForPrice(int price) {
  if (price >= 5000) return GiftTier.legendary;
  if (price >= 1000) return GiftTier.epic;
  if (price >= 250) return GiftTier.rare;
  return GiftTier.simple;
}

extension GiftTierLook on GiftTier {
  String get label => switch (this) {
        GiftTier.simple => 'Adi',
        GiftTier.rare => 'Nadir',
        GiftTier.epic => 'Epik',
        GiftTier.legendary => 'Əfsanəvi',
      };

  /// Nişan və işıq rəngi.
  int get color => switch (this) {
        GiftTier.simple => 0xff6f6683,
        GiftTier.rare => 0xff22a7ff,
        GiftTier.epic => 0xffb06ab3,
        GiftTier.legendary => 0xffffd458,
      };

  /// Animasiya nə qədər davam edir (millisaniyə).
  int get durationMs => switch (this) {
        GiftTier.simple => 1400,
        GiftTier.rare => 2200,
        GiftTier.epic => 3200,
        GiftTier.legendary => 4500,
      };

  /// Neçə hissəcik uçur.
  int get particles => switch (this) {
        GiftTier.simple => 0,
        GiftTier.rare => 14,
        GiftTier.epic => 30,
        GiftTier.legendary => 60,
      };

  /// Ekranı tam tutur?
  bool get fullScreen =>
      this == GiftTier.epic || this == GiftTier.legendary;
}
