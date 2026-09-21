/// Səs maskası — yazılmış səsi dəyişdirir.
///
/// DİQQƏT: bu, **yazıldıqdan sonra** tətbiq olunur. Canlı otaqda,
/// danışdığın anda səsi dəyişmək başqa məsələdir: orada axını
/// göndərməzdən əvvəl emal etmək lazımdır və hər platformada ayrıca
/// həll tələb edir (vebdə Web Audio, mobildə yerli kod). Səsli anlar
/// və pıçıltı üçün isə bu yanaşma tam kifayətdir.
///
/// Effektlər sadə riyaziyyatla alınır — kənar kitabxana yoxdur.
library;

import 'dart:math' as math;
import 'dart:typed_data';

/// Mövcud maskalar.
enum VoiceFx { none, high, low, robot }

extension VoiceFxInfo on VoiceFx {
  String get label => switch (this) {
        VoiceFx.none => 'Təbii',
        VoiceFx.high => 'Nazik',
        VoiceFx.low => 'Qalın',
        VoiceFx.robot => 'Robot',
      };

  String get emoji => switch (this) {
        VoiceFx.none => '🙂',
        VoiceFx.high => '🐿️',
        VoiceFx.low => '🐻',
        VoiceFx.robot => '🤖',
      };
}

/// Maskanı WAV baytlarına tətbiq edir və yeni WAV qaytarır.
///
/// Format tanınmasa giriş olduğu kimi qaytarılır — maska işləməsə də
/// səs itməməlidir.
Uint8List applyVoiceFx(Uint8List wav, VoiceFx fx) {
  if (fx == VoiceFx.none) return wav;

  final start = _dataStart(wav);
  if (start < 0) return wav;

  final samples = _readSamples(wav, start);
  if (samples.isEmpty) return wav;

  final out = switch (fx) {
    // Addım böyükdürsə nümunələr atlanır: yazı qısalır, səs nazilir.
    VoiceFx.high => _resample(samples, 1.28),
    VoiceFx.low => _resample(samples, 0.78),
    VoiceFx.robot => _ringModulate(samples, _sampleRate(wav)),
    VoiceFx.none => samples,
  };

  return _buildWav(out, _sampleRate(wav));
}

/// Sürəti dəyişməklə tonu dəyişir.
///
/// [factor] 1-dən böyükdürsə səs nazilir və qısalır, kiçikdirsə
/// qalınlaşır və uzanır. Tonu sürətdən ayırmaq üçün faza vokoderi
/// lazımdır — o, bu effektdən qat-qat mürəkkəbdir və buradakı məqsəd
/// (əylənmək və səsi tanınmaz etmək) üçün lazım deyil.
Int16List _resample(Int16List input, double factor) {
  final length = (input.length / factor).floor();
  if (length <= 1) return input;

  final out = Int16List(length);

  for (var i = 0; i < length; i++) {
    final position = i * factor;
    final index = position.floor();
    final next = math.min(index + 1, input.length - 1);
    final blend = position - index;

    // Xətti interpolyasiya: kəskin sıçrayış cırıltı yaradır.
    out[i] = (input[index] * (1 - blend) + input[next] * blend).round();
  }

  return out;
}

/// Halqa modulyasiyası — metal "robot" tonu.
///
/// Səsi sabit tezlikli dalğaya vururuq. Uzunluq dəyişmir.
Int16List _ringModulate(Int16List input, int sampleRate) {
  final out = Int16List(input.length);
  const carrier = 60.0;

  for (var i = 0; i < input.length; i++) {
    final wave = math.sin(2 * math.pi * carrier * i / sampleRate);

    // Tam modulyasiya səsi anlaşılmaz edir, ona görə yarısı saxlanılır.
    final value = input[i] * (0.5 + 0.5 * wave);
    out[i] = value.round().clamp(-32768, 32767);
  }

  return out;
}

/// WAV-ın uzunluğu (millisaniyə).
///
/// Maska tətbiq olunandan sonra lazımdır: ton dəyişəndə yazının
/// uzunluğu da dəyişir, köhnə rəqəm yalan olardı.
int wavDurationMs(Uint8List wav) {
  final start = _dataStart(wav);
  if (start < 0) return 0;

  final samples = (wav.length - start) ~/ 2;
  final rate = _sampleRate(wav);
  if (rate <= 0) return 0;

  return (samples / rate * 1000).round();
}

int _sampleRate(Uint8List wav) {
  if (wav.length < 28) return 16000;
  final rate = ByteData.sublistView(wav, 24, 28).getUint32(0, Endian.little);
  return rate == 0 ? 16000 : rate;
}

int _dataStart(Uint8List bytes) {
  if (bytes.length < 44) return -1;
  if (bytes[0] != 0x52 || bytes[1] != 0x49 ||
      bytes[2] != 0x46 || bytes[3] != 0x46) {
    return -1;
  }

  var offset = 12;
  while (offset + 8 <= bytes.length) {
    final isData = bytes[offset] == 0x64 &&
        bytes[offset + 1] == 0x61 &&
        bytes[offset + 2] == 0x74 &&
        bytes[offset + 3] == 0x61;

    final size = ByteData.sublistView(bytes, offset + 4, offset + 8)
        .getUint32(0, Endian.little);

    if (isData) return offset + 8;
    offset += 8 + size + (size.isOdd ? 1 : 0);
  }

  return -1;
}

Int16List _readSamples(Uint8List bytes, int start) {
  final count = (bytes.length - start) ~/ 2;
  if (count <= 0) return Int16List(0);

  final data = ByteData.sublistView(bytes, start);
  final out = Int16List(count);

  for (var i = 0; i < count; i++) {
    out[i] = data.getInt16(i * 2, Endian.little);
  }

  return out;
}

/// 16 bitlik mono WAV qurur.
Uint8List _buildWav(Int16List samples, int sampleRate) {
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
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, samples.length * 2, Endian.little);

  for (var i = 0; i < samples.length; i++) {
    data.setInt16(44 + i * 2, samples[i], Endian.little);
  }

  return data.buffer.asUint8List();
}
