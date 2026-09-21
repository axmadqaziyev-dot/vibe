import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'chat_lock.dart';
import 'legal.dart';
import 'media_store.dart';
import 'dart:async';
import 'package:record/record.dart';
import 'package:cross_file/cross_file.dart';
import 'voice/audio_file.dart';
import 'voice/waveform.dart';
import 'photo_pick.dart';
import 'rich_post_text.dart';
import 'video_pick.dart';
import 'media_upload.dart';
import 'telemetry.dart';
import 'ui/vibe_chrome.dart';
import 'ui/vibe_design.dart';
import 'user_profile.dart';

/// Yeni an paylaşma ekranı.
///
/// Threads üslubu: mətn tək başına da paylaşıla bilər, şəkil və video
/// isteğe bağlıdır. Şəkillər sənədin içində sıxılmış şəkildə saxlanılır,
/// video isə Supabase Storage-a yüklənir.
class CreateMomentPage extends StatefulWidget {
  const CreateMomentPage({
    super.key,
    required this.profile,
    this.asStory = false,
  });

  final UserProfile profile;

  /// Stori rejimi — eyni ekran, başqa kolleksiya.
  ///
  /// Ayrıca ekran yazmaq təkrar olardı: şəkil seçmə, video seçmə,
  /// səs yazma və yükləmə tam eyni işdir. Fərq yalnız sənədin
  /// hara yazılmasındadır.
  final bool asStory;

  @override
  State<CreateMomentPage> createState() => _CreateMomentPageState();
}

/// Bir sənədə sığması üçün şəkillərin ümumi həcmi bu həddi keçməməlidir.
const int _maxTotalImageBytes = 780 * 1024;
const int _maxImages = 3;

/// Səsli an bundan uzun ola bilməz — uzun səs nə yüklənir, nə dinlənilir.
const int maxMomentVoiceSeconds = 60;

class _CreateMomentPageState extends State<CreateMomentPage> {
  final caption = TextEditingController();
  final focus = FocusNode();

  final List<StoredImage> photos = [];
  /// Seçilmiş videonun adı — yalnız "video varmı" yoxlaması üçün.
  String? videoName;
  Uint8List? videoBytes;
  bool posting = false;

  // ---- səsli an ----
  final recorder = AudioRecorder();
  final clock = Stopwatch();
  Timer? ticker;

  Uint8List? audioBytes;
  List<int> audioWave = const [];
  int audioMs = 0;
  bool recording = false;

  @override
  void initState() {
    super.initState();
    caption.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    ticker?.cancel();
    recorder.dispose();
    caption.dispose();
    focus.dispose();
    super.dispose();
  }

  bool get canPost =>
      !posting &&
      !recording &&
      (caption.text.trim().isNotEmpty ||
          photos.isNotEmpty ||
          videoName != null ||
          audioBytes != null);

  int get usedBytes =>
      photos.fold(0, (total, image) =>
          total + image.full.length + image.thumb.length);

