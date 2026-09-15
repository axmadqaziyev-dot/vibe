import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show Supabase, FileOptions;

const maxVoiceBytes = 12 * 1024 * 1024;
const maxVoiceSeconds = 60;

class VoiceDraft {
  VoiceDraft({
    required this.id,
    required this.bytes,
    required this.durationMs,
  });

  final String id;
  final Uint8List bytes;
  final int durationMs;

  bool uploaded = false;
}

String voiceStoragePath(
  String chatId,
  String senderId,
  String messageId,
) {
  return 'chat_audio/$chatId/$senderId/$messageId/voice.wav';
}

abstract class VoiceStorage {
  Future<void> upload(String path, Uint8List bytes);

  Future<Uint8List?> download(String path);
}

class SupabaseVoiceStorage implements VoiceStorage {
  static const String bucket = 'voice-messages';

  @override
  Future<void> upload(String path, Uint8List bytes) async {
    await Supabase.instance.client.storage
        .from(bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'audio/wav',
            cacheControl: '3600',
            upsert: false,
          ),
        );
  }

  @override
  Future<Uint8List?> download(String path) async {
    final bytes = await Supabase.instance.client.storage
        .from(bucket)
        .download(path);

    return bytes;
  }
}

class VoiceMessageService {
  VoiceMessageService({
    FirebaseFirestore? firestore,
    VoiceStorage? storage,
  })  : db = firestore ?? FirebaseFirestore.instance,
        storage = storage ?? SupabaseVoiceStorage();

  final FirebaseFirestore db;
  final VoiceStorage storage;

  Future<void> send({
    required VoiceDraft draft,
    required String chatId,
    required String senderId,
    required String senderName,
    required String recipientId,
    required String recipientName,
  }) async {
    if (draft.bytes.isEmpty ||
        draft.bytes.length > maxVoiceBytes ||
        draft.durationMs < 500 ||
        draft.durationMs > maxVoiceSeconds * 1000) {
      throw ArgumentError('Invalid voice message.');
    }

    final ids = [senderId, recipientId]..sort();

    if (senderId == recipientId ||
        chatId != ids.join('_') ||
        !RegExp(r'^[A-Za-z0-9]{20}$').hasMatch(draft.id)) {
      throw ArgumentError('Invalid conversation or message id.');
    }

    final chat = db.collection('chats').doc(chatId);

    await chat.set(
      {
        'members': [senderId, recipientId],
        'memberNames': {
          senderId: senderName,
          recipientId: recipientName,
        },
      },
      SetOptions(merge: true),
    );

    final path = voiceStoragePath(
      chatId,
      senderId,
      draft.id,
    );

    if (!draft.uploaded) {
      await storage.upload(path, draft.bytes);
      draft.uploaded = true;
    }

    final message = chat.collection('messages').doc(draft.id);

    await db.runTransaction((transaction) async {
      final snapshot = await transaction.get(message);

      if (snapshot.exists) {
        return;
      }

      transaction.set(
        message,
        {
          'senderId': senderId,
          'text': '',
          'type': 'audio',
          'audioPath': path,
          'durationMs': draft.durationMs,
          'sizeBytes': draft.bytes.length,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );

      transaction.set(
        chat,
        {
          'lastMessage': '🎤 Səsli mesaj',
          'lastSenderId': senderId,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<Uint8List> download(String path) async {
    if (!path.startsWith('chat_audio/')) {
      throw ArgumentError('Invalid audio path.');
    }

    final bytes = await storage.download(path);

    if (bytes == null || bytes.isEmpty) {
      throw StateError('Audio is empty.');
    }

    return bytes;
  }
}