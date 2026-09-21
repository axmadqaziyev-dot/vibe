import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/story_overlay.dart';

void main() {
  group('üst qat', () {
    test('sənədə yazılır və geri oxunur', () {
      const overlay = StoryOverlay(
        kind: OverlayKind.text,
        value: 'Salam',
        dx: .3,
        dy: .7,
        scale: 1.5,
        colorValue: 0xffff2bd6,
      );

      final back = StoryOverlay.from(overlay.toMap())!;

      expect(back.kind, OverlayKind.text);
      expect(back.value, 'Salam');
      expect(back.dx, .3);
      expect(back.scale, 1.5);
      expect(back.colorValue, 0xffff2bd6);
    });

    test('boş dəyər qəbul olunmur', () {
      expect(StoryOverlay.from({'value': ''}), isNull);
      expect(StoryOverlay.from('yazı'), isNull);
      expect(StoryOverlay.from(null), isNull);
    });

    test('sahəsi olmayan sənəd ortadan başlayır', () {
      final overlay = StoryOverlay.from({'value': 'a'})!;
      expect(overlay.dx, .5);
      expect(overlay.dy, .5);
      expect(overlay.scale, 1);
    });

    test('yer ekrandan kənara çıxmır', () {
      // Barmaq sürüşüb ekrandan çıxanda yazı itirdi.
      const overlay = StoryOverlay(kind: OverlayKind.text, value: 'a');

      expect(overlay.copyWith(dx: 5).dx, lessThanOrEqualTo(1));
      expect(overlay.copyWith(dx: -3).dx, greaterThanOrEqualTo(0));
      expect(overlay.copyWith(dy: 9).dy, lessThanOrEqualTo(1));
    });

    test('ölçü məhdudlanır', () {
      const overlay = StoryOverlay(kind: OverlayKind.emoji, value: '🎂');

      expect(overlay.copyWith(scale: 100).scale, 4.0);
      expect(overlay.copyWith(scale: 0.01).scale, 0.4);
    });

    test('siyahı oxunur, pozuq sətirlər atılır', () {
      final list = StoryOverlay.listFrom([
        {'value': 'bir', 'kind': 'text'},
        {'value': ''},
        'zibil',
        {'value': '🎉', 'kind': 'emoji'},
      ]);

      expect(list.length, 2);
      expect(list.first.value, 'bir');
      expect(list.last.kind, OverlayKind.emoji);
    });

    test('siyahı olmayan dəyər boş verir', () {
      expect(StoryOverlay.listFrom(null), isEmpty);
      expect(StoryOverlay.listFrom('a'), isEmpty);
    });
  });

  group('fon', () {
    test('tanınmayan ad ilk fonu verir', () {
      expect(backgroundById('yoxdur').id, storyBackgrounds.first.id);
      expect(backgroundById(null).id, storyBackgrounds.first.id);
    });

    test('ad üzrə tapılır', () {
      expect(backgroundById('deniz').name, 'Dəniz');
    });
  });

  group('şablon', () {
    test('hər şablon iki qat verir', () {
      for (final template in storyTemplates) {
        final overlays = template.overlays();

        expect(overlays.length, 2);
        expect(overlays.first.kind, OverlayKind.text);
        expect(overlays.last.kind, OverlayKind.emoji);
        expect(overlays.first.value, isNotEmpty);
      }
    });

    test('hər şablonun fonu mövcuddur', () {
      for (final template in storyTemplates) {
        expect(
          backgroundById(template.backgroundId).id,
          template.backgroundId,
          reason: '${template.id} fonu tapılmadı',
        );
      }
    });
  });
}
