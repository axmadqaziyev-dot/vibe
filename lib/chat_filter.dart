/// Söhbət mövzusu süzgəci.
///
/// `legal.dart`-dakı söz süzgəci **bir mesaja** baxır: söyüş varsa
/// göndərməyə qoymur. Bu fayl isə **söhbətin gedişinə** baxır.
///
/// Səbəb: bəzi mövzular tək-tək sözlə tanınmır. İki nəfər yavaş-yavaş
/// dini mübahisəyə və ya 18+ yazışmaya keçir — hər ayrıca mesaj
/// "təmiz" görünür, söhbət isə artıq qaydadan kənardadır. Ona görə
/// son mesajlar bir yerdə ölçülür və hədd keçiləndə söhbət bağlanır.
///
/// Üç şey xüsusi diqqət tələb edir:
///
/// 1. **Gündəlik dindarlıq mövzu deyil.** "İnşallah", "maşallah",
///    "vallah", "çox şükür" — bunlar Azərbaycan və Türkiyə danışığında
///    adi sözlərdir. Onlar sayılsaydı, demək olar hər söhbət bağlanardı.
///    Ona görə belə ifadələr ölçmədən əvvəl mətndən çıxarılır.
///
/// 2. **Bir söz kifayət etmir.** "Namaz qıldın?" sualı söhbəti
///    bağlamır. Bağlanma yalnız mövzu davam edəndə baş verir.
///
/// 3. **Yazılış oyunları.** "s3ks", "секс", "SİKKKİŞ" — hamısı eyni
///    şəklə salınır: hərflər sadələşir, rəqəm-hərf əvəzləmələri açılır,
///    təkrar hərflər birləşir, kiril latına çevrilir.
///
/// Fayl təmiz Dart-dır — Flutter-siz sınana bilir.
library;

/// Qadağan mövzular.
enum FilterTopic {
  /// Dini mübahisə, məzhəb, təbliğ.
  religion,

  /// 18+ məzmun, cinsi yazışma.
  adult,

  /// Nifrət, təhqir, zorakılıq, uşaq təhlükəsizliyi.
  hate,

  /// Narkotik və qanunsuz satış.
  drugs,
}

extension FilterTopicInfo on FilterTopic {
  /// İstifadəçiyə göstərilən ad.
  String get label => switch (this) {
        FilterTopic.religion => 'dini mübahisə',
        FilterTopic.adult => '18+ məzmun',
        FilterTopic.hate => 'nifrət və təhqir',
        FilterTopic.drugs => 'qadağan maddələr',
      };

  String get emoji => switch (this) {
        FilterTopic.religion => '🕊️',
        FilterTopic.adult => '🔞',
        FilterTopic.hate => '🚫',
        FilterTopic.drugs => '⛔',
      };

  /// Söhbət bağlananda göstərilən izah.
  String get explanation => switch (this) {
        FilterTopic.religion =>
          'VIBE dini mübahisə yeri deyil. İnancına görə heç kim mühakimə '
              'olunmur, amma bu mövzu burada aparılmır.',
        FilterTopic.adult =>
          'VIBE-də 18+ yazışma qadağandır. Bu, həm qaydalardır, həm də '
              'mağazaların tələbidir.',
        FilterTopic.hate =>
          'Təhqir, nifrət və zorakılıq çağırışına sıfır dözümlülük var.',
        FilterTopic.drugs =>
          'Qadağan maddələrlə bağlı yazışma qanunsuzdur və dərhal '
              'dayandırılır.',
      };
}

// ============================================================
// MƏTNİN SADƏLƏŞDİRİLMƏSİ
// ============================================================

/// Hərf əvəzləmələri: Azərbaycan/Türk hərfləri və kiril → latın.
///
/// Kiril ona görə var ki, ölkədə rus dilində yazışma az deyil:
/// "секс" ilə "seks" eyni sözdür, süzgəc ikisini də görməlidir.
const Map<String, String> _fold = {
  'ə': 'e', 'ş': 's', 'ç': 'c', 'ğ': 'g', 'ı': 'i', 'ö': 'o', 'ü': 'u',
  'â': 'a', 'î': 'i', 'û': 'u', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u',
  'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'д': 'd', 'е': 'e', 'ё': 'e',
  'ж': 'j', 'з': 'z', 'и': 'i', 'й': 'i', 'к': 'k', 'л': 'l', 'м': 'm',
  'н': 'n', 'о': 'o', 'п': 'p', 'р': 'r', 'с': 's', 'т': 't', 'у': 'u',
  'ф': 'f', 'х': 'x', 'ц': 'c', 'ч': 'c', 'ш': 's', 'щ': 's', 'ъ': '',
  'ы': 'i', 'ь': '', 'э': 'e', 'ю': 'yu', 'я': 'ya',
};

/// Rəqəm-hərf əvəzləmələri ("s3ks" → "seks").
const Map<String, String> _leet = {
  '@': 'a', r'$': 's', '0': 'o', '1': 'i', '3': 'e', '4': 'a', '5': 's',
  '7': 't',
};

/// Mətni müqayisə üçün sadə şəklə salır.
///
/// Nəticə yalnız kiçik latın hərfi və tək boşluqdan ibarət olur.
/// Eyni funksiya axtarılan sözlərə də tətbiq olunur — beləliklə iki
/// tərəf həmişə eyni qaydada yazılır.
String foldForFilter(String input) {
  final buffer = StringBuffer();

  for (final rune in input.toLowerCase().runes) {
    final ch = String.fromCharCode(rune);
    buffer.write(_fold[ch] ?? _leet[ch] ?? ch);
  }

  var out = buffer.toString().replaceAll(RegExp(r'[^a-z]+'), ' ');

  // "sikkkk" → "sik". Təkrar hərf uzatmaqla süzgəcdən yayınmanın qarşısı.
  out = out.replaceAllMapped(RegExp(r'(.)\1+'), (m) => m[1]!);

  return out.trim();
}

/// Ölçülməməli gündəlik ifadələr.
///
/// Bunlar dini söhbət deyil, danışıq qəlibidir. Ölçmədən əvvəl mətndən
/// silinir ki, "İnşallah sabah gəlirəm" cümləsi mövzu sayılmasın.
final List<RegExp> _everyday = [
  'insalah', 'masalah', 'valah', 'bilah', 'estagfurulah',
  'alah qoysa', 'alah razi olsun', 'alah kerim', 'alaha sukur',
  'cox sukur', 'sukur alaha', 'aman alah', 'bismilah', 'alah gostermesin',
  'alah esqine', 'salam aleykum', 'aleykum salam', 'xudaya sukur',
  'alah rehmet elesin', 'basin sag olsun', 'alah bereket',
].map((phrase) => RegExp(r'\b' + foldForFilter(phrase) + r'\b'))
    .toList(growable: false);

// ============================================================
// SÖZ SİYAHILARI
// ============================================================

class _Term {
  const _Term(
    this.word,
    this.weight, {
    this.exact = false,
    this.instant = false,
  });

  /// Axtarılan söz (adi yazılışda — özü sadələşdirilir).
  final String word;

  /// Ağırlıq: nə qədər güclü işarədir.
  final int weight;

  /// Yalnız tam söz kimi axtarılsın?
  ///
  /// Adi halda sonluq qəbul edilir — Azərbaycan və türk dilləri
  /// şəkilçili dillərdir: "kafirsən", "məscidə", "ateistəm" eyni
  /// kökdür. Amma qısa və çoxmənalı sözlərdə bu təhlükəlidir:
  /// "din" sonluq qəbul etsəydi, "dinlə" və "dincəl" də tutulardı.
  final bool exact;

  /// Bir dəfə görünməsi söhbəti dərhal bağlayır?
  ///
  /// Yalnız mübahisəsiz hallarda: uşaq istismarı, zorlama çağırışı,
  /// irqi söyüş. Burada "xəbərdarlıq edək, görək nə olur" yanaşması
  /// yanlışdır.
  final bool instant;
}

