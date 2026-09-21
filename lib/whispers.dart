import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';

import 'media_upload.dart';
import 'ui/vibe_design.dart';
import 'user_profile.dart';
import 'voice/audio_file.dart';
import 'voice/moment_voice.dart';
import 'voice/voice_fx.dart';
import 'voice/waveform.dart';
import 'app/i18n.dart';

/// Pıçıltı — anonim səs divarı.
///
/// Adsız, şəkilsiz 20 saniyəlik səs. Kimin dediyi görünmür, amma
/// sənəddə saxlanılır: anonimlik oxuyan üçündür, məsuliyyətdən azad
/// etmir. Şikayət olunanda moderator kimin yazdığını görə bilir.
///
/// Bu, tətbiqin ən riskli hissəsidir, ona görə qaydalar sərtdir:
/// hər yazının yanında şikayət düyməsi var və üç şikayətdən sonra
/// yazı avtomatik gizlənir.
const int whisperSeconds = 20;

/// Bu qədər şikayətdən sonra yazı gizlənir.
const int whisperHideAfterReports = 3;

/// Anonim ad — sənəd açarından çıxarılır.
///
/// Eyni yazı hər cihazda eyni adla görünür, amma ad heç bir profilə
/// aparmır. Məqsəd söhbətə tutacaq vermək, kimliyi açmaq deyil.
String whisperAlias(String id) {
  const names = [
    'Gecə quşu', 'Sakit külək', 'Uzaq səs', 'Kölgə', 'Ulduz',
    'Yağış', 'Dəniz', 'Qərib', 'Tənha yol', 'Payız',
    'Səhər', 'Duman', 'Alov', 'Qar', 'Sükut',
  ];

  var sum = 0;
  for (final code in id.codeUnits) {
    sum = (sum + code) % 100000;
  }

  return names[sum % names.length];
}

/// Anonim rəng — eyni yazı həmişə eyni rəngdə görünsün.
Color whisperColor(String id) {
  const colors = [
    Color(0xff8b5cff),
    Color(0xff22a7ff),
    Color(0xffff2bd6),
    Color(0xff2de28a),
    Color(0xffffd458),
    Color(0xffff8a3d),
  ];

  var sum = 0;
  for (final code in id.codeUnits) {
    sum = (sum + code * 7) % 100000;
  }

  return colors[sum % colors.length];
}

/// Yazı gizlədilməlidirmi?
bool whisperHidden(Map<String, dynamic> data) {
  final reports = int.tryParse('${data['reportCount'] ?? 0}') ?? 0;
  return data['hidden'] == true || reports >= whisperHideAfterReports;
}

// ============================================================
// EKRAN
// ============================================================

class WhispersPage extends StatefulWidget {
  const WhispersPage({super.key, required this.profile, this.database});

  final UserProfile profile;
  final FirebaseFirestore? database;

  @override
  State<WhispersPage> createState() => _WhispersPageState();
}

class _WhispersPageState extends State<WhispersPage> {
  FirebaseFirestore get db => widget.database ?? FirebaseFirestore.instance;

  final recorder = AudioRecorder();
  final clock = Stopwatch();
  Timer? ticker;

  bool recording = false;
  bool sending = false;
  int elapsed = 0;

  /// Səs maskası — anonimliyi gücləndirir və əylənclidir.
  VoiceFx fx = VoiceFx.none;

  @override
  void dispose() {
    ticker?.cancel();
    recorder.dispose();
    super.dispose();
  }

