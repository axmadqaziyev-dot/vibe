import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'user_profile.dart';

class CreateMomentPage extends StatefulWidget {
  const CreateMomentPage({super.key, required this.profile});
  final UserProfile profile;

  @override
  State<CreateMomentPage> createState() => _CreateMomentPageState();
}

class _CreateMomentPageState extends State<CreateMomentPage> {
  final caption = TextEditingController();
  XFile? picked;
  Uint8List? bytes;
  bool posting = false;

  Future<void> pickImage() async {
    final result = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 86,
      maxWidth: 1800,
    );
    if (result == null) return;
    final data = await result.readAsBytes();
    if (!mounted) return;
    setState(() {
      picked = result;
      bytes = data;
    });
  }

  Future<void> post() async {
    if (posting || bytes == null) return;
    setState(() => posting = true);

    try {
      final id = FirebaseFirestore.instance.collection('moments').doc().id;
      final ref = FirebaseStorage.instance
          .ref('moments/${widget.profile.uid}/$id.jpg');

      await ref.putData(
        bytes!,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('moments').doc(id).set({
        'id': id,
        'ownerUid': widget.profile.uid,
        'ownerName': widget.profile.name,
        'imageUrl': url,
        'caption': caption.text.trim(),
        'createdAt': Timestamp.now(),
        'visibility': 'public',
      });

      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => posting = false);
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
          'Yeni An',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          TextButton(
            onPressed: posting ? null : post,
            child: Text(posting ? 'Paylaşılır...' : 'Paylaş'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: pickImage,
            child: Container(
              height: 420,
              decoration: BoxDecoration(
                color: const Color(0xff151020),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xff3b2a4e)),
              ),
              child: bytes == null
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_rounded,
                          color: Color(0xffff2bd6),
                          size: 58,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Şəkil seç',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.memory(
                        bytes!,
                        fit: BoxFit.cover,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: caption,
            maxLines: 4,
            maxLength: 500,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Bu an haqqında yaz...',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: const Color(0xff151020),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