  void _say(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _addPhoto(ImageSource source) async {
    if (photos.length >= _maxImages) {
      _say('Bir anda ən çox $_maxImages şəkil paylaşa bilərsən.');
      return;
    }

    // Kamera bir şəkil verir — orada paketin seçicisi qalır.
    if (source == ImageSource.camera) {
      final image = await pickStoredImage(
        source: source,
        fullWidth: 720,
        thumbWidth: 220,
        fullQuality: 68,
      );
      if (image == null || !mounted) return;
      _acceptPhotos([image]);
      return;
    }

    // Qalereya: bir dəfəyə bir neçə şəkil.
    //
    // Əvvəl hər şəkil üçün qalereya yenidən açılırdı — dörd şəkil
    // üçün dörd dəfə. Instagram-da bir dəfə girib hamısını seçirsən.
    final picked = await pickGalleryPhotos(max: _maxImages - photos.length);
    if (picked.isEmpty || !mounted) return;

    final images = <StoredImage>[];
    for (final file in picked) {
      final image = compressToStoredImage(
        file.bytes,
        fullWidth: 720,
        thumbWidth: 220,
        fullQuality: 68,
      );
      if (image != null) images.add(image);
    }

    if (images.isEmpty) {
      _say('Şəkil oxunmadı.');
      return;
    }

    _acceptPhotos(images);
  }

  /// Seçilmiş şəkilləri həcm həddini aşmadan əlavə edir.
  void _acceptPhotos(List<StoredImage> images) {
    var used = usedBytes;
    final added = <StoredImage>[];

    for (final image in images) {
      if (photos.length + added.length >= _maxImages) break;

      final size = image.full.length + image.thumb.length;
      if (used + size > _maxTotalImageBytes) break;

      used += size;
      added.add(image);
    }

    if (added.isEmpty) {
      _say('Şəkillər çox böyükdür. Birini silib yenidən sına.');
      return;
    }

    setState(() => photos.addAll(added));

    if (added.length < images.length) {
      _say('${added.length} şəkil əlavə olundu, qalanı sığmadı.');
    }
  }

  Future<void> _addVideo() async {
    // Öz seçicimiz: vebdə paketin uzun accept siyahısı iOS Safari-də
    // qalereyanı gizlədib birbaşa Faylları açırdı.
    final picked = await pickGalleryVideo();
    if (picked == null || !mounted) return;

    final data = picked.bytes;

    if (data.lengthInBytes > 60 * 1024 * 1024) {
      _say('Video çox böyükdür. 60 MB-a qədər video paylaşa bilərsən.');
      return;
    }

    setState(() {
      videoName = picked.name;
      videoBytes = data;
    });
  }

  Future<void> post() async {
    if (!canPost) return;
    if (!guardContent(context, caption.text)) return;
    if (!guardTopic(context, caption.text)) return;

    setState(() => posting = true);
    try {
      final id = FirebaseFirestore.instance.collection('moments').doc().id;

      // Ölkəni profildən bir dəfə oxuyuruq: tövsiyə lenti hər an üçün
      // müəllifin profilinə ayrıca sorğu göndərməsin deyə an sənədinə yazılır.
      var ownerCountry = '';
      try {
        final me = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.profile.uid)
            .get();
        ownerCountry = '${me.data()?['countryCode'] ?? ''}';
      } catch (_) {}

      String? audioUrl;
      if (audioBytes != null) {
        audioUrl = await MediaUpload.upload(
          bucket: MediaUpload.videoBucket,
          path: '${widget.profile.uid}/moment-$id.wav',
          bytes: audioBytes!,
          contentType: 'audio/wav',
        );
      }

      String? videoUrl;
      if (videoBytes != null) {
        videoUrl = await MediaUpload.upload(
          bucket: MediaUpload.videoBucket,
          path: '${widget.profile.uid}/moment-$id.mp4',
          bytes: videoBytes!,
          contentType: 'video/mp4',
        );
      }

      if (widget.asStory) {
        await FirebaseFirestore.instance.collection('stories').doc(id).set({
          'id': id,
          'ownerUid': widget.profile.uid,
          'ownerName': widget.profile.name,
          'ownerPhoto': '${(await FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.profile.uid)
                  .get())
              .data()?['photoUrl'] ?? ''}',
          'caption': caption.text.trim(),
          if (photos.isNotEmpty) 'imageUrl': photos.first.full,
          if (videoUrl != null) 'videoUrl': videoUrl,
          'viewCount': 0,
          'createdAt': Timestamp.now(),
        });

        if (!mounted) return;
        Navigator.pop(context);
        return;
      }

      await FirebaseFirestore.instance.collection('moments').doc(id).set({
        'id': id,
        'ownerUid': widget.profile.uid,
        'ownerName': widget.profile.name,
        'caption': caption.text.trim(),
        if (photos.isNotEmpty) 'images': photos.map((e) => e.full).toList(),
        if (photos.isNotEmpty) 'thumbs': photos.map((e) => e.thumb).toList(),
        if (photos.isNotEmpty) 'imageUrl': photos.first.full,
        if (photos.isNotEmpty) 'thumbUrl': photos.first.thumb,
        if (videoUrl != null) 'videoUrl': videoUrl,
        if (audioUrl != null) ...{
          'audioUrl': audioUrl,
          'audioMs': audioMs,
          // Dalğa sənəddə saxlanılır: lent onu çəkmək üçün faylı
          // endirmək məcburiyyətində qalmasın.
          'audioWave': audioWave,
        },
        if (ownerCountry.isNotEmpty) 'ownerCountry': ownerCountry,
        // Hashtaglar ayrıca siyahıda saxlanılır: axtarış mətnin
        // içində yox, bu siyahıda gedir — həm sürətli, həm də böyük
        // hərf fərqindən asılı deyil.
        'tags': hashtagsIn(caption.text),
        'mentions': mentionsIn(caption.text),
        'createdAt': Timestamp.now(),
        'visibility': 'public',
        'likeCount': 0,
        'commentCount': 0,
        'viewCount': 0,
      });

