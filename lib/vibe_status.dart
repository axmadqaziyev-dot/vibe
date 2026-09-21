// VIBE STATUS — istifadəçinin hazırkı əhvalı ("vibe").
//
// Firestore: users/{uid}.vibe = { mood, note, at }
// 12 saatdan köhnə status avtomatik olaraq göstərilmir.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ui/vibe_design.dart';

// ============================================================
// MODEL
// ============================================================

class VibeMood {
  const VibeMood(this.id, this.emoji, this.label, this.color);

  final String id;
  final String emoji;
  final String label;
  final Color color;
}

const vibeMoods = <VibeMood>[
  VibeMood('chat', '💬', 'Söhbətə hazıram', vPurple),
  VibeMood('fun', '😂', 'Gülmək istəyirəm', Color(0xffffb037)),
  VibeMood('music', '🎧', 'Musiqi dinləyirəm', vBlue),
  VibeMood('love', '💜', 'Romantik', vPink),
  VibeMood('game', '🎮', 'Oyun oynayıram', Color(0xff48e08a)),
  VibeMood('party', '🥳', 'Party modundayam', Color(0xffff4bdb)),
  VibeMood('coffee', '☕', 'Qəhvə üstə', Color(0xffc08457)),
  VibeMood('travel', '✈️', 'Səyahətdəyəm', Color(0xff37d6d0)),
  VibeMood('study', '📚', 'Dərs oxuyuram', Color(0xff7f9cff)),
  VibeMood('tired', '😴', 'Yorğunam', Color(0xff8f86a3)),
  VibeMood('sad', '🥺', 'Dəstəyə ehtiyacım var', Color(0xff9aa7ff)),
  VibeMood('busy', '⏳', 'Məşğulam', vRose),
];

VibeMood? moodById(String? id) {
  if (id == null || id.isEmpty) return null;
  for (final mood in vibeMoods) {
    if (mood.id == id) return mood;
  }
  return null;
}

/// Bir istifadəçinin aktiv vibe statusu.
class VibeStatus {
  const VibeStatus({required this.mood, required this.note, required this.at});

  final VibeMood mood;
  final String note;
  final DateTime at;

  /// 12 saat sonra status "köhnəlmiş" sayılır.
  static const lifetime = Duration(hours: 12);

  /// users/{uid} sənədinin datasından status oxuyur.
  /// Status yoxdursa və ya vaxtı keçibsə `null` qaytarır.
  static VibeStatus? from(Map<String, dynamic>? data) {
    final raw = data?['vibe'];
    if (raw is! Map) return null;

    final mood = moodById('${raw['mood'] ?? ''}');
    if (mood == null) return null;

    final at = raw['at'];
    final time = at is Timestamp ? at.toDate() : null;
    if (time == null) return null;
    if (DateTime.now().difference(time) > lifetime) return null;

    return VibeStatus(
      mood: mood,
      note: '${raw['note'] ?? ''}'.trim(),
      at: time,
    );
  }

  String get title => note.isEmpty ? mood.label : note;

  String get ago {
    final minutes = DateTime.now().difference(at).inMinutes;
    if (minutes < 1) return 'indi';
    if (minutes < 60) return '$minutes dəq əvvəl';
    return '${minutes ~/ 60} saat əvvəl';
  }
}

// ============================================================
// YAZMA
// ============================================================

/// Statusu yazır. `mood` null olanda statusu silir.
Future<void> saveVibe(String uid, VibeMood? mood, String note) async {
  final ref = FirebaseFirestore.instance.collection('users').doc(uid);

  if (mood == null) {
    await ref.set({'vibe': FieldValue.delete()}, SetOptions(merge: true));
    return;
  }

  await ref.set({
    'vibe': {
      'mood': mood.id,
      'note': note.trim(),
      'at': Timestamp.now(),
    },
  }, SetOptions(merge: true));
}

// ============================================================
// GÖRÜNÜŞ
// ============================================================

/// Kiçik status nişanı — profil kartlarında və söhbət başlığında.
class VibePill extends StatelessWidget {
  const VibePill({
    super.key,
    required this.status,
    this.compact = false,
    this.onTap,
  });

  final VibeStatus status;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = status.mood.color;

    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 7 : 11,
          vertical: compact ? 3 : 6,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: .55)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              status.mood.emoji,
              style: TextStyle(fontSize: compact ? 10 : 13),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                compact ? status.mood.label : status.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 9.5 : 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Başqa bir istifadəçinin statusunu canlı göstərir.
class VibePillStream extends StatelessWidget {
  const VibePillStream({super.key, required this.uid, this.compact = true});

  final String uid;
  final bool compact;

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots(),
        builder: (context, snapshot) {
          final status = VibeStatus.from(snapshot.data?.data());
          if (status == null) return const SizedBox.shrink();
          return VibePill(status: status, compact: compact);
        },
      );
}

