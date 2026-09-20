/// Tanış olmaq üçün adam tövsiyəsi.
///
/// Yeni gələn adam boş söhbət siyahısı görür və nə edəcəyini bilmir.
/// Bu siyahı ona bir neçə tanış namizəd verir.
///
/// Seçim məntiqi burada ayrıca saxlanılır ki, ekrandan asılı olmadan
/// yoxlanıla bilsin.
library;

/// Tövsiyəyə namizəd.
class Candidate {
  const Candidate({
    required this.uid,
    required this.name,
    this.photo = '',
    this.age = 0,
    this.country = '',
    this.online = false,
    this.hasAbout = false,
    this.suspended = false,
  });

  final String uid;
  final String name;
  final String photo;
  final int age;
  final String country;
  final bool online;

  /// Profilində özü haqqında yazıb.
  final bool hasAbout;

  final bool suspended;
}

/// Bir namizədin balı.
///
/// Onlayn olmaq ən ağır çəkidir: cavab verəcək adama salam göndərmək
/// mənalıdır, aylardır girməyənə yox.
double candidateScore(Candidate person, {String myCountry = ''}) {
  var score = 0.0;

  if (person.online) score += 3;

  // Şəkli olan profil daha inandırıcıdır.
  if (person.photo.trim().isNotEmpty) score += 1.5;

  if (person.hasAbout) score += 0.5;

  if (myCountry.isNotEmpty && person.country == myCountry) score += 1;

  return score;
}

/// Tövsiyə siyahısını qurur.
///
/// Kənarda qalanlar:
///   * özün
///   * artıq izlədiklərin və yazışdıqların — onlarla tanışsan
///   * bloklananlar və dayandırılmış hesablar
///   * adı olmayan yarımçıq profillər
List<Candidate> pickSuggestions(
  Iterable<Candidate> all, {
  required String myUid,
  Set<String> known = const {},
  Set<String> blocked = const {},
  String myCountry = '',
  int limit = 6,
}) {
  final list = all.where((person) {
    if (person.uid == myUid) return false;
    if (person.uid.isEmpty) return false;
    if (person.suspended) return false;
    if (known.contains(person.uid)) return false;
    if (blocked.contains(person.uid)) return false;
    if (person.name.trim().isEmpty) return false;
    return true;
  }).toList();

  list.sort((a, b) {
    final diff = candidateScore(b, myCountry: myCountry)
        .compareTo(candidateScore(a, myCountry: myCountry));
    if (diff != 0) return diff;

    // Bal bərabərdirsə ada görə — sıra hər açılışda eyni qalsın.
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });

  return list.take(limit).toList();
}
