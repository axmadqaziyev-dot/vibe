/// Qrup haqqında — üzvlər və idarəetmə.
///
/// Kim nəyi edə bilər sualının cavabı `group_chat.dart`-dadır; burada
/// yalnız həmin cavab ekrana çıxarılır. Düymə görünmürsə, deməli
/// icazə yoxdur — belə olanda istifadəçi işləməyən düyməyə basmır.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'game_center.dart';
import 'group_chat.dart';
import 'group_page.dart';
import 'people_picker.dart';
import 'ui/vibe_chrome.dart';
import 'ui/vibe_design.dart';
import 'user_profile.dart';
import 'app/i18n.dart';

void showGroupInfo(
  BuildContext context, {
  required UserProfile profile,
  required GroupInfo group,
  FirebaseFirestore? database,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xff120d1d),
    showDragHandle: true,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .88,
    ),
    builder: (_) => _GroupInfoSheet(
      profile: profile,
      groupId: group.id,
      database: database,
    ),
  );
}

class _GroupInfoSheet extends StatelessWidget {
  const _GroupInfoSheet({
    required this.profile,
    required this.groupId,
    this.database,
  });

  final UserProfile profile;
  final String groupId;
  final FirebaseFirestore? database;

  FirebaseFirestore get db => database ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get ref =>
      db.collection('groups').doc(groupId);

