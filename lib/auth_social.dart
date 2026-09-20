// SOSİAL GİRİŞ — Google və Apple.
//
// Apple: iOS/macOS-da Apple-ın tələb etdiyi NATIV axın (sign_in_with_apple)
// nonce ilə işlədilir. Web və Android-də Firebase-in OAuth axını qalır.
// Apple ilk girişdə adı yalnız BİR DƏFƏ qaytarır — ona görə dərhal saxlanılır.

import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'install_app.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Apple düyməsi göstərilməlidirmi?
/// iOS/macOS-da məcburidir (App Store qaydası), web-də dəstəklənir.
bool get appleSignInAvailable {
  if (kIsWeb) return true;
  try {
    return Platform.isIOS || Platform.isMacOS;
  } catch (_) {
    return false;
  }
}

/// İstifadəçinin dayandırdığı axın — səhv kimi göstərilmir.
class SignInCancelled implements Exception {
  const SignInCancelled();
}

String _randomNonce([int length = 32]) {
  const charset =
      '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
  final random = Random.secure();
  return List.generate(
    length,
    (_) => charset[random.nextInt(charset.length)],
  ).join();
}

String _sha256(String input) =>
    sha256.convert(utf8.encode(input)).toString();

// ============================================================
// GOOGLE
// ============================================================

Future<UserCredential> signInWithGoogle() async {
  final provider = GoogleAuthProvider()
    ..setCustomParameters({'prompt': 'select_account'});

  if (kIsWeb) return _webSignIn(provider);

  final credential = await FirebaseAuth.instance.signInWithProvider(provider);
  await _saveSocialProfile(credential);
  return credential;
}

/// Vebdə giriş: açılan pəncərə, alınmasa yönləndirmə.
///
/// Ana ekrana qurulmuş tətbiqdə (PWA) açılan pəncərə boş ağ ekran kimi
/// görünür və giriş baş tutmur. Ona görə orada birbaşa yönləndirmə
/// işlədilir — səhifə Google-a keçir, girişdən sonra geri qayıdır.
Future<UserCredential> _webSignIn(AuthProvider provider) async {
  if (isRunningStandalone) {
    await FirebaseAuth.instance.signInWithRedirect(provider);
    // Səhifə yönləndirilir; nəticə `handleRedirectSignIn()` ilə oxunur.
    throw SignInRedirecting();
  }

  try {
    final credential = await FirebaseAuth.instance.signInWithPopup(provider);
    await _saveSocialProfile(credential);
    return credential;
  } on FirebaseAuthException catch (e) {
    const popupProblems = {
      'popup-blocked',
      'popup-closed-by-user',
      'cancelled-popup-request',
      'operation-not-supported-in-this-environment',
      'web-context-canceled',
    };

    if (!popupProblems.contains(e.code)) rethrow;
    if (e.code == 'popup-closed-by-user') throw SignInCancelled();

    // Pəncərə bloklanıbsa yönləndirmə ilə davam edirik.
    await FirebaseAuth.instance.signInWithRedirect(provider);
    throw SignInRedirecting();
  }
}

/// Səhifə Google/Apple-dan qayıdanda nəticəni oxuyur.
///
/// `main()`-də Firebase hazır olandan sonra çağırılır.
Future<void> handleRedirectSignIn() async {
  if (!kIsWeb) return;
  try {
    final result = await FirebaseAuth.instance.getRedirectResult();
    if (result.user != null) await _saveSocialProfile(result);
  } catch (_) {
    // Yönləndirmə yoxdursa və ya alınmayıbsa, adi giriş ekranı qalır.
  }
}

/// Səhifə yönləndirilir — xəta deyil, sadəcə axın davam edir.
class SignInRedirecting implements Exception {}

// ============================================================
// APPLE
// ============================================================

Future<UserCredential> signInWithApple() async {
  // Web və Android: Firebase-in öz OAuth axını.
  if (kIsWeb || !(Platform.isIOS || Platform.isMacOS)) {
    final provider = AppleAuthProvider()
      ..addScope('email')
      ..addScope('name');

    if (kIsWeb) return _webSignIn(provider);

    final credential = await FirebaseAuth.instance.signInWithProvider(provider);
    await _saveSocialProfile(credential);
    return credential;
  }

  // iOS/macOS: nativ "Sign in with Apple".
  final rawNonce = _randomNonce();

  final AuthorizationCredentialAppleID apple;
  try {
    apple = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: _sha256(rawNonce),
    );
  } on SignInWithAppleAuthorizationException catch (e) {
    if (e.code == AuthorizationErrorCode.canceled) {
      throw const SignInCancelled();
    }
    rethrow;
  }

  final oauth = OAuthProvider('apple.com').credential(
    idToken: apple.identityToken,
    rawNonce: rawNonce,
    accessToken: apple.authorizationCode,
  );

  final credential = await FirebaseAuth.instance.signInWithCredential(oauth);

  // Apple adı yalnız ilk girişdə verir — dərhal saxlanılır.
  final fullName = [apple.givenName, apple.familyName]
      .whereType<String>()
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .join(' ');

  await _saveSocialProfile(
    credential,
    fallbackName: fullName.isEmpty ? null : fullName,
    fallbackEmail: apple.email,
  );

  return credential;
}

