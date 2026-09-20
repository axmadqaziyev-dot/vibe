import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/voice/waveform.dart';

/// Sadə 16 bitlik mono WAV qurur.
Uint8List makeWav(List<int> samples) {
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
  data.setUint16(20, 1, Endian.little); // PCM
  data.setUint16(22, 1, Endian.little); // mono
  data.setUint32(24, 16000, Endian.little);
  data.setUint32(28, 32000, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, samples.length * 2, Endian.little);

  for (var i = 0; i < samples.length; i++) {
    data.setInt16(44 + i * 2, samples[i], Endian.little);
  }

  return data.buffer.asUint8List();
}

void main() {
  group('WAV-dan dalğa', () {
    test('Sükut sıfır sütunlar verir', () {
      final wav = makeWav(List<int>.filled(4800, 0));
      expect(waveformFromWav(wav), List<int>.filled(waveformBuckets, 0));
    });

    test('Uca hissə sakit hissədən hündürdür', () {
      // Birinci yarı sakit, ikinci yarı uca.
      final samples = [
        for (var i = 0; i < 2400; i++) 200,
        for (var i = 0; i < 2400; i++) 20000,
      ];

      final wave = waveformFromWav(makeWav(samples));

      expect(wave.first, lessThan(wave.last));
      expect(wave.last, 100, reason: 'ən uca sütun 100 olmalıdır');
    });

    test('Sabit səsdə bütün sütunlar bərabərdir', () {
      final wav = makeWav(List<int>.filled(4800, 8000));
      final wave = waveformFromWav(wav);

      expect(wave.toSet().length, 1);
      expect(wave.first, 100);
    });

    test('Sinus dalğası hamar çıxır', () {
      final samples = [
        for (var i = 0; i < 9600; i++)
          (math.sin(i / 20) * 15000).round(),
      ];

      final wave = waveformFromWav(makeWav(samples));

      expect(wave.length, waveformBuckets);
      expect(wave.every((v) => v >= 0 && v <= 100), isTrue);
      // Sabit amplitudalı sinusda sütunlar bir-birinə yaxın olmalıdır.
      expect(wave.reduce(math.min), greaterThan(70));
    });

    test('Zədəli fayl boş siyahı qaytarır', () {
      expect(waveformFromWav(Uint8List.fromList([1, 2, 3])), isEmpty);
      expect(waveformFromWav(Uint8List(0)), isEmpty);
    });

    test('RIFF olmayan fayl qəbul edilmir', () {
      final wav = makeWav(List<int>.filled(4800, 100));
      wav[0] = 0x00;
      expect(waveformFromWav(wav), isEmpty);
    });

    test('Çox qısa yazı sütunları doldura bilmirsə boş qayıdır', () {
      expect(waveformFromWav(makeWav(List<int>.filled(10, 500))), isEmpty);
    });
  });

  group('Sənəddən oxuma', () {
    test('Düzgün siyahı olduğu kimi qayıdır', () {
      final list = List<int>.generate(waveformBuckets, (i) => i % 100);
      expect(waveformFromData(list), list);
    });

    test('Siyahı olmayan dəyər boş qayıdır', () {
      expect(waveformFromData(null), isEmpty);
      expect(waveformFromData('salam'), isEmpty);
    });

    test('Yanlış tipli elementlər sıfır sayılır', () {
      final out = waveformFromData(['a', null, 50], buckets: 3);
      expect(out, [0, 0, 50]);
    });

    test('Qısa siyahı lazımi uzunluğa çatdırılır', () {
      final out = waveformFromData([0, 100], buckets: 4);
      expect(out.length, 4);
      expect(out.first, 0);
      expect(out.last, 100);
    });

    test('Həddi aşan dəyərlər kəsilir', () {
      expect(waveformFromData([500, -20], buckets: 2), [100, 0]);
    });
  });
}
