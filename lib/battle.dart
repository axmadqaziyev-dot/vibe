/// Söz döyüşü — otaqda növbə ilə deyişmə.
///
/// Bir mexanika, üç mədəniyyət:
///   * Meyxana (Azərbaycan) — bəhr və qafiyə üstündə deyişmə
///   * Atışma (Türkiyə) — mani atışması və rap düellosu
///   * Freestyle (beynəlxalq) — söz üstündə improvizasiya
///
/// Qaydalar eynidir: ekranda söz çıxır, mikrofondakılar növbə ilə
/// o sözün üstündə deyir, dinləyicilər hədiyyə ilə tərəf tutur.
///
/// Növbə hesablaması burada ayrıca saxlanılır ki, ekrandan asılı
/// olmadan yoxlanıla bilsin.
library;

/// Döyüş növü.
enum BattleMode { meyxana, atisma, freestyle }

extension BattleModeInfo on BattleMode {
  String get id => name;

  String get label => switch (this) {
        BattleMode.meyxana => 'Meyxana',
        BattleMode.atisma => 'Atışma',
        BattleMode.freestyle => 'Freestyle',
      };

  String get hint => switch (this) {
        BattleMode.meyxana => 'Qafiyə üstündə deyişmə',
        BattleMode.atisma => 'Mani və rap düellosu',
        BattleMode.freestyle => 'Söz üstündə improvizasiya',
      };

  String get emoji => switch (this) {
        BattleMode.meyxana => '🎤',
        BattleMode.atisma => '🔥',
        BattleMode.freestyle => '🎧',
      };
}

BattleMode battleModeFrom(Object? value) {
  final id = '$value';
  for (final mode in BattleMode.values) {
    if (mode.id == id) return mode;
  }
  return BattleMode.meyxana;
}

/// Hər rejim üçün söz siyahısı.
///
/// Sözlər qısa və tanış seçilib: iştirakçı sözü başa düşmək üçün
/// vaxt itirməməlidir, dərhal qafiyə qurmalıdır.
const Map<BattleMode, List<String>> battleWords = {
  BattleMode.meyxana: [
    'gözəl', 'könül', 'yaz', 'dost', 'yol', 'söz', 'gecə', 'ürək',
    'vətən', 'ana', 'sevgi', 'qismət', 'dünya', 'zaman', 'könül',
    'bahar', 'ulduz', 'dəniz', 'qürbət', 'xatirə',
  ],
  BattleMode.atisma: [
    'sevda', 'yürek', 'yıldız', 'gurbet', 'bahar', 'dost', 'yol',
    'zaman', 'hayat', 'deniz', 'ateş', 'rüya', 'umut', 'kader',
    'gönül', 'vatan', 'anne', 'gece', 'söz', 'hatıra',
  ],
  BattleMode.freestyle: [
    'fire', 'street', 'dream', 'money', 'city', 'night', 'heart',
    'game', 'story', 'light', 'road', 'time', 'crown', 'shadow',
    'echo', 'rise', 'storm', 'gold', 'wave', 'flow',
  ],
};

/// Verilmiş toxumla söz seçir.
///
/// Təsadüfi yox, toxuma görə seçilir: bütün cihazlar eyni sözü
/// görməlidir, yoxsa hər kəs başqa söz üzərində deyərdi.
String battleWordFor(BattleMode mode, int seed) {
  final words = battleWords[mode] ?? battleWords[BattleMode.meyxana]!;
  return words[seed.abs() % words.length];
}

/// Bir nəfərin danışma vaxtı.
const int battleTurnSeconds = 30;

/// Neçə dövrə oynanılır.
const int battleRounds = 3;

/// Növbənin kimdə olduğunu hesablayır.
///
/// [speakers] mikrofondakıların kürsü nömrələridir. Boşdursa -1 qayıdır.
/// [turn] başlanğıcdan bəri keçən növbələrin sayıdır.
int battleSpeakerAt(List<int> speakers, int turn) {
  if (speakers.isEmpty) return -1;
  return speakers[turn % speakers.length];
}

/// Hazırkı dövrə (1-dən başlayır).
int battleRoundAt(List<int> speakers, int turn) {
  if (speakers.isEmpty) return 1;
  return (turn ~/ speakers.length) + 1;
}

/// Döyüş bitibmi?
bool battleFinished(List<int> speakers, int turn, {int rounds = battleRounds}) {
  if (speakers.isEmpty) return true;
  return turn >= speakers.length * rounds;
}

/// Döyüşün ümumi uzunluğu (saniyə) — başlamazdan əvvəl göstərmək üçün.
int battleTotalSeconds(
  int speakerCount, {
  int rounds = battleRounds,
  int turnSeconds = battleTurnSeconds,
}) =>
    speakerCount * rounds * turnSeconds;
