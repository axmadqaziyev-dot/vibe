/// Stori redaktoru.
///
/// Əvvəl stori adi "an" ekranından paylaşılırdı: şəkil seç, yaz,
/// göndər. Nəticədə stori quru şəkil idi və adamlar onu paylaşmırdı.
///
/// Instagram-da storinin dəyəri üstünə qoyduqlarındadır. Burada da
/// eyni yol var:
///
/// * şəkil seç **və ya** hazır rəngli fon götür (şəkilsiz stori);
/// * hazır şablonla bir toxunuşda başla — "Ad günün mübarək", təbrik,
///   otağa dəvət. Boş ekrana yazı yazmaq çətindir, adam nə yazacağını
///   bilmir və paylaşmaqdan vaz keçir;
/// * yazı və stiker əlavə et, barmaqla yerini dəyiş, böyüt-kiçilt.
///
/// Üst qatların yeri nisbi saxlanılır — `story_overlay.dart`-a bax.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'media_store.dart';
import 'story_overlay.dart';
import 'ui/vibe_chrome.dart';
import 'ui/vibe_design.dart';
import 'user_profile.dart';
import 'app/i18n.dart';

class StoryEditorPage extends StatefulWidget {
  const StoryEditorPage({
    super.key,
    required this.profile,
    this.template,
    this.sharedMoment,
    this.database,
  });

  final UserProfile profile;

  /// Hazır şablonla açılıb.
  final StoryTemplate? template;

  /// Anı storiyə atmaq — həmin anın şəkli fon olur.
  final Map<String, dynamic>? sharedMoment;

  final FirebaseFirestore? database;

  @override
  State<StoryEditorPage> createState() => _StoryEditorPageState();
}

class _StoryEditorPageState extends State<StoryEditorPage> {
  FirebaseFirestore get db => widget.database ?? FirebaseFirestore.instance;

  StoredImage? photo;
  String sharedImage = '';

  String backgroundId = storyBackgrounds.first.id;
  final overlays = <StoryOverlay>[];

  int selected = -1;
  bool sending = false;

  @override
  void initState() {
    super.initState();

    final template = widget.template;
    if (template != null) {
      backgroundId = template.backgroundId;
      overlays.addAll(template.overlays());
    }

    final moment = widget.sharedMoment;
    if (moment != null) {
      sharedImage = '${moment['thumbUrl'] ?? moment['imageUrl'] ?? ''}';

      final caption = '${moment['caption'] ?? ''}'.trim();
      overlays.add(StoryOverlay(
        kind: OverlayKind.text,
        value: caption.isEmpty ? 'Yeni anım var' : caption,
        dy: .8,
        scale: .9,
      ));
    }
  }

  // ----------------------------------------------------------
  // ƏMƏLİYYATLAR
  // ----------------------------------------------------------

  Future<void> _pickPhoto() async {
    final picked = await pickStoredImage(
      source: ImageSource.gallery,
      fullWidth: 900,
      thumbWidth: 260,
      fullQuality: 70,
    );

    if (picked == null || !mounted) return;
    setState(() {
      photo = picked;
      sharedImage = '';
    });
  }

  Future<void> _addText() async {
    final text = await _askText();
    if (text == null || text.isEmpty) return;

    setState(() {
      overlays.add(StoryOverlay(
        kind: OverlayKind.text,
        value: text,
        dy: .4 + overlays.length * .06,
      ));
      selected = overlays.length - 1;
    });
  }

