// PUSH BİLDİRİŞLƏR (FCM).
//
// Müştəri tərəfi:
//  • icazə istəyir (iOS/Android 13+)
//  • cihaz tokenini users/{uid}/tokens/{token} altında saxlayır
//  • tətbiq açıqkən gələn bildirişi yerli bildiriş kimi göstərir
//  • bildirişə toxunanda müvafiq söhbəti açır
//
// Göndərmə tərəfi Cloud Functions-dadır (functions/index.js).
// Web-də FCM ayrıca VAPID açarı və service worker tələb etdiyi üçün
// bu modul web-də heç nə etmir.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Bildirişə toxunanda açılacaq söhbət — naviqasiya hazır olanda oxunur.
final ValueNotifier<PushTarget?> pendingPushTarget =
    ValueNotifier<PushTarget?>(null);

class PushTarget {
  const PushTarget({required this.uid, required this.name});

  final String uid;
  final String name;
}

/// Arxa planda gələn mesaj. Top-level funksiya olmalıdır.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Sistem bildirişi özü göstərir; burada əlavə iş lazım deyil.
}

const _androidChannel = AndroidNotificationChannel(
  'vibe_messages',
  'VIBE mesajları',
  description: 'Yeni mesaj, izləyici və otaq bildirişləri',
  importance: Importance.high,
);

final _local = FlutterLocalNotificationsPlugin();

bool _started = false;

/// Veb push üçün açıq açar.
///
/// Firebase Console → Project settings → Cloud Messaging →
/// "Web Push certificates" → Generate key pair.
///
/// Açar gizli deyil: hər cihazda tətbiqin içindədir. Boş olduqda
/// vebdə bildiriş sadəcə qurulmur, tətbiq normal işləyir.
const String webPushKey =
    'BDUqKFVsREnGu7Ou-xGLaWjiFqkVWbJgA3Ik9_pIi_mSE-eR4BPmnjyiK0Iys_o8vKd35s4BmrtHySBjHKOnXQA';

/// Giriş edəndən sonra çağırılır.
Future<void> startPushNotifications(String uid) async {
  // Vebdə başqa yol var: yerli bildiriş kitabxanası işləmir, bildirişi
  // xidmət işçisi (firebase-messaging-sw.js) özü göstərir.
  if (kIsWeb) {
    await _startWeb(uid);
    return;
  }
  if (_started) {
    await _saveToken(uid);
    return;
  }
  _started = true;

  try {
    final messaging = FirebaseMessaging.instance;

    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return;
    }

    // Yerli bildiriş kanalı (tətbiq açıq olanda göstərmək üçün)
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.contains('|')) {
          final parts = payload.split('|');
          pendingPushTarget.value = PushTarget(uid: parts[0], name: parts[1]);
        }
      },
    );

    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_androidChannel);

    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Tətbiq açıqkən gələn bildiriş
    FirebaseMessaging.onMessage.listen(_showLocal);

    // Bildirişə toxunub tətbiqi açdı
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

    // Tətbiq bağlı ikən bildirişdən açılıb
    final initial = await messaging.getInitialMessage();
    if (initial != null) _handleTap(initial);

    // Token yenilənəndə yenidən saxla
    messaging.onTokenRefresh.listen((token) => _writeToken(uid, token));

    await _saveToken(uid);
  } catch (_) {
    // Bildirişlər işləməsə də tətbiq normal davam edir.
  }
}

void _showLocal(RemoteMessage message) {
  final notification = message.notification;
  if (notification == null) return;

  final data = message.data;
  final payload = '${data['fromUid'] ?? ''}|${data['fromName'] ?? ''}';

  _local.show(
    id: notification.hashCode,
    title: notification.title,
    body: notification.body,
    payload: payload,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        _androidChannel.id,
        _androidChannel.name,
        channelDescription: _androidChannel.description,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(),
    ),
  );
}

void _handleTap(RemoteMessage message) {
  final uid = '${message.data['fromUid'] ?? ''}';
  if (uid.isEmpty) return;
  pendingPushTarget.value = PushTarget(
    uid: uid,
    name: '${message.data['fromName'] ?? 'İstifadəçi'}',
  );
}



/// Vebdə bildiriş icazəsi hansı haldadır?
///
/// `null` — hələ soruşulmayıb (düymə göstərilməlidir).
/// `true` — icazə var. `false` — rədd edilib, artıq soruşmaq olmaz.
Future<bool?> webPushStatus() async {
  if (!kIsWeb || webPushKey.isEmpty) return true;

  try {
    final settings =
        await FirebaseMessaging.instance.getNotificationSettings();

    return switch (settings.authorizationStatus) {
      AuthorizationStatus.notDetermined => null,
      AuthorizationStatus.denied => false,
      _ => true,
    };
  } catch (_) {
    return true;
  }
}

/// İstifadəçi düyməyə basanda icazə soruşur.
Future<bool> askWebPush(String uid) async {
  await _startWeb(uid, ask: true);
  return (await webPushStatus()) == true;
}

/// Vebdə bildirişi qurur.
///
/// İki şərt var: səhifə HTTPS olmalıdır və istifadəçi icazə verməlidir.
/// iPhone-da əlavə şərt: tətbiq ana ekrana əlavə edilməlidir — Apple
/// brauzer sekməsində veb bildirişə icazə vermir.
Future<void> _startWeb(String uid, {bool ask = false}) async {
  if (webPushKey.isEmpty) return;

  try {
    final messaging = FirebaseMessaging.instance;

    // iPhone icazə pəncərəsini yalnız istifadəçi toxunanda açır.
    // Avtomatik çağırış Safari tərəfindən sakitcə rədd edilir, ona görə
    // açılışda yalnız mövcud vəziyyətə baxırıq; soruşmaq düymədən gəlir.
    var settings = await messaging.getNotificationSettings();

    if (settings.authorizationStatus == AuthorizationStatus.notDetermined) {
      if (!ask) return;
      settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    final token = await messaging.getToken(vapidKey: webPushKey);
    if (token != null && token.isNotEmpty) await _writeToken(uid, token);

    // Açar cihazda dəyişə bilər (brauzer yenilənəndə) — izləyirik.
    messaging.onTokenRefresh.listen((fresh) => _writeToken(uid, fresh));

    // Tətbiq açıq olanda gələn bildiriş: burada ayrıca göstərmirik,
    // çünki mesaj səsi (`message_chime.dart`) onsuz da xəbər verir və
    // iki bildiriş üst-üstə düşərdi.
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final data = message.data;
      final from = '${data['fromUid'] ?? ''}';
      final name = '${data['fromName'] ?? ''}';
      if (from.isNotEmpty) {
        pendingPushTarget.value = PushTarget(uid: from, name: name);
      }
    });
  } catch (_) {
    // Bildiriş qurulmasa da tətbiq normal işləməlidir.
  }
}

Future<void> _saveToken(String uid) async {
  try {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await _writeToken(uid, token);
  } catch (_) {}
}

Future<void> _writeToken(String uid, String token) async {
  try {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('tokens')
        .doc(token)
        .set({
          'token': token,
          'platform': defaultTargetPlatform.name,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  } catch (_) {}
}

/// Çıxış edəndə bu cihazın tokenini silir — başqası girəndə
/// köhnə istifadəçinin bildirişləri gəlməsin.
Future<void> stopPushNotifications(String uid) async {
  if (kIsWeb) return;
  try {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('tokens')
        .doc(token)
        .delete();
  } catch (_) {}
}
