import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/gifts.dart';

void main() {
  group('hədiyyə pilləsi', () {
    test('qiymətə görə ayrılır', () {
      expect(tierForPrice(10), GiftTier.simple);
      expect(tierForPrice(249), GiftTier.simple);
      expect(tierForPrice(250), GiftTier.rare);
      expect(tierForPrice(1000), GiftTier.epic);
      expect(tierForPrice(5000), GiftTier.legendary);
    });

    test('bahalı hədiyyə daha uzun oynayır', () {
      expect(
        GiftTier.legendary.durationMs,
        greaterThan(GiftTier.simple.durationMs),
      );
      expect(
        GiftTier.epic.particles,
        greaterThan(GiftTier.rare.particles),
      );
    });

    test('yalnız bahalı hədiyyə ekranı tutur', () {
      expect(GiftTier.simple.fullScreen, isFalse);
      expect(GiftTier.rare.fullScreen, isFalse);
      expect(GiftTier.epic.fullScreen, isTrue);
      expect(GiftTier.legendary.fullScreen, isTrue);
    });

    test('kataloqdakı hər hədiyyənin pilləsi var', () {
      for (final gift in allGifts) {
        expect(tierForPrice(gift.price).label, isNotEmpty);
      }
    });

    test('ən bahalı hədiyyə əfsanəvidir', () {
      final top = allGifts.map((g) => g.price).reduce((a, b) => a > b ? a : b);
      expect(tierForPrice(top), GiftTier.legendary);
    });
  });
}