  Future<String?> _askText({String initial = ''}) async {
    final controller = TextEditingController(text: initial);

    final value = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: const Color(0xff151020),
        title: const Text(
          'Yazı',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          maxLength: 120,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: t('Nə yazırsan?'),
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
            onPressed: () => Navigator.pop(dialog, controller.text.trim()),
            child: Text(t('Əlavə et')),
          ),
        ],
      ),
    );

    controller.dispose();
    return value;
  }

  void _addEmoji() {
    const choices = [
      '❤️', '🎉', '🎂', '🔥', '✨', '😂', '😍', '💜',
      '👑', '🎈', '🌹', '⭐', '🙌', '💯', '🎁', '🕊️',
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xff151020),
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final emoji in choices)
                PressableScale(
                  onTap: () {
                    Navigator.pop(sheet);
                    setState(() {
                      overlays.add(StoryOverlay(
                        kind: OverlayKind.emoji,
                        value: emoji,
                        dy: .35 + overlays.length * .05,
                        scale: 1.6,
                      ));
                      selected = overlays.length - 1;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(emoji, style: const TextStyle(fontSize: 30)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _publish() async {
    if (sending) return;

    if (photo == null && sharedImage.isEmpty && overlays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('Şəkil seç və ya bir yazı əlavə et.'))),
      );
      return;
    }

    setState(() => sending = true);

    try {
      final id = db.collection('stories').doc().id;

      String ownerPhoto = '';
      try {
        final me = await db.collection('users').doc(widget.profile.uid).get();
        ownerPhoto = '${me.data()?['photoUrl'] ?? ''}';
      } catch (_) {}

      await db.collection('stories').doc(id).set({
        'id': id,
        'ownerUid': widget.profile.uid,
        'ownerName': widget.profile.name,
        'ownerPhoto': ownerPhoto,
        'caption': '',
        if (photo != null) 'imageUrl': photo!.full,
        if (photo == null && sharedImage.isNotEmpty) 'imageUrl': sharedImage,
        // Şəkil yoxdursa fon rəngi ilə göstərilir.
        if (photo == null && sharedImage.isEmpty) 'bg': backgroundId,
        'overlays': [for (final item in overlays) item.toMap()],
        'viewCount': 0,
        'createdAt': Timestamp.now(),
      });

      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('Stori paylaşılmadı.'))),
        );
      }
    }
  }

  // ----------------------------------------------------------
  // EKRAN
  // ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: _canvas(),
                ),
              ),
            ),
            if (photo == null && sharedImage.isEmpty) _backgroundRow(),
            _templateRow(),
            _bottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _topBar() => Padding(
        padding: const EdgeInsets.fromLTRB(6, 4, 12, 4),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            ),
            const Expanded(
              child: Text(
                'Stori',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (selected >= 0)
              TextButton.icon(
                onPressed: () => setState(() {
                  overlays.removeAt(selected);
                  selected = -1;
                }),
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Color(0xffff8a9b), size: 19),
                label: const Text(
                  'Sil',
                  style: TextStyle(color: Color(0xffff8a9b)),
                ),
              ),
          ],
        ),
      );

  /// Storinin özü — fon və üst qatlar.
  Widget _canvas() => LayoutBuilder(
        builder: (context, box) {
          final background = backgroundById(backgroundId);

          return GestureDetector(
            // Boş yerə toxunmaq seçimi götürür.
            onTap: () => setState(() => selected = -1),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (photo != null)
                  Image(
                    image: vibeImageProvider(photo!.full)!,
                    fit: BoxFit.cover,
                  )
                else if (sharedImage.isNotEmpty)
                  Image(
                    image: vibeImageProvider(sharedImage)!,
                    fit: BoxFit.cover,
                  )
                else
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          for (final value in background.colors) Color(value),
                        ],
                      ),
                    ),
                  ),

                for (var i = 0; i < overlays.length; i++)
                  _overlayView(i, box.biggest),
              ],
            ),
          );
        },
      );

  Widget _overlayView(int index, Size size) {
    final item = overlays[index];
    final active = selected == index;

    return Positioned(
      left: item.dx * size.width,
      top: item.dy * size.height,
      child: FractionalTranslation(
        translation: const Offset(-.5, -.5),
        child: GestureDetector(
          onTap: () => setState(() => selected = index),
          onDoubleTap: item.kind == OverlayKind.text
              ? () async {
                  final text = await _askText(initial: item.value);
                  if (text == null || text.isEmpty) return;
                  setState(() => overlays[index] = item.copyWith(value: text));
                }
              : null,
          onPanUpdate: (details) => setState(() {
            overlays[index] = item.copyWith(
              dx: item.dx + details.delta.dx / size.width,
              dy: item.dy + details.delta.dy / size.height,
            );
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: active ? Colors.white70 : Colors.transparent,
              ),
            ),
            child: item.kind == OverlayKind.emoji
                ? Text(
                    item.value,
                    style: TextStyle(fontSize: 34 * item.scale),
                  )
                : Text(
                    item.value,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(item.colorValue),
                      fontSize: 22 * item.scale,
                      fontWeight: FontWeight.w900,
                      height: 1.25,
                      shadows: const [
                        Shadow(color: Colors.black54, blurRadius: 10),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  /// Seçilmiş qatın ölçüsü və rəngi.
  Widget _tools() {
    final item = overlays[selected];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Icon(Icons.zoom_out_map_rounded, size: 17, color: vMuted),
            Expanded(
              child: Slider(
                value: item.scale,
                min: .4,
                max: 4,
                activeColor: vPink,
                onChanged: (value) => setState(
                  () => overlays[selected] = item.copyWith(scale: value),
                ),
              ),
            ),
          ],
        ),
        if (item.kind == OverlayKind.text)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final value in storyTextColors)
                  PressableScale(
                    onTap: () => setState(
                      () => overlays[selected] =
                          item.copyWith(colorValue: value),
                    ),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: Color(value),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: item.colorValue == value
                              ? vPink
                              : Colors.white24,
                          width: item.colorValue == value ? 2.4 : 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _backgroundRow() => SizedBox(
        height: 54,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
          children: [
            for (final item in storyBackgrounds)
              PressableScale(
                onTap: () => setState(() => backgroundId = item.id),
                child: Container(
                  width: 40,
                  margin: const EdgeInsets.only(right: 9),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [for (final c in item.colors) Color(c)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: backgroundId == item.id ? vPink : Colors.white12,
                      width: backgroundId == item.id ? 2 : 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );

  Widget _templateRow() => SizedBox(
        height: 38,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          children: [
            for (final template in storyTemplates)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: VibeChip(
                  label: t(template.label),
                  emoji: template.emoji,
                  onTap: () => setState(() {
                    overlays
                      ..clear()
                      ..addAll(template.overlays());
                    backgroundId = template.backgroundId;
                    selected = -1;
                  }),
                ),
              ),
          ],
        ),
      );

  Widget _bottomBar() => Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected >= 0) _tools(),
            Row(
              children: [
                _toolButton(Icons.image_rounded, 'Şəkil', _pickPhoto),
                _toolButton(Icons.title_rounded, 'Yazı', _addText),
                _toolButton(
                    Icons.emoji_emotions_rounded, 'Stiker', _addEmoji),
                const SizedBox(width: 8),
                Expanded(
                  child: GradientButton(
                    label: sending ? 'Paylaşılır…' : 'Paylaş',
                    icon: Icons.send_rounded,
                    gradient: vHot,
                    height: 48,
                    onPressed: sending ? null : _publish,
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _toolButton(IconData icon, String label, VoidCallback onTap) =>
      PressableScale(
        onTap: onTap,
        child: Container(
          width: 52,
          height: 48,
          margin: const EdgeInsets.only(right: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .07),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(color: vMuted, fontSize: 9),
              ),
            ],
          ),
        ),
      );
}
