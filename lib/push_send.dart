import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Push bildirişin GÖNDƏRİLMƏSİ.
///
/// Firebase Cloud Functions pullu Blaze planı tələb etdiyi üçün göndərmə
/// Supabase Edge Function-a köçürülüb (`supabase/functions/send-push`).
/// Ünvan boş olduqda funksiya sakitcə heç nə etmir — yəni deploy edilənə
/// qədər tətbiq normal işləyir, sadəcə bildiriş getmir.
///
/// Deploy etdikdən sonra alınan URL-i buraya yaz.
const String pushFunctionUrl = '';

/// [toUid] istifadəçisinin bütün cihazlarına bildiriş göndərir.
///
/// Səhv olarsa səssizcə keçir: bildiriş getməməsi mesajın göndərilməsini
/// dayandırmamalıdır.
Future<void> sendPushToUser({
  required String toUid,
  required String title,
  required String body,
  String type = 'message',
  String? fromName,
  FirebaseFirestore? database,
}) async {
  if (pushFunctionUrl.isEmpty) return;

  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid == toUid) return;

    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) return;

    final db = database ?? FirebaseFirestore.instance;
    final tokens = await db
        .collection('users')
        .doc(toUid)
        .collection('tokens')
        .limit(20)
        .get();

    final ids = tokens.docs.map((doc) => doc.id).where((id) => id.isNotEmpty);
    if (ids.isEmpty) return;

    await http
        .post(
          Uri.parse(pushFunctionUrl),
          headers: {
            'authorization': 'Bearer $idToken',
            'content-type': 'application/json',
          },
          body: jsonEncode({
            'tokens': ids.toList(),
            'title': title,
            'body': body,
            'type': type,
            if (fromName != null) 'fromName': fromName,
          }),
        )
        .timeout(const Duration(seconds: 8));
  } catch (_) {
    // Bildiriş getməsə də əsas əməliyyat davam edir.
  }
}
