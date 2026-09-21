import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/voice/voice_fx.dart';
import 'package:flutter_application_1/voice/waveform.dart';

Uint8List makeWav(List<int> samples, {int rate = 16000}) {
  final data = ByteData(44 + samples.length * 2);

  void ascii(int offset, String text) {
    for (var i = 0; i < text.length; i++) {
      data.setUint8(offset + i, text.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  data.setUint32(4, 36 + samples.length * 2, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, rate, Endian.little);
  data.setUint32(28, rate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, samples.length * 2, Endian.little);

  for (var i = 0; i < samples.length; i++) {
    data.setInt16(44 + i * 2, samples[i], Endian.little);
  }

  return data.buffer.asUint8List();
}

int sampleCount(Uint8List wav) => (wav.length - 44) ~/ 2;

final tone = [
  for (var i = 0; i < 8000; i++) (math.sin(i / 12) * 12000).round(),
];

void main() {
  group('Maskalar', () {
    test('Hər maskanın adı və işarəsi var', () {
      for (final fx in VoiceFx.values) {
        expect(fx.label.trim(), isNotEmpty);
        expect(fx.emoji.trim(), isNotEmpty);
      }
    });

    test('Təbii maska heç nə dəyişmir', () {
      final wav = makeWav(tone);
      expect(applyVoiceFx(wav, VoiceFx.none), same(wav));
    });

    test('Nazik səs qısalır', () {
      // Sürət artdığı üçün yazı qısalır.
      final out = applyVoiceFx(makeWav(tone), VoiceFx.high);
      expect(sampleCount(out), lessThan(tone.length));
    });

    test('Qalın səs uzanır', () {
      final out = applyVoiceFx(makeWav(tone), VoiceFx.low);
      expect(sampleCount(out), greaterThan(tone.length));
    });

    test('Robot maskası uzunluğu saxlayır', () {
      final out = applyVoiceFx(makeWav(tone), VoiceFx.robot);
      expect(sampleCount(out), tone.length);
    });

    test('Nəticə düzgün WAV-dır və dalğası oxunur', () {
      for (final fx in VoiceFx.values) {
        final out = applyVoiceFx(makeWav(tone), fx);
        expect(waveformFromWav(out).length, waveformBuckets, reason: fx.label);
      }
    });

    test('Səs itmir — nəticə sükut deyil', () {
      for (final fx in [VoiceFx.high, VoiceFx.low, VoiceFx.robot]) {
        final wave = waveformFromWav(applyVoiceFx(makeWav(tone), fx));
        expect(wave.reduce(math.max), greaterThan(0), reason: fx.label);
      }
    });

    test('Zədəli fayl olduğu kimi qayıdır', () {
      final broken = Uint8List.fromList([1, 2, 3, 4]);
      expect(applyVoiceFx(broken, VoiceFx.high), broken);
    });

    test('Boş yazı sınmır', () {
      final empty = makeWav(const []);
      expect(() => applyVoiceFx(empty, VoiceFx.robot), returnsNormally);
    });

    test('Nümunə tezliyi saxlanılır', () {
      final out = applyVoiceFx(makeWav(tone, rate: 22050), VoiceFx.robot);
      final rate = ByteData.sublistView(out, 24, 28).getUint32(0, Endian.little);
      expect(rate, 22050);
    });
  });
}
