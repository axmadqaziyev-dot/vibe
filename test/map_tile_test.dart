import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/map_tile.dart';

void main() {
  group('lövhə hesablaması', () {
    test('sıfır nöqtəsi mərkəzdədir', () {
      // Zoom 1-də dünya 2x2 lövhədir; (0,0) sağ-aşağı kvadratın
      // başlanğıcıdır.
      expect(tileX(0, 1), 1);
      expect(tileY(0, 1), 1);
    });

    test('Bakı düzgün lövhəyə düşür', () {
      // 40.3777, 49.8920 — zoom 15.
      expect(tileX(49.8920, 15), 20925);
      expect(tileY(40.3777, 15), 12360);
    });

    test('qütblər daşmır', () {
      // Mercator qütbdə sonsuzluğa gedir; hesablama sərhəddə
      // saxlanılmalıdır.
      final n = (1 << 15) - 1;
      expect(tileY(90, 15), inInclusiveRange(0, n));
      expect(tileY(-90, 15), inInclusiveRange(0, n));
    });

    test('sərhəd uzunluqları daşmır', () {
      final n = (1 << 15) - 1;
      expect(tileX(180, 15), inInclusiveRange(0, n));
      expect(tileX(-180, 15), 0);
    });

    test('ünvan düzgün qurulur', () {
      expect(
        mapTileUrl(40.3777, 49.8920),
        'https://tile.openstreetmap.org/15/20925/12360.png',
      );
    });
  });

  group('yazı', () {
    test('koordinat dörd rəqəmlə yazılır', () {
      expect(coordinateText(40.377712, 49.891974), '40.3777, 49.8920');
    });

    test('xəritə ünvanı koordinatı daşıyır', () {
      expect(mapOpenUrl(40.5, 49.5), contains('40.5,49.5'));
    });
  });
}