const Map<FilterTopic, List<_Term>> _terms = {
  // --------------------------------------------------------
  // DİN
  // --------------------------------------------------------
  // Ağırlıqlar qəsdən kiçikdir: məqsəd inancı cəzalandırmaq deyil,
  // söhbət mübahisəyə çevriləndə dayandırmaqdır.
  FilterTopic.religion: [
    // Mübahisəyə aparan sözlər.
    _Term('kafir', 3),
    _Term('dinsiz', 3),
    _Term('allahsiz', 3),
    _Term('küfr', 3),
    _Term('murtəd', 3),
    _Term('şəriət', 3),
    _Term('şeriat', 3),
    _Term('cihad', 3),
    _Term('təriqət', 3),
    _Term('tarikat', 3),
    _Term('məzhəb', 3),
    _Term('mezhep', 3),
    _Term('şiə', 3),
    _Term('sünni', 3),
    _Term('sunni', 3),

    // Mövzu sözləri.
    _Term('namaz', 2),
    _Term('oruc', 2),
    _Term('orucluq', 2),
    _Term('quran', 2),
    _Term('kuran', 2),
    _Term('incil', 2),
    _Term('tövrat', 2),
    _Term('hədis', 2),
    _Term('peyğəmbər', 2),
    _Term('peygamber', 2),
    _Term('məscid', 2),
    _Term('mescit', 2),
    _Term('kilsə', 2),
    _Term('kilise', 2),
    _Term('sinaqoq', 2),
    _Term('əzan', 2),
    _Term('hicab', 2),
    _Term('başörtü', 2),
    _Term('ateist', 2),
    _Term('imam', 2),
    _Term('molla', 2),
    _Term('axund', 2),
    _Term('ayətullah', 2),
    _Term('quranda', 2),
    _Term('bible', 2),
    _Term('jesus', 2),
    _Term('prophet', 2),
    _Term('mosque', 2),
    _Term('atheist', 2),

    // Zəif işarələr — təkbaşına heç nə demir, yığılanda deyir.
    _Term('din', 1, exact: true),
    _Term('dini', 1, exact: true),
    _Term('dində', 1, exact: true),
    _Term('günah', 1),
    _Term('savab', 1),
    _Term('haram', 1),
    _Term('halal', 1),
    _Term('helal', 1),
    _Term('cənnət', 1),
    _Term('cəhənnəm', 1),
    _Term('cennet', 1),
    _Term('cehennem', 1),
    _Term('müsəlman', 1),
    _Term('musluman', 1),
    _Term('xristian', 1),
    _Term('hristiyan', 1),
    _Term('yəhudi', 1),
    _Term('allah', 1),
    _Term('tanrı', 1),
  ],

  // --------------------------------------------------------
  // 18+
  // --------------------------------------------------------
  FilterTopic.adult: [
    _Term('porno', 4),
    _Term('porn', 4),
    _Term('pornhub', 4),
    _Term('onlyfans', 4),
    _Term('seks', 4),
    _Term('sex', 4, exact: true),
    _Term('sikiş', 4),
    _Term('sikis', 4),
    _Term('mastürbasiya', 4),
    _Term('masturbasiya', 4),
    _Term('masturbation', 4),
    _Term('orqazm', 4),
    _Term('orgazm', 4),
    _Term('orgasm', 4),
    _Term('sperma', 4),
    _Term('penis', 4),
    _Term('vagina', 4),
    _Term('vajina', 4),
    _Term('amcıq', 4),
    _Term('çılpaq', 4),
    _Term('ciplak', 4),
    _Term('nude', 4),
    _Term('nudes', 4),
    _Term('striptiz', 4),
    _Term('striptease', 4),
    _Term('eskort', 4),
    _Term('escort', 4),
    _Term('fahişə', 4),
    _Term('hentai', 4),
    _Term('bdsm', 4),
    _Term('erotik', 4),
    _Term('erotic', 4),
    _Term('seksual', 4),
    _Term('sexual', 4),
    _Term('anal', 2, exact: true),
    _Term('oral seks', 4),
    _Term('göt ver', 4),
    _Term('sekslə', 4),

    // Yumşaq işarələr.
    _Term('seksi', 2),
    _Term('sexy', 2),
    _Term('soyun', 2),
    _Term('iç paltarı', 2),
    _Term('alt paltarı', 2),
    _Term('yataqda', 1, exact: true),
  ],

  // --------------------------------------------------------
  // NİFRƏT VƏ ZORAKILIQ
  // --------------------------------------------------------
  FilterTopic.hate: [
    _Term('pedofil', 6, instant: true),
    _Term('pedo', 6, instant: true),
    _Term('child porn', 6, instant: true),
    _Term('uşaq pornosu', 6, instant: true),
    _Term('təcavüz et', 6, instant: true),
    _Term('zorlayaram', 6, instant: true),
    _Term('rape', 6, exact: true, instant: true),
    _Term('nigger', 6, instant: true),
    _Term('faggot', 6, instant: true),
    _Term('öldürəcəm səni', 6, instant: true),
    _Term('səni öldürərəm', 6, instant: true),

    _Term('ibnə', 3),
    _Term('təcavüz', 3),
    _Term('tecavuz', 3),
    _Term('soyqırım', 2),
  ],

  // --------------------------------------------------------
  // QADAĞAN MADDƏLƏR
  // --------------------------------------------------------
  FilterTopic.drugs: [
    _Term('narkotik', 4),
    _Term('heroin', 4),
    _Term('kokain', 4),
    _Term('cocaine', 4),
    _Term('metamfetamin', 4),
    _Term('marixuana', 4),
    _Term('marijuana', 4),
    _Term('esrar', 4),
    _Term('hashish', 4),
    _Term('ekstazi', 4),
    _Term('ekstazy', 4),
  ],
};

