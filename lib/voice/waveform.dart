/// Səs yazısından dalğa şəkli çıxarır.
///
/// Şəkil qəsdən yazma anında hesablanır və sənədə yazılır: oxuyan tərəf
/// faylı endirmədən dalğanı çəkə bilir. Əks halda lentdəki hər səs anı
/// üçün megabaytlarla fayl endirilməli olardı.
///
/// Uydurma dalğa çəkmək də olardı, amma o zaman şəkil səslə heç bir
/// əlaqəsi olmayan bəzək olardı — sükut da, qışqırıq da eyni görünərdi.
library;

import 'dart:math' as math;
import 'dart:typed_data';

/// Neçə sütun çəkiləcək.
const int waveformBuckets = 48;

/// WAV baytlarından sütun hündürlüklərini (0..100) çıxarır.
///
/// Yalnız 16 bitlik PCM dəstəklənir — `record` paketi elə onu yazır.
/// Format tanınmasa boş siyahı qayıdır və ekran sadə xətt göstərir.
List<int> waveformFromWav(Uint8List bytes, {int buckets = waveformBuckets}) {
  if (buckets <= 0) return const [];

  final start = _dataChunkStart(bytes);
  if (start < 0) return const [];

  final sampleCount = (bytes.length - start) ~/ 2;
  if (sampleCount < buckets) return const [];

  final data = ByteData.sublistView(bytes, start);
  final perBucket = sampleCount ~/ buckets;

  final levels = <double>[];
  var loudest = 0.0;

  for (var i = 0; i < buckets; i++) {
    var sum = 0.0;

    for (var j = 0; j < perBucket; j++) {
      final sample = data.getInt16((i * perBucket + j) * 2, Endian.little);
      sum += sample * sample;
    }

    // Kvadratik orta: qulağın eşitdiyi gücə insan qavrayışına daha yaxındır.
    final level = math.sqrt(sum / perBucket);
    levels.add(level);
    if (level > loudest) loudest = level;
  }

  if (loudest <= 0) return List<int>.filled(buckets, 0);

  // Ən uca yerə görə normallaşdırırıq — sakit yazı da görünsün.
  return levels
      .map((level) => (level / loudest * 100).round().clamp(0, 100))
      .toList();
}

/// WAV başlığında `data` hissəsinin harada başladığını tapır.
///
/// Başlıq həmişə eyni uzunluqda olmur: bəzi yazıcılar araya əlavə
/// hissələr qoyur, ona görə sabit sürüşmə işlətmirik.
int _dataChunkStart(Uint8List bytes) {
  if (bytes.length < 44) return -1;

  // "RIFF" ... "WAVE"
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

    // Hissələrin uzunluğu cütə yuvarlaqlaşır.
    offset += 8 + size + (size.isOdd ? 1 : 0);
  }

  return -1;
}

/// Sənəddən oxunan dalğanı təmizləyir.
///
/// Köhnə və ya zədəli sənəddə siyahı başqa tipdə ola bilər; ekran
/// sınmasın deyə hər dəyər ayrıca yoxlanılır.
List<int> waveformFromData(Object? raw, {int buckets = waveformBuckets}) {
  if (raw is! List) return const [];

  final list = raw
      .map((e) => e is num ? e.toInt().clamp(0, 100) : 0)
      .toList();

  if (list.isEmpty) return const [];
  if (list.length == buckets) return list;

  // Uzunluq fərqlidirsə sütunları yenidən paylayırıq.
  return List<int>.generate(buckets, (i) {
    final index = (i * list.length / buckets).floor();
    return list[index.clamp(0, list.length - 1)];
  });
}
