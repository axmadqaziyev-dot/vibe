/// Agentlik səhifəsi.
///
/// Üç hal var və ekran hər üçünü bir yerdə həll edir:
///
/// * agentliyin varsa — öz agentliyin, yayımçılar və qazanc;
/// * yoxdursa — qoşulmaq (kodla) və ya qurmaq;
/// * sahibsənsə — kodu paylaşmaq, yayımçı çıxarmaq.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'agency.dart';
import 'media_store.dart';
import 'ui/vibe_chrome.dart';
import 'ui/vibe_design.dart';
import 'user_profile.dart';
import 'app/i18n.dart';

class AgencyHubPage extends StatelessWidget {
  const AgencyHubPage({
    super.key,
    required this.profile,
    this.database,
  });

  final UserProfile profile;
  final FirebaseFirestore? database;

  FirebaseFirestore get db => database ?? FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: vBg,
      appBar: AppBar(
        backgroundColor: const Color(0xff0b0711),
        foregroundColor: Colors.white,
        title: const Text(
          'Agentlik',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: db
            .collection('agencies')
            .where('hosts', arrayContains: profile.uid)
            .limit(1)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: vPink),
            );
          }

          final docs = snap.data!.docs;
          if (docs.isEmpty) return _AgencyEmpty(profile: profile, db: db);

          return _AgencyView(
            profile: profile,
            db: db,
            agency: Agency.from(docs.first.id, docs.first.data()),
          );
        },
      ),
    );
  }
}

// ============================================================
// AGENTLİYİ OLMAYAN
// ============================================================

class _AgencyEmpty extends StatelessWidget {
  const _AgencyEmpty({required this.profile, required this.db});

  final UserProfile profile;
  final FirebaseFirestore db;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 30),
        children: [
          const Icon(Icons.apartment_rounded, size: 56, color: vPurple),
          const SizedBox(height: 16),
          const Text(
            'Agentlik nədir?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Agentlik yayımçı yığır, otaqlarını doldurur və qazancdan '
            'pay alır. Yayımçı tək qalanda otağını doldura bilmir — '
            'agentlik məhz bunun üçündür.\n\n'
            'Agentliyin payı sənin qazancından ÇIXMIR: ayrıca hesablanır.',
            textAlign: TextAlign.center,
            style: TextStyle(color: vMuted, fontSize: 13, height: 1.55),
          ),
          const SizedBox(height: 26),
          GradientButton(
            label: t('Kodla qoşul'),
            icon: Icons.vpn_key_rounded,
            gradient: vBrand,
            height: 52,
            onPressed: () => _join(context),
          ),
          const SizedBox(height: 12),
          PressableScale(
            onTap: () => _create(context),
            child: Container(
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .06),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: vLine),
              ),
              child: const Text(
                'Öz agentliyini qur',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      );

  Future<void> _join(BuildContext context) async {
    final controller = TextEditingController();

    final code = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: const Color(0xff151020),
        title: const Text(
          'Agentlik kodu',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(color: Colors.white, letterSpacing: 4),
          decoration: const InputDecoration(
            hintText: 'ABC234',
            hintStyle: TextStyle(color: vMuted, letterSpacing: 4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: Text(t('Ləğv et'), style: TextStyle(color: vMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, controller.text),
            child: Text(t('Qoşul')),
          ),
        ],
      ),
    );

    controller.dispose();
    if (code == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);

    if (!isValidAgencyCode(code)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Kod altı simvol olmalıdır.')),
      );
      return;
    }

    try {
      final found = await db
          .collection('agencies')
          .where('code', isEqualTo: cleanAgencyCode(code))
          .limit(1)
          .get();

      if (found.docs.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Belə agentlik tapılmadı.')),
        );
        return;
      }

      final doc = found.docs.first;
      final agency = Agency.from(doc.id, doc.data());

      if (agency.isFull) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Agentlik doludur.')),
        );
        return;
      }

      await doc.reference.set({
        'hosts': FieldValue.arrayUnion([profile.uid]),
        'hostNames': {profile.uid: profile.name},
      }, SetOptions(merge: true));

      // Hədiyyə gələndə pay bu sahəyə baxaraq yazılır. Olmasa,
      // agentlik heç nə almazdı.
      await db.collection('users').doc(profile.uid).set(
        {'agencyId': doc.id},
        SetOptions(merge: true),
      );

      messenger.showSnackBar(
        SnackBar(content: Text('${agency.name} agentliyinə qoşuldun.')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Qoşulmaq alınmadı.')),
      );
    }
  }

  Future<void> _create(BuildContext context) async {
    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: const Color(0xff151020),
        title: const Text(
          'Agentliyin adı',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 30,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Məsələn: VIBE Stars',
            hintStyle: TextStyle(color: vMuted),
            counterStyle: TextStyle(color: vMuted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: Text(t('Ləğv et'), style: TextStyle(color: vMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, controller.text),
            child: const Text('Qur'),
          ),
        ],
      ),
    );

    controller.dispose();
    if (name == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);

    try {
      final id = db.collection('agencies').doc().id;

      await db.collection('agencies').doc(id).set({
        'id': id,
        'name': cleanAgencyName(name),
        'code': newAgencyCode(),
        'ownerUid': profile.uid,
        'hosts': [profile.uid],
        'hostNames': {profile.uid: profile.name},
        'earned': 0,
        'createdAt': Timestamp.now(),
      });

      await db.collection('users').doc(profile.uid).set(
        {'agencyId': id},
        SetOptions(merge: true),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Agentlik yaradılmadı.')),
      );
    }
  }
}