/// Sözləri bir dəfə regex-ə çevirib saxlayırıq.
///
/// Hər mesajda yenidən qurmaq bahadır: siyahı 150-dən çoxdur, söhbət
/// isə hər hərfdə yenilənir.
class _Compiled {
  _Compiled(this.topic, this.pattern, this.term);

  final FilterTopic topic;
  final RegExp pattern;
  final _Term term;
}

final List<_Compiled> _compiled = () {
  final out = <_Compiled>[];

  for (final entry in _terms.entries) {
    for (final term in entry.value) {
      final folded = foldForFilter(term.word);
      if (folded.isEmpty) continue;

      // Dörd hərf: "mescid-e", "kafir-sen", "ateist-em" tutulur,
      // amma söz tamam başqa sözə çevriləcək qədər uzanmır.
      final suffix = term.exact ? '' : r'[a-z]{0,4}';
      out.add(_Compiled(
        entry.key,
        // Sadələşdirilmiş mətndə yalnız hərf və boşluq olur — xüsusi
        // simvol yoxdur, ona görə qaçırmağa ehtiyac qalmır.
        RegExp(r'\b' + folded + suffix + r'\b'),
        term,
      ));
    }
  }

  return out;
}();

// ============================================================
// ÖLÇMƏ
// ============================================================

/// Bir mətnin ölçüsü.
class TextScan {
  const TextScan(this.scores, this.instant);

  /// Mövzu → xal.
  final Map<FilterTopic, int> scores;

  /// Dərhal bağlanmalı sözə rast gəlinib.
  final bool instant;

  bool get isClean => scores.isEmpty && !instant;

  int scoreOf(FilterTopic topic) => scores[topic] ?? 0;

  /// Ən ağır mövzu.
  FilterTopic? get top {
    FilterTopic? best;
    var bestScore = 0;

    for (final entry in scores.entries) {
      if (entry.value > bestScore) {
        best = entry.key;
        bestScore = entry.value;
      }
    }

    return best;
  }
}

/// Bir mesajı ölçür.
TextScan scanText(String text) {
  if (text.trim().isEmpty) return const TextScan({}, false);

  var folded = foldForFilter(text);

  // Gündəlik qəliblər ölçülmür.
  for (final phrase in _everyday) {
    folded = folded.replaceAll(phrase, ' ');
  }

  final scores = <FilterTopic, int>{};
  var instant = false;

  // "18+" rəqəmlə yazılır — sadələşdirmədən sonra itir, ona görə
  // xam mətndə ayrıca axtarılır.
  if (RegExp(r'(^|\D)(18\s*\+|\+\s*18)').hasMatch(text)) {
    scores[FilterTopic.adult] = 4;
  }

  for (final item in _compiled) {
    if (!item.pattern.hasMatch(folded)) continue;

    scores[item.topic] = (scores[item.topic] ?? 0) + item.term.weight;
    if (item.term.instant) instant = true;
  }

  return TextScan(scores, instant);
}

// ============================================================
// SÖHBƏTİN QİYMƏTİ
// ============================================================

/// Söhbətin vəziyyəti.
enum FilterLevel {
  /// Hər şey qaydasındadır.
  ok,