      // "Paylaşan" medalı üçün sayğac.
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.profile.uid)
            .set({'momentCount': FieldValue.increment(1)},
                SetOptions(merge: true));
      } catch (_) {}

      Telemetry.log('moment_created', {
        'photos': photos.length,
        'video': videoUrl != null ? 1 : 0,
      });

      if (mounted) Navigator.pop(context);
    } on MediaBucketMissing catch (e) {
      _say('Video yaddaşı hazır deyil: Supabase-də "${e.bucket}" '
          'adlı public bucket yaradılmalıdır.');
    } catch (_) {
      _say('An paylaşılmadı. Yenidən sına.');
    } finally {
      if (mounted) setState(() => posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: vBg,
      appBar: AppBar(
        backgroundColor: vBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded, color: vInk),
        ),
        title: const Text(
          'Yeni an',
          style: TextStyle(
            color: vInk,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GradientButton(
              label: posting ? 'Paylaşılır…' : 'Paylaş',
              expand: false,
              height: 38,
              fontSize: 13.5,
              gradient: vBrand,
              onPressed: canPost ? post : null,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: ClipOval(
                            child: _MyAvatar(profile: widget.profile),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Threads üslubundakı şaquli xətt.
                        Container(width: 2, height: 90, color: vLine),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.profile.name,
                            style: const TextStyle(
                              color: vInk,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          TextField(
                            controller: caption,
                            focusNode: focus,
                            autofocus: true,
                            maxLines: null,
                            maxLength: 500,
                            style: const TextStyle(
                              color: vInk,
                              fontSize: 15.5,
                              height: 1.45,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Bu an haqqında yaz…',
                              hintStyle: TextStyle(color: vMuted),
                              border: InputBorder.none,
                              counterStyle: TextStyle(color: vMuted),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 6),
                            ),
                          ),
                          if (photos.isNotEmpty) _photoStrip(),
                          if (videoName != null) _videoCard(),
                          if (recording || audioBytes != null) _audioPreview(),
                          const SizedBox(height: 4),
                          _attachRow(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _footer(),
          ],
        ),
      ),
    );
  }

  Widget _photoStrip() {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SizedBox(
        height: 150,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: photos.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) => Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: 120,
                  height: 150,
                  child: VibePhoto(url: photos[i].thumb, name: ''),
                ),
              ),
              Positioned(
                right: 4,
                top: 4,
                child: GestureDetector(
                  onTap: () => setState(() => photos.removeAt(i)),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .65),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _videoCard() {
    final megabytes = (videoBytes?.lengthInBytes ?? 0) / (1024 * 1024);
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: vPanel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: vLine),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              gradient: vBrand,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.play_arrow_rounded,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Video hazırdır',
                  style: TextStyle(
                    color: vInk,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${megabytes.toStringAsFixed(1)} MB',
                  style: const TextStyle(color: vMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => setState(() {
              videoName = null;
              videoBytes = null;
            }),
            icon: const Icon(Icons.close_rounded, color: vMuted, size: 18),
          ),
        ],
      ),
    );
  }


  // ----------------------------------------------------------
  // SƏSLİ AN
  // ----------------------------------------------------------

  Future<void> _startRecording() async {
    if (recording) return;

    try {
      if (!await recorder.hasPermission()) {
        _say('Mikrofona icazə verilməyib. Parametrlərdən icazə ver.');
        return;
      }

      final path = await newRecordingPath();

      // WAV seçilir: dalğa şəklini çıxarmaq üçün baytları birbaşa
      // oxumaq lazımdır, sıxılmış formatda bu mümkün olmazdı.
      await recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: path,
      );

      if (!mounted) {
        await recorder.cancel();
        return;
      }

      clock
        ..reset()
        ..start();

      setState(() {
        recording = true;
        audioMs = 0;
      });

      ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (!mounted) return;
        setState(() => audioMs = clock.elapsedMilliseconds);

        // Özü dayanır: uzun səs həm yüklənmir, həm dinlənilmir.
        if (audioMs >= maxMomentVoiceSeconds * 1000) _stopRecording();
      });
    } catch (_) {
      if (mounted) {
        _say('Səs yazılmadı. Səhifəni HTTPS üzərindən aç və icazəni yoxla.');
      }
    }
  }

  Future<void> _stopRecording() async {
    if (!recording) return;

    ticker?.cancel();
    clock.stop();

    try {
      final path = await recorder.stop();
      if (path == null) throw StateError('fayl');

      final bytes = await XFile(path).readAsBytes();

      if (clock.elapsedMilliseconds < 1000 || bytes.length <= 44) {
        if (mounted) {
          setState(() => recording = false);
          _say('Səs çox qısadır. Ən azı bir saniyə danış.');
        }
        return;
      }

      if (!mounted) return;

      setState(() {
        recording = false;
        audioBytes = bytes;
        audioMs = clock.elapsedMilliseconds;
        // Dalğa elə indi hesablanır: sonradan faylı yenidən oxumaq
        // lazım gəlməsin deyə sənədlə birlikdə saxlanılır.
        audioWave = waveformFromWav(bytes);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => recording = false);
      _say('Səs saxlanmadı. Yenidən sına.');
    }
  }

  void _removeAudio() => setState(() {
        audioBytes = null;
        audioWave = const [];
        audioMs = 0;
      });

  /// Yazılan səsin önizləməsi.
  Widget _audioPreview() {
    final seconds = (audioMs / 1000).round();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff241a44), Color(0xff17122a)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: vPurple.withValues(alpha: .4)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: recording ? null : vHot,
              color: recording ? const Color(0xffff657b) : null,
              shape: BoxShape.circle,
            ),
            child: Icon(
              recording ? Icons.fiber_manual_record_rounded : Icons.graphic_eq_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recording ? 'Yazılır…' : 'Səs hazırdır',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$seconds saniyə',
                  style: const TextStyle(color: vMuted, fontSize: 11.5),
                ),
              ],
            ),
          ),
          if (!recording)
            IconButton(
              tooltip: 'Səsi sil',
              icon: const Icon(Icons.close_rounded, color: vMuted),
              onPressed: _removeAudio,
            ),
        ],
      ),
    );
  }

  Widget _attachRow() {
    return Row(
      children: [
        _attachButton(
          Icons.photo_library_rounded,
          'Qalereya',
          () => _addPhoto(ImageSource.gallery),
        ),
        _attachButton(
          Icons.photo_camera_rounded,
          'Kamera',
          () => _addPhoto(ImageSource.camera),
        ),
        _attachButton(
          Icons.videocam_rounded,
          'Video',
          _addVideo,
        ),
        _attachButton(
          recording ? Icons.stop_circle_rounded : Icons.mic_rounded,
          recording ? 'Dayandır' : 'Səs',
          recording ? _stopRecording : _startRecording,
        ),
      ],
    );
  }

  Widget _attachButton(IconData icon, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: PressableScale(
        onTap: posting ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: vLine),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: vMuted),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(color: vMuted, fontSize: 12.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _footer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: vLine)),
      ),
      child: Row(
        children: [
          const Icon(Icons.public_rounded, size: 15, color: vMuted),
          const SizedBox(width: 7),
          const Expanded(
            child: Text(
              'Hər kəs görə bilər',
              style: TextStyle(color: vMuted, fontSize: 12.5),
            ),
          ),
          if (photos.isNotEmpty)
            Text(
              '${photos.length}/$_maxImages şəkil',
              style: const TextStyle(color: vMuted, fontSize: 12),
            ),
        ],
      ),
    );
  }
}

/// Paylaşan şəxsin profil şəkli.
class _MyAvatar extends StatelessWidget {
  const _MyAvatar({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(profile.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? const <String, dynamic>{};
        return VibePhoto(
          url: '${data['photoUrl'] ?? ''}',
          name: profile.name,
          emoji: '${data['avatarEmoji'] ?? ''}',
        );
      },
    );
  }
}