// ============================================================
// AGENTLİYİ OLAN
// ============================================================

class _AgencyView extends StatelessWidget {
  const _AgencyView({
    required this.profile,
    required this.db,
    required this.agency,
  });

  final UserProfile profile;
  final FirebaseFirestore db;
  final Agency agency;

  DocumentReference<Map<String, dynamic>> get ref =>
      db.collection('agencies').doc(agency.id);

  @override
  Widget build(BuildContext context) {
    final owner = agency.canManage(profile.uid);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snap) {
        final names = (snap.data?.data()?['hostNames'] as Map?) ?? const {};

        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 30),
          children: [
            Row(
              children: [
                SizedBox(
                  width: 62,
                  height: 62,
                  child: ClipOval(
                    child: VibePhoto(url: agency.logo, name: agency.name),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        agency.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${agency.hostCount} yayımçı',
                        style: const TextStyle(color: vMuted, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Qazanc.
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xff2a1a52), Color(0xff6b2f9e)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.savings_rounded, color: vGold, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Agentliyin payı',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        Text(
                          '${agency.earned} sikkə',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (owner) ...[
              PressableScale(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: agency.code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Kod kopyalandı.')),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: BoxDecoration(
                    color: vPanel,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: vLine),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.vpn_key_rounded, color: vBlue, size: 20),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Dəvət kodu',
                          style: TextStyle(color: vMuted, fontSize: 12.5),
                        ),
                      ),
                      Text(
                        agency.code,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          letterSpacing: 4,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.copy_rounded, color: vMuted, size: 17),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.add_a_photo_rounded, color: vPurple),
                title: const Text(
                  'Loqonu dəyiş',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  final picked = await pickStoredImage(
                    fullWidth: 300,
                    thumbWidth: 140,
                  );
                  if (picked == null) return;
                  await ref.set(
                    {'logo': picked.thumb},
                    SetOptions(merge: true),
                  );
                },
              ),
            ],

            const Divider(height: 26, color: Color(0xff2d2540)),
            const Text(
              'Yayımçılar',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),

            for (final uid in agency.hosts)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: SizedBox(
                  width: 40,
                  height: 40,
                  child: ClipOval(
                    child: VibePhoto(
                      url: '',
                      name: '${names[uid] ?? 'Yayımçı'}',
                    ),
                  ),
                ),
                title: Text(
                  '${names[uid] ?? 'Yayımçı'}',
                  style: const TextStyle(color: Colors.white, fontSize: 14.5),
                ),
                subtitle: uid == agency.ownerUid
                    ? const Text(
                        'sahib',
                        style: TextStyle(color: vGold, fontSize: 11.5),
                      )
                    : null,
                trailing: agency.canRemove(profile.uid, uid)
                    ? IconButton(
                        onPressed: () async {
                          await ref.set({
                            'hosts': FieldValue.arrayRemove([uid]),
                          }, SetOptions(merge: true));

                          await db.collection('users').doc(uid).set(
                            {'agencyId': ''},
                            SetOptions(merge: true),
                          );
                        },
                        icon: const Icon(Icons.person_remove_rounded,
                            color: Color(0xffff657b), size: 20),
                      )
                    : null,
              ),

            const SizedBox(height: 14),

            if (agency.canLeave(profile.uid))
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading:
                    const Icon(Icons.logout_rounded, color: Color(0xffff657b)),
                title: const Text(
                  'Agentlikdən çıx',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  await ref.set({
                    'hosts': FieldValue.arrayRemove([profile.uid]),
                  }, SetOptions(merge: true));

                  await db.collection('users').doc(profile.uid).set(
                    {'agencyId': ''},
                    SetOptions(merge: true),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}
