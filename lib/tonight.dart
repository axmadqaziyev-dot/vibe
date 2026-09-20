/// "Bu axşam nə istəyirsən?" — niyyətə görə tanışlıq.
///
/// Bu tətbiqlərdə tanışlıq şəkildən başlayır: adam profillərə baxır,
/// üzə görə yazır. Nəticə həmişə eynidir — qızlar onlarla naməlum
/// mesaj alıb bezir, oğlanlar cavab almayıb bezir.
///
/// Niyyət başqa cür işləyir: adam nə istədiyini seçir, sistem uyğun
/// gələni tapır. Danışmaq istəyən dinləmək istəyənlə qoşulur, dərdini
/// deyən onu eşitməyə hazır olanla.
///
/// Uyğunluq hesablaması burada ayrıca saxlanılır ki, ekrandan asılı
/// olmadan yoxlanıla bilsin.
library;

/// Niyyət bu qədər saat sonra sönür.
///
/// "Bu axşam" sabaha qalmamalıdır: köhnə niyyət yalan siqnaldır.
const int tonightHours = 8;

/// Seçilə bilən niyyətlər.
enum Tonight { talk, listen, game, meet, vent, sing }

extension TonightInfo on Tonight {
  String get id => name;

  String get label => switch (this) {
        Tonight.talk => 'Danışmaq',
        Tonight.listen => 'Dinləmək',
        Tonight.game => 'Oyun oynamaq',
        Tonight.meet => 'Tanış olmaq',
        Tonight.vent => 'Dərdləşmək',
        Tonight.sing => 'Oxumaq',
      };

  String get emoji => switch (this) {
        Tonight.talk => '💬',
        Tonight.listen => '🎧',
        Tonight.game => '🎮',
        Tonight.meet => '💘',
        Tonight.vent => '😔',
        Tonight.sing => '🎤',
      };

  String get hint => switch (this) {
        Tonight.talk => 'Danışacaq adam axtarıram',
        Tonight.listen => 'Susub qulaq asmaq istəyirəm',
        Tonight.game => 'Birlikdə oynayaq',
        Tonight.meet => 'Yeni adamla tanış olmaq',
        Tonight.vent => 'Ürəyimi boşaltmaq istəyirəm',
        Tonight.sing => 'Meyxana, mahnı, söz döyüşü',
      };
}

Tonight? tonightFrom(Object? value) {
  final id = '$value';
  for (final item in Tonight.values) {
    if (item.id == id) return item;
  }
  return null;
}

/// İki niyyətin uyğunluğu (0..1).
///
/// Ən yüksək bal həmişə eyni niyyətdə olmur: iki nəfər də danışmaq
/// istəyirsə bir-birini dinləməyəcək. Danışan ilə dinləyən isə
/// mükəmməl cütdür. Ona görə cədvəl "tamamlayıcı" cütlərə üstünlük verir.
double tonightMatch(Tonight mine, Tonight theirs) {
  // Tamamlayıcı cütlər.
  const perfect = {
    (Tonight.talk, Tonight.listen),
    (Tonight.listen, Tonight.talk),
    (Tonight.vent, Tonight.listen),
    (Tonight.listen, Tonight.vent),
    (Tonight.sing, Tonight.listen),
    (Tonight.listen, Tonight.sing),
  };

  if (perfect.contains((mine, theirs))) return 1;

  // Birlikdə edilən işlərdə eyni niyyət düzgündür.
  const together = {Tonight.game, Tonight.meet, Tonight.sing};
  if (mine == theirs && together.contains(mine)) return 1;

  // İki dinləyici bir-birinə söz vermir — bu yoxlama ümumi "eyni niyyət"
  // şərtindən əvvəl gəlməlidir, yoxsa heç vaxt işə düşmür.
  if (mine == Tonight.listen && theirs == Tonight.listen) return 0.2;

  // Eyni niyyət, amma birlikdə edilən iş deyil: pis deyil, ideal da deyil.
  if (mine == theirs) return 0.5;

  // Dərdləşən adama oyun təklifi uyğun gəlmir.
  if (mine == Tonight.vent && theirs == Tonight.game) return 0.1;
  if (mine == Tonight.game && theirs == Tonight.vent) return 0.1;

  return 0.4;
}

/// Niyyət hələ keçərlidirmi?
bool tonightAlive(DateTime? chosenAt, {DateTime? now}) {
  if (chosenAt == null) return false;
  final moment = now ?? DateTime.now();
  return moment.difference(chosenAt).inHours < tonightHours;
}

/// Sənəddən niyyəti oxuyur; vaxtı keçibsə null qaytarır.
Tonight? tonightOf(Object? raw, {DateTime? now}) {
  if (raw is! Map) return null;

  final at = raw['at'];
  DateTime? chosenAt;

  if (at is DateTime) {
    chosenAt = at;
  } else if (at != null) {
    // Firestore Timestamp: toDate() metodu ilə gəlir.
    try {
      chosenAt = (at as dynamic).toDate() as DateTime;
    } catch (_) {
      chosenAt = null;
    }
  }

  if (!tonightAlive(chosenAt, now: now)) return null;
  return tonightFrom(raw['intent']);
}
