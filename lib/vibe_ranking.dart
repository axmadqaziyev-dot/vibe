import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'rankings.dart';
import 'user_profile.dart';

const _bg = Color(0xff070510);
const _panel = Color(0xff151020);
const _muted = Color(0xffa89fbd);
const _pink = Color(0xffff2bd6);
const _purple = Color(0xff8b5cff);
const _gold = Color(0xffffd86b);

/// Reytinq lövhəsi: kim nə qədər hədiyyə göndərib, alıb; hansı otaq öndədir.
///
/// Üç dövr var. Günlük və həftəlik lövhə `rankings/{açar}` altından oxunur —
/// hədiyyə göndəriləndə ora da yazılır. Ümumi lövhə isə profilin özündəki
/// yığılmış sayğaclardan gəlir, ona görə ayrıca sənəd saxlanmır.
class VibeRankingPage extends StatefulWidget {
  const VibeRankingPage({
    super.key,
    required this.profile,
    this.database,
    this.now,
  });

  final UserProfile profile;

  /// Testdən saxta baza vermək üçün.
  final FirebaseFirestore? database;

  /// Testdən sabit tarix vermək üçün.
  final DateTime? now;

  @override
  State<VibeRankingPage> createState() => _VibeRankingPageState();
}

class _VibeRankingPageState extends State<VibeRankingPage> {
  RankingPeriod period = RankingPeriod.today;

  FirebaseFirestore get db => widget.database ?? FirebaseFirestore.instance;
  DateTime get now => widget.now ?? DateTime.now();

  /// Seçilmiş dövr üçün sıralanmış sorğu.
  Query<Map<String, dynamic>> _query(String field, bool rooms) {
    final key = periodKey(period, now);

    // Ümumi lövhədə dövr sənədi yoxdur — əsas kolleksiyalardan oxuyuruq.
    if (key == null) {
      return rooms
          ? db.collection('partyRooms').orderBy('giftTotal', descending: true)
          : db.collection('users').orderBy(field, descending: true);
    }

    return db
        .collection('rankings')
        .doc(key)
        .collection(rooms ? 'rooms' : 'users')
        .orderBy(rooms ? 'total' : field, descending: true);
  }

  /// Ümumi lövhədə sahələrin adı başqadır.
  String _field(String periodField, String allField) =>
      period == RankingPeriod.all ? allField : periodField;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: const Color(0xff0b0711),
          title: const Text(
            'Reytinq',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          bottom: const TabBar(
            indicatorColor: _pink,
            labelColor: Colors.white,
            unselectedLabelColor: _muted,
            tabs: [
              Tab(text: 'Göndərən'),
              Tab(text: 'Alan'),
              Tab(text: 'Otaqlar'),
            ],
          ),
        ),
        body: Column(
          children: [
            _periodBar(),
            Expanded(
              child: TabBarView(
                children: [
                  _RankingList(
                    query: _query(_field('sent', 'giftSent'), false),
                    valueField: _field('sent', 'giftSent'),
                    suffix: ' coin',
                    meUid: widget.profile.uid,
                    empty: period == RankingPeriod.today
                        ? 'Bu gün hələ hədiyyə göndərilməyib'
                        : 'Bu dövrdə hədiyyə göndərilməyib',
                  ),
                  _RankingList(
                    query: _query(_field('received', 'giftReceived'), false),
                    valueField: _field('received', 'giftReceived'),
                    suffix: ' coin',
                    meUid: widget.profile.uid,
                    empty: period == RankingPeriod.today
                        ? 'Bu gün hələ hədiyyə alınmayıb'
                        : 'Bu dövrdə hədiyyə alınmayıb',
                  ),
                  _RankingList(
                    query: _query('total', true),
                    valueField:
                        period == RankingPeriod.all ? 'giftTotal' : 'total',
                    nameField: 'title',
                    suffix: ' coin',
                    meUid: '',
                    empty: 'Hələ otaq reytinqi yoxdur',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _periodBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      child: Row(
        children: [
          for (final value in RankingPeriod.values)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: GestureDetector(
                  onTap: () => setState(() => period = value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      gradient: period == value
                          ? const LinearGradient(colors: [_pink, _purple])
                          : null,
                      color: period == value ? null : _panel,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: period == value
                            ? Colors.transparent
                            : const Color(0xff342743),
                      ),
                    ),
                    child: Text(
                      value.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: period == value ? Colors.white : _muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Bir lövhə: ilk üçlük podiumda, qalanı siyahıda, altda sənin yerin.
class _RankingList extends StatelessWidget {
  const _RankingList({
    required this.query,
    required this.valueField,
    required this.suffix,
    required this.meUid,
    required this.empty,
    this.nameField = 'name',
  });

  final Query<Map<String, dynamic>> query;
  final String valueField;
  final String nameField;
  final String suffix;

  /// Boş olsa "sənin yerin" sətri göstərilmir (otaq lövhəsində).
  final String meUid;
  final String empty;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.limit(50).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Reytinq yüklənmədi.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
            ),
          );
        }

        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: _pink));
        }

        // Sayğacı sıfır olanlar lövhəni doldurmasın.
        final rows = snap.data!.docs
            .map((doc) => _Row.from(doc.data(), valueField, nameField))
            .where((row) => row.value > 0)
            .toList();

        if (rows.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                empty,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _muted, height: 1.4),
              ),
            ),
          );
        }