  /// Mövzuya yaxınlaşır — xəbərdarlıq göstərilir, yazmaq olur.
  warn,

  /// Hədd keçilib — söhbət bağlanır.
  lock,
}

class ChatVerdict {
  const ChatVerdict(this.level, this.topic, this.score);

  final FilterLevel level;

  /// Hansı mövzuya görə.
  final FilterTopic? topic;

  /// Yığılmış xal — sınaqda və loqda faydalıdır.
  final int score;

  static const clean = ChatVerdict(FilterLevel.ok, null, 0);

  bool get blocks => level == FilterLevel.lock;
}

/// Neçə son mesaja baxılır.
///
/// Çox qısa pəncərə mövzunu görmür, çox uzun isə bir saat əvvəl
/// bağlanmış mövzuya görə söhbəti cəzalandırır.
const int filterWindow = 20;

/// Bir mesajın verə biləcəyi ən çox xal.
///
/// Olmasaydı, söz yığını olan tək mesaj söhbəti bağlayardı.
const int _perMessageCap = 5;

/// Xəbərdarlıq həddi.
const int warnThreshold = 4;

/// Bağlanma həddi.
const int lockThreshold = 8;

/// Son mesajlara baxıb söhbətin vəziyyətini qaytarır.
///
/// [recent] — köhnədən yeniyə və ya əksinə, fərq etmir; hamısı eyni
/// çəkidədir. [pending] — göndərilmək üzrə olan mesaj.
ChatVerdict evaluateChat(Iterable<String> recent, {String? pending}) {
  final totals = <FilterTopic, int>{};
  var instant = false;
  FilterTopic? instantTopic;

  void add(String text) {
    final scan = scanText(text);
    if (scan.instant) {
      instant = true;
      instantTopic ??= scan.top;
    }

    for (final entry in scan.scores.entries) {
      final capped = entry.value > _perMessageCap ? _perMessageCap : entry.value;
      totals[entry.key] = (totals[entry.key] ?? 0) + capped;
    }
  }

  for (final text in recent.take(filterWindow)) {
    add(text);
  }
  if (pending != null) add(pending);

  if (instant) {
    return ChatVerdict(
      FilterLevel.lock,
      instantTopic ?? FilterTopic.hate,
      lockThreshold,
    );
  }

  FilterTopic? worst;
  var worstScore = 0;

  for (final entry in totals.entries) {
    if (entry.value > worstScore) {
      worst = entry.key;
      worstScore = entry.value;
    }
  }

  if (worst == null) return ChatVerdict.clean;

  if (worstScore >= lockThreshold) {
    return ChatVerdict(FilterLevel.lock, worst, worstScore);
  }

  if (worstScore >= warnThreshold) {
    return ChatVerdict(FilterLevel.warn, worst, worstScore);
  }

  return ChatVerdict.clean;
}

/// Tək mesajın özü qadağan məzmun daşıyır?
///
/// Otaq söhbətində istifadə olunur: orada bütün otağı bağlamaq düzgün
/// deyil, amma açıq-aşkar mesaj getməməlidir.
FilterTopic? singleMessageBlock(String text) {
  final scan = scanText(text);
  if (scan.instant) return scan.top ?? FilterTopic.hate;

  // Dini mesaj təkbaşına bloklanmır — o, mövzudur, pozuntu deyil.
  for (final topic in [FilterTopic.adult, FilterTopic.hate, FilterTopic.drugs]) {
    if (scan.scoreOf(topic) >= 4) return topic;
  }

  return null;
}

/// Bağlanma müddəti.
///
/// İlk dəfə bir gün. Təkrarlanırsa uzanır — eyni söhbətdə üçüncü dəfə
/// təsadüf deyil.
Duration lockDuration(int previousLocks) => switch (previousLocks) {
      <= 0 => const Duration(hours: 24),
      1 => const Duration(days: 3),
      _ => const Duration(days: 7),
    };

/// Qalan vaxtı insan dilində yazır.
String remainingText(Duration left) {
  if (left.inMinutes <= 0) return 'bir neçə saniyə';
  if (left.inMinutes < 60) return '${left.inMinutes} dəqiqə';
  if (left.inHours < 24) return '${left.inHours} saat';
  return '${left.inDays} gün';
}
