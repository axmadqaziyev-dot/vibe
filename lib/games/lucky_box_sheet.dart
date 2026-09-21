/// Şanslı qutu — otaqdakı ekranı.
///
/// Sikkə hesabı serverdə deyil, sənəddə aparılır (bütün tətbiqdə
/// belədir). Ona görə mərc və uduş **bir əməliyyatda** yazılır:
/// yarıda kəsilsə, ya hər ikisi olur, ya heç biri. Əks halda mərc
/// gedib uduş gəlməyə bilərdi.
library;

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ui/vibe_design.dart';
import '../user_profile.dart';
import 'lucky_box.dart';
import '../app/i18n.dart';

void showLuckyBox(
  BuildContext context, {
  required UserProfile profile,
  String? roomId,
  FirebaseFirestore? database,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xff120d1d),
    showDragHandle: true,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .85,
    ),
    builder: (_) => _LuckyBoxSheet(
      profile: profile,
      roomId: roomId,
      database: database,
    ),
  );
}

class _LuckyBoxSheet extends StatefulWidget {
  const _LuckyBoxSheet({
    required this.profile,
    this.roomId,
    this.database,
  });

  final UserProfile profile;
  final String? roomId;
  final FirebaseFirestore? database;

  @override
  State<_LuckyBoxSheet> createState() => _LuckyBoxSheetState();
}

class _LuckyBoxSheetState extends State<_LuckyBoxSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  final random = Random();

  int bet = boxBets.first;
  bool busy = false;
  BoxPrize? result;
  int won = 0;

  FirebaseFirestore get db => widget.database ?? FirebaseFirestore.instance;

  @override
  void dispose() {
    shake.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    if (busy) return;

    setState(() {
      busy = true;
      result = null;
    });

    HapticFeedback.mediumImpact();
    await shake.forward(from: 0);

    final prize = openBox(random: random);
    final payout = boxPayout(bet, prize);

    try {
      final me = db.collection('users').doc(widget.profile.uid);

      // Bir əməliyyat: balans yoxlanılır, mərc çıxılır, uduş yazılır.
      await db.runTransaction((tx) async {
        final snap = await tx.get(me);
        final coins = int.tryParse('${snap.data()?['coins'] ?? 0}') ?? 0;

        if (coins < bet) throw StateError('az');

        tx.set(me, {
          'coins': coins - bet + payout,
        }, SetOptions(merge: true));
      });

      if (!mounted) return;

      setState(() {
        result = prize;
        won = payout;
        busy = false;
      });

      if (payout > bet) HapticFeedback.heavyImpact();

      // Böyük uduş otağa elan olunur — oyun bununla canlanır.
      final roomId = widget.roomId;
      if (roomId != null && payout >= bet * 5) {
        await db
            .collection('partyRooms')
            .doc(roomId)
            .collection('messages')
            .add({
          'uid': 'system',
          'name': 'VIBE',
          'text': '${prize.emoji} ${widget.profile.name} şanslı qutudan '
              '$payout sikkə uddu!',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } on StateError {
      if (!mounted) return;
      setState(() => busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('Sikkən çatmır.'))),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('Alınmadı. Yenidən sına.'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
        children: [
          const Text(
            'Şanslı qutu',
            style: TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Orta qaytarma: ${(boxReturnRate * 100).toStringAsFixed(0)}%. '
            'Şanslar aşağıda açıq yazılıb.',
            style: const TextStyle(color: vMuted, fontSize: 12),
          ),
          const SizedBox(height: 18),

          _box(),
          const SizedBox(height: 16),

          // Mərc seçimi.
          Wrap(
            spacing: 8,
            children: [
              for (final value in boxBets)
                ChoiceChip(
                  label: Text('$value'),
                  selected: bet == value,
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    color: bet == value ? Colors.white : vMuted,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                  selectedColor: vPink.withValues(alpha: .3),
                  backgroundColor: const Color(0xff1b1528),
                  side: BorderSide(
                    color: bet == value ? vPink : Colors.white12,
                  ),
                  onSelected: busy ? null : (_) => setState(() => bet = value),
                ),
            ],
          ),
          const SizedBox(height: 16),

          GradientButton(
            label: busy ? 'Açılır…' : 'Aç — $bet sikkə',
            icon: Icons.card_giftcard_rounded,
            gradient: vHot,
            height: 52,
            onPressed: busy ? null : _open,
          ),

          const SizedBox(height: 20),
          const Text(
            'Şanslar',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          for (final prize in boxPrizes) _chanceRow(prize),
        ],
      ),
    );
  }

  Widget _box() => AnimatedBuilder(
        animation: shake,
        builder: (context, child) {
          // Açılışdan əvvəl qutu yırğalanır.
          final angle = busy
              ? sin(shake.value * pi * 8) * .12 * (1 - shake.value)
              : 0.0;

          return Transform.rotate(angle: angle, child: child);
        },
        child: Container(
          height: 150,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xff2a1a52), Color(0xff6b2f9e)],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: vPink.withValues(alpha: .4)),
          ),
          child: result == null
              ? const Text('🎁', style: TextStyle(fontSize: 62))
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      result!.emoji,
                      style: const TextStyle(fontSize: 46),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      won > 0 ? '+$won sikkə' : 'Bu dəfə boş',
                      style: TextStyle(
                        color: won > 0 ? vGold : Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
        ),
      );

  Widget _chanceRow(BoxPrize prize) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(
          children: [
            Text(prize.emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                prize.label,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
            Text(
              '${boxChance(prize).toStringAsFixed(1)}%',
              style: const TextStyle(
                color: vMuted,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
}
