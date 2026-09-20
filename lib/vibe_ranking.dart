import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'user_profile.dart';

const _bg = Color(0xff070510);
const _panel = Color(0xff151020);
const _muted = Color(0xffa89fbd);
const _pink = Color(0xffff2bd6);
const _purple = Color(0xff8b5cff);

class VibeRankingPage extends StatelessWidget {
  const VibeRankingPage({super.key, required this.profile});
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final users = FirebaseFirestore.instance.collection('users');

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: const Color(0xff0b0711),
          title: const Text(
            'VIBE Ranking',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          bottom: const TabBar(
            indicatorColor: _pink,
            labelColor: Colors.white,
            unselectedLabelColor: _muted,
            tabs: [
              Tab(text: 'Top Gifter'),
              Tab(text: 'Top Host'),
              Tab(text: 'Level'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _RankingList(
              stream: users.orderBy('giftSent', descending: true).limit(50).snapshots(),
              valueField: 'giftSent',
              valueSuffix: ' coin',
              emptyLabel: 'Hələ gift ranking yoxdur',
            ),
            _RankingList(
              stream: users.orderBy('giftReceived', descending: true).limit(50).snapshots(),
              valueField: 'giftReceived',
              valueSuffix: ' coin',
              emptyLabel: 'Hələ host ranking yoxdur',
            ),
            _RankingList(
              stream: users.orderBy('level', descending: true).limit(50).snapshots(),
              valueField: 'level',
              valueSuffix: ' LVL',
              emptyLabel: 'Hələ level ranking yoxdur',
            ),
          ],
        ),
      ),
    );
  }
}

class _RankingList extends StatelessWidget {
  const _RankingList({
    required this.stream,
    required this.valueField,
    required this.valueSuffix,
    required this.emptyLabel,
  });

  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final String valueField;
  final String valueSuffix;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (_, snap) {
        if (snap.hasError) {
          return const Center(
            child: Text(
              'Ranking yüklənmədi.',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }
        if (!snap.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: _pink),
          );
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Text(
              emptyLabel,
              style: const TextStyle(color: _muted),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final d = docs[i].data();
            final name = '${d['name'] ?? 'VIBE'}';
            final photo = '${d['photoUrl'] ?? ''}';
            final value = int.tryParse('${d[valueField] ?? 0}') ?? 0;
            final vip = d['vip'] == true;

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _panel,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: i < 3 ? _purple : const Color(0xff342743),
                  width: i < 3 ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Text(
                      i == 0
                          ? '🥇'
                          : i == 1
                              ? '🥈'
                              : i == 2
                                  ? '🥉'
                                  : '#${i + 1}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: _purple,
                    backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                    child: photo.isEmpty
                        ? Text(
                            name.isEmpty ? 'V' : name.characters.first.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (vip) ...[
                          const SizedBox(width: 5),
                          const Icon(
                            Icons.workspace_premium_rounded,
                            color: Color(0xffffd86b),
                            size: 18,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Text(
                    '$value$valueSuffix',
                    style: const TextStyle(
                      color: _pink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
