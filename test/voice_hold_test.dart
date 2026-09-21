import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/voice/voice_hold.dart';

void main() {
  group('göndər düyməsi', () {
    test('yazı başlamayıbsa işləmir', () {
      expect(canSendVoice(VoiceStage.idle, 5000), isFalse);
    });

    test('çox qısa yazı göndərilmir', () {
      // Səhvən toxunmaq mesaj yaratmamalıdır.
      expect(canSendVoice(VoiceStage.recording, 100), isFalse);
      expect(canSendVoice(VoiceStage.ready, minVoiceMs - 1), isFalse);
    });

    test('kifayət qədər uzun yazı göndərilir', () {
      expect(canSendVoice(VoiceStage.recording, minVoiceMs), isTrue);
      expect(canSendVoice(VoiceStage.ready, 4000), isTrue);
    });
  });

  group('sayğac', () {
    test('saniyə iki rəqəmlə yazılır', () {
      expect(holdTimer(0), '0:00');
      expect(holdTimer(7400), '0:07');
      expect(holdTimer(65000), '1:05');
    });

    test('dəqiqə keçidi düzgündür', () {
      expect(holdTimer(59999), '0:59');
      expect(holdTimer(60000), '1:00');
    });
  });
}
