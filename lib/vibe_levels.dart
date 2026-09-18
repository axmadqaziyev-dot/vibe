import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'user_profile.dart';

const _bg = Color(0xff070510);
const _panel = Color(0xff151020);
const _muted = Color(0xffa89fbd);
const _pink = Color(0xffff2bd6);
const _purple = Color(0xff8b5cff);

class VibeLevelsPage extends StatelessWidget {
  const VibeLevelsPage({super.key, required this.profile});
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance.collection('users').doc(profile.uid);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: const Color(0xff0b0711),
        title: const Text(
          'Level & Medallar',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: ref.snapshots(),
        builder: (_, snap) {
          final d = snap.data?.data() ?? {};
          final sent = int.tryParse('${d['giftSent'] ?? 0}') ?? 0;
          final received = int.tryParse('${d['giftReceived'] ?? 0}') ?? 0;
          final score = sent + received;
          final level = 1 + (score ~/ 500);
          final current = score % 500;
          final progress = current / 500.0;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xff2f1744), Color(0xff5a1b5f)],
                  ),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: const Color(0xff704a8f)),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: _purple,
                      child: Text(
                        '$level',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Level $level',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$current / 500 XP',
                      style: const TextStyle(color: _muted),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: LinearProgressIndicator(
                        minHeight: 10,
                        value: progress,
                        backgroundColor: const Color(0xff261a31),
                        valueColor: const AlwaysStoppedAnimation(_pink),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Medallar',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              _medal('🌱', 'Yeni VIBE', level >= 1, 'Level 1'),
              _medal('🔥', 'Aktiv üzv', level >= 5, 'Level 5'),
              _medal('💜', 'Social Star', level >= 10, 'Level 10'),
              _medal('👑', 'VIBE Elite', level >= 20, 'Level 20'),
              _medal('💎', 'Legend', level >= 50, 'Level 50'),
            ],
          );
        },
      ),
    );
  }

  Widget _medal(String emoji, String title, bool unlocked, String requirement) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: unlocked ? _purple : const Color(0xff342743),
        ),
      ),
      child: Row(
        children: [
          Text(
            unlocked ? emoji : '🔒',
            style: const TextStyle(fontSize: 30),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: unlocked ? Colors.white : Colors.white38,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  requirement,
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),
          if (unlocked)
            const Icon(Icons.check_circle_rounded, color: Color(0xff35e18b)),
        ],
      ),
    );
  }
}
