# Giriş (Apple / Google) — konsol addımları

Kod tərəfi hazırdır. Aşağıdakılar yalnız sənin hesablarından edilə bilər.

## 1. Bundle ID-ni dəyiş (məcburi)

Hazırda `com.example.flutterApplication1` — Apple bunu qəbul etmir.

- Xcode → Runner → Signing & Capabilities → Bundle Identifier: məs. `az.vibe.app`
- `ios/Runner/GoogleService-Info.plist` içindəki `BUNDLE_ID` də eyni olmalıdır
  (Firebase Console-dan yeni plist yüklə).
- Android üçün `android/app/build.gradle` → `applicationId`.

## 2. Apple ilə giriş

Kodda artıq var: iOS/macOS-da nativ `sign_in_with_apple` (nonce ilə),
web/Android-də Firebase OAuth axını. `ios/Runner/Runner.entitlements` yaradılıb
və Xcode konfiqurasiyalarına bağlanıb.

Səndən tələb olunanlar:

1. **Apple Developer** (developer.apple.com):
   - Certificates, Identifiers & Profiles → Identifiers → App ID-ni seç →
     **Sign In with Apple** ✔
   - Services ID yarat (web/Android üçün), Return URL:
     `https://vibe-f9d13.firebaseapp.com/__/auth/handler`
   - Keys → yeni Key → **Sign in with Apple** ✔ → `.p8` faylını yüklə
     (Key ID və Team ID lazım olacaq).
2. **Firebase Console** → Authentication → Sign-in method → **Apple**: aktiv et,
   Services ID, Apple Team ID, Key ID və `.p8` açarını daxil et.
3. Xcode → Signing & Capabilities → **+ Capability** → Sign in with Apple
   (entitlements faylı hazırdır, Xcode-da bir dəfə təsdiqləmək lazımdır).

> Apple hesabı olmadan iOS-da sınamaq mümkün deyil — simulyatorda da Apple ID
> ilə daxil olmaq tələb olunur.

## 3. Google ilə giriş

`ios/Runner/GoogleService-Info.plist` faylında `CLIENT_ID` və
`REVERSED_CLIENT_ID` **yoxdur** — bu o deməkdir ki, Firebase-də iOS üçün Google
provayderi hələ aktiv deyil. Ona görə iOS-da Google girişi işləməyəcək.

1. Firebase Console → Authentication → Sign-in method → **Google**: aktiv et.
2. Project Settings → iOS app → yeni `GoogleService-Info.plist` yüklə və
   `ios/Runner/` içindəkini əvəz et (yeni faylda `REVERSED_CLIENT_ID` olacaq).
3. `ios/Runner/Info.plist` faylına əlavə et:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <!-- GoogleService-Info.plist içindəki REVERSED_CLIENT_ID -->
      <string>com.googleusercontent.apps.XXXXXXXX-YYYYYYYY</string>
    </array>
  </dict>
</array>
```

4. Android üçün: Firebase Console-a **SHA-1** və **SHA-256** barmaq izlərini
   əlavə et (`cd android && ./gradlew signingReport`), sonra yeni
   `google-services.json` yüklə.

## 4. Firestore qaydalarını deploy et

Bloklama və "Populyar" sıralaması yeni qaydalara bağlıdır:

```bash
firebase deploy --only firestore:rules
```
