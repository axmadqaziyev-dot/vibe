import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'blocking.dart';
import 'ui/vibe_design.dart';
import 'user_profile.dart';

/// Paylaşımı dostlara yönləndirmək üçün vərəq.
///
/// İki yol var:
///   * VIBE-in içində — seçilən adamların söhbətinə mesaj kimi düşür
///   * VIBE-dən kənara — telefonun öz paylaşım pəncərəsi (WhatsApp, Telegram…)
///
/// Kənar paylaşımda ünvan kimi tətbiqin özünün linki gedir: birbaşa
/// paylaşıma aparan dərin keçid hələ qurulmayıb, ona görə açılmayan
/// ünvan yazmırıq.
Future<void> showShareSheet(
  BuildContext context, {
  required UserProfile profile,
  required String title,
  required String body,
  FirebaseFirestore? database,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xff151020),
    showDragHandle: true,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .8,
    ),
    builder: (sheet) => _ShareSheet(
      profile: profile,
      title: title,
      body: body,
      database: database,
    ),
  );
}

class _ShareSheet extends StatefulWidget {
  const _ShareSheet({
    required this.profile,
    required this.title,
    required this.body,
    this.database,
  });

  final UserProfile profile;

  /// Mesajda görünəcək başlıq, məsələn "Əhmədin anı".
  final String title;

  /// Paylaşımın mətni.
  final String body;

  final FirebaseFirestore? database;

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  FirebaseFirestore get db => widget.database ?? FirebaseFirestore.instance;

  String query = '';
  final Set<String> picked = <String>{};
  bool sending = false;

  /// Göndərməyə dəyər adamlar: izlədiklərim və yazışdıqlarım.
  ///
  /// Bütün istifadəçiləri çəkmək düzgün olmazdı — tanımadığın adama
  /// yönləndirmək istəməzsən, siyahı da miqyaslanmazdı.
  late final Future<List<_Person>> people = _load();

