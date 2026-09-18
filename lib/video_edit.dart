import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class VideoEditPage extends StatefulWidget {
  const VideoEditPage({
    super.key,
    required this.videoId,
    required this.data,
  });

  final String videoId;
  final Map<String, dynamic> data;

  @override
  State<VideoEditPage> createState() => _VideoEditPageState();
}

class _VideoEditPageState extends State<VideoEditPage> {
  late final TextEditingController caption;
  late String visibility;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    caption = TextEditingController(
      text: '${widget.data['caption'] ?? ''}',
    );
    visibility = '${widget.data['visibility'] ?? 'public'}';
  }

  Future<void> save() async {
    if (saving) return;

    setState(() => saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('videos')
          .doc(widget.videoId)
          .set({
        'caption': caption.text.trim(),
        'visibility': visibility,
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));

      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff070510),
      appBar: AppBar(
        backgroundColor: const Color(0xff0b0711),
        title: const Text(
          'Videonu düzəlt',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : save,
            child: Text(saving ? 'Saxlanır...' : 'Saxla'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: caption,
            maxLines: 5,
            maxLength: 2200,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Başlıq',
              labelStyle: const TextStyle(color: Colors.white70),
              filled: true,
              fillColor: const Color(0xff151020),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: visibility,
            dropdownColor: const Color(0xff151020),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Görünürlük',
              labelStyle: const TextStyle(color: Colors.white70),
              filled: true,
              fillColor: const Color(0xff151020),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
            ),
            items: const [
              DropdownMenuItem(
                value: 'public',
                child: Text('Public'),
              ),
              DropdownMenuItem(
                value: 'private',
                child: Text('Gizli'),
              ),
            ],
            onChanged: (v) {
              if (v != null) setState(() => visibility = v);
            },
          ),
        ],
      ),
    );
  }
}