  void _say(String text) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(text)));

  Future<void> _start() async {
    if (recording || sending) return;

    try {
      if (!await recorder.hasPermission()) {
        _say('Mikrofona icazə verilməyib.');
        return;
      }

      final path = await newRecordingPath();

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
        elapsed = 0;
      });

      ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (!mounted) return;
        setState(() => elapsed = clock.elapsedMilliseconds);
        if (elapsed >= whisperSeconds * 1000) _stop();
      });
    } catch (_) {
      if (mounted) _say('Səs yazılmadı. İcazəni yoxla.');
    }
  }

  Future<void> _stop() async {
    if (!recording) return;

    ticker?.cancel();
    clock.stop();

    setState(() {
      recording = false;
      sending = true;
    });

    try {
      final path = await recorder.stop();
      if (path == null) throw StateError('fayl');

      final bytes = await XFile(path).readAsBytes();

      if (clock.elapsedMilliseconds < 1000 || bytes.length <= 44) {
        if (mounted) {
          setState(() => sending = false);
          _say('Çox qısadır. Ən azı bir saniyə danış.');
        }
        return;
      }

      await _publish(bytes, clock.elapsedMilliseconds);
    } catch (_) {
      if (!mounted) return;
      setState(() => sending = false);
      _say('Göndərilmədi. Bağlantını yoxla.');
    }
  }

  Future<void> _publish(Uint8List raw, int durationMs) async {
    final id = db.collection('whispers').doc().id;

    // Maska tətbiq olunur; ton dəyişəndə uzunluq da dəyişir,
    // ona görə müddət yenidən hesablanır.
    final bytes = applyVoiceFx(raw, fx);
    final length = fx == VoiceFx.none ? durationMs : wavDurationMs(bytes);

    final url = await MediaUpload.upload(
      bucket: MediaUpload.videoBucket,
      path: 'whispers/$id.wav',
      bytes: bytes,
      contentType: 'audio/wav',
    );

    await db.collection('whispers').doc(id).set({
      'audioUrl': url,
      'audioMs': length,
      'audioWave': waveformFromWav(bytes),
      // Anonimlik oxuyan üçündür: ad ekranda görünmür, amma sənəddə
      // qalır ki, şikayət olunanda moderator kimi tapa bilsin.
      'authorUid': widget.profile.uid,
      'likeCount': 0,
      'reportCount': 0,
      'hidden': false,
      'createdAt': Timestamp.now(),
    });

    if (!mounted) return;
    setState(() => sending = false);
    _say('Pıçıltın divara düşdü.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: vBg,
      appBar: AppBar(
        backgroundColor: const Color(0xff0b0711),
        title: const Text(
          'Pıçıltı',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: Column(
        children: [
          _intro(),
          Expanded(child: _list()),
          _recorder(),
        ],
      ),
    );
  }

  Widget _intro() => Container(
        margin: const EdgeInsets.fromLTRB(14, 12, 14, 6),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: vPanel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: vLine),
        ),
        child: const Row(
          children: [
            Text('🤫', style: TextStyle(fontSize: 22)),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Adsız 20 saniyə. Kimin dediyi görünmür — amma söyüş, '
                'təhqir və şəxsi məlumat qadağandır.',
                style: TextStyle(color: vMuted, fontSize: 12, height: 1.4),
              ),
            ),
          ],
        ),
      );

  Widget _list() {
    final query = db
        .collection('whispers')
        .orderBy('createdAt', descending: true)
        .limit(50);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Text(t('Yüklənmədi.'), style: TextStyle(color: Colors.white70)),
          );
        }

        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: vPink));
        }

        final docs =
            snap.data!.docs.where((doc) => !whisperHidden(doc.data())).toList();

        if (docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Text(
                'Divar boşdur.\nBirinci pıçıltı sənin olsun.',
                textAlign: TextAlign.center,
                style: TextStyle(color: vMuted, height: 1.5),
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) => _card(docs[i]),
        );
      },
    );
  }

  Widget _card(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final alias = whisperAlias(doc.id);
    final color = whisperColor(doc.id);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: vPanel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: color.withValues(alpha: .25),
                child: Text(
                  alias.characters.first,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Text(
                alias,
                style: TextStyle(
                  color: color,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              _likeButton(doc),
              IconButton(
                tooltip: t('Şikayət et'),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.flag_outlined, size: 17, color: vMuted),
                onPressed: () => _report(doc),
              ),
            ],
          ),
          const SizedBox(height: 10),
          MomentVoice(
            url: '${d['audioUrl'] ?? ''}',
            durationMs: int.tryParse('${d['audioMs'] ?? 0}') ?? 0,
            waveform: waveformFromData(d['audioWave']),
            name: alias,
          ),
        ],
      ),
    );
  }

  Widget _likeButton(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final count = int.tryParse('${doc.data()['likeCount'] ?? 0}') ?? 0;

    return GestureDetector(
      onTap: () => doc.reference.set(
        {'likeCount': FieldValue.increment(1)},
        SetOptions(merge: true),
      ),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.favorite_rounded, size: 15, color: vPink),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _report(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: const Color(0xff151020),
        title: const Text(
          'Şikayət et',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: const Text(
          'Bu pıçıltı qaydalara ziddirsə şikayət et. '
          'Üç şikayətdən sonra avtomatik gizlənir və moderator baxır.',
          style: TextStyle(color: vMuted, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('İmtina', style: TextStyle(color: vMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text(
              'Şikayət et',
              style: TextStyle(
                color: Color(0xffff657b),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );

    if (yes != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);

    try {
      await doc.reference.set(
        {'reportCount': FieldValue.increment(1)},
        SetOptions(merge: true),
      );

      await db.collection('reports').add({
        'type': 'whisper',
        'whisperId': doc.id,
        'reporterUid': widget.profile.uid,
        'reason': 'Anonim səs',
        'status': 'new',
        'createdAt': Timestamp.now(),
      });

      messenger.showSnackBar(
        SnackBar(content: Text(t('Şikayət göndərildi.'))),
      );
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(t('Alınmadı.'))));
    }
  }

  Widget _recorder() {
    final seconds = (elapsed / 1000).round();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      decoration: const BoxDecoration(
        color: Color(0xff0f0a1a),
        border: Border(top: BorderSide(color: Color(0xff2a1f3d))),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _fxRow(),
            const SizedBox(height: 12),
            Row(
          children: [
            Expanded(
              child: Text(
                recording
                    ? 'Yazılır… $seconds/$whisperSeconds san'
                    : sending
                        ? 'Göndərilir…'
                        : 'Basıb saxla, danış, burax',
                style: TextStyle(
                  color: recording ? vPink : vMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            GestureDetector(
              onTapDown: (_) => _start(),
              onTapUp: (_) => _stop(),
              onTapCancel: _stop,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: recording ? 68 : 58,
                height: recording ? 68 : 58,
                decoration: BoxDecoration(
                  gradient: vHot,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: vPink.withValues(alpha: recording ? .5 : .25),
                      blurRadius: recording ? 24 : 12,
                    ),
                  ],
                ),
                child: Icon(
                  sending
                      ? Icons.hourglass_top_rounded
                      : recording
                          ? Icons.stop_rounded
                          : Icons.mic_rounded,
                  color: Colors.white,
                  size: recording ? 30 : 26,
                ),
              ),
            ),
          ],
            ),
          ],
        ),
      ),
    );
  }

  /// Maska seçimi.
  Widget _fxRow() => SizedBox(
        height: 32,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final value in VoiceFx.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: recording ? null : () => setState(() => fx = value),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: fx == value
                          ? vPink.withValues(alpha: .18)
                          : Colors.white.withValues(alpha: .05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: fx == value ? vPink : Colors.white12,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(value.emoji,
                            style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 6),
                        Text(
                          value.label,
                          style: TextStyle(
                            color: fx == value ? Colors.white : vMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}
