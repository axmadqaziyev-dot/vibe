/// Söhbət bildirişi — kimə lazımdır, kimə yox.
///
/// Əvvəl hər mesaj "Bildirişlər" siyahısına düşürdü. Nəticədə tanış
/// adamla adi yazışma onlarla bildiriş yaradırdı: siyahı "İlkin: vvd",
/// "İlkin: vbdd", "İlkin: salsv" ilə dolurdu. Mesajın özü onsuz da
/// Mesajlar siyahısında görünür — bildiriş orada təkrardır.
///
/// Qayda sadədir: **tanımadığın adam yazanda xəbər ver.**
///
/// Adamı "tanıyıram" saymağın ölçüsü onu izləməyimdir. İzləyirəmsə
/// söhbət gözlənilən söhbətdir, bildirişə ehtiyac yoxdur. İzləmirəmsə
/// bu, yad adamın ilk müraciətidir — onu görmək lazımdır.
///
/// Telefonun öz bildirişi (push) bundan asılı deyil və həmişə gedir:
/// tətbiq bağlı olanda mesajdan xəbər tutmaq istənilən halda lazımdır.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Alan tərəf göndərəni izləyirmi?
Future<bool> receiverFollows({
  required String toUid,
  required String fromUid,
  FirebaseFirestore? database,
}) async {
  if (toUid.isEmpty || fromUid.isEmpty || toUid == fromUid) return true;

  try {
    final snap = await (database ?? FirebaseFirestore.instance)
        .collection('users')
        .doc(toUid)
        .collection('following')
        .doc(fromUid)
        .get();

    return snap.exists;
  } catch (_) {
    // Oxuya bilmədiksə bildiriş yazmırıq: artıq bildiriş az bildirişdən
    // pisdir — istifadəçi siyahını bağlayır və heç birinə baxmır.
    return true;
  }
}

/// Lazımdırsa söhbət bildirişi yazır.
Future<void> notifyNewMessage({
  required String toUid,
  required String fromUid,
  required String fromName,
  required String body,
  required String chatId,
  FirebaseFirestore? database,
}) async {
  if (await receiverFollows(
    toUid: toUid,
    fromUid: fromUid,
    database: database,
  )) {
    return;
  }

  try {
    await (database ?? FirebaseFirestore.instance)
        .collection('users')
        .doc(toUid)
        .collection('notifications')
        .add({
      'type': 'message',
      'title': fromName,
      'body': body,
      'fromUid': fromUid,
      'chatId': chatId,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  } catch (_) {}
}