  @override
  Widget build(BuildContext context) {
    // Canlı axın: üzv çıxarılanda siyahı dərhal dəyişir.
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        if (data == null) {
          return const SizedBox(
            height: 220,
            child: Center(child: CircularProgressIndicator(color: vPink)),
          );
        }

        final group = GroupInfo.from(groupId, data);
        final me = profile.uid;

        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              _header(context, group),
              const SizedBox(height: 18),

              if (group.canEdit(me)) ...[
                _tile(
                  icon: Icons.drive_file_rename_outline_rounded,
                  color: vPurple,
                  label: t('Adı dəyiş'),
                  onTap: () => _rename(context, group),
                ),
                _tile(
                  icon: Icons.add_a_photo_rounded,
                  color: const Color(0xff22a7ff),
                  label: t('Şəkli dəyiş'),
                  onTap: () => _changePhoto(context),
                ),
              ],

              if (group.canInvite(me))
                _tile(
                  icon: Icons.person_add_alt_1_rounded,
                  color: const Color(0xff2de28a),
                  label: t('Üzv əlavə et'),
                  onTap: () => _invite(context, group),
                ),

              _tile(
                icon: Icons.sports_esports_rounded,
                color: vPink,
                label: t('Oyunlar'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VibeGameCenterPage(profile: profile),
                    ),
                  );
                },
              ),

              // Elan rejimi — yalnız sahib və adminlər yazır.
              if (group.canEdit(me))
                SwitchListTile(
                  value: group.onlyAdminsWrite,
                  activeThumbColor: vPink,
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Yalnız adminlər yazsın',
                    style: TextStyle(color: Colors.white, fontSize: 14.5),
                  ),
                  subtitle: const Text(
                    'Elan rejimi — qalanlar oxuyur',
                    style: TextStyle(color: vMuted, fontSize: 12),
                  ),
                  onChanged: (value) => ref.set(
                    {'onlyAdminsWrite': value},
                    SetOptions(merge: true),
                  ),
                ),

              const Divider(height: 26, color: Color(0xff2d2540)),

              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 2),
                child: Text(
                  'Üzvlər · ${group.members.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),

              for (final uid in group.members)
                _member(context, group, uid, data),

              const SizedBox(height: 16),

              if (group.canLeave(me))
                _tile(
                  icon: Icons.logout_rounded,
                  color: const Color(0xffff657b),
                  label: t('Qrupdan çıx'),
                  onTap: () => _leave(context, group),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _header(BuildContext context, GroupInfo group) => Row(
        children: [
          SizedBox(
            width: 62,
            height: 62,
            child: ClipOval(
              child: VibePhoto(url: group.photo, name: group.name),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${group.members.length} üzv · '
                  '${group.admins.length + 1} idarəçi',
                  style: const TextStyle(color: vMuted, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _tile({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) =>
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: color),
        title: Text(label, style: const TextStyle(color: Colors.white)),
        onTap: onTap,
      );

  Widget _member(
    BuildContext context,
    GroupInfo group,
    String uid,
    Map<String, dynamic> data,
  ) {
    final names = (data['memberNames'] as Map?) ?? const {};
    final name = '${names[uid] ?? 'İstifadəçi'}';
    final role = group.roleOf(uid);
    final muted = group.muted.contains(uid);

    final canManage = group.canRemove(profile.uid, uid) ||
        group.canPromote(profile.uid, uid);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: SizedBox(
        width: 40,
        height: 40,
        child: ClipOval(child: _MemberPhoto(uid: uid, name: name)),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 14.5),
            ),
          ),
          if (role == GroupRole.owner || role == GroupRole.admin) ...[
            const SizedBox(width: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: vGold.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                role == GroupRole.owner ? 'sahib' : 'admin',
                style: const TextStyle(
                  color: vGold,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: muted
          ? const Text(
              'Yazması dayandırılıb',
              style: TextStyle(color: Color(0xffff8a9b), fontSize: 11.5),
            )
          : null,
      trailing: canManage
          ? IconButton(
              onPressed: () => _memberMenu(context, group, uid, name),
              icon: const Icon(Icons.more_horiz_rounded, color: vMuted),
            )
          : null,
    );
  }

  void _memberMenu(
    BuildContext context,
    GroupInfo group,
    String uid,
    String name,
  ) {
    final muted = group.muted.contains(uid);
    final isAdmin = group.admins.contains(uid);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xff151020),
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),

            if (group.canPromote(profile.uid, uid))
              ListTile(
                leading: const Icon(Icons.shield_rounded, color: vGold),
                title: Text(
                  isAdmin ? 'Adminlikdən çıxar' : 'Admin et',
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(sheet);
                  ref.set({
                    'admins': isAdmin
                        ? FieldValue.arrayRemove([uid])
                        : FieldValue.arrayUnion([uid]),
                  }, SetOptions(merge: true));
                },
              ),

            if (group.canMute(profile.uid, uid))
              ListTile(
                leading: Icon(
                  muted ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                  color: const Color(0xff22a7ff),
                ),
                title: Text(
                  muted ? 'Yazmağa icazə ver' : 'Yazmağını dayandır',
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(sheet);
                  ref.set({
                    'muted': muted
                        ? FieldValue.arrayRemove([uid])
                        : FieldValue.arrayUnion([uid]),
                  }, SetOptions(merge: true));
                },
              ),

            if (group.canRemove(profile.uid, uid))
              ListTile(
                leading: const Icon(Icons.person_remove_rounded,
                    color: Color(0xffff657b)),
                title: const Text(
                  'Qrupdan çıxar',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(sheet);
                  ref.set({
                    'members': FieldValue.arrayRemove([uid]),
                    'admins': FieldValue.arrayRemove([uid]),
                    'muted': FieldValue.arrayRemove([uid]),
                  }, SetOptions(merge: true));
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _rename(BuildContext context, GroupInfo group) async {
    final controller = TextEditingController(text: group.name);

    final value = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: const Color(0xff151020),
        title: const Text(
          'Qrupun adı',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(counterStyle: TextStyle(color: vMuted)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: Text(t('Ləğv et'), style: TextStyle(color: vMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, controller.text),
            child: Text(t('Saxla')),
          ),
        ],
      ),
    );

    controller.dispose();
    if (value == null) return;

    await ref.set(
      {'name': cleanGroupName(value)},
      SetOptions(merge: true),
    );
  }

  Future<void> _changePhoto(BuildContext context) async {
    final picked = await pickGroupPhoto();
    if (picked == null) return;

    await ref.set({'photo': picked.thumb}, SetOptions(merge: true));
  }

  Future<void> _invite(BuildContext context, GroupInfo group) async {
    final messenger = ScaffoldMessenger.of(context);

    if (group.members.length >= maxGroupMembers) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Qrup doludur.')),
      );
      return;
    }

    final chosen = await pickPeople(
      context,
      profile: profile,
      exclude: group.members.toSet(),
      title: 'Kimi əlavə edirsən?',
    );

    if (chosen.isEmpty) return;

    final names = <String, Object>{};
    for (final person in chosen) {
      names[person.uid] = person.name;
    }

    await ref.set({
      'members': FieldValue.arrayUnion([for (final p in chosen) p.uid]),
      'memberNames': names,
    }, SetOptions(merge: true));
  }

  Future<void> _leave(BuildContext context, GroupInfo group) async {
    final navigator = Navigator.of(context);

    await ref.set({
      'members': FieldValue.arrayRemove([profile.uid]),
      'admins': FieldValue.arrayRemove([profile.uid]),
    }, SetOptions(merge: true));

    // Vərəq və qrup ekranı bağlanır.
    navigator.pop();
    navigator.pop();
  }
}

class _MemberPhoto extends StatelessWidget {
  const _MemberPhoto({required this.uid, required this.name});

  final String uid;
  final String name;

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
        builder: (context, snap) => VibePhoto(
          url: '${snap.data?.data()?['photoUrl'] ?? ''}',
          name: name,
        ),
      );
}
