import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'gifts.dart';
import 'push_send.dart';
import 'ui/vibe_design.dart';

/// ORTAQ HƏDİYYƏ PANELİ.
///
/// Otaqdan kənarda — anlarda, profildə, söhbətdə — hədiyyə göndərmək üçün.
/// Sikkə tutulması və sayğacların yenilənməsi bir tranzaksiyada gedir ki,
/// yarımçıq vəziyyət qalmasın.
Future<bool> showGiftSheet(
  BuildContext context, {
  required String fromUid,
  required String fromName,
  required String toUid,
  required String toName,

  /// Hədiyyə bir paylaşıma göndərilirsə, onun sənədi.
  DocumentReference<Map<String, dynamic>>? target,
  FirebaseFirestore? database,
}) async {
  if (fromUid == toUid) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Özünə hədiyyə göndərə bilməzsən.')),
    );
    return false;
  }

  final sent = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheet) => _GiftSheet(
      fromUid: fromUid,
      fromName: fromName,
      toUid: toUid,
      toName: toName,
      target: target,
      database: database,
    ),
  );

  return sent ?? false;
}

class _GiftSheet extends StatefulWidget {
  const _GiftSheet({
    required this.fromUid,
    required this.fromName,
    required this.toUid,
    required this.toName,
    this.target,
    this.database,
  });

  final String fromUid;
  final String fromName;
  final String toUid;
  final String toName;
  final DocumentReference<Map<String, dynamic>>? target;
  final FirebaseFirestore? database;

  @override
  State<_GiftSheet> createState() => _GiftSheetState();
}

class _GiftSheetState extends State<_GiftSheet> {
  VibeGift? selected;
  bool sending = false;

  FirebaseFirestore get db => widget.database ?? FirebaseFirestore.instance;

  Future<void> _send() async {
    final gift = selected;
    if (gift == null || sending) return;

    setState(() => sending = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await db.runTransaction((tx) async {
        final meRef = db.collection('users').doc(widget.fromUid);
        final youRef = db.collection('users').doc(widget.toUid);

        final meSnap = await tx.get(meRef);
        final meData = meSnap.data() ?? {};
        final coins = int.tryParse('${meData['coins'] ?? 0}') ?? 0;

        if (coins < gift.price) throw StateError('coins');

        final sentTotal =
            (int.tryParse('${meData['giftSent'] ?? 0}') ?? 0) + gift.price;

        tx.set(meRef, {
          'coins': coins - gift.price,
          'giftSent': sentTotal,
          'level': 1 + (sentTotal ~/ 500),
        }, SetOptions(merge: true));

        final youSnap = await tx.get(youRef);
        final youData = youSnap.data() ?? {};
        final received =
            (int.tryParse('${youData['giftReceived'] ?? 0}') ?? 0) + gift.price;

        tx.set(youRef, {
          'giftReceived': received,
          'level': 1 + (received ~/ 500),
        }, SetOptions(merge: true));

        // Paylaşıma göndərilibsə, orada da görünsün.
        final target = widget.target;
        if (target != null) {
          tx.set(target, {
            'giftTotal': FieldValue.increment(gift.price),
            'giftCount': FieldValue.increment(1),
          }, SetOptions(merge: true));
        }
      });

      // Bildiriş — tranzaksiyadan kənarda, çünki uğursuzluğu kritik deyil.
      try {
        await db
            .collection('users')
            .doc(widget.toUid)
            .collection('notifications')
            .add({
          'type': 'gift',
          'title': '${widget.fromName} sənə hədiyyə göndərdi',
          'body': '${gift.emoji} ${gift.title} · ${gift.price} coin',
          'fromUid': widget.fromUid,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}

      unawaited(sendPushToUser(
        toUid: widget.toUid,
        title: widget.fromName,
        body: '${gift.emoji} ${gift.title} hədiyyə etdi',
        type: 'gift',
        fromName: widget.fromName,
      ));

      if (mounted) Navigator.pop(context, true);
      messenger.showSnackBar(
        SnackBar(content: Text('${gift.emoji} ${gift.title} göndərildi')),
      );
    } on StateError {
      setState(() => sending = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Balansın çatmır. ${gift.price} coin lazımdır.'),
        ),
      );
    } catch (_) {
      setState(() => sending = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Hədiyyə göndərilmədi. Yenidən sına.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final gifts = giftsFor(DateTime.now());
    final season = activeSeasonName(DateTime.now());

    return Container(
      decoration: const BoxDecoration(
        color: vPanel,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        border: Border(top: BorderSide(color: vLine)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: vLine,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${widget.toName}-ə hədiyyə',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: vInk,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (season != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: vGold.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: vGold.withValues(alpha: .5)),
                    ),
                    child: Text(
                      season,
                      style: const TextStyle(
                        color: vGold,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: GridView.builder(
                shrinkWrap: true,
                itemCount: gifts.length,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: .84,
                ),
                itemBuilder: (context, i) {
                  final gift = gifts[i];
                  final isSelected = selected == gift;

                  return GestureDetector(
                    onTap: () => setState(() => selected = gift),
                    child: Container(
                      decoration: BoxDecoration(
                        color: vBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? vPink : vLine,
                          width: isSelected ? 1.6 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(gift.emoji,
                              style: const TextStyle(fontSize: 26)),
                          const SizedBox(height: 3),
                          Text(
                            gift.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: vInk,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${gift.price}',
                            style: const TextStyle(
                              color: vGold,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            GradientButton(
              label: sending
                  ? 'Göndərilir…'
                  : (selected == null
                      ? 'Hədiyyə seç'
                      : 'Göndər · ${selected!.price} coin'),
              icon: Icons.card_giftcard_rounded,
              gradient: vHot,
              height: 50,
              onPressed: selected == null || sending ? null : _send,
            ),
          ],
        ),
      ),
    );
  }
}
