// VIBE OYUN MƏRKƏZİ.
//
// İki hissə var:
//  1) Coin oyunları — mərc VIBE coin ilə, nəticə Firestore tranzaksiyası ilə
//     balansa yazılır (saxta rəqəm yoxdur, balans real dəyişir).
//  2) Sosial oyunlar — Doğruluq/Cəsarət kimi, coin tələb etmir.
//
// Coinlər yalnız tətbiqdaxili virtual vahiddir; real pul mərci deyil.

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'coin_wallet.dart';
import 'user_profile.dart';
import 'ui/vibe_design.dart';
import 'ui/vibe_chrome.dart';

const _bg = Color(0xff070510);
const _panel = Color(0xff151020);
const _pink = Color(0xffff2bd6);

class VibeGameCenterPage extends StatefulWidget {
  const VibeGameCenterPage({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<VibeGameCenterPage> createState() => _VibeGameCenterPageState();
}

class _VibeGameCenterPageState extends State<VibeGameCenterPage> {
  static const tabs = ['Coin oyunları', 'Sosial oyunlar'];

  int tab = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _bg,
    body: AuroraBackground(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 16, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  ),
                  const Expanded(
                    child: Text(
                      'Oyun mərkəzi',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  CoinBadge(
                    uid: widget.profile.uid,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CoinHistoryPage(uid: widget.profile.uid),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            UnderlineTabs(
              labels: tabs,
              index: tab,
              onChanged: (i) => setState(() => tab = i),
            ),
            Expanded(
              child: tab == 0
                  ? _CoinGames(profile: widget.profile)
                  : const _SocialGames(),
            ),
          ],
        ),
      ),
    ),
  );
}

// ============================================================
// COIN OYUNLARI
// ============================================================

class _CoinGames extends StatefulWidget {
  const _CoinGames({required this.profile});

  final UserProfile profile;

  @override
  State<_CoinGames> createState() => _CoinGamesState();
}

class _CoinGamesState extends State<_CoinGames> {
  static const bets = [10, 50, 100, 250];

  final random = Random.secure();

  int bet = 10;
  bool busy = false;
  String log = '';

