import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/server_time.dart';

void main() {
  setUp(() => serverClockOffset = Duration.zero);
  tearDown(() => serverClockOffset = Duration.zero);

  group('fərqin hesablanması', () {
    test('saat düz olanda fərq sıfıra yaxındır', () {
      final before = DateTime(2026, 9, 21, 12, 0, 0);
      final after = DateTime(2026, 9, 21, 12, 0, 0, 200);

      final offset = offsetFrom(
        before: before,
        after: after,
        // Server sorğunun ortasında yazıb.
        serverStamp: DateTime(2026, 9, 21, 12, 0, 0, 100),
      );

      expect(offset, Duration.zero);
    });

    test('telefon geri qalıbsa fərq müsbətdir', () {
      // Telefon 12:00 göstərir, server 12:05-dir.
      final offset = offsetFrom(
        before: DateTime(2026, 9, 21, 12, 0),
        after: DateTime(2026, 9, 21, 12, 0),
        serverStamp: DateTime(2026, 9, 21, 12, 5),
      );

      expect(offset, const Duration(minutes: 5));
    });

    test('telefon irəlidirsə fərq mənfidir', () {
      final offset = offsetFrom(
        before: DateTime(2026, 9, 21, 12, 10),
        after: DateTime(2026, 9, 21, 12, 10),
        serverStamp: DateTime(2026, 9, 21, 12, 0),
      );

      expect(offset, const Duration(minutes: -10));
    });

    test('şəbəkə gecikməsi fərqə yazılmır', () {
      // Sorğu 2 saniyə çəkib, server tam ortada yazıb.
      final offset = offsetFrom(
        before: DateTime(2026, 9, 21, 12, 0, 0),
        after: DateTime(2026, 9, 21, 12, 0, 2),
        serverStamp: DateTime(2026, 9, 21, 12, 0, 1),
      );

      expect(offset, Duration.zero);
    });

    test('vaxt geri getsə ölçməyə etibar olunmur', () {
      final offset = offsetFrom(
        before: DateTime(2026, 9, 21, 12, 0, 5),
        after: DateTime(2026, 9, 21, 12, 0, 0),
        serverStamp: DateTime(2026, 9, 21, 12, 0, 3),
      );

      expect(offset, Duration.zero);
    });
  });

  group('serverNow', () {
    test('fərq tətbiq olunur', () {
      serverClockOffset = const Duration(minutes: 5);

      final diff = serverNow().difference(DateTime.now());
      expect(diff.inSeconds, closeTo(300, 2));
    });

    test('fərq sıfır olanda telefonun saatıdır', () {
      final diff = serverNow().difference(DateTime.now());
      expect(diff.inSeconds.abs(), lessThan(2));
    });

    test('keçən vaxt düzgün ölçülür', () {
      // Telefon 5 dəqiqə geri qalıb. Serverdə 1 dəqiqə əvvəl yazılmış
      // nişan telefonun saatı ilə "4 dəqiqə gələcəkdə" görünərdi.
      serverClockOffset = const Duration(minutes: 5);

      final stamp = serverNow().subtract(const Duration(minutes: 1));
      expect(sinceServer(stamp).inSeconds, closeTo(60, 2));
    });
  });
}
