/// Söhbətin bağlanması.
///
/// `chat_filter.dart` qərar verir, bu fayl qərarı yerinə yetirir:
/// söhbət sənədinə kilid yazır, ekranda səbəbini göstərir.
///
/// Kilid **söhbət sənədində** saxlanılır, cihazda yox. Səbəb sadədir:
/// hər iki tərəf eyni şeyi görməlidir. Cihazda saxlansaydı, tətbiqi
/// silib yenidən quraşdırmaqla kilid keçərdi.
///
/// Kilid həmişəlik deyil. Müddət bitəndə söhbət öz-özünə açılır və
/// ölçmə sıfırdan başlayır — çünki pəncərə yalnız son mesajlara baxır.
/// Təkrar olunursa müddət uzanır (`lockDuration`).
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'chat_filter.dart';
import 'legal.dart';
import 'ui/vibe_design.dart';

/// Söhbət sənədindəki kilid.
class ChatLock {
  const ChatLock({required this.until, required this.topic});

  final DateTime until;
  final FilterTopic topic;

  /// Qalan vaxt. Mənfidirsə kilid bitib — `readChatLock` belə kilidi
  /// onsuz da qaytarmır.
  Duration get left => until.difference(DateTime.now());
}

/// Söhbət sənədindən kilidi oxuyur.
///
/// Müddəti bitmiş kilid `null` qaytarır — sənəddə qalsa da artıq
/// qüvvədə deyil.
ChatLock? readChatLock(Map<String, dynamic>? data) {
  if (data == null) return null;

  final raw = data['lockedUntil'];
  if (raw is! Timestamp) return null;

  final until = raw.toDate();
  if (!until.isAfter(DateTime.now())) return null;

  final name = '${data['lockedTopic'] ?? ''}';
  final topic = FilterTopic.values.firstWhere(
    (t) => t.name == name,
    orElse: () => FilterTopic.adult,
  );

  return ChatLock(until: until, topic: topic);
}

/// Neçənci dəfə bağlanır.
int lockCountOf(Map<String, dynamic>? data) =>
    int.tryParse('${data?['lockCount'] ?? 0}') ?? 0;

/// Söhbəti bağlayır.
///
/// `set(merge)` istifadə olunur: ilk mesajda söhbət sənədi hələ
/// yaranmamış ola bilər.
Future<void> applyChatLock(
  DocumentReference<Map<String, dynamic>> chat, {
  required FilterTopic topic,
  required int previousLocks,
  required List<String> members,
}) async {
  final until = DateTime.now().add(lockDuration(previousLocks));

  await chat.set({
    'members': members,
    'lockedUntil': Timestamp.fromDate(until),
    'lockedTopic': topic.name,
    'lockedAt': Timestamp.now(),
    'lockCount': FieldValue.increment(1),
  }, SetOptions(merge: true));
}

// ============================================================
// EKRAN
// ============================================================

/// Söhbət bağlananda mesaj panelinin yerinə çıxır.
class ChatLockBanner extends StatelessWidget {
  const ChatLockBanner({super.key, required this.lock});

  final ChatLock lock;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
        decoration: BoxDecoration(
          color: const Color(0xff2a1220),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xff54233c)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(lock.topic.emoji, style: const TextStyle(fontSize: 19)),
                const SizedBox(width: 9),
                const Expanded(
                  child: Text(
                    'Bu söhbət dayandırılıb',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              '${lock.topic.explanation}\n\n'
              'Söhbət ${remainingText(lock.left)} sonra yenidən açılacaq.',
              style: const TextStyle(
                color: Color(0xffe4c6d4),
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 11),
            Row(
              children: [
                PressableScale(
                  onTap: () => LegalPage.openRules(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: vRose.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Text(
                      'İcma qaydaları',
                      style: TextStyle(
                        color: Color(0xffffc9d3),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                const Expanded(
                  child: Text(
                    'Səhv olduğunu düşünürsənsə dəstəyə yaz.',
                    style: TextStyle(color: vMuted, fontSize: 11.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Hədd yaxınlaşanda göstərilən nazik zolaq.
///
/// Xəbərdarlıq olmadan bağlamaq ədalətsizdir: adam nəyin səhv
/// getdiyini bilmədən söhbətdən məhrum olur.
class ChatWarnStrip extends StatelessWidget {
  const ChatWarnStrip({super.key, required this.topic});

  final FilterTopic topic;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        color: const Color(0xff2a2410),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: vGold, size: 17),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                'Söhbət ${topic.label} mövzusuna yaxınlaşır. '
                'Davam etsə, yazışma dayandırılacaq.',
                style: const TextStyle(
                  color: Color(0xffffe6a8),
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      );
}

/// Tək mesajı mövzuya görə yoxlayır.
///
/// Şəxsi söhbətdə bütün yazışma bağlanır, amma otaqda və açıq
/// paylaşımda bu düzgün deyil: orada onlarla adam var, bir nəfərin
/// yazdığına görə hamını susdurmaq olmaz. Burada yalnız həmin mesaj
/// getmir.
bool guardTopic(BuildContext context, String text) {
  final topic = singleMessageBlock(text);
  if (topic == null) return true;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: const Color(0xff4a1020),
      duration: const Duration(seconds: 4),
      content: Text('${topic.emoji} Bu mesaj göndərilmədi: ${topic.label}. '
          '${topic.explanation}'),
    ),
  );

  return false;
}
