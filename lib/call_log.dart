/// Zəngin söhbətdə izi.
///
/// Zəng edib cavab almayanda söhbətdə heç nə qalmırdı — nə "cavabsız
/// zəng", nə vaxt, nə də zəngin olub-olmadığı. Adam sabah açıb
/// baxanda zəng etdiyini xatırlamırdı. WhatsApp, Instagram və Telegram
/// zəngi söhbətə yazır; biz də yazmalıyıq.
///
/// Qeydi **yalnız zəng edən tərəf** yazır. İki səbəb:
///
/// 1. Firestore qaydası mesajın `senderId` sahəsini yazanın özü kimi
///    tələb edir. Qarşı tərəf yazsaydı, "cavabsız zəng" onun öz
///    tərəfində görünərdi — sanki o zəng edib.
/// 2. Sənədin adı zəngin öz nömrəsidir. Hər iki tərəf cəhd etsə belə
///    bir qeyd yaranır, təkrar olmur.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

// Söhbət sənədinin adı burada hazırdır — iki yerdə saxlasaq,
// birini dəyişəndə qeyd başqa sənədə düşərdi.
import 'blocking.dart' show chatIdFor;

/// Zəng necə bitdi.
enum CallOutcome {
  /// Danışıldı.
  answered,

  /// Cavab verilmədi.
  missed,

  /// Qarşı tərəf rədd etdi.
  declined,

  /// Zəng edən özü dayandırdı.
  cancelled,
}

CallOutcome outcomeFromName(Object? name) => CallOutcome.values.firstWhere(
      (value) => value.name == '${name ?? ''}',
      orElse: () => CallOutcome.missed,
    );

/// Söhbətdə görünən yazı.
///
/// [mine] — qeydə baxan adam zəng edən tərəfdirmi. "Cavabsız zəng"
/// ilə "Zəngini buraxdın" eyni hadisənin iki üzüdür.
String callLogText({
  required bool video,
  required CallOutcome outcome,
  required int seconds,
  required bool mine,
}) {
  final kind = video ? 'Video zəng' : 'Səsli zəng';

  // Qarşı tərəf üçün hər cavabsız hal eynidir: "Cavabsız zəng".
  // Zəng edən üçün isə fərq var — rədd edilmək, ləğv etmək və cavab
  // almamaq başqa-başqa şeylərdir.
  final missedForThem = 'Cavabsız ${kind.toLowerCase()}';

  return switch (outcome) {
    CallOutcome.answered => '$kind · ${callDuration(seconds)}',
    CallOutcome.declined => mine ? '$kind rədd edildi' : missedForThem,
    CallOutcome.cancelled => mine ? 'Zəng ləğv edildi' : missedForThem,
    CallOutcome.missed => mine ? 'Cavab verilmədi' : missedForThem,
  };
}

/// "0:45", "2:14", "1:05:30".
String callDuration(int seconds) {
  if (seconds < 0) seconds = 0;

  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final rest = seconds % 60;

  final two = rest.toString().padLeft(2, '0');

  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:$two';
  }
  return '$minutes:$two';
}

/// Qeydi söhbətə yazır.
///
/// Səhv olsa udulur: zəng bitib, istifadəçi üçün qeyd ikinci
/// dərəcəlidir və xəta pəncərəsi burada mənasızdır.
Future<void> writeCallLog({
  required String callId,
  required String callerUid,
  required String callerName,
  required String calleeUid,
  required String calleeName,
  required bool video,
  required CallOutcome outcome,
  required int seconds,
  FirebaseFirestore? database,
}) async {
  if (callerUid.isEmpty || calleeUid.isEmpty) return;

  final db = database ?? FirebaseFirestore.instance;
  final chat = db.collection('chats').doc(chatIdFor(callerUid, calleeUid));

  final preview = callLogText(
    video: video,
    outcome: outcome,
    seconds: seconds,
    mine: false,
  );

  try {
    final batch = db.batch();

    batch.set(chat, {
      'members': [callerUid, calleeUid],
      'memberNames': {callerUid: callerName, calleeUid: calleeName},
      // Cavabsız zəng oxunmamış sayılır — qarşı tərəf görməlidir.
      if (outcome != CallOutcome.answered)
        'unread': {calleeUid: FieldValue.increment(1)},
      'lastMessage': (video ? '📹 ' : '📞 ') + preview,
      'lastSenderId': callerUid,
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));

    // Sənədin adı zəngin nömrəsidir — təkrar yazı bir qeyd qalır.
    batch.set(chat.collection('messages').doc(callId), {
      'senderId': callerUid,
      'text': '',
      'type': 'call',
      'callVideo': video,
      'callOutcome': outcome.name,
      'callSeconds': seconds,
      'createdAt': Timestamp.now(),
      'clientCreatedAt': DateTime.now().millisecondsSinceEpoch,
    });

    await batch.commit();
  } catch (_) {
    // Qeyd yazılmasa da zəng bitib — istifadəçiyə xəta göstərmirik.
  }
}
