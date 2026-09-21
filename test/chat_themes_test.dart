import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/chat_themes.dart';

void main() {
  group('Mövzular', () {
    test('Hər mövzunun açarı, adı və rəngləri var', () {
      for (final theme in chatThemes) {
        expect(theme.id.trim(), isNotEmpty);
        expect(theme.name.trim(), isNotEmpty);
        expect(theme.background.length, greaterThanOrEqualTo(2));
        expect(theme.mine.length, greaterThanOrEqualTo(2));
      }
    });

    test('Açarlar təkrarlanmır', () {
      final ids = chatThemes.map((e) => e.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('Açardan mövzu tapılır', () {
      expect(chatThemeOf('sunset').name, 'Gün batımı');
      expect(chatThemeOf('paper').dark, isFalse);
    });

    test('Tanınmayan açar ilk mövzunu verir', () {
      // Köhnə söhbətdə mövzu sahəsi olmaya bilər.
      expect(chatThemeOf(null).id, chatThemes.first.id);
      expect(chatThemeOf('kohne-movzu').id, chatThemes.first.id);
    });

    test('Ən azı altı mövzu var', () {
      expect(chatThemes.length, greaterThanOrEqualTo(6));
    });

    test('Keçidlər qurula bilir', () {
      for (final theme in chatThemes) {
        expect(theme.backgroundGradient.colors, theme.background);
        expect(theme.mineGradient.colors, theme.mine);
      }
    });
  });
}
