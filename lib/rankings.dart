import 'package:cloud_firestore/cloud_firestore.dart';

/// Reytinq dövrləri.
///
/// Yalnız ümumi hesab olanda lövhə donur: başdakı beş nəfər aylarla dəyişmir
/// və qalanların cəhd etməsinə səbəb qalmır. Günlük və həftəlik lövhə hər
/// gün sıfırdan başlayır — bu, adamları geri gətirən şeydir.
enum RankingPeriod { today, week, all }

extension RankingPeriodLabel on RankingPeriod {
  String get label => switch (this) {
        RankingPeriod.today => 'Bu gün',
        RankingPeriod.week => 'Həftə',
        RankingPeriod.all => 'Ümumi',
      };
}

/// Günün açarı: `d2026-09-21`.
///
/// Cihazın yerli vaxtı ilə hesablanır — istifadəçi üçün "bu gün" odur.
String dayKey(DateTime now) {
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  return 'd${now.year}-$month-$day';
}

/// Həftənin açarı: `w2026-38` (ISO-8601 həftə nömrəsi).
///
/// ISO qaydası ilə həftə bazar ertəsi başlayır və ilin ilk həftəsi
/// 4 yanvarın düşdüyü həftədir. Ona görə həftənin cümə axşamına baxırıq:
/// o gün hansı ildədirsə, həftə də o ilə aiddir. Beləcə dekabrın sonu və
/// yanvarın əvvəli iki yerə parçalanmır.
String weekKey(DateTime now) {
  final date = DateTime.utc(now.year, now.month, now.day);
  final thursday = date.add(Duration(days: 4 - date.weekday));
  final firstDay = DateTime.utc(thursday.year, 1, 1);
  final week = 1 + (thursday.difference(firstDay).inDays ~/ 7);

  return 'w${thursday.year}-${week.toString().padLeft(2, '0')}';
}

/// Dövrün sənəd açarı. Ümumi lövhə `users` kolleksiyasından oxunur,
/// ona görə burada açarı olmur.
String? periodKey(RankingPeriod period, DateTime now) => switch (period) {
      RankingPeriod.today => dayKey(now),
      RankingPeriod.week => weekKey(now),
      RankingPeriod.all => null,
    };

/// Hədiyyəni dövr lövhələrinə yazır.
///
/// Tranzaksiyanın içindən çağırılır ki, sikkə çıxılmadan xal yazılmasın.
/// Yalnız yazma əməliyyatıdır — oxuma yoxdur, ona görə tranzaksiyadakı
/// "əvvəlcə oxu, sonra yaz" qaydasını pozmur.
///
/// Hər dövr üçün ayrıca sənəd saxlanılır: `rankings/d2026-09-21/users/{uid}`.
/// Ad və şəkil sənədin içində təkrarlanır ki, lövhəni göstərmək üçün
/// əlli ayrı profil sorğusu getməsin.
void recordGiftInTransaction(
  Transaction tx, {
  required FirebaseFirestore db,
  required String fromUid,
  required String fromName,
  String fromPhoto = '',
  required String toUid,
  required String toName,
  String toPhoto = '',
  required int amount,
  String? roomId,
  String? roomTitle,
  DateTime? now,
}) {
  if (amount <= 0 || fromUid.isEmpty || toUid.isEmpty) return;

  final moment = now ?? DateTime.now();
  final stamp = FieldValue.serverTimestamp();

  for (final key in [dayKey(moment), weekKey(moment)]) {
    final period = db.collection('rankings').doc(key);

    tx.set(period.collection('users').doc(fromUid), {
      'uid': fromUid,
      'name': fromName,
      if (fromPhoto.isNotEmpty) 'photoUrl': fromPhoto,
      'sent': FieldValue.increment(amount),
      'updatedAt': stamp,
    }, SetOptions(merge: true));

    tx.set(period.collection('users').doc(toUid), {
      'uid': toUid,
      'name': toName,
      if (toPhoto.isNotEmpty) 'photoUrl': toPhoto,
      'received': FieldValue.increment(amount),
      'updatedAt': stamp,
    }, SetOptions(merge: true));

    if (roomId != null && roomId.isNotEmpty) {
      tx.set(period.collection('rooms').doc(roomId), {
        'roomId': roomId,
        'title': roomTitle ?? '',
        'total': FieldValue.increment(amount),
        'updatedAt': stamp,
      }, SetOptions(merge: true));
    }

    // Dövrün özü boş sənəd qalmasın — konsolda görünsün deyə.
    tx.set(period, {'updatedAt': stamp}, SetOptions(merge: true));
  }
}
