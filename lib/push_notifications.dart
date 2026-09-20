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

/// Giriş edəndən sonra çağırılır.
Future<void> startPushNotifications(String uid) async {
  if (kIsWeb) return; // web üçün ayrıca VAPID quraşdırması lazımdır
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
