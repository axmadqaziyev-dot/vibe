import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/vibe_level.dart';

void main() {
  group('səviyyə', () {
    test('başlanğıc birinci səviyyədir', () {
      expect(levelFromXp(0), 1);
      expect(levelFromXp(-50), 1);
      expect(xpForLevel(1), 0);
    });

    test('ikinci səviyyə 100 xal istəyir', () {
      expect(xpForLevel(2), 100);
      expect(levelFromXp(99), 1);
      expect(levelFromXp(100), 2);
    });

    test('hər səviyyə əvvəlkindən bahadır', () {
      // Artım azalmalıdır: yuxarı səviyyə dəyərini saxlasın.
      final first = xpForLevel(3) - xpForLevel(2);
      final later = xpForLevel(10) - xpForLevel(9);

      expect(later, greaterThan(first));
    });

    test('səviyyə yüz ilə məhdudlanır', () {
      expect(levelFromXp(1 << 62), lessThanOrEqualTo(100));
    });

    test('alınan hədiyyə yarım sayılır', () {
      // Yayımçı onsuz da hədiyyə alır; tam sayılsa səviyyə yalnız
      // onlarda olardı.
      expect(xpOf(giftSent: 100, giftReceived: 0), 100);
      expect(xpOf(giftSent: 0, giftReceived: 100), 50);
      expect(xpOf(giftSent: 40, giftReceived: 20), 50);
    });

    test('rəng səviyyə ilə dəyişir', () {
      expect(levelColor(1), isNot(levelColor(15)));
      expect(levelColor(50), levelColor(70));
    });
  });

  group('VIP', () {
    test('xərcləməyən adamda pillə yoxdur', () {
      expect(vipFromSpent(0), 0);
      expect(vipFromSpent(999), 0);
      expect(vipLabel(0), '');
    });

    test('pillələr sırayla açılır', () {
      expect(vipFromSpent(1000), 1);
      expect(vipFromSpent(3000), 2);
      expect(vipFromSpent(1000000), 10);
    });

    test('onuncudan sonra SVIP başlayır', () {
      expect(vipLabel(10), 'VIP10');
      expect(vipLabel(11), 'SVIP1');
      expect(vipLabel(13), 'SVIP3');
      expect(vipFromSpent(2500000), 11);
    });

    test('ən yuxarı pillədən yuxarı qalxmır', () {
      expect(vipFromSpent(999999999), 13);
      expect(spentToNextVip(999999999), isNull);
    });

    test('növbəti pilləyə qalan hesablanır', () {
      expect(spentToNextVip(0), 1000);
      expect(spentToNextVip(900), 100);
      expect(spentToNextVip(1000), 2000);
    });
  });

  group('nişanlar sənəddən', () {
    test('boş sənəd birinci səviyyə verir', () {
      final badges = VibeBadges.from(null);

      expect(badges.level, 1);
      expect(badges.vip, 0);
      expect(badges.hasVip, isFalse);
    });

    test('mətn kimi yazılmış rəqəm də oxunur', () {
      final badges = VibeBadges.from({'giftSent': '5000'});

      expect(badges.vip, greaterThan(0));
      expect(badges.vipText, startsWith('VIP'));
    });

    test('yalnız hədiyyə alan adam VIP olmur', () {
      // VIP xərcləmənin ölçüsüdür; qarışdırılsa pillənin mənası
      // itərdi.
      final badges = VibeBadges.from({'giftReceived': 5000000});

      expect(badges.vip, 0);
      expect(badges.level, greaterThan(1));
    });
  });
}
