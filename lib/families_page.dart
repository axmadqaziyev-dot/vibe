import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'families.dart';
import 'ui/vibe_design.dart';
import 'user_profile.dart';
import 'app/i18n.dart';

/// Ailələr meydanı — siyahı, yaratmaq və ailəyə qoşulmaq.
class FamiliesPage extends StatefulWidget {
  const FamiliesPage({super.key, required this.profile, this.database});

  final UserProfile profile;
  final FirebaseFirestore? database;

  @override
  State<FamiliesPage> createState() => _FamiliesPageState();
}

class _FamiliesPageState extends State<FamiliesPage> {
  FirebaseFirestore get db => widget.database ?? FirebaseFirestore.instance;

  /// null = hamısı.
  FamilyKind? kind;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: vBg,
      appBar: AppBar(
        backgroundColor: const Color(0xff0b0711),
        title: const Text(
          'Ailələr',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: 'Ailə yarat',
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: _create,
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          _kindRow(),
          const SizedBox(height: 12),
          Expanded(child: _list()),
        ],
      ),
    );
  }

  Widget _kindRow() => SizedBox(
        height: 34,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          itemCount: FamilyKind.values.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: VibeChip(
                  label: t('Hamısı'),
                  emoji: '✨',
                  color: vPink,
                  selected: kind == null,
                  onTap: () => setState(() => kind = null),
                ),
              );
            }

            final value = FamilyKind.values[i - 1];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: VibeChip(
                label: value.label,
                emoji: value.emoji,
                color: vPurple,
                selected: kind == value,
                onTap: () => setState(
                  () => kind = kind == value ? null : value,
                ),
              ),
            );
          },
        ),
      );

  Widget _list() {
    // Sıralama xəzinəyə görədir: güclü ailələr başda görünsün.
    final query = db
        .collection('families')
        .orderBy('treasure', descending: true)
        .limit(50);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const Center(
            child: Text(
              'Siyahı yüklənmədi.',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: vPink));
        }

        final docs = snap.data!.docs.where((doc) {
          if (kind == null) return true;
          return familyKindFrom(doc.data()['kind']) == kind;
        }).toList();

        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏰', style: TextStyle(fontSize: 42)),
                  const SizedBox(height: 12),
                  Text(
                    kind == null
                        ? 'Hələ ailə yoxdur.\nBirincisini sən yarat.'
                        : 'Bu yöndə ailə yoxdur.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: vMuted, height: 1.5),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) => _card(docs[i]),
        );
      },
    );
  }

  Widget _card(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final name = '${d['name'] ?? 'Ailə'}';
    final about = '${d['about'] ?? ''}'.trim();
    final members = int.tryParse('${d['memberCount'] ?? 0}') ?? 0;
    final treasure = int.tryParse('${d['treasure'] ?? 0}') ?? 0;
    final value = familyKindFrom(d['kind']);
    final level = familyLevel(treasure);

    return PressableScale(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FamilyPage(
            profile: widget.profile,
            familyId: doc.id,
            database: widget.database,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: vPanel,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: vLine),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _crest(name, level),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$members üzv',
                        style: const TextStyle(color: vMuted, fontSize: 11.5),
                      ),
                    ],
                  ),
                  if (about.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      about,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: vMuted,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _tag('${value.emoji} ${value.label}', vPurple),
                      const SizedBox(width: 6),
                      _tag('💰 $treasure', vGold),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Ailə nişanı — şəkil yoxdursa adın ilk hərfi və səviyyə.
  Widget _crest(String name, int level) => Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: vHot,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                name.isEmpty ? 'A' : name.characters.first.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          Positioned(
            right: -4,
            bottom: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: vBg,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: vGold),
              ),
              child: Text(
                'Lv $level',
                style: const TextStyle(
                  color: vGold,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      );

  Widget _tag(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .16),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      );

  Future<void> _create() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateFamilyPage(
          profile: widget.profile,
          database: widget.database,
        ),
      ),
    );

    if (created == true && mounted) setState(() {});
  }
}

// ============================================================
// AİLƏ YARATMAQ
// ============================================================

class CreateFamilyPage extends StatefulWidget {
  const CreateFamilyPage({super.key, required this.profile, this.database});

  final UserProfile profile;
  final FirebaseFirestore? database;

  @override
  State<CreateFamilyPage> createState() => _CreateFamilyPageState();
}

class _CreateFamilyPageState extends State<CreateFamilyPage> {
  final nameController = TextEditingController();
  final aboutController = TextEditingController();