        final top = rows.take(3).toList();
        final rest = rows.skip(3).toList();

        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
                children: [
                  _Podium(top: top, suffix: suffix),
                  const SizedBox(height: 14),
                  for (var i = 0; i < rest.length; i++) ...[
                    _RankRow(row: rest[i], place: i + 4, suffix: suffix),
                    const SizedBox(height: 9),
                  ],
                ],
              ),
            ),
            if (meUid.isNotEmpty) _myPlace(rows),
          ],
        );
      },
    );
  }

  /// Altdakı sabit sətir — istifadəçi öz yerini axtarmasın deyə.
  Widget _myPlace(List<_Row> rows) {
    final index = rows.indexWhere((row) => row.uid == meUid);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: const BoxDecoration(
        color: Color(0xff0f0a1a),
        border: Border(top: BorderSide(color: Color(0xff2a1f3d))),
      ),
      child: Text(
        index < 0
            ? 'Sən ilk 50-də deyilsən — hədiyyə göndər, yüksəl'
            : 'Sənin yerin: #${index + 1} · ${rows[index].value}$suffix',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: index < 0 ? _muted : Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Lövhənin bir sətri — istifadəçi də, otaq da eyni formaya salınır.
class _Row {
  const _Row({
    required this.uid,
    required this.name,
    required this.photo,
    required this.value,
  });

  final String uid;
  final String name;
  final String photo;
  final int value;

  factory _Row.from(
    Map<String, dynamic> data,
    String valueField,
    String nameField,
  ) {
    return _Row(
      uid: '${data['uid'] ?? data['roomId'] ?? ''}',
      name: '${data[nameField] ?? 'VIBE'}',
      photo: '${data['photoUrl'] ?? data['coverUrl'] ?? ''}',
      value: int.tryParse('${data[valueField] ?? 0}') ?? 0,
    );
  }
}

/// İlk üçlük. Birinci ortada və daha böyük durur.
class _Podium extends StatelessWidget {
  const _Podium({required this.top, required this.suffix});

  final List<_Row> top;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    // Sırası: ikinci solda, birinci ortada, üçüncü sağda.
    final order = <({_Row row, int place})>[
      if (top.length > 1) (row: top[1], place: 2),
      (row: top[0], place: 1),
      if (top.length > 2) (row: top[2], place: 3),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final entry in order)
          Expanded(
            child: _PodiumSpot(
              row: entry.row,
              place: entry.place,
              suffix: suffix,
            ),
          ),
      ],
    );
  }
}

class _PodiumSpot extends StatelessWidget {
  const _PodiumSpot({
    required this.row,
    required this.place,
    required this.suffix,
  });

  final _Row row;
  final int place;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final first = place == 1;
    final radius = first ? 38.0 : 30.0;
    final ring = switch (place) {
      1 => _gold,
      2 => const Color(0xffc9d2e0),
      _ => const Color(0xffd9915b),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            switch (place) { 1 => '🥇', 2 => '🥈', _ => '🥉' },
            style: TextStyle(fontSize: first ? 26 : 20),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: ring, width: first ? 2.5 : 2),
              boxShadow: first
                  ? [
                      BoxShadow(
                        color: ring.withValues(alpha: .4),
                        blurRadius: 16,
                      ),
                    ]
                  : null,
            ),
            child: CircleAvatar(
              radius: radius,
              backgroundColor: _purple,
              backgroundImage:
                  row.photo.isNotEmpty ? NetworkImage(row.photo) : null,
              child: row.photo.isEmpty
                  ? Text(
                      row.name.isEmpty
                          ? 'V'
                          : row.name.characters.first.toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: first ? 26 : 20,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            row.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: first ? 14 : 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${row.value}$suffix',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: ring,
              fontSize: first ? 13 : 11.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dördüncü yerdən aşağı adi sətir.
class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.row,
    required this.place,
    required this.suffix,
  });

  final _Row row;
  final int place;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xff342743)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '#$place',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _muted,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 6),
          CircleAvatar(
            radius: 21,
            backgroundColor: _purple,
            backgroundImage:
                row.photo.isNotEmpty ? NetworkImage(row.photo) : null,
            child: row.photo.isEmpty
                ? Text(
                    row.name.isEmpty
                        ? 'V'
                        : row.name.characters.first.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    row.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${row.value}$suffix',
            style: const TextStyle(color: _pink, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
