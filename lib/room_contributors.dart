/// Otağın töhfə sıralaması.
///
/// Hədiyyə bu tətbiqlərin mühərrikidir, amma hədiyyə verən adam
/// bizdə heç yerdə görünmürdü: pul gedirdi, ad qalmırdı. SUGO-da
/// "Katkı Sıralaması" məhz bunun üçündür — adam öz adını siyahının
/// başında görmək üçün verir.
///
/// Sayğaclar hədiyyə göndərilən anda, eyni əməliyyat içində yazılır.
/// Sonradan bütün hədiyyələri toplamaq olardı, amma otaq bir ildə
/// on minlərlə sənəd yığır — hər açılışda onları oxumaq həm yavaş,
/// həm bahadır.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'ui/vibe_chrome.dart';
import 'ui/vibe_design.dart';

/// Günün açarı: `d_2026-09-21`.
String dayKey(DateTime time) {
  final month = time.month.toString().padLeft(2, '0');
  final day = time.day.toString().padLeft(2, '0');
  return 'd_${time.year}-$month-$day';
}

/// Həftənin açarı: `w_2026-38`.
///
/// Həftə bazar ertəsindən başlayır. Sadə "ilin neçənci günü / 7"
/// bölgüsü il sərhədində sıçrayır, ona görə ISO qaydası ilə
/// hesablanır.
String weekKey(DateTime time) {
  final date = DateTime(time.year, time.month, time.day);

  // Həmin həftənin cümə axşamı — ISO həftəsi ona görə təyin olunur.
  final thursday = date.add(Duration(days: 4 - (date.weekday)));
  final firstDay = DateTime(thursday.year, 1, 1);

  final week = ((thursday.difference(firstDay).inDays) / 7).floor() + 1;
  return 'w_${thursday.year}-${week.toString().padLeft(2, '0')}';
}

/// Hədiyyə yazılanda sayğaclara əlavə olunan sahələr.
///
/// `FieldValue.increment` üç sahəni birdən artırır: ümumi, günlük və
/// həftəlik. Ayrı-ayrı yazsaydıq, üç əməliyyat olardı.
Map<String, Object> contributorUpdate({
  required String name,
  required String photo,
  required int amount,
  DateTime? now,
}) {
  final time = now ?? DateTime.now();

  return {
    'name': name,
    if (photo.isNotEmpty) 'photo': photo,
    'total': FieldValue.increment(amount),
    dayKey(time): FieldValue.increment(amount),
    weekKey(time): FieldValue.increment(amount),
    'updatedAt': Timestamp.fromDate(time),
  };
}

/// Sıralama dövrü.
enum GiftPeriod { day, week, all }

extension GiftPeriodInfo on GiftPeriod {
  String get label => switch (this) {
        GiftPeriod.day => 'Bu gün',
        GiftPeriod.week => 'Bu həftə',
        GiftPeriod.all => 'Hamısı',
      };

  /// Hansı sahəyə görə sıralanır.
  String fieldFor(DateTime now) => switch (this) {
        GiftPeriod.day => dayKey(now),
        GiftPeriod.week => weekKey(now),
        GiftPeriod.all => 'total',
      };
}

class Contributor {
  const Contributor({
    required this.uid,
    required this.name,
    required this.photo,
    required this.amount,
  });

  final String uid;
  final String name;
  final String photo;
  final int amount;
}

/// Sənədləri seçilmiş dövrə görə sıralayır.
///
/// Sıralama cihazda aparılır: Firestore-da dəyişən adlı sahəyə görə
/// sıralamaq hər gün üçün ayrıca indeks tələb edərdi.
List<Contributor> rankContributors(
  Iterable<({String id, Map<String, dynamic> data})> docs,
  GiftPeriod period, {
  DateTime? now,
}) {
  final field = period.fieldFor(now ?? DateTime.now());

  final out = <Contributor>[];

  for (final doc in docs) {
    final amount = int.tryParse('${doc.data[field] ?? 0}') ?? 0;
    if (amount <= 0) continue;

    out.add(Contributor(
      uid: doc.id,
      name: '${doc.data['name'] ?? ''}',
      photo: '${doc.data['photo'] ?? ''}',
      amount: amount,
    ));
  }

  out.sort((a, b) => b.amount.compareTo(a.amount));
  return out;
}

// ============================================================
// EKRAN
// ============================================================

