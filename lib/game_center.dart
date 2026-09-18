import 'dart:math';
import 'package:flutter/material.dart';
import 'user_profile.dart';

const _bg = Color(0xff070510);
const _panel = Color(0xff151020);
const _pink = Color(0xffff2bd6);
const _purple = Color(0xff8b5cff);
const _blue = Color(0xff22a7ff);
const _muted = Color(0xffa89fbd);

class VibeGameCenterPage extends StatefulWidget {
  const VibeGameCenterPage({super.key, required this.profile});
  final UserProfile profile;

  @override
  State<VibeGameCenterPage> createState() => _VibeGameCenterPageState();
}

class _VibeGameCenterPageState extends State<VibeGameCenterPage> {
  final random = Random();
  String result = 'Bir oyun seç ✨';

  void _dice() => setState(() => result = '🎲 Zər: ${random.nextInt(6) + 1}');
  void _coin() => setState(() => result = random.nextBool() ? '🪙 Yazı' : '🪙 Tura');
  void _rps() {
    const values = ['✊ Daş', '✋ Kağız', '✌️ Qayçı'];
    setState(() => result = values[random.nextInt(values.length)]);
  }

  void _truth() {
    const q = [
      '🔥 Həqiqət: ən böyük arzun nədir?',
      '🔥 Həqiqət: son dəfə kimə mesaj yazmısan?',
      '😈 Cəsarət: 10 saniyə mahnı oxu',
      '😈 Cəsarət: bir nəfərə kompliment et',
      '🔥 Həqiqət: ən utandığın an nə olub?',
    ];
    setState(() => result = q[random.nextInt(q.length)]);
  }

  void _would() {
    const q = [
      '🤔 Gələcəyi görmək VS keçmişə qayıtmaq',
      '🤔 Pul VS sevgi',
      '🤔 Dənizdə yaşamaq VS kosmosda yaşamaq',
      '🤔 Bir ay telefonsuz VS bir ay internetsiz',
    ];
    setState(() => result = q[random.nextInt(q.length)]);
  }

  void _spin() {
    const q = [
      '🎡 Mahnı oxu',
      '🎡 Birini seç və sual ver',
      '🎡 Gülməli səs çıxart',
      '🎡 Profilindən bir fakt danış',
      '🎡 Bir emoji ilə əhvalını göstər',
    ];
    setState(() => result = q[random.nextInt(q.length)]);
  }

  void _emoji() {
    const q = [
      '😎 Tap: 🌞🕶️🏖️',
      '😎 Tap: ✈️🌍📸',
      '😎 Tap: 🎤🎶🔥',
      '😎 Tap: 🍕❤️',
    ];
    setState(() => result = q[random.nextInt(q.length)]);
  }

  void _word() {
    const letters = ['A', 'B', 'M', 'S', 'T', 'K'];
    setState(() => result = '🔤 "${letters[random.nextInt(letters.length)]}" hərfi ilə söz de');
  }

  @override
  Widget build(BuildContext context) {
    final games = <_GameItem>[
      _GameItem('🎲', 'Zər', _dice),
      _GameItem('🪙', 'Yazı-Tura', _coin),
      _GameItem('✊', 'Daş-Kağız-Qayçı', _rps),
      _GameItem('🔥', 'Truth / Dare', _truth),
      _GameItem('🤔', 'Would You Rather', _would),
      _GameItem('🎡', 'Spin Wheel', _spin),
      _GameItem('😎', 'Emoji Guess', _emoji),
      _GameItem('🔤', 'Söz zənciri', _word),
    ];

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: const Color(0xff0b0711),
        title: const Text(
          'VIBE Game Center',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xff26113c), Color(0xff45154c), Color(0xff182e56)],
              ),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: const Color(0xff65407c)),
            ),
            child: Column(
              children: [
                const Icon(Icons.sports_esports_rounded, color: _pink, size: 42),
                const SizedBox(height: 10),
                Text(
                  result,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: games.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemBuilder: (_, i) {
              final g = games[i];
              return InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: g.onTap,
                child: Container(
                  decoration: BoxDecoration(
                    color: _panel,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xff38264b)),
                    boxShadow: const [
                      BoxShadow(color: Color(0x221d0d30), blurRadius: 16),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(g.emoji, style: const TextStyle(fontSize: 36)),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          g.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _GameItem {
  const _GameItem(this.emoji, this.title, this.onTap);
  final String emoji;
  final String title;
  final VoidCallback onTap;
}