// ============================================================
// PROFİLİ SAXLA
// ============================================================

/// users/{uid} sənədini yaradır və ya tamamlayır.
/// Mövcud adı/şəkli üzərinə yazmır.
Future<void> _saveSocialProfile(
  UserCredential credential, {
  String? fallbackName,
  String? fallbackEmail,
}) async {
  final user = credential.user;
  if (user == null) return;

  if ((user.displayName == null || user.displayName!.trim().isEmpty) &&
      fallbackName != null) {
    try {
      await user.updateDisplayName(fallbackName);
    } catch (_) {}
  }

  final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);

  try {
    final snapshot = await ref.get();
    final existing = snapshot.data() ?? const <String, dynamic>{};

    final name = '${existing['name'] ?? ''}'.trim().isNotEmpty
        ? '${existing['name']}'
        : (user.displayName?.trim().isNotEmpty == true
              ? user.displayName!.trim()
              : (fallbackName ?? 'VIBE istifadəçisi'));

    final email = '${existing['email'] ?? ''}'.trim().isNotEmpty
        ? '${existing['email']}'
        : (user.email ?? fallbackEmail ?? '');

    await ref.set({
      'uid': user.uid,
      'name': name,
      'email': email,
      if ('${existing['photoUrl'] ?? ''}'.trim().isEmpty &&
          (user.photoURL ?? '').isNotEmpty)
        'photoUrl': user.photoURL,
      'provider': credential.additionalUserInfo?.providerId ?? 'social',
      if (!snapshot.exists) 'createdAt': FieldValue.serverTimestamp(),
      if (!snapshot.exists) 'level': 1,
      if (!snapshot.exists) 'coins': 100,
      'lastSeen': FieldValue.serverTimestamp(),
      'online': true,
    }, SetOptions(merge: true));
  } catch (_) {
    // Profil sonradan da tamamlana bilər; giriş dayandırılmır.
  }
}

/// Firebase xətasını istifadəçi dilinə çevirir.
String describeAuthError(Object error) {
  if (error is SignInCancelled) return '';
  // Səhifə yönləndirilir — istifadəçiyə xəta göstərmirik.
  if (error is SignInRedirecting) return '';

  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'account-exists-with-different-credential':
        return 'Bu e-poçt başqa üsulla qeydiyyatdan keçib. '
            'Əvvəlki üsulla gir, sonra hesabları birləşdir.';
      case 'invalid-credential':
        return 'Giriş məlumatı etibarsızdır. Yenidən sına.';
      case 'operation-not-allowed':
        return 'Bu giriş üsulu Firebase-də aktiv deyil.';
      case 'user-disabled':
        return 'Bu hesab dayandırılıb.';
      case 'network-request-failed':
        return 'İnternet bağlantısı yoxdur.';
      case 'web-context-canceled':
      case 'canceled':
        return '';
      default:
        return error.message ?? 'Giriş alınmadı.';
    }
  }

  if (error is SignInWithAppleAuthorizationException) {
    if (error.code == AuthorizationErrorCode.canceled) return '';
    if (error.code == AuthorizationErrorCode.notHandled ||
        error.code == AuthorizationErrorCode.notInteractive) {
      return 'Apple girişi bu cihazda açılmadı. '
          'Cihazda Apple ID-yə daxil olduğunu yoxla.';
    }
    return 'Apple ilə giriş alınmadı: ${error.message}';
  }

  return 'Giriş alınmadı. Yenidən sına.';
}

/// Qeydiyyat xətasını istifadəçi dilinə çevirir.
String describeRegisterError(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'Bu e-poçtla artıq hesab var. Daxil olmağa çalış.';
      case 'invalid-email':
        return 'E-poçt ünvanı düzgün deyil.';
      case 'weak-password':
        return 'Şifrə zəifdir — ən az 6 simvol olmalıdır.';
      case 'operation-not-allowed':
        return 'E-poçtla qeydiyyat Firebase-də aktiv deyil.';
      case 'network-request-failed':
        return 'İnternet bağlantısı yoxdur.';
      default:
        return error.message ?? 'Qeydiyyat alınmadı. Yenidən sına.';
    }
  }
  return 'Qeydiyyat alınmadı. Yenidən sına.';
}
