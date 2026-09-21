/// Serverin saatı.
///
/// Firestore-da vaxtlar `FieldValue.serverTimestamp()` ilə yazılır —
/// yəni **serverin** saatı ilə. Onları oxuyub `DateTime.now()` ilə
/// müqayisə etmək isə **telefonun** saatını işə salır. Bu iki saat
/// bir-birindən dəqiqələrlə fərqlənə bilər: istifadəçi saatı əl ilə
/// dəyişib, cihaz uzun müddət söndürülüb, vaxt qurşağı səhv qalıb.
///
/// Nəticə acı idi:
///
/// * `isReallyOnline` −5 ilə +45 saniyə arasını tələb edirdi. Saat bir
///   dəqiqə fərqlidirsə, **heç kim onlayn görünmürdü**.
/// * Saat geri qalıbsa fərq mənfi çıxırdı və çoxdan çıxmış adam
///   həmişəlik "otaqda" qalırdı.
/// * "Yazır…" və "Görüldü" nişanları da eyni səbəbdən işləmirdi.
///
/// Həlli budur: girişdə serverin saatı ilə telefonun saatı arasındakı
/// fərq bir dəfə ölçülür və bütün müqayisələr `serverNow()` üzərindən
/// aparılır. Ölçmə alınmasa fərq sıfır qalır — yəni tətbiq əvvəlki
/// kimi işləyir, pisləşmir.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Telefonun saatı serverdən nə qədər geridədir (və ya irəlidədir).
Duration serverClockOffset = Duration.zero;

/// Serverin indiki vaxtı — telefonun saatına düzəliş tətbiq olunmuş.
DateTime serverNow() => DateTime.now().add(serverClockOffset);

/// Server vaxtından bəri nə qədər keçib.
///
/// Sənəddəki `Timestamp` üçün nəzərdə tutulub.
Duration sinceServer(DateTime serverTime) => serverNow().difference(serverTime);

/// Ölçmədən fərqi hesablayır.
///
/// [before] və [after] sorğunun getdiyi və qayıtdığı anlardır.
/// Serverin yazdığı an ikisinin arasında baş verib, ona görə orta
/// nöqtə götürülür — belə olanda şəbəkə gecikməsi fərqə yazılmır.
Duration offsetFrom({
  required DateTime before,
  required DateTime after,
  required DateTime serverStamp,
}) {
  final roundTrip = after.difference(before);

  // Mənfi getdi-gəldi mümkün deyil; saat ölçmə anında dəyişibsə
  // ölçməyə etibar etmirik.
  if (roundTrip.isNegative) return Duration.zero;

  final middle = before.add(roundTrip ~/ 2);
  return serverStamp.difference(middle);
}

/// Fərqi ölçür və yadda saxlayır.
///
/// Səhv olsa fərq toxunulmaz qalır: ölçə bilmədik deyə tətbiqin
/// işləməsi dayanmamalıdır.
Future<void> syncServerClock(String uid, {FirebaseFirestore? database}) async {
  if (uid.isEmpty) return;

  try {
    final ref = (database ?? FirebaseFirestore.instance)
        .collection('users')
        .doc(uid);

    final before = DateTime.now();

    await ref.set(
      {'clockPing': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );

    // Mütləq serverdən oxunmalıdır: yerli yaddaşdakı nüsxədə
    // `serverTimestamp` hələ boş olur.
    final snap = await ref.get(const GetOptions(source: Source.server));
    final after = DateTime.now();

    final raw = snap.data()?['clockPing'];
    if (raw is! Timestamp) return;

    serverClockOffset = offsetFrom(
      before: before,
      after: after,
      serverStamp: raw.toDate(),
    );
  } catch (_) {
    // Ölçmə alınmadı — fərq sıfır qalır, davranış əvvəlki kimidir.
  }
}
