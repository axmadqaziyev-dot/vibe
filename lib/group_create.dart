/// Qrup qurmaq.
///
/// İki addım: kimləri əlavə edirsən, adı nədir. Şəkil istəyə bağlıdır
/// — məcburi etsək, adam qrup qurmaqdan vaz keçər.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'group_chat.dart';
import 'group_page.dart';
import 'media_store.dart';
import 'people_picker.dart';
import 'ui/vibe_chrome.dart';
import 'ui/vibe_design.dart';
import 'user_profile.dart';

/// Qrup qurma axını: adam seç → ad ver → yarat.
Future<void> startGroupCreation(
  BuildContext context, {
  required UserProfile profile,
  FirebaseFirestore? database,
}) async {
  final chosen = await pickPeople(
    context,
    profile: profile,
    exclude: {profile.uid},
    title: 'Qrupa kimi salırsan?',
    database: database,
  );

  if (chosen.isEmpty || !context.mounted) return;

  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => GroupCreatePage(
        profile: profile,
        members: chosen,
        database: database,
      ),
    ),
  );
}

class GroupCreatePage extends StatefulWidget {
  const GroupCreatePage({
    super.key,
    required this.profile,
    required this.members,
    this.database,
  });

  final UserProfile profile;
  final List<PickedPerson> members;
  final FirebaseFirestore? database;

  @override
  State<GroupCreatePage> createState() => _GroupCreatePageState();
}

class _GroupCreatePageState extends State<GroupCreatePage> {
  final controller = TextEditingController();

  StoredImage? photo;
  bool busy = false;

  FirebaseFirestore get db => widget.database ?? FirebaseFirestore.instance;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await pickGroupPhoto();
    if (picked == null || !mounted) return;
    setState(() => photo = picked);
  }

  Future<void> _create() async {
    if (busy) return;
    setState(() => busy = true);

    try {
      final id = db.collection('groups').doc().id;

      final members = <String>[
        widget.profile.uid,
        for (final person in widget.members) person.uid,
      ];

      final names = <String, Object>{
        widget.profile.uid: widget.profile.name,
        for (final person in widget.members) person.uid: person.name,
      };

      await db.collection('groups').doc(id).set({
        'id': id,
        'name': cleanGroupName(controller.text),
        if (photo != null) 'photo': photo!.thumb,
        'ownerUid': widget.profile.uid,
        'members': members,
        'memberNames': names,
        'admins': <String>[],
        'muted': <String>[],
        'onlyAdminsWrite': false,
        'lastMessage': '${widget.profile.name} qrupu qurdu',
        'lastSenderId': widget.profile.uid,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

      if (!mounted) return;

      // Qurma ekranı yığında qalmasın: geri basanda söhbətə yox,
      // siyahıya qayıtmalıdır.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => GroupPage(
            profile: widget.profile,
            groupId: id,
            database: widget.database,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Qrup yaradılmadı.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: vBg,
      appBar: AppBar(
        backgroundColor: const Color(0xff0b0711),
        foregroundColor: Colors.white,
        title: const Text(
          'Yeni qrup',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        children: [
          Center(
            child: PressableScale(
              onTap: _pickPhoto,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: vPanel,
                      border: Border.all(color: vLine),
                    ),
                    child: ClipOval(
                      child: photo == null
                          ? const Icon(Icons.groups_2_rounded,
                              color: vMuted, size: 38)
                          : Image(
                              image: vibeImageProvider(photo!.thumb)!,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      gradient: vHot,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.photo_camera_rounded,
                        size: 15, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          TextField(
            controller: controller,
            maxLength: 40,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            cursorColor: vPink,
            decoration: InputDecoration(
              labelText: 'Qrupun adı',
              labelStyle: const TextStyle(color: vMuted),
              counterStyle: const TextStyle(color: vMuted),
              filled: true,
              fillColor: vPanel,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Üzvlər · ${widget.members.length + 1}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final person in widget.members)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: ClipOval(
                        child: VibePhoto(
                          url: person.photo,
                          name: person.name,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 56,
                      child: Text(
                        person.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: vMuted, fontSize: 10.5),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 28),
          GradientButton(
            label: busy ? 'Yaradılır…' : 'Qrupu yarat',
            icon: Icons.check_rounded,
            gradient: vBrand,
            height: 52,
            onPressed: busy ? null : _create,
          ),
        ],
      ),
    );
  }
}
