/// "Tövsiyə" lentinin sıralaması.
///
/// Məqsəd: adam lenti açanda ona uyğun və təzə paylaşım görsün.
/// Süni intellekt lazım deyil — bal sistemi kifayətdir və hər balın niyə
/// verildiyi aydın qalır, lazım olanda çəkiləri dəyişmək olur.
///
/// Hesablama tamamilə cihazda aparılır: server tərəfdə iş yoxdur.
library;

import 'dart:math' as math;

/// Bir anın bütün əlamətləri.
class MomentSignals {
  const MomentSignals({
    required this.ageHours,
    this.likes = 0,
    this.comments = 0,
    this.gifts = 0,
    this.fromFollowed = false,
    this.friendOfFriend = false,
    this.sameCountry = false,
    this.sharedInterests = 0,
  });

  /// Paylaşılandan neçə saat keçib.
  final double ageHours;

  final int likes;
  final int comments;
  final int gifts;

  /// Artıq izlədiyin adamdır.
  final bool fromFollowed;

  /// İzlədiyin birinin izlədiyi adamdır.
  final bool friendOfFriend;

  final bool sameCountry;

  /// Neçə maraq üst-üstə düşür.
  final int sharedInterests;
}

/// Təzəlik balı: 12 saatdan bir yarıya düşür.
///
/// Belə olmasa bir dəfə çox bəyənilmiş köhnə paylaşım həftələrlə lentin
/// başında qalar və təzə paylaşan adam heç vaxt görünməz.
double freshnessScore(double ageHours) =>
    1 / (1 + math.max(0, ageHours) / 12);

/// Cəlbedicilik balı.
///
/// Şərh bəyənmədən iki dəfə, hədiyyə üç dəfə ağırdır — onlar daha çox
/// zəhmət tələb edir, deməli daha güclü siqnaldır.
///
/// Loqarifm götürülür ki, 1000 bəyənməli bir paylaşım qalan hər şeyi
/// əzməsin: 1000 ilə 100 arasında fərq olsun, amma 10 qat olmasın.
double engagementScore({int likes = 0, int comments = 0, int gifts = 0}) {
  final weighted = likes + comments * 2 + gifts * 3;
  if (weighted <= 0) return 0;
  return math.log(1 + weighted) / math.ln10;
}

/// Uyğunluq balı — adamın öz dairəsinə və maraqlarına yaxınlıq.
double affinityScore(MomentSignals s) {
  var score = 0.0;

  // Dostun dostu: yeni adamla tanış olmağın ən təbii yolu.
  if (s.friendOfFriend) score += 0.8;

  if (s.sameCountry) score += 0.4;

  // Üçdən sonra əlavə maraq fərq etmir — yoxsa hər şeyi yazan adam
  // süni şəkildə yuxarı qalxardı.
  score += math.min(s.sharedInterests, 3) * 0.25;

  // İzlədiyin adam bu lentdə aşağı düşür: onu onsuz da
  // "İzlədiklərim" sekməsində görürsən.
  if (s.fromFollowed) score -= 0.5;

  return score;
}

/// Anın ümumi balı.
double momentScore(MomentSignals s) =>
    freshnessScore(s.ageHours) * 2.0 +
    engagementScore(
          likes: s.likes,
          comments: s.comments,
          gifts: s.gifts,
        ) *
        0.8 +
    affinityScore(s);

/// Eyni adamın paylaşımları arda-arda gəlməsin.
///
/// Sıralama sırf bala görə olsa, aktiv bir nəfər lentin yarısını tuta
/// bilər. Bu funksiya sırasını saxlayır, amma bir müəllifdən ardıcıl
/// [maxInRow] paylaşımdan sonrakını geri atır.
List<T> spreadAuthors<T>(
  List<T> items,
  String Function(T) authorOf, {
  int maxInRow = 2,
}) {
  final result = <T>[];
  final waiting = <T>[];

  var lastAuthor = '';
  var streak = 0;

  void place(T item) {
    final author = authorOf(item);
    if (author == lastAuthor) {
      streak++;
    } else {
      lastAuthor = author;
      streak = 1;
    }
    result.add(item);
  }

  for (final item in items) {
    final author = authorOf(item);

    if (author == lastAuthor && streak >= maxInRow) {
      waiting.add(item);
      continue;
    }

    place(item);

    // Növbədə gözləyən varsa və müəllifi dəyişibsə, onu buraxırıq.
    for (var i = 0; i < waiting.length; i++) {
      if (authorOf(waiting[i]) != lastAuthor || streak < maxInRow) {
        place(waiting.removeAt(i));
        break;
      }
    }
  }

  // Yerdə qalanlar sonda gəlir — heç nə itmir.
  result.addAll(waiting);
  return result;
}