/// Öz statusun — toxunanda seçim pəncərəsi açılır.
/// Həm ana səhifədə, həm də profil səhifəsində istifadə olunur.
class MyVibeCard extends StatelessWidget {
  const MyVibeCard({
    super.key,
    required this.uid,
    this.database,
    this.compact = false,
  });

  final String uid;
  final FirebaseFirestore? database;

  /// Dar rejim — yan-yana iki kart kimi göstəriləndə.
  final bool compact;

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: (database ?? FirebaseFirestore.instance)
            .collection('users')
            .doc(uid)
            .snapshots(),
        builder: (context, snapshot) {
          final status = VibeStatus.from(snapshot.data?.data());
          final accent = status?.mood.color ?? vPurple;

          if (compact) {
            return GlassCard(
              glow: accent,
              border: accent.withValues(alpha: .45),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: GestureDetector(
                onTap: () => showVibePicker(context, uid, status),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      status?.mood.emoji ?? '✨',
                      style: const TextStyle(fontSize: 22),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      status == null ? 'Əhvalın' : status.mood.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      status == null ? 'Seç və paylaş' : status.ago,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: vMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            );
          }

          return GlassCard(
            glow: accent,
            border: accent.withValues(alpha: .45),
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        accent.withValues(alpha: .9),
                        vPink.withValues(alpha: .6),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(color: accent.withValues(alpha: .45), blurRadius: 16),
                    ],
                  ),
                  child: Text(
                    status?.mood.emoji ?? '✨',
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        status == null ? 'Vibe-ını seç' : status.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        status == null
                            ? 'Əhvalını paylaş, uyğun insanlar səni tapsın.'
                            : '${status.mood.label} · ${status.ago}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: vMuted,
                          fontSize: 11.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GradientButton(
                  label: status == null ? 'Seç' : 'Dəyiş',
                  expand: false,
                  height: 38,
                  fontSize: 12.5,
                  gradient: LinearGradient(colors: [accent, vPink]),
                  onPressed: () => showVibePicker(context, uid, status),
                ),
              ],
            ),
          );
        },
      );
}

// ============================================================
// SEÇİM PƏNCƏRƏSİ
// ============================================================

/// Öz vibe-ını seçmək üçün alt pəncərə açır.
Future<void> showVibePicker(
  BuildContext context,
  String uid,
  VibeStatus? current,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheet) => _VibePickerSheet(uid: uid, current: current),
  );
}

class _VibePickerSheet extends StatefulWidget {
  const _VibePickerSheet({required this.uid, required this.current});

  final String uid;
  final VibeStatus? current;

  @override
  State<_VibePickerSheet> createState() => _VibePickerSheetState();
}

class _VibePickerSheetState extends State<_VibePickerSheet> {
  late VibeMood? selected = widget.current?.mood;
  late final noteController = TextEditingController(
    text: widget.current?.note ?? '',
  );
  bool saving = false;

  @override
  void dispose() {
    noteController.dispose();
    super.dispose();
  }

  Future<void> _save({required bool clear}) async {
    if (saving) return;
    setState(() => saving = true);

    try {
      await saveVibe(
        widget.uid,
        clear ? null : selected,
        clear ? '' : noteController.text,
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            clear ? 'Vibe statusu silindi.' : 'Vibe yeniləndi ✨',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Status yadda saxlanmadı. Yenidən sına.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xff120d1d),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: Color(0xff33264a))),
        ),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xff3c2f55),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const GradientText(
                'Bugünkü vibe-ın nədir?',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const Text(
                'Status 12 saat görünür. İnsanlar səni əhvalına görə tapa bilər.',
                style: TextStyle(color: vMuted, fontSize: 12.5, height: 1.4),
              ),
              const SizedBox(height: 18),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 210),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 9,
                    runSpacing: 9,
                    children: [
                      for (final mood in vibeMoods)
                        VibeChip(
                          label: mood.label,
                          emoji: mood.emoji,
                          color: mood.color,
                          selected: selected?.id == mood.id,
                          onTap: () => setState(
                            () => selected = selected?.id == mood.id ? null : mood,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteController,
                maxLength: 60,
                style: const TextStyle(color: Colors.white),
                cursorColor: vPink,
                decoration: InputDecoration(
                  hintText: 'İstəsən bir cümlə yaz: "Film tövsiyəsi axtarıram"',
                  hintStyle: const TextStyle(color: Color(0xff8f86a3), fontSize: 13),
                  counterStyle: const TextStyle(color: Color(0xff6f6684), fontSize: 11),
                  filled: true,
                  fillColor: const Color(0xff1a1327),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (widget.current != null) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: saving ? null : () => _save(clear: true),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          side: const BorderSide(color: Color(0xff5c4a78)),
                        ),
                        child: const Text('Sil'),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    flex: 2,
                    child: GradientButton(
                      label: saving ? 'Saxlanılır…' : 'Vibe-ı paylaş',
                      icon: Icons.auto_awesome_rounded,
                      onPressed: saving || selected == null
                          ? null
                          : () => _save(clear: false),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
