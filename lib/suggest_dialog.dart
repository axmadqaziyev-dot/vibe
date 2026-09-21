import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'blocking.dart';
import 'main.dart' show isReallyOnline;
import 'suggest_people.dart';
import 'ui/vibe_design.dart';
import 'user_profile.dart';
import 'app/i18n.dart';

/// "Sənə uyğun olanlar" pəncərəsi.
///
/// Yeni gələn adam boş söhbət siyahısı görür və nə edəcəyini bilmir.
/// Bu pəncərə ona bir neçə namizəd verir və bir toxunuşla salam göndərir.
///
/// Namizədlər qabaqcadan seçilmiş gəlir, amma istəmədiyini götürmək olur —
/// heç kim xəbərsiz mesaj göndərmir.
Future<void> showSuggestionsDialog(
  BuildContext context, {
  required UserProfile profile,
  required List<Candidate> people,
  FirebaseFirestore? database,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialog) => _SuggestionsDialog(
      profile: profile,
      people: people,
      database: database,
    ),
  );
}

/// Bazadan namizədləri yığır.
///
/// Tanış olduqların (izlədiklərin və yazışdıqların) siyahıdan çıxır.
Future<List<Candidate>> loadSuggestions({
  required UserProfile profile,
  FirebaseFirestore? database,
  int limit = 6,
}) async {
  final db = database ?? FirebaseFirestore.instance;
  final me = db.collection('users').doc(profile.uid);

  final known = <String>{};
  var myCountry = '';

  try {
    final snap = await me.get();
    myCountry = '${snap.data()?['countryCode'] ?? ''}';
  } catch (_) {}

  try {
    final following = await me.collection('following').limit(200).get();
    known.addAll(following.docs.map((e) => e.id));
  } catch (_) {}

  try {
    final chats = await db
        .collection('chats')
        .where('members', arrayContains: profile.uid)
        .limit(100)
        .get();

    for (final doc in chats.docs) {
      known.addAll(List<String>.from(doc.data()['members'] ?? const []));
    }
  } catch (_) {}

  final blocked = <String>{};
  try {
    blocked.addAll(await watchHiddenUids(profile.uid, database: db).first);
  } catch (_) {}

  try {
    final users = await db.collection('users').limit(200).get();

    return pickSuggestions(
      users.docs.map((doc) {
        final d = doc.data();
        return Candidate(
          uid: doc.id,
          name: '${d['name'] ?? ''}',
          photo: '${d['photoUrl'] ?? ''}',
          age: int.tryParse('${d['age'] ?? 0}') ?? 0,
          country: '${d['countryCode'] ?? ''}',
          online: isReallyOnline(d),
          hasAbout: '${d['about'] ?? ''}'.trim().isNotEmpty,
          suspended: d['suspended'] == true,
        );
      }),
      myUid: profile.uid,
      known: known,
      blocked: blocked,
      myCountry: myCountry,
      limit: limit,
    );
  } catch (_) {
    return const [];
  }
}

class _SuggestionsDialog extends StatefulWidget {
  const _SuggestionsDialog({
    required this.profile,
    required this.people,
    this.database,
  });

  final UserProfile profile;
  final List<Candidate> people;
  final FirebaseFirestore? database;

  @override
  State<_SuggestionsDialog> createState() => _SuggestionsDialogState();
}

class _SuggestionsDialogState extends State<_SuggestionsDialog> {
  late final Set<String> picked = widget.people.map((e) => e.uid).toSet();
  bool sending = false;

  FirebaseFirestore get db => widget.database ?? FirebaseFirestore.instance;

  Future<void> _sayHello() async {
    if (picked.isEmpty || sending) return;

    setState(() => sending = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    const text = 'Salam 👋';

    try {
      final batch = db.batch();

      for (final person in widget.people.where((e) => picked.contains(e.uid))) {
        final chat = db.collection('chats').doc(
              chatIdFor(widget.profile.uid, person.uid),
            );

        batch.set(chat, {
          'members': [widget.profile.uid, person.uid],
          'memberNames': {
            widget.profile.uid: widget.profile.name,
            person.uid: person.name,
          },
          'lastMessage': text,
          'lastSenderId': widget.profile.uid,
          'messageCount': FieldValue.increment(1),
          'updatedAt': Timestamp.now(),
        }, SetOptions(merge: true));

        batch.set(chat.collection('messages').doc(), {
          'senderId': widget.profile.uid,
          'text': text,
          'type': 'text',
          'createdAt': Timestamp.now(),
        });
      }

      await batch.commit();

      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('${picked.length} nəfərə salam göndərildi.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => sending = false);
      messenger.showSnackBar(
        SnackBar(content: Text(t('Göndərilmədi. Bağlantını yoxla.'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xff241a44), Color(0xff15102a)],
          ),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: vPink.withValues(alpha: .35)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Sənə uyğun olanlar',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close_rounded, color: vMuted),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Bir toxunuşla salam göndər — istəmədiyini siyahıdan çıxar.',
                style: TextStyle(color: vMuted, fontSize: 12.5, height: 1.4),
              ),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: .82,
              ),
              itemCount: widget.people.length,
              itemBuilder: (context, i) => _tile(widget.people[i]),
            ),
            const SizedBox(height: 18),
            GradientButton(
              label: sending
                  ? 'Göndərilir…'
                  : picked.isEmpty
                      ? 'Kimsə seçilməyib'
                      : 'Salam de (${picked.length})',
              icon: Icons.favorite_rounded,
              gradient: vHot,
              height: 52,
              onPressed: sending || picked.isEmpty ? null : _sayHello,
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(Candidate person) {
    final chosen = picked.contains(person.uid);

    return GestureDetector(
      onTap: () => setState(() {
        chosen ? picked.remove(person.uid) : picked.add(person.uid);
      }),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: chosen ? .09 : .04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: chosen ? vPink.withValues(alpha: .6) : Colors.white12,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: vPurple,
                  backgroundImage: person.photo.isNotEmpty
                      ? NetworkImage(person.photo)
                      : null,
                  child: person.photo.isEmpty
                      ? Text(
                          person.name.characters.first.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        )
                      : null,
                ),
                if (chosen)
                  const Positioned(
                    right: -1,
                    top: -1,
                    child: CircleAvatar(
                      radius: 8,
                      backgroundColor: vPink,
                      child: Icon(Icons.check_rounded,
                          size: 11, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 7),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                person.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (person.age > 0) ...[
              const SizedBox(height: 3),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: vPink.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${person.age}',
                  style: const TextStyle(
                    color: Color(0xffff9fe4),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