void showRoomContributors(BuildContext context, String roomId) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xff120d1d),
    showDragHandle: true,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .8,
    ),
    builder: (_) => RoomContributorsSheet(roomId: roomId),
  );
}

class RoomContributorsSheet extends StatefulWidget {
  const RoomContributorsSheet({
    super.key,
    required this.roomId,
    this.database,
  });

  final String roomId;
  final FirebaseFirestore? database;

  @override
  State<RoomContributorsSheet> createState() => _RoomContributorsSheetState();
}

class _RoomContributorsSheetState extends State<RoomContributorsSheet> {
  GiftPeriod period = GiftPeriod.day;

  FirebaseFirestore get db => widget.database ?? FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Töhfə sıralaması',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Otağa ən çox dəstək verənlər.',
                style: TextStyle(color: vMuted, fontSize: 12.5),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final value in GiftPeriod.values) ...[
                  Expanded(
                    child: PressableScale(
                      onTap: () => setState(() => period = value),
                      child: Container(
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: period == value
                              ? vPink.withValues(alpha: .22)
                              : Colors.white.withValues(alpha: .05),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: period == value ? vPink : Colors.white12,
                          ),
                        ),
                        child: Text(
                          value.label,
                          style: TextStyle(
                            color: period == value ? Colors.white : vMuted,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (value != GiftPeriod.values.last)
                    const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          Flexible(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              // Otaqlar `partyRooms` kolleksiyasındadır. `rooms`
              // yazılsaydı siyahı həmişə boş qalardı.
              stream: db
                  .collection('partyRooms')
                  .doc(widget.roomId)
                  .collection('contributors')
                  .orderBy('total', descending: true)
                  .limit(100)
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(30),
                    child: CircularProgressIndicator(color: vPink),
                  );
                }

                final ranked = rankContributors(
                  snap.data!.docs.map((d) => (id: d.id, data: d.data())),
                  period,
                );

                if (ranked.isEmpty) return _empty();

                return ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  children: [
                    _podium(ranked),
                    const SizedBox(height: 14),
                    for (var i = 3; i < ranked.length; i++)
                      _row(i + 1, ranked[i]),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty() => const Padding(
        padding: EdgeInsets.fromLTRB(24, 20, 24, 40),
        child: Column(
          children: [
            Icon(Icons.emoji_events_rounded, size: 44, color: vGold),
            SizedBox(height: 12),
            Text(
              'Bu dövrdə hələ hədiyyə yoxdur',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'İlk dəstəyi sən ver — adın birinci yazılsın.',
              textAlign: TextAlign.center,
              style: TextStyle(color: vMuted, fontSize: 12.5, height: 1.4),
            ),
          ],
        ),
      );

  /// İlk üç — ortada birinci, yanlarda ikinci və üçüncü.
  Widget _podium(List<Contributor> ranked) {
    Contributor? at(int index) =>
        index < ranked.length ? ranked[index] : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: _step(at(1), 2, 54, const Color(0xffbfd4e8))),
        const SizedBox(width: 8),
        Expanded(child: _step(at(0), 1, 68, vGold)),
        const SizedBox(width: 8),
        Expanded(child: _step(at(2), 3, 48, const Color(0xffd9a06b))),
      ],
    );
  }

  Widget _step(Contributor? who, int place, double size, Color color) {
    if (who == null) {
      return Column(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .05),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white12),
            ),
            child: const Icon(Icons.person_rounded, color: vMuted),
          ),
          const SizedBox(height: 7),
          const Text(
            'Boşdur',
            style: TextStyle(color: vMuted, fontSize: 11.5),
          ),
        ],
      );
    }

    return Column(
      children: [
        Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: .35), blurRadius: 14),
                ],
              ),
              child: ClipOval(
                child: VibePhoto(url: who.photo, name: who.name),
              ),
            ),
            Positioned(
              top: -9,
              child: Text(
                place == 1 ? '👑' : (place == 2 ? '🥈' : '🥉'),
                style: const TextStyle(fontSize: 17),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          who.name.isEmpty ? 'İstifadəçi' : who.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          '${who.amount}',
          style: TextStyle(
            color: color,
            fontSize: 12.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _row(int place, Contributor who) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              child: Text(
                '$place',
                style: const TextStyle(
                  color: vMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            SizedBox(
              width: 36,
              height: 36,
              child: ClipOval(child: VibePhoto(url: who.photo, name: who.name)),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                who.name.isEmpty ? 'İstifadəçi' : who.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '${who.amount}',
              style: const TextStyle(
                color: vGold,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
}