  /// Mərci tutur, oyunu işlədir, uduşu qaytarır.
  ///
  /// `play` uduş əmsalını qaytarır: 0 = uduzdun, 2 = mərcin 2 qatı.
  Future<void> _play({
    required String name,
    required double Function() play,
    required String Function(double multiplier, int win) describe,
  }) async {
    if (busy) return;
    setState(() => busy = true);

    try {
      // 1) Mərc tutulur.
      await changeCoins(
        uid: widget.profile.uid,
        delta: -bet,
        reason: '$name · mərc',
      );

      // 2) Nəticə.
      final multiplier = play();
      final win = (bet * multiplier).round();

      // 3) Uduş varsa qaytarılır.
      if (win > 0) {
        await changeCoins(
          uid: widget.profile.uid,
          delta: win,
          reason: '$name · uduş',
        );

        // "Oyunçu" medalı üçün sayğac.
        if (win > bet) {
          try {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(widget.profile.uid)
                .set({'gameWins': FieldValue.increment(1)},
                    SetOptions(merge: true));
          } catch (_) {}
        }
      }

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      final text = describe(multiplier, win);
      setState(() => log = text);
      _announce(text, win > 0);
    } on InsufficientCoins catch (e) {
      if (!mounted) return;
      final text = 'Balans çatmır: ${e.balance} coin var, '
          '${e.needed} lazımdır.';
      setState(() => log = text);
      _announce(text, false);
    } catch (_) {
      if (!mounted) return;
      const text = 'Oyun tamamlanmadı. Bağlantını yoxla.';
      setState(() => log = text);
      _announce(text, false);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  /// Nəticəni ekranın altında göstərir.
  ///
  /// Nəticə mətni siyahının yuxarısındadır; istifadəçi aşağıdakı oyuna
  /// basanda onu görmür. Ona görə nəticə həm də bildiriş kimi çıxır.
  void _announce(String text, bool won) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          text,
          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
        ),
        backgroundColor: won ? const Color(0xff10502f) : const Color(0xff3a1730),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ---- oyunlar ----

  /// Çarx: ev üstünlüyü ~8%. Ehtimallar cəmi 100.
  double _wheel() {
    final roll = random.nextInt(100);
    if (roll < 40) return 0; // uduzdun
    if (roll < 70) return 1; // mərc geri
    if (roll < 88) return 2;
    if (roll < 97) return 3;
    if (roll < 99) return 5;
    return 10;
  }

  double _dice(int mine, int house) {
    if (mine > house) return 2;
    if (mine == house) return 1;
    return 0;
  }

  double _slot(List<int> reels) {
    if (reels[0] == reels[1] && reels[1] == reels[2]) {
      return reels[0] == 0 ? 12 : 6; // 7-7-7 daha çox verir
    }
    if (reels[0] == reels[1] || reels[1] == reels[2] || reels[0] == reels[2]) {
      return 1.5;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
    children: [
      // ---- mərc seçimi ----
      const Text(
        'Mərc',
        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          for (final value in bets) ...[
            Expanded(
              child: VibeChip(
                label: '$value',
                emoji: '🪙',
                selected: bet == value,
                onTap: busy ? null : () => setState(() => bet = value),
              ),
            ),
            if (value != bets.last) const SizedBox(width: 8),
          ],
        ],
      ),
      const SizedBox(height: 18),

      if (log.isNotEmpty) ...[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _panel.withValues(alpha: .8),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _pink.withValues(alpha: .4)),
          ),
          child: Text(
            log,
            style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.4),
          ),
        ),
        const SizedBox(height: 18),
      ],

      _game(
        emoji: '🎡',
        title: 'Şans çarxı',
        subtitle: 'x0 – x10 arası. Ən böyük uduş burada.',
        colors: const [Color(0xff8b5cff), Color(0xffff2bd6)],
        onTap: () => _play(
          name: 'Şans çarxı',
          play: _wheel,
          describe: (m, win) => m == 0
              ? '🎡 Çarx boş dayandı. -$bet coin.'
              : '🎡 Çarx x${m.toStringAsFixed(m == m.roundToDouble() ? 0 : 1)} '
                    'verdi → +$win coin (xalis ${win - bet}).',
        ),
      ),
      _game(
        emoji: '🎲',
        title: 'Zər düelli',
        subtitle: 'Sənin zərin evin zərindən böyük olsun.',
        colors: const [Color(0xff22a7ff), Color(0xff8b5cff)],
        onTap: () {
          final mine = random.nextInt(6) + 1 + random.nextInt(6) + 1;
          final house = random.nextInt(6) + 1 + random.nextInt(6) + 1;
          _play(
            name: 'Zər düelli',
            play: () => _dice(mine, house),
            describe: (m, win) => '🎲 Sən $mine · Ev $house → '
                '${m == 2 ? 'Uddun! +$win coin' : m == 1 ? 'Bərabər, mərc geri döndü' : 'Uduzdun, -$bet coin'}',
          );
        },
      ),
      _game(
        emoji: '🎰',
        title: 'Slot',
        subtitle: 'Üç eyni simvol → x6, üç yeddi → x12.',
        colors: const [Color(0xffffb347), Color(0xffff5f6d)],
        onTap: () {
          const symbols = ['7️⃣', '🍒', '🔔', '⭐', '🍋'];
          final reels = List.generate(3, (_) => random.nextInt(symbols.length));
          _play(
            name: 'Slot',
            play: () => _slot(reels),
            describe: (m, win) =>
                '🎰 ${reels.map((i) => symbols[i]).join(' ')}  →  '
                '${m == 0 ? 'uduş yoxdur, -$bet coin' : '+$win coin'}',
          );
        },
      ),
      _game(
        emoji: '🪙',
        title: 'Tək / Cüt',
        subtitle: 'Sadə və sürətli: x2.',
        colors: const [Color(0xff48e08a), Color(0xff22a7ff)],
        onTap: () {
          final even = random.nextBool();
          final number = random.nextInt(100);
          _play(
            name: 'Tək/Cüt',
            play: () => (number.isEven == even) ? 2 : 0,
            describe: (m, win) => '🪙 Rəqəm $number (${number.isEven ? 'cüt' : 'tək'}) '
                '→ ${m > 0 ? '+$win coin' : '-$bet coin'}',
          );
        },
      ),

      const SizedBox(height: 22),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .04),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: vMuted, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Oyunlar yalnız tətbiqdaxili VIBE coin ilə oynanılır. '
                'Real pul mərci və ya ödənişi yoxdur.',
                style: TextStyle(color: vMuted, fontSize: 11.5, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _game({
    required String emoji,
    required String title,
    required String subtitle,
    required List<Color> colors,
    required VoidCallback onTap,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: PressableScale(
      onTap: busy ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _panel.withValues(alpha: .75),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.last.withValues(alpha: .45)),
          boxShadow: [
            BoxShadow(color: colors.last.withValues(alpha: .18), blurRadius: 18),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: colors),
                borderRadius: BorderRadius.circular(17),
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(color: vMuted, fontSize: 12, height: 1.35),
                  ),
                ],
              ),
            ),
            if (busy)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: _pink),
              )
            else
              Text(
                '-$bet',
                style: const TextStyle(
                  color: vGold,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

// ============================================================
// SOSİAL OYUNLAR (coinsiz)
// ============================================================

class _SocialGames extends StatefulWidget {
  const _SocialGames();

  @override
  State<_SocialGames> createState() => _SocialGamesState();
}

class _SocialGamesState extends State<_SocialGames> {
  final random = Random();
  String result = 'Bir oyun seç ✨';

  void _pick(List<String> pool) =>
      setState(() => result = pool[random.nextInt(pool.length)]);

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
    children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xff2b0f52), Color(0xff9c1d80)]),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(
          result,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            height: 1.4,
          ),
        ),
      ),
      const SizedBox(height: 18),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _tile('🎲 Zər', () => _pick(['🎲 Zər: ${random.nextInt(6) + 1}'])),
          _tile('🪙 Yazı-tura',
              () => _pick(['🪙 Yazı', '🪙 Tura'])),
          _tile('✊ Daş-kağız', () => _pick(['✊ Daş', '✋ Kağız', '✌️ Qayçı'])),
          _tile('🔥 Doğruluq', () => _pick(const [
                '🔥 Ən böyük arzun nədir?',
                '🔥 Son dəfə kimə mesaj yazmısan?',
                '🔥 Ən utandığın an nə olub?',
                '🔥 Gizli istedadın nədir?',
              ])),
          _tile('😈 Cəsarət', () => _pick(const [
                '😈 10 saniyə mahnı oxu',
                '😈 Birinə kompliment et',
                '😈 Son şəklini təsvir et',
                '😈 Yalnız emoji ilə cavab ver',
              ])),
          _tile('🤔 Sən seç', () => _pick(const [
                '🤔 Gələcəyi görmək VS keçmişə qayıtmaq',
                '🤔 Pul VS sevgi',
                '🤔 Bir ay telefonsuz VS bir ay internetsiz',
                '🤔 Dəniz VS dağ',
              ])),
        ],
      ),
    ],
  );

  Widget _tile(String label, VoidCallback onTap) => PressableScale(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: _panel.withValues(alpha: .8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xff33284a)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      ),
    ),
  );
}
