# VIBE — App Store / Google Play buraxılış siyahısı

Kodda hazır olanlar ✅ və yalnız sənin hesablarından edilə biləcəklər ⚠️.

---

## ✅ 1. Bundle ID — EDİLDİ

`com.example.flutterApplication1` → **`az.vibe.app`**

Firebase CLI ilə layihəyə yeni Android və iOS tətbiqi əlavə olundu, konfiqurasiya
faylları yüklənib əvəz edildi:

- `android/app/build.gradle.kts` → `namespace` + `applicationId`
- `MainActivity.kt` → `az/vibe/app/` qovluğuna köçürüldü
- Xcode → `PRODUCT_BUNDLE_IDENTIFIER`
- `google-services.json`, `GoogleService-Info.plist` → yeniləndi
- `lib/firebase_options.dart`, `firebase.json` → yeni app ID-lər
- `Info.plist` → Google girişi üçün `REVERSED_CLIENT_ID` URL sxemi

> Köhnə tətbiqlər Firebase-də qalır — silmə, zərəri yoxdur.

⚠️ Android quraşdırması bu kompyuterdə yoxdur (`No Android SDK`), ona görə APK
build-i yoxlanmayıb. Android Studio olan cihazda `flutter build apk` işlətmək
lazımdır.

---

## ✅ 2. Hazır olanlar

| Tələb | Vəziyyət |
|---|---|
| Hesabın tətbiq daxilindən silinməsi (Guideline 5.1.1v) | Ayarlar → «Hesabı həmişəlik sil» (iki təsdiqli) |
| İstifadə şərtləri + icma qaydaları | Qeydiyyatda məcburi qəbul + Ayarlarda keçidlər |
| Uyğunsuz məzmun süzgəci (Guideline 1.2) | Söhbət, otaq və an mətnlərində söz filtri |
| Şikayət mexanizmi | Profil və mesaj menyularında |
| İstifadəçini bloklamaq | İki tərəfli + Firestore qaydası ilə server tərəfdə |
| Tərtibatçı ilə əlaqə | Ayarlar → Dəstək (`asifnasrullazade@gmail.com`) |
| 18+ yaş yoxlaması | Qeydiyyatda |
| iOS icazə mətnləri | Kamera, mikrofon, qalereya — `Info.plist` |
| Tətbiq ikonu | `assets/icon/` + bütün platformalar üçün generasiya olunub |
| Tətbiq adı | iOS `VIBE`, Android `VIBE` |
| Sign in with Apple (kod) | Nativ axın + entitlements |
| Firestore indeksləri | `firestore.indexes.json` |

İkonu yenidən yaratmaq lazım olsa:

```bash
flutter test test/app_icon_test.dart && dart run flutter_launcher_icons
```

---

## 🔴 3. Firebase Storage QURULMAYIB

Deploy sınayarkən aşkar etdim: layihədə **Storage aktiv deyil**. Bu səbəbdən
profil şəkli, örtük, qalereya, an, video və səsli mesaj **heç vaxt yüklənmir**.

→ [Console → Storage → Get Started](https://console.firebase.google.com/project/vibe-f9d13/storage)

Sonra:

```bash
firebase deploy --only storage
```

---

## ⚠️ 4. Push bildirişlər — kod hazırdır, Blaze planı lazımdır

Müştəri tərəfi (`lib/push_notifications.dart`) və göndərən tərəf
(`functions/index.js`) hazırdır: yeni mesaj, izləmə/bəyənmə və otaq hədiyyəsi
üçün bildiriş gedir; bloklanmış istifadəçiyə göndərilmir; ölü tokenlər
avtomatik təmizlənir.

1. [Blaze planına keç](https://console.firebase.google.com/project/vibe-f9d13/usage/details)
   (istifadə az olanda praktiki olaraq pulsuzdur)
2. ```bash
   cd functions && npm install
   firebase deploy --only functions
   ```
3. **iOS üçün ƏLAVƏ**: Apple Developer → Keys → yeni **APNs Auth Key** (`.p8`)
   → Firebase Console → Project settings → Cloud Messaging → APNs açarını yüklə.
   Bunsuz iOS-da push getmir.
4. Xcode → Signing & Capabilities → **+ Push Notifications**
   (entitlements faylı hazırdır; buraxlış üçün `aps-environment` = `production` et)

> Web-də push quraşdırılmayıb (ayrıca VAPID açarı və service worker tələb edir).

---

## ⚠️ 5. Firebase Console addımları

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage
```

Authentication → Sign-in method:
- **Email/Password** — aktiv olmalıdır
- **Google** — aktiv et, sonra yeni `GoogleService-Info.plist` yüklə
  (hazırkı faylda `REVERSED_CLIENT_ID` yoxdur, ona görə iOS-da Google işləmir)
- **Apple** — Services ID, Team ID, Key ID və `.p8` açarı

Detallar: [SETUP_AUTH.md](SETUP_AUTH.md)

---

## ⚠️ 6. Hüquqi səhifələri yayımla

Apple **ictimai Privacy Policy URL** tələb edir. Səhifələr hazırdır:

```bash
flutter build web --release
firebase deploy --only hosting
```

Sonra bu linkləri App Store Connect-ə yaz:
- Privacy Policy: `https://vibe-f9d13.web.app/privacy.html`
- Terms (EULA): `https://vibe-f9d13.web.app/terms.html`
- Support URL: `https://vibe-f9d13.web.app/rules.html`

---

## ⚠️ 7. App Store Connect

- **Yaş reytinqi: 17+** — filtrsiz istifadəçi məzmunu və söhbət var.
  Anketdə «Unrestricted Web Access» = Yox, «User Generated Content» = Bəli.
- **Ekran şəkilləri**: 6.7" (1290×2796) və 6.5" — ən azı 3 ədəd.
- **Demo hesab**: Apple-a test üçün e-poçt/şifrə ver (App Review Information).
  Hesabsız tətbiq boş görünür — mütləq ver.
- **Review qeydi**: «Virtual coins have no monetary value and cannot be
  purchased or cashed out. No real-money gambling.»

---

## ⚠️ 8. Buraxılışdan əvvəl bilməli olduqların

1. **Səsli otaqlarda real səs yoxdur.** Oturacaqlar, mikrofon icazəsi,
   hədiyyələr və çat işləyir; səs ötürülməsi üçün SFU xidməti lazımdır
   (Agora / ZEGOCLOUD / LiveKit). Açar versən inteqrasiya edərəm.
   Bunsuz «səsli otaq» adını mağazada vəd etmə.
2. **Push bildirişlər** kodda hazırdır, Blaze planı və APNs açarı gözləyir
   (yuxarıda 4-cü bənd).
3. **Moderasiya insan tələb edir.** Şikayətlər `reports` kolleksiyasına düşür;
   Admin paneldən baxılır. Apple 24 saat ərzində cavab verilməsini gözləyir.
4. **Dəstək e-poçtu şəxsi ünvanındır** — istəsən `lib/legal.dart` içindəki
   `supportEmail` dəyərini ayrıca ünvanla əvəz et.

---

## Buraxılış əmrləri

```bash
flutter clean && flutter pub get
flutter analyze
flutter test
flutter build ipa --release        # iOS (Mac lazımdır)
flutter build appbundle --release  # Android
```