  FamilyKind kind = FamilyKind.social;
  bool saving = false;

  FirebaseFirestore get db => widget.database ?? FirebaseFirestore.instance;

  @override
  void dispose() {
    nameController.dispose();
    aboutController.dispose();
    super.dispose();
  }

  void _say(String text) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(text)));

  Future<void> _create() async {
    if (saving) return;

    final nameError = familyNameError(nameController.text);
    if (nameError != null) {
      _say(nameError);
      return;
    }

    final aboutError = familyAboutError(aboutController.text);
    if (aboutError != null) {
      _say(aboutError);
      return;
    }

    setState(() => saving = true);

    final name = nameController.text.trim();
    final about = aboutController.text.trim();
    final navigator = Navigator.of(context);

    try {
      final me = db.collection('users').doc(widget.profile.uid);
      final family = db.collection('families').doc();

      await db.runTransaction((tx) async {
        final snap = await tx.get(me);
        final data = snap.data() ?? {};

        // Bir adam eyni anda yalnız bir ailədə ola bilər.
        if ('${data['familyId'] ?? ''}'.isNotEmpty) {
          throw StateError('family');
        }

        final coins = int.tryParse('${data['coins'] ?? 0}') ?? 0;
        if (coins < familyCreateCost) throw StateError('coins');

        tx.set(me, {
          'coins': coins - familyCreateCost,
          'familyId': family.id,
        }, SetOptions(merge: true));

        tx.set(family, {
          'name': name,
          'about': about,
          'kind': kind.id,
          'ownerUid': widget.profile.uid,
          'ownerName': widget.profile.name,
          'memberCount': 1,
          // Yaratmağa verilən sikkənin yarısı xəzinəyə keçir ki, ailə
          // sıfırdan başlamasın və qurucunun töhfəsi görünsün.
          'treasure': familyCreateCost ~/ 2,
          'createdAt': Timestamp.now(),
        });

        tx.set(family.collection('members').doc(widget.profile.uid), {
          'uid': widget.profile.uid,
          'name': widget.profile.name,
          'role': 'owner',
          'contributed': familyCreateCost ~/ 2,
          'joinedAt': Timestamp.now(),
        });
      });

      navigator.pop(true);
    } on StateError catch (error) {
      if (!mounted) return;
      setState(() => saving = false);
      _say(error.message == 'coins'
          ? 'Sikkə çatmır. Ailə üçün $familyCreateCost sikkə lazımdır.'
          : 'Artıq bir ailədəsən. Əvvəlcə oradan çıx.');
    } catch (_) {
      if (!mounted) return;
      setState(() => saving = false);
      _say('Alınmadı. Bağlantını yoxla.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: vBg,
      appBar: AppBar(
        backgroundColor: const Color(0xff0b0711),
        title: const Text(
          'Ailə yarat',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
        children: [
          _field(
            controller: nameController,
            label: 'Ailənin adı',
            icon: Icons.shield_rounded,
            maxLength: 20,
          ),
          const SizedBox(height: 16),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Yön',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in FamilyKind.values)
                VibeChip(
                  label: value.label,
                  emoji: value.emoji,
                  color: vPurple,
                  selected: kind == value,
                  onTap: () => setState(() => kind = value),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _field(
            controller: aboutController,
            label: 'Təsvir',
            icon: Icons.notes_rounded,
            maxLines: 4,
            maxLength: 200,
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: vGold.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: vGold.withValues(alpha: .4)),
            ),
            child: Row(
              children: [
                const Text('💰', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Ailə yaratmaq $familyCreateCost sikkədir.\n'
                    'Yarısı ailənin xəzinəsinə keçir.',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          GradientButton(
            label: saving ? 'Yaradılır…' : 'Ailəni yarat',
            icon: Icons.shield_rounded,
            gradient: vBrand,
            height: 54,
            onPressed: saving ? null : _create,
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    int? maxLength,
  }) =>
      TextField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        cursorColor: vPink,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: vMuted, fontSize: 14),
          floatingLabelStyle: const TextStyle(color: vPink, fontSize: 13),
          prefixIcon: Padding(
            padding: EdgeInsets.only(bottom: maxLines > 1 ? 60 : 0),
            child: Icon(icon, size: 19, color: vMuted),
          ),
          filled: true,
          fillColor: vPanelHigh,
          counterStyle: const TextStyle(color: Color(0xff6f6786), fontSize: 11),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: vLine),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: vLine),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: vPink, width: 1.4),
          ),
        ),
      );
}

