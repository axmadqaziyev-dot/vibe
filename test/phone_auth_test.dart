import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/auth_phone.dart';

void main() {
  group('Nömrə formatı', () {
    test('Sıfırla başlayan yerli nömrə beynəlxalq formata düşür', () {
      expect(normalizePhone('0501234567'), '+994501234567');
      expect(normalizePhone('050 123 45 67'), '+994501234567');
      expect(normalizePhone('(050) 123-45-67'), '+994501234567');
    });

    test('Sıfırsız yazılan nömrə də tanınır', () {
      expect(normalizePhone('501234567'), '+994501234567');
    });

    test('Ölkə kodu yazılıbsa toxunulmur', () {
      expect(normalizePhone('+905321234567'), '+905321234567');
      expect(normalizePhone('00905321234567'), '+905321234567');
    });

    test('Başqa ölkə kodu ilə işləyir', () {
      expect(
        normalizePhone('5551234567', defaultCode: '+1'),
        '+15551234567',
      );
    });
  });

  group('Nömrə yoxlaması', () {
    test('Düzgün nömrələr qəbul olunur', () {
      expect(isValidPhone('0501234567'), isTrue);
      expect(isValidPhone('+994 50 123 45 67'), isTrue);
    });

    test('Qısa və boş nömrələr rədd olunur', () {
      expect(isValidPhone(''), isFalse);
      expect(isValidPhone('123'), isFalse);
      expect(isValidPhone('05012'), isFalse);
    });

    test('Həddən artıq uzun nömrə rədd olunur', () {
      expect(isValidPhone('+9945012345678901234'), isFalse);
    });
  });

  group('Xəta mətnləri', () {
    test('Tanınmayan xəta istifadəçiyə səbəbi göstərir', () {
      // Problemi tapmaq üçün xətanın özü də mətnə düşür.
      final text = describePhoneError(Exception('boom'));
      expect(text, contains('Alınmadı'));
      expect(text, contains('boom'));
    });
  });
}
