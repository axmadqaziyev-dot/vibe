// VIBE COIN — virtual balans.
//
// users/{uid}.coins            → balans
// users/{uid}/wallet/{autoId}  → hərəkət tarixçəsi
//
// Qeyd: bunlar yalnız tətbiqdaxili virtual coinlərdir. Real pulla alış
// və ya real pul ödənişi YOXDUR — əlavə etməzdən əvvəl yerli qanunvericiliyi
// və App Store / Google Play qaydalarını yoxlamaq lazımdır.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'ui/vibe_design.dart';
import 'ui/vibe_chrome.dart';

class InsufficientCoins implements Exception {
  const InsufficientCoins(this.balance, this.needed);

  final int balance;
  final int needed;
}

FirebaseFirestore get _db => FirebaseFirestore.instance;

DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
    _db.collection('users').doc(uid);

/// Balansı canlı izləyir.
Stream<int> watchCoins(String uid, {FirebaseFirestore? database}) =>
    (database ?? _db)
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snap) => (snap.data()?['coins'] as num?)?.toInt() ?? 0);

/// Balansı bir dəfə oxuyur.
Future<int> readCoins(String uid) async {
  final snap = await _userRef(uid).get();
  return (snap.data()?['coins'] as num?)?.toInt() ?? 0;
}

/// Balansı dəyişir. Mənfi `delta` xərcdir və balans çatmasa atılır.
///
/// Tranzaksiya ilə işləyir — eyni anda iki oyun oynasan da balans pozulmur.
Future<int> changeCoins({
  required String uid,
  required int delta,
  required String reason,
  FirebaseFirestore? database,
}) async {
  final db = database ?? _db;
  final ref = db.collection('users').doc(uid);

  // Diqqət: tranzaksiyanın İÇİNDƏN xüsusi istisna atmaq olmaz —
  // Firestore onu öz xətasına sarıyır və `on InsufficientCoins` tutmur.
  // Ona görə vəziyyəti bayraqla çıxarıb kənarda atırıq.
  var shortfall = -1;

  final newBalance = await db.runTransaction<int>((tx) async {
    final snap = await tx.get(ref);
    final current = (snap.data()?['coins'] as num?)?.toInt() ?? 0;

    if (delta < 0 && current + delta < 0) {
      shortfall = current;
      return current; // yazmadan çıxırıq
    }

    shortfall = -1;
    final next = current + delta;
    tx.set(ref, {'coins': next}, SetOptions(merge: true));
    return next;
  });

  if (shortfall >= 0) {
    throw InsufficientCoins(shortfall, -delta);
  }

  // Tarixçə — uğursuz olsa balans yenə düzgündür.
  try {
    await ref.collection('wallet').add({
      'amount': delta,
      'reason': reason,
      'balance': newBalance,
      'at': FieldValue.serverTimestamp(),
    });
  } catch (_) {}

  return newBalance;
}

/// Hesabda `coins` sahəsi hələ yoxdursa, bir dəfəlik başlanğıc balansı verir.
/// Köhnə hesablar da bundan faydalanır.
Future<void> ensureWelcomeBonus(String uid, {int amount = 100}) async {
  final ref = _userRef(uid);
  try {
    final snap = await ref.get();
    if (!snap.exists) return;
    if (snap.data()?.containsKey('coins') == true) return;

    await ref.set({'coins': amount}, SetOptions(merge: true));
    await ref.collection('wallet').add({
      'amount': amount,
      'reason': 'Xoş gəldin bonusu',
      'balance': amount,
      'at': FieldValue.serverTimestamp(),
    });
  } catch (_) {}
}

/// Kiçik balans nişanı — oyun və otaq ekranlarında.
class CoinBadge extends StatelessWidget {
  const CoinBadge({super.key, required this.uid, this.onTap, this.database});

  final String uid;
  final VoidCallback? onTap;
  final FirebaseFirestore? database;

  @override
  Widget build(BuildContext context) => StreamBuilder<int>(
    stream: watchCoins(uid, database: database),
    builder: (context, snapshot) => PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          gradient: vSunset,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: vGold.withValues(alpha: .35), blurRadius: 14),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.monetization_on_rounded,
                size: 16, color: Color(0xff4c2600)),
            const SizedBox(width: 6),
            Text(
              compactCount(snapshot.data ?? 0),
              style: const TextStyle(
                color: Color(0xff4c2600),
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Coin hərəkətlərinin tarixçəsi.
class CoinHistoryPage extends StatelessWidget {
  const CoinHistoryPage({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: vBg,
    appBar: AppBar(
      backgroundColor: const Color(0xff0b0711),
      foregroundColor: Colors.white,
      title: const Text(
        'Coin tarixçəsi',
        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
      ),
    ),
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _userRef(uid)
          .collection('wallet')
          .orderBy('at', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: vPink));
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(
            child: Text('Hələ hərəkət yoxdur.', style: TextStyle(color: vMuted)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final d = docs[index].data();
            final amount = (d['amount'] as num?)?.toInt() ?? 0;
            final plus = amount >= 0;
            final at = d['at'];

            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (plus ? vMint : vRose).withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  plus ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                  color: plus ? vMint : vRose,
                  size: 19,
                ),
              ),
              title: Text(
                '${d['reason'] ?? 'Hərəkət'}',
                style: const TextStyle(color: Colors.white, fontSize: 14.5),
              ),
              subtitle: Text(
                at is Timestamp
                    ? '${at.toDate().day}.${at.toDate().month} '
                          '${at.toDate().hour.toString().padLeft(2, '0')}:'
                          '${at.toDate().minute.toString().padLeft(2, '0')}'
                    : '',
                style: const TextStyle(color: vMuted, fontSize: 11.5),
              ),
              trailing: Text(
                '${plus ? '+' : ''}$amount',
                style: TextStyle(
                  color: plus ? vMint : vRose,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            );
          },
        );
      },
    ),
  );
}