// ============================================================
// AİLƏ SƏHİFƏSİ
// ============================================================

class FamilyPage extends StatelessWidget {
  const FamilyPage({
    super.key,
    required this.profile,
    required this.familyId,
    this.database,
  });

  final UserProfile profile;
  final String familyId;
  final FirebaseFirestore? database;

  FirebaseFirestore get db => database ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get family =>
      db.collection('families').doc(familyId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: vBg,
      appBar: AppBar(
        backgroundColor: const Color(0xff0b0711),
        title: const Text('Ailə', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: family.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(
              child: Text(
                'Ailə yüklənmədi.',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator(color: vPink));
          }

          final d = snap.data!.data();
          if (d == null) {
            return const Center(
              child: Text(
                'Bu ailə artıq yoxdur.',
                style: TextStyle(color: vMuted),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              _header(context, d),
              const SizedBox(height: 18),
              _membersTitle(),
              const SizedBox(height: 8),
              _members(context, d),
            ],
          );
        },
      ),
    );
  }

  Widget _header(BuildContext context, Map<String, dynamic> d) {
    final name = '${d['name'] ?? 'Ailə'}';
    final about = '${d['about'] ?? ''}'.trim();
    final treasure = int.tryParse('${d['treasure'] ?? 0}') ?? 0;
    final members = int.tryParse('${d['memberCount'] ?? 0}') ?? 0;
    final kind = familyKindFrom(d['kind']);
    final level = familyLevel(treasure);
    final left = familyToNextLevel(treasure);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff241a44), Color(0xff15102a)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: vLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  gradient: vHot,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: Text(
                    name.isEmpty ? 'A' : name.characters.first.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${kind.emoji} ${kind.label} · $members üzv · Lv $level',
                      style: const TextStyle(color: vMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (about.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              about,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: familyProgress(treasure),
              minHeight: 8,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation(vGold),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            left > 0
                ? 'Xəzinə: $treasure · növbəti səviyyəyə $left sikkə'
                : 'Xəzinə: $treasure · ən yüksək səviyyə',
            style: const TextStyle(color: vMuted, fontSize: 11.5),
          ),
          const SizedBox(height: 16),
          _actions(context, d),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context, Map<String, dynamic> d) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: family.collection('members').doc(profile.uid).snapshots(),
        builder: (context, snap) {
          final inFamily = snap.data?.exists == true;
          final owner = '${d['ownerUid'] ?? ''}' == profile.uid;

          // Üzv olanlar xəzinəyə töhfə verə bilir — səviyyə bununla artır.
          if (inFamily || owner) {
            return Row(
              children: [
                Expanded(
                  child: GradientButton(
                    label: 'Xəzinəyə töhfə',
                    icon: Icons.savings_rounded,
                    gradient: vSunset,
                    height: 48,
                    onPressed: () => _contribute(context),
                  ),
                ),
                if (!owner) ...[
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 52,
                    height: 48,
                    child: IconButton(
                      tooltip: 'Ailədən çıx',
                      icon: const Icon(Icons.logout_rounded, color: vMuted),
                      onPressed: () => _leave(context),
                    ),
                  ),
                ],
              ],
            );
          }

          return GradientButton(
            label: 'Ailəyə qoşul',
            icon: Icons.group_add_rounded,
            gradient: vBrand,
            height: 48,
            onPressed: () => _join(context, d),
          );
        },
      );

  Widget _membersTitle() => const Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Üzvlər',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      );

  Widget _members(BuildContext context, Map<String, dynamic> family_) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: family
            .collection('members')
            .orderBy('contributed', descending: true)
            .limit(familyMaxMembers)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator(color: vPink)),
            );
          }

          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: Text('Hələ üzv yoxdur.',
                  style: TextStyle(color: vMuted)),
            );
          }

          return Column(
            children: [
              for (var i = 0; i < docs.length; i++)
                _memberRow(docs[i].data(), i + 1),
            ],
          );
        },
      );

  Widget _memberRow(Map<String, dynamic> d, int place) {
    final name = '${d['name'] ?? 'VIBE'}';
    final contributed = int.tryParse('${d['contributed'] ?? 0}') ?? 0;
    final owner = '${d['role'] ?? ''}' == 'owner';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: vPanel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: vLine),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '#$place',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: vMuted,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 6),
          CircleAvatar(
            radius: 18,
            backgroundColor: vPurple,
            child: Text(
              name.isEmpty ? 'V' : name.characters.first.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (owner) ...[
                  const SizedBox(width: 6),
                  const Text('👑', style: TextStyle(fontSize: 13)),
                ],
              ],
            ),
          ),
          Text(
            '$contributed',
            style: const TextStyle(color: vGold, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }


  /// Xəzinəyə sikkə verir.
  ///
  /// Sikkə istifadəçidən çıxır, ailənin xəzinəsinə və adamın öz töhfə
  /// sayğacına yazılır. Üçü də bir tranzaksiyadadır: yarımçıq qalsa
  /// sikkə itər və ya yoxdan yaranardı.
  Future<void> _contribute(BuildContext context) async {
    final controller = TextEditingController(text: '1000');

    final amount = await showDialog<int>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: const Color(0xff151020),
        title: const Text(
          'Xəzinəyə töhfə',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Verdiyin sikkə ailənin səviyyəsini qaldırır və '
              'üzvlər siyahısında sənin adının yanında görünür.',
              style: TextStyle(color: vMuted, height: 1.45, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 18),
              cursorColor: vPink,
              decoration: const InputDecoration(
                prefixText: '💰  ',
                prefixStyle: TextStyle(fontSize: 18),
                hintText: 'Məbləğ',
                hintStyle: TextStyle(color: vMuted),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('İmtina', style: TextStyle(color: vMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(
              dialog,
              int.tryParse(controller.text.trim()) ?? 0,
            ),
            child: const Text(
              'Ver',
              style: TextStyle(color: vGold, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );

    if (amount == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);

    if (amount <= 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Məbləğ sıfırdan böyük olmalıdır.')),
      );
      return;
    }

    try {
      final me = db.collection('users').doc(profile.uid);

      await db.runTransaction((tx) async {
        final snap = await tx.get(me);
        final coins = int.tryParse('${snap.data()?['coins'] ?? 0}') ?? 0;

        if (coins < amount) throw StateError('coins');

        tx.set(me, {'coins': coins - amount}, SetOptions(merge: true));

        tx.set(family, {
          'treasure': FieldValue.increment(amount),
        }, SetOptions(merge: true));

        tx.set(family.collection('members').doc(profile.uid), {
          'contributed': FieldValue.increment(amount),
        }, SetOptions(merge: true));
      });

      messenger.showSnackBar(
        SnackBar(content: Text('$amount sikkə xəzinəyə keçdi.')),
      );
    } on StateError {
      messenger.showSnackBar(
        const SnackBar(content: Text('Sikkən çatmır.')),
      );
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Alınmadı.')));
    }
  }

  Future<void> _join(BuildContext context, Map<String, dynamic> d) async {
    final messenger = ScaffoldMessenger.of(context);
    final members = int.tryParse('${d['memberCount'] ?? 0}') ?? 0;

    if (members >= familyMaxMembers) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Ailə doludur.')),
      );
      return;
    }

    try {
      final me = db.collection('users').doc(profile.uid);

      await db.runTransaction((tx) async {
        final snap = await tx.get(me);
        if ('${snap.data()?['familyId'] ?? ''}'.isNotEmpty) {
          throw StateError('family');
        }

        tx.set(me, {'familyId': familyId}, SetOptions(merge: true));

        tx.set(family.collection('members').doc(profile.uid), {
          'uid': profile.uid,
          'name': profile.name,
          'role': 'member',
          'contributed': 0,
          'joinedAt': Timestamp.now(),
        });

        tx.set(family, {
          'memberCount': FieldValue.increment(1),
        }, SetOptions(merge: true));
      });

      messenger.showSnackBar(const SnackBar(content: Text('Ailəyə qoşuldun.')));
    } on StateError {
      messenger.showSnackBar(
        const SnackBar(content: Text('Artıq bir ailədəsən.')),
      );
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Alınmadı.')));
    }
  }

  Future<void> _leave(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final batch = db.batch();

      batch.set(db.collection('users').doc(profile.uid), {
        'familyId': '',
      }, SetOptions(merge: true));

      batch.delete(family.collection('members').doc(profile.uid));

      // Sayğac mənfi düşməsin deyə serverdə azaldılır.
      batch.set(family, {
        'memberCount': FieldValue.increment(-1),
      }, SetOptions(merge: true));

      await batch.commit();

      messenger.showSnackBar(const SnackBar(content: Text('Ailədən çıxdın.')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Alınmadı.')));
    }
  }
}
