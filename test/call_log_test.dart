import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/call_log.dart';

void main() {
  group('müddət', () {
    test('saniyə iki rəqəmlə yazılır', () {
      expect(callDuration(5), '0:05');
      expect(callDuration(65), '1:05');
    });

    test('saat əlavə olunur', () {
      expect(callDuration(3661), '1:01:01');
    });

    test('mənfi dəyər sıfır sayılır', () {
      // Saat fərqi səbəbindən mənfi çıxa bilər.
      expect(callDuration(-10), '0:00');
    });
  });

  group('yazı', () {
    test('danışılan zəng müddətlə görünür', () {
      expect(
        callLogText(
          video: false,
          outcome: CallOutcome.answered,
          seconds: 134,
          mine: true,
        ),
        'Səsli zəng · 2:14',
      );
    });

    test('qarşı tərəf üçün hər cavabsız hal eynidir', () {
      for (final outcome in [
        CallOutcome.missed,
        CallOutcome.declined,
        CallOutcome.cancelled,
      ]) {
        expect(
          callLogText(
            video: true,
            outcome: outcome,
            seconds: 0,
            mine: false,
          ),
          'Cavabsız video zəng',
        );
      }
    });

    test('zəng edən üçün hallar fərqlidir', () {
      expect(
        callLogText(
          video: false,
          outcome: CallOutcome.declined,
          seconds: 0,
          mine: true,
        ),
        'Səsli zəng rədd edildi',
      );
      expect(
        callLogText(
          video: false,
          outcome: CallOutcome.cancelled,
          seconds: 0,
          mine: true,
        ),
        'Zəng ləğv edildi',
      );
    });
  });

  group('nəticə adı', () {
    test('tanınmayan ad cavabsız sayılır', () {
      expect(outcomeFromName('kohne'), CallOutcome.missed);
      expect(outcomeFromName(null), CallOutcome.missed);
      expect(outcomeFromName('answered'), CallOutcome.answered);
    });
  });
}
