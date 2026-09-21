/// Şanslı qutu.
///
/// SUGO-nun "Şanslı Çanta"sının qarşılığı: mərc qoyursan, qutu açılır,
/// içindən sikkə çıxır. Otaqda adamı saxlayan və xərcləməyə sövq edən
/// mexanizm budur.
///
/// İki şeyi qəsdən belə etdim:
///
/// 1. **Ehtimallar açıq yazılır.** Gizlədilsə, adam nə qədər
///    uduzduğunu bilmir və sonra tətbiqə inamını itirir. Açıq
///    yazılanda isə oyun oyun olaraq qalır.
/// 2. **Qazanc payı sabitdir və sınanır.** Təsadüfi rəqəmlərlə
///    işləyən sistemdə bir sıfır səhvi qoysan, ya tətbiq iflas edir,
///    ya da heç kim udmur. Sınaq bunu tutur.
library;

import 'dart:math';

/// Qutudan çıxa bilən nəticə.
class BoxPrize {
  const BoxPrize({
    required this.multiplier,
    required this.weight,
    required this.emoji,
    required this.label,
  });

  /// Mərcin neçə misli qaytarılır. 0 = heç nə.
  final double multiplier;

  /// Nisbi şans çəkisi.
  final int weight;

  final String emoji;
  final String label;
}

/// Qutunun içindəkilər.
///
/// Çəkilərin cəmi 1000-dir ki, faiz birbaşa oxunsun.
const boxPrizes = <BoxPrize>[
  BoxPrize(multiplier: 0, weight: 420, emoji: '💨', label: 'Boş'),
  BoxPrize(multiplier: 0.5, weight: 250, emoji: '🪙', label: 'Yarısı'),
  BoxPrize(multiplier: 1, weight: 180, emoji: '💰', label: 'Geri'),
  BoxPrize(multiplier: 2, weight: 100, emoji: '💎', label: '2 misli'),
  BoxPrize(multiplier: 5, weight: 40, emoji: '👑', label: '5 misli'),
  BoxPrize(multiplier: 20, weight: 9, emoji: '🚀', label: '20 misli'),
  BoxPrize(multiplier: 100, weight: 1, emoji: '🏆', label: 'CACKPOT'),
];

/// Çəkilərin cəmi.
int get boxWeightTotal =>
    boxPrizes.fold(0, (sum, prize) => sum + prize.weight);

/// Bir nəticənin faizi.
double boxChance(BoxPrize prize) => prize.weight * 100 / boxWeightTotal;

/// Oyunçuya orta hesabla qaytarılan pay.
///
/// 1-dən kiçik olmalıdır, yoxsa tətbiq uduzur. Çox kiçik olsa,
/// oyunçu tez bezir. 0.85 civarı sənaye ölçüsüdür.
double get boxReturnRate {
  var total = 0.0;
  for (final prize in boxPrizes) {
    total += prize.multiplier * prize.weight;
  }
  return total / boxWeightTotal;
}

/// Mərc seçimləri.
const boxBets = <int>[100, 500, 1000, 5000];

/// Qutunu açır.
///
/// [random] sınaq üçün verilir — nəticə təkrarlana bilsin.
BoxPrize openBox({Random? random}) {
  final roll = (random ?? Random()).nextInt(boxWeightTotal);

  var passed = 0;
  for (final prize in boxPrizes) {
    passed += prize.weight;
    if (roll < passed) return prize;
  }

  // Bura düşmək mümkün deyil; yenə də boş qaytarırıq ki, çağıran
  // tərəf `null` yoxlamasın.
  return boxPrizes.first;
}

/// Uduş məbləği.
int boxPayout(int bet, BoxPrize prize) => (bet * prize.multiplier).round();
