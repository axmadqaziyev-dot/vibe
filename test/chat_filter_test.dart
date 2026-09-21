import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/chat_filter.dart';

void main() {
  group('sadələşdirmə', () {
    test('Azərbaycan hərfləri latına düşür', () {
      expect(foldForFilter('Çılpaq ŞƏKİL'), 'cilpaq sekil');
    });

    test('təkrar hərflər birləşir', () {
      expect(foldForFilter('siiiikkkk'), 'sik');
    });

    test('rəqəm əvəzləməsi açılır', () {
      expect(foldForFilter('s3ks'), 'seks');
    });

    test('kiril latına çevrilir', () {
      expect(foldForFilter('секс'), 'seks');
    });
  });

  group('təmiz söhbət bağlanmır', () {
    // Ən böyük risk yalan həyəcandır: adi söhbəti bağlasaq,
    // istifadəçi tətbiqi silər.
    final innocent = <String>[
      'İnşallah sabah görüşərik',
      'Maşallah nə gözəl şəkildir',
      'Vallah bilmirəm, çox şükür hər şey yaxşıdır',
      'Salam aleykum, necəsən?',
      'Şikayət etdim, cavab gəlmədi',
      'Analiz nəticəsi hazırdır',
      'Dincəlirəm, musiqi dinləyirəm',
      'Dostum gəldi, dönər yedik',
      'Bu gün işdə çox yoruldum',
      'Sənə bir mahnı göndərim?',
      'Başın sağ olsun, Allah rəhmət eləsin',
      'Allah qoysa bazar günü gəlirəm',
    ];

    for (final text in innocent) {
      test('"$text" təmizdir', () {
        expect(evaluateChat([text]).level, FilterLevel.ok);
      });
    }

    // Bu sözlər qadağan sözlərə oxşayır, amma tamam başqa mənadadır.
    // Hər biri əvvəl süzgəci yanıldırdı.
    const tricky = <String, String>{
      'Zavodun sexində işləyir': 'sex — emalatxana',
      'Rap dinləyirəm, raper olmaq istəyirəm': 'raper — rape deyil',
      'Hadisə barədə xəbər oxudum': 'hadisə — hədis deyil',
      'Əsrarəngiz mənzərə idi': 'əsrarəngiz — esrar deyil',
      'Pedaqoji institutda oxuyur': 'pedaqoji — pedo deyil',
      'İmamverdi müəllim zəng etdi': 'ad — imam deyil',
      'Cihaz işləmir, servise verdim': 'cihaz — cihad deyil',
      'Analiz nəticəsini gözləyirəm': 'analiz — anal deyil',
      'Dinlə bu mahnını, çox gözəldir': 'dinlə — din deyil',
      'Şikayət yazdım, cavab yoxdur': 'şikayət — söyüş deyil',
    };

    tricky.forEach((text, why) {
      test('"$text" təmizdir ($why)', () {
        expect(evaluateChat([text]).level, FilterLevel.ok);
      });
    });

    test('bütün adi söhbət bir yerdə də təmizdir', () {
      expect(evaluateChat(innocent).level, FilterLevel.ok);
    });

    test('bir dəfə "namaz" soruşmaq söhbəti bağlamır', () {
      final verdict = evaluateChat(['Namaz qıldın?', 'Hə, sən necəsən']);
      expect(verdict.blocks, isFalse);
    });
  });

  group('dini mübahisə', () {
    test('davam edən mübahisə bağlanır', () {
      final verdict = evaluateChat([
        'Sən namaz qılırsan?',
        'Yox, mən ateistəm',
        'Onda sən kafirsən, cəhənnəmə gedəcəksən',
        'Quranda belə yazılmayıb, məzhəbin səhvdir',
      ]);

      expect(verdict.level, FilterLevel.lock);
      expect(verdict.topic, FilterTopic.religion);
    });

    test('yaxınlaşanda əvvəlcə xəbərdarlıq olur', () {
      final verdict = evaluateChat([
        'Məscidə getdin?',
        'Oruc tutursan?',
      ]);

      expect(verdict.level, FilterLevel.warn);
      expect(verdict.topic, FilterTopic.religion);
    });

    test('tək dini mesaj otaqda bloklanmır', () {
      // Din mövzudur, pozuntu deyil — tək mesaj kəsilmir.
      expect(singleMessageBlock('Bu gün oruc tutdum'), isNull);
    });
  });

  group('18+', () {
    test('iki açıq mesaj söhbəti bağlayır', () {
      final verdict = evaluateChat([
        'Çılpaq şəkil göndər',
        'Sənə porno link atım?',
      ]);

      expect(verdict.level, FilterLevel.lock);
      expect(verdict.topic, FilterTopic.adult);
    });

    test('gizlədilmiş yazılış da tutulur', () {
      expect(scanText('s3ks video').scoreOf(FilterTopic.adult), greaterThan(0));
      expect(scanText('секс').scoreOf(FilterTopic.adult), greaterThan(0));
    });

    test('"18+" tutulur', () {
      expect(scanText('18+ kanal').scoreOf(FilterTopic.adult), greaterThan(0));
    });

    test('açıq mesaj tək-tək də bloklanır', () {
      expect(singleMessageBlock('porno göndər'), FilterTopic.adult);
    });

    test('"analiz" 18+ sayılmır', () {
      expect(scanText('analiz nəticəsi').scoreOf(FilterTopic.adult), 0);
    });
  });

  group('dərhal bağlanan hallar', () {
    test('uşaq istismarı ilk mesajda bağlayır', () {
      final verdict = evaluateChat(const [], pending: 'pedofil kanal var');
      expect(verdict.level, FilterLevel.lock);
    });

    test('zorakılıq təhdidi ilk mesajda bağlayır', () {
      final verdict = evaluateChat(['səni öldürərəm']);
      expect(verdict.level, FilterLevel.lock);
      expect(verdict.topic, FilterTopic.hate);
    });
  });

  group('narkotik', () {
    test('satış söhbəti bağlanır', () {
      final verdict = evaluateChat([
        'Heroin tapa bilərsən?',
        'Kokain də var',
      ]);

      expect(verdict.level, FilterLevel.lock);
      expect(verdict.topic, FilterTopic.drugs);
    });
  });

  group('pəncərə və müddət', () {
    test('yalnız son mesajlara baxılır', () {
      // Köhnə mübahisə 20 mesaj geridə qalıbsa, söhbət yenidən açıqdır.
      final old = <String>[
        ...List<String>.filled(filterWindow, 'salam necəsən'),
        'kafir məzhəb şəriət',
      ];

      expect(evaluateChat(old).level, FilterLevel.ok);
    });

    test('bir mesaj təkbaşına həddi keçmir', () {
      // Söz yığını olan tək mesaj bağlamamalıdır — yoxsa kimsə
      // qarşı tərəfi bir mesajla söhbətdən məhrum edərdi.
      final verdict = evaluateChat(const [], pending: 'namaz oruc quran hədis məscid əzan hicab');

      expect(verdict.blocks, isFalse);
    });

    test('təkrar bağlanma uzanır', () {
      expect(lockDuration(0), const Duration(hours: 24));
      expect(lockDuration(1), const Duration(days: 3));
      expect(lockDuration(5), const Duration(days: 7));
    });

    test('qalan vaxt oxunaqlı yazılır', () {
      expect(remainingText(const Duration(hours: 5)), '5 saat');
      expect(remainingText(const Duration(days: 2)), '2 gün');
      expect(remainingText(const Duration(minutes: 20)), '20 dəqiqə');
    });
  });
}
