import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/moment_ranking.dart';

void main() {
  group('Təzəlik', () {
    test('Təzə paylaşım köhnədən yuxarıdır', () {
      expect(freshnessScore(0), greaterThan(freshnessScore(12)));
      expect(freshnessScore(12), greaterThan(freshnessScore(48)));
    });

    test('12 saatda bal təxminən yarıya düşür', () {
      expect(freshnessScore(12), closeTo(freshnessScore(0) / 2, 0.01));
    });

    test('Gələcək tarix balı şişirtmir', () {
      // Cihazın saatı səhv qurulubsa mənfi yaş gələ bilər.
      expect(freshnessScore(-100), freshnessScore(0));
    });
  });

  group('Cəlbedicilik', () {
    test('Şərh bəyənmədən ağırdır', () {
      expect(
        engagementScore(comments: 10),
        greaterThan(engagementScore(likes: 10)),
      );
    });

    test('Hədiyyə şərhdən ağırdır', () {
      expect(
        engagementScore(gifts: 10),
        greaterThan(engagementScore(comments: 10)),
      );
    });

    test('Heç nə yoxdursa bal sıfırdır', () {
      expect(engagementScore(), 0);
    });

    test('Böyük saylar lenti əzmir', () {
      // 1000 bəyənmə 100-dən yalnız bir qədər güclü olmalıdır.
      final az = engagementScore(likes: 100);
      final cox = engagementScore(likes: 1000);

      expect(cox, greaterThan(az));
      expect(cox, lessThan(az * 1.6));
    });
  });

  group('Uyğunluq', () {
    test('Dostun dostu yuxarı qalxır', () {
      const yaxin = MomentSignals(ageHours: 1, friendOfFriend: true);
      const yad = MomentSignals(ageHours: 1);

      expect(momentScore(yaxin), greaterThan(momentScore(yad)));
    });

    test('Eyni ölkə yuxarı qalxır', () {
      const yerli = MomentSignals(ageHours: 1, sameCountry: true);
      const uzaq = MomentSignals(ageHours: 1);

      expect(momentScore(yerli), greaterThan(momentScore(uzaq)));
    });

    test('Üçdən sonra əlavə ortaq maraq fərq etmir', () {
      const uc = MomentSignals(ageHours: 1, sharedInterests: 3);
      const on = MomentSignals(ageHours: 1, sharedInterests: 10);

      expect(momentScore(on), momentScore(uc));
    });

    test('İzlədiyin adam bu lentdə aşağı düşür', () {
      const izlenen = MomentSignals(ageHours: 1, fromFollowed: true);
      const yeni = MomentSignals(ageHours: 1);

      expect(momentScore(izlenen), lessThan(momentScore(yeni)));
    });
  });

  group('Ümumi sıralama', () {
    test('Təzə və maraqlı paylaşım köhnə məşhurdan yuxarıdır', () {
      // Bir həftəlik, çox bəyənilmiş.
      const kohne = MomentSignals(ageHours: 168, likes: 500);
      // İki saatlıq, az bəyənilmiş, amma dostun dostundan.
      const teze =
          MomentSignals(ageHours: 2, likes: 3, friendOfFriend: true);

      expect(momentScore(teze), greaterThan(momentScore(kohne)));
    });
  });

  group('Müəlliflərin yayılması', () {
    String yazar(String s) => s.split('-').first;

    test('Bir adamdan arda-arda ikidən çox olmur', () {
      final input = ['a-1', 'a-2', 'a-3', 'a-4', 'b-1', 'c-1'];
      final out = spreadAuthors(input, yazar);

      var streak = 0;
      var last = '';
      for (final item in out) {
        final author = yazar(item);
        streak = author == last ? streak + 1 : 1;
        last = author;
        expect(streak, lessThanOrEqualTo(2), reason: out.toString());
      }
    });

    test('Heç bir paylaşım itmir', () {
      final input = ['a-1', 'a-2', 'a-3', 'a-4', 'b-1'];
      final out = spreadAuthors(input, yazar);

      expect(out.toSet(), input.toSet());
      expect(out.length, input.length);
    });

    test('Müəlliflər onsuz da qarışıqdırsa sıra dəyişmir', () {
      final input = ['a-1', 'b-1', 'c-1', 'a-2'];
      expect(spreadAuthors(input, yazar), input);
    });

    test('Tək müəllif olanda hamısı qalır', () {
      final input = ['a-1', 'a-2', 'a-3'];
      final out = spreadAuthors(input, yazar);

      expect(out.length, 3);
      expect(out.toSet(), input.toSet());
    });
  });
}
