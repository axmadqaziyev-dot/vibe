/// Adam seçmə ekranı.
///
/// Üç yerdə lazımdır: qrup qurmaq, qrupa üzv əlavə etmək, mesaj
/// yönləndirmək. Hər dəfə yenidən yazsaq, biri düzələndə o biri
/// geridə qalardı.
///
/// Siyahı bütün istifadəçilərdən ibarət deyil — izlədiklərim və
/// yazışdıqlarım göstərilir. Tanımadığın adamı qrupa salmaq istəməzsən,
/// üstəlik tam siyahı böyüdükcə yüklənməz olur.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'ui/vibe_chrome.dart';
import 'ui/vibe_design.dart';
import 'user_profile.dart';

class PickedPerson {
  const PickedPerson({
    required this.uid,
    required this.name,
    this.photo = '',
  });

  final String uid;
  final String name;
  final String photo;
}

/// Tanışların siyahısını yığır.
Future<List<PickedPerson>> loadKnownPeople({
  required String uid,
  FirebaseFirestore? database,
}) async {
  final db = database ?? FirebaseFirestore.instance;
  final found = <String, PickedPerson>{};

  Future<void> add(String id, String name, String photo) async {
    if (id.isEmpty || id == uid || found.containsKey(id)) return;
    found[id] = PickedPerson(uid: id, name: name, photo: photo);
  }

  try {
    final following = await db
        .collection('users')
        .doc(uid)
        .collection('following')
        .limit(200)
        .get();

    for (final doc in following.docs) {
      await add(
        doc.id,
        '${doc.data()['name'] ?? ''}',
        '${doc.data()['photo'] ?? ''}',
      );
    }
  } catch (_) {}

  try {
    final chats = await db
        .collection('chats')
        .where('members', arrayContains: uid)
        .limit(100)
        .get();

    for (final doc in chats.docs) {
      final members = (doc.data()['members'] as List?) ?? const [];
      final names = (doc.data()['memberNames'] as Map?) ?? const {};

      for (final value in members) {
        final id = '$value';
        await add(id, '${names[id] ?? ''}', '');
      }
    }
  } catch (_) {}

  // Adı boş qalanları istifadəçi sənədindən tamamlayırıq.
  final missing = found.values.where((p) => p.name.trim().isEmpty).toList();

  for (final person in missing.take(30)) {
    try {
      final snap = await db.collection('users').doc(person.uid).get();
      final data = snap.data();
      if (data == null) continue;

      found[person.uid] = PickedPerson(
        uid: person.uid,
        name: '${data['name'] ?? 'İstifadəçi'}',
        photo: '${data['photoUrl'] ?? ''}',
      );
    } catch (_) {}
  }

  final list = found.values.toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  return list;
}

/// Adam seçmə vərəqini açır və seçilənləri qaytarır.
Future<List<PickedPerson>> pickPeople(
  BuildContext context, {
  required UserProfile profile,
  Set<String> exclude = const {},
  String title = 'Kimi seçirsən?',
  FirebaseFirestore? database,
}) async {
  final picked = await showModalBottomSheet<List<PickedPerson>>(
    context: context,
    backgroundColor: const Color(0xff120d1d),
    showDragHandle: true,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .85,
    ),
    builder: (_) => _PeoplePicker(
      profile: profile,
      exclude: exclude,
      title: title,
      database: database,
    ),
  );

  return picked ?? const [];
}

class _PeoplePicker extends StatefulWidget {
  const _PeoplePicker({
    required this.profile,
    required this.exclude,
    required this.title,
    this.database,
  });

  final UserProfile profile;
  final Set<String> exclude;
  final String title;
  final FirebaseFirestore? database;

  @override
  State<_PeoplePicker> createState() => _PeoplePickerState();
}

class _PeoplePickerState extends State<_PeoplePicker> {
  late final Future<List<PickedPerson>> people = loadKnownPeople(
    uid: widget.profile.uid,
    database: widget.database,
  );

  final chosen = <String, PickedPerson>{};
  String query = '';

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
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: TextField(
                onChanged: (value) =>
                    setState(() => query = value.toLowerCase().trim()),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                cursorColor: vPink,
                decoration: InputDecoration(
                  hintText: 'Ad ilə axtar',
                  hintStyle: const TextStyle(color: vMuted, fontSize: 13),
                  prefixIcon:
                      const Icon(Icons.search_rounded, color: vMuted, size: 20),
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
            ),
            Flexible(child: _list()),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: GradientButton(
                label: chosen.isEmpty
                    ? 'Seç'
                    : 'Davam et (${chosen.length})',
                icon: Icons.check_rounded,
                gradient: vBrand,
                height: 50,
                onPressed: chosen.isEmpty
                    ? null
                    : () => Navigator.pop(
                          context,
                          chosen.values.toList(),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list() => FutureBuilder<List<PickedPerson>>(
        future: people,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Padding(
              padding: EdgeInsets.all(30),
              child: Center(child: CircularProgressIndicator(color: vPink)),
            );
          }

          final all = snap.data!
              .where((p) => !widget.exclude.contains(p.uid))
              .toList();

          final shown = query.isEmpty
              ? all
              : all
                  .where((p) => p.name.toLowerCase().contains(query))
                  .toList();

          if (shown.isEmpty) {
            return const Padding(
              padding: EdgeInsets.fromLTRB(28, 10, 28, 30),
              child: Text(
                'Kimsə tapılmadı.\nƏvvəlcə adamları izlə və ya yazış.',
                textAlign: TextAlign.center,
                style: TextStyle(color: vMuted, height: 1.5, fontSize: 13),
              ),
            );
          }

          return ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: shown.length,
            itemBuilder: (context, i) {
              final person = shown[i];
              final picked = chosen.containsKey(person.uid);

              return ListTile(
                onTap: () => setState(() {
                  if (picked) {
                    chosen.remove(person.uid);
                  } else {
                    chosen[person.uid] = person;
                  }
                }),
                leading: SizedBox(
                  width: 42,
                  height: 42,
                  child: ClipOval(
                    child: VibePhoto(url: person.photo, name: person.name),
                  ),
                ),
                title: Text(
                  person.name.isEmpty ? 'İstifadəçi' : person.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 14.5),
                ),
                trailing: Icon(
                  picked
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: picked ? vPink : vMuted,
                ),
              );
            },
          );
        },
      );
}
