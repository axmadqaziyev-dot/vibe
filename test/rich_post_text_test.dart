import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/rich_post_text.dart';

void main() {
  group('mətnin hissələrə ayrılması', () {
    test('adi mətn bir hissədir', () {
      final parts = parsePostText('Bu gün hava gözəldir');
      expect(parts.length, 1);
      expect(parts.first.kind, SpanKind.plain);
    });

    test('hashtag tanınır', () {
      final parts = parsePostText('Bakıda #səhər çox gözəldir');
      expect(parts[1], const TextPart(SpanKind.hashtag, '#səhər'));
      expect(parts[1].value, 'səhər');
    });

    test('Azərbaycan hərfləri kəsilmir', () {
      // ə, ı, ş, ç, ğ, ö, ü ASCII-dən kənardadır — sadə \w onları
      // tutmur və "#gəncləşdi" yarıda kəsilərdi.
      expect(hashtagsIn('#gəncləşdi'), ['gəncləşdi']);

      // "İ" Unicode qaydasına görə "i + nöqtə"yə düşür. Normallaşdırma
      // olmasa "#İlkin" ilə "#ilkin" fərqli hashtag olardı.
      expect(hashtagsIn('#İlkin'), hashtagsIn('#ilkin'));
      expect(hashtagsIn('#ÇİÇƏK'), ['çiçək']);
    });

    test('ad tanınır', () {
      final parts = parsePostText('Salam @Ilkin necəsən');
      expect(parts[1].kind, SpanKind.mention);
      expect(parts[1].value, 'Ilkin');
    });

    test('link tanınır', () {
      final parts = parsePostText('Bax: https://vibe-f9d13.web.app burada');
      expect(parts[1].kind, SpanKind.link);
      expect(parts[1].text, 'https://vibe-f9d13.web.app');
    });

    test('bir cümlədə hamısı', () {
      final parts = parsePostText('@Asif #bakı www.vibe.az');
      expect(
        parts.where((p) => p.kind != SpanKind.plain).map((p) => p.kind),
        [SpanKind.mention, SpanKind.hashtag, SpanKind.link],
      );
    });

    test('e-poçt ad kimi sayılmır', () {
      // "ad@domen" formasında @ sözün ortasındadır. Mention yalnız
      // ayrı söz kimi tutulmalıdır, yoxsa hər e-poçt profil linki
      // olardı.
      final parts = parsePostText('yaz mene asif@gmail.com');
      expect(parts.any((p) => p.kind == SpanKind.mention), isFalse);
    });

    test('tək "#" hashtag deyil', () {
      final parts = parsePostText('qiymət # 5 manat');
      expect(parts.any((p) => p.kind == SpanKind.hashtag), isFalse);
    });

    test('təkrar hashtag bir dəfə sayılır', () {
      expect(hashtagsIn('#bakı gözəldir #Bakı'), ['bakı']);
    });

    test('adlar yığılır', () {
      expect(mentionsIn('@Asif və @Ilkin gəlir'), ['Asif', 'Ilkin']);
    });

    test('boş mətn boş siyahı verir', () {
      expect(parsePostText(''), isEmpty);
      expect(hashtagsIn(''), isEmpty);
    });
  });
}