  Future<List<_Person>> _load() async {
    final me = db.collection('users').doc(widget.profile.uid);
    final ids = <String>{};

    try {
      final following = await me.collection('following').limit(100).get();
      ids.addAll(following.docs.map((e) => e.id));
    } catch (_) {}

    try {
      final chats = await db
          .collection('chats')
          .where('members', arrayContains: widget.profile.uid)
          .limit(50)
          .get();

      for (final doc in chats.docs) {
        for (final uid in List<String>.from(doc.data()['members'] ?? const [])) {
          if (uid != widget.profile.uid) ids.add(uid);
        }
      }
    } catch (_) {}

    ids.remove(widget.profile.uid);
    if (ids.isEmpty) return const [];

    // Firestore `whereIn` bir sorğuda 30 sənəd verir, ona görə hissələyirik.
    final list = <_Person>[];
    final all = ids.toList();

    for (var i = 0; i < all.length; i += 30) {
      final chunk = all.sublist(i, (i + 30).clamp(0, all.length));
      try {
        final snap = await db
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        for (final doc in snap.docs) {
          final d = doc.data();
          list.add(_Person(
            uid: doc.id,
            name: '${d['name'] ?? 'VIBE'}',
            photo: '${d['photoUrl'] ?? ''}',
          ));
        }
      } catch (_) {}
    }

    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  String get _shareText => [
        widget.title,
        if (widget.body.trim().isNotEmpty) widget.body.trim(),
        'https://vibe-f9d13.web.app',
      ].join('\n');

  Future<void> _send(List<_Person> all) async {
    if (picked.isEmpty || sending) return;

    setState(() => sending = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final batch = db.batch();

      for (final uid in picked) {
        final name = all.firstWhere(
          (p) => p.uid == uid,
          orElse: () => const _Person(uid: '', name: 'VIBE', photo: ''),
        ).name;

        final chat = db.collection('chats').doc(
              chatIdFor(widget.profile.uid, uid),
            );

        batch.set(chat, {
          'members': [widget.profile.uid, uid],
          'memberNames': {
            widget.profile.uid: widget.profile.name,
            uid: name,
          },
          'lastMessage': widget.title,
          'lastSenderId': widget.profile.uid,
          'messageCount': FieldValue.increment(1),
          'updatedAt': Timestamp.now(),
        }, SetOptions(merge: true));

        batch.set(chat.collection('messages').doc(), {
          'senderId': widget.profile.uid,
          'text': _shareText,
          // Adi mətn kimi göndərilir: söhbət ekranı yalnız tanıdığı
          // növləri ayrıca çəkir, naməlum növ boş görünə bilər.
          'type': 'text',
          'createdAt': Timestamp.now(),
        });
      }

      await batch.commit();

      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('${picked.length} nəfərə göndərildi.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => sending = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Göndərilmədi. Bağlantını yoxla.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 0, 18, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Yönləndir',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            _search(),
            Flexible(child: _peopleList()),
            _bottomRow(),
          ],
        ),
      ),
    );
  }

  Widget _search() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: TextField(
          onChanged: (v) => setState(() => query = v.toLowerCase().trim()),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          cursorColor: vPink,
          decoration: InputDecoration(
            hintText: 'Ad ilə axtar',
            hintStyle: const TextStyle(color: vMuted, fontSize: 13),
            prefixIcon: const Icon(Icons.search_rounded, color: vMuted, size: 20),
            isDense: true,
            filled: true,
            fillColor: const Color(0xff1b1528),
            contentPadding: const EdgeInsets.symmetric(vertical: 13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      );

  Widget _peopleList() => FutureBuilder<List<_Person>>(
        future: people,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Padding(
              padding: EdgeInsets.all(28),
              child: Center(child: CircularProgressIndicator(color: vPink)),
            );
          }

          final all = snap.data!;
          final shown = query.isEmpty
              ? all
              : all
                  .where((p) => p.name.toLowerCase().contains(query))
                  .toList();

          if (all.isEmpty) {
            return const Padding(
              padding: EdgeInsets.fromLTRB(28, 10, 28, 24),
              child: Text(
                'Hələ kimsəni izləmirsən və yazışmamısan.\n'
                'Aşağıdakı düymə ilə tətbiqdən kənara paylaşa bilərsən.',
                textAlign: TextAlign.center,
                style: TextStyle(color: vMuted, height: 1.5, fontSize: 13),
              ),
            );
          }

          if (shown.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Tapılmadı.', style: TextStyle(color: vMuted)),
            );
          }

          return GridView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 10,
              crossAxisSpacing: 8,
              childAspectRatio: .78,
            ),
            itemCount: shown.length,
            itemBuilder: (context, i) => _personTile(shown[i], all),
          );
        },
      );

  Widget _personTile(_Person person, List<_Person> all) {
    final chosen = picked.contains(person.uid);

    return GestureDetector(
      onTap: () => setState(() {
        chosen ? picked.remove(person.uid) : picked.add(person.uid);
      }),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: chosen ? vPink : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: 27,
                  backgroundColor: vPurple,
                  backgroundImage: person.photo.isNotEmpty
                      ? NetworkImage(person.photo)
                      : null,
                  child: person.photo.isEmpty
                      ? Text(
                          person.name.isEmpty
                              ? 'V'
                              : person.name.characters.first.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        )
                      : null,
                ),
              ),
              if (chosen)
                const Positioned(
                  right: 0,
                  bottom: 0,
                  child: CircleAvatar(
                    radius: 9,
                    backgroundColor: vPink,
                    child: Icon(Icons.check_rounded,
                        size: 12, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            person.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 11.5),
          ),
        ],
      ),
    );
  }

  Widget _bottomRow() => FutureBuilder<List<_Person>>(
        future: people,
        builder: (context, snap) {
          final all = snap.data ?? const <_Person>[];

          return Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xff2a1f3d))),
            ),
            child: picked.isEmpty
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _action(
                        icon: Icons.link_rounded,
                        label: 'Kopyala',
                        onTap: () async {
                          await Clipboard.setData(
                            ClipboardData(text: _shareText),
                          );
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Kopyalandı.')),
                          );
                        },
                      ),
                      _action(
                        icon: Icons.ios_share_rounded,
                        label: 'Paylaş',
                        onTap: () async {
                          // Telefonun öz pəncərəsi: WhatsApp, Telegram və s.
                          await SharePlus.instance.share(
                            ShareParams(text: _shareText),
                          );
                          if (context.mounted) Navigator.pop(context);
                        },
                      ),
                    ],
                  )
                : GradientButton(
                    label: sending
                        ? 'Göndərilir…'
                        : 'Göndər (${picked.length})',
                    icon: Icons.send_rounded,
                    gradient: vBrand,
                    height: 50,
                    onPressed: sending ? null : () => _send(all),
                  ),
          );
        },
      );

  Widget _action({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xff1b1528),
              ),
              child: Icon(icon, color: Colors.white, size: 21),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(color: vMuted, fontSize: 11.5),
            ),
          ],
        ),
      );
}

class _Person {
  const _Person({
    required this.uid,
    required this.name,
    required this.photo,
  });

  final String uid;
  final String name;
  final String photo;
}
