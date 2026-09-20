# VIBE — Play Store və App Store yolu

Hazırkı vəziyyət:

| Platforma | Vəziyyət |
|---|---|
| Veb (kompüter + telefon brauzeri) | ✅ Yayımda — https://vibe-f9d13.web.app, quraşdırıla bilən (PWA) |
| Android APK (birbaşa quraşdırma) | ✅ Yığılır — `build/app/outputs/flutter-apk/` |
| Android AAB (Play Store) | ⚠️ Yığılır, amma **sınaq açarı ilə** imzalanıb — mağazaya yüklənməzdən əvvəl öz açarın lazımdır |
| iOS IPA (App Store) | ⛔ Windows-da yığıla bilməz — Mac və ya Codemagic lazımdır |

---

## 1. Android imza açarı (yalnız sən edə bilərsən)

Açarın şifrəsini mən təyin edə bilmərəm və etməməliyəm. Özün yarat:

```bash
"C:\Program Files\Eclipse Adoptium\jdk-17.0.20.101-hotspot\bin\keytool.exe" -genkey -v -keystore Z:\vibe\android\vibe.jks -keyalg RSA -keysize 2048 -validity 10000 -alias vibe
```

Soruşacaq: şifrə (iki dəfə), ad, təşkilat, şəhər, ölkə kodu (AZ).

**Bu faylı və şifrəni itirmə.** İtirsən, Play Store-da tətbiqi bir daha yeniləyə
bilməzsən — yeni tətbiq kimi yükləmək lazım gələcək.

Sonra `android/key.properties` faylını yarat:

```properties
storePassword=<yazdığın şifrə>
keyPassword=<yazdığın şifrə>
keyAlias=vibe
storeFile=vibe.jks
```

Bu fayl `.gitignore`-a əlavə olunub — repoya düşməyəcək.

Sonra:

```bash
flutter build appbundle --release
```

Nəticə: `build/app/outputs/bundle/release/app-release.aab` — Play Console-a
yüklənəcək fayl.

---

## 2. Play Console

1. https://play.google.com/console — birdəfəlik 25 USD qeydiyyat haqqı
2. **Create app** → ad: VIBE, dil: Azərbaycan, tip: App, pulsuz
3. Tələb olunanlar:
   - Məxfilik siyasəti linki: https://vibe-f9d13.web.app/privacy.html
   - İstifadə şərtləri: https://vibe-f9d13.web.app/terms.html
   - Ekran şəkilləri: ən az 2 telefon şəkli (1080×1920)
   - Feature grafik: 1024×500
   - İkon: 512×512
   - Məzmun reytinqi anketi (sosial tətbiq, 18+)
   - **Data safety** anketi: topladığımız məlumatlar — e-poçt, ad, şəkil,
     yaş, cins, maraqlar, cihaz tokeni
4. **Internal testing** trekində başla, özün sına, sonra Production

Sosial tətbiqlər üçün Google **hesab silmə** tələb edir — o, tətbiqdə var
(Ayarlar → Hesabı sil) və linkini anketdə göstərmək lazımdır.

---

## 3. iOS / App Store

Windows-da IPA yığmaq mümkün deyil. İki yol:

**A. Codemagic (Mac almadan)** — `codemagic.yaml` faylı hazırdır.
1. codemagic.io → GitHub ilə gir → bu reponu bağla
2. Apple Developer Program üzvlüyü (ildə 99 USD)
3. App Store Connect → Users → Integrations → **API açarı** yarat
4. Codemagic → Teams → Code signing identities → açarı əlavə et
5. `ios-release` iş axınını işə sal → IPA avtomatik TestFlight-a gedir

Pulsuz tarif: ayda 500 dəqiqə macOS vaxtı — bir neçə build üçün kifayətdir.

**B. Mac** — Xcode ilə `flutter build ipa`.

Hər iki halda əlavə lazımdır:
- **APNs Auth Key** (push bildirişlər üçün) → Firebase Console → Cloud Messaging
- Sign in with Apple konfiqurasiyası → `SETUP_AUTH.md`

---

## 4. Versiya nömrəsi

`pubspec.yaml` faylında:

```yaml
version: 1.0.0+1
```

`1.0.0` — istifadəçinin gördüyü versiya, `+1` — build nömrəsi.
Mağazaya hər yeni yükləmədə **build nömrəsi artmalıdır**: `1.0.0+2`, `1.0.1+3`…

---

## 5. Bu kompüterdə quraşdırılanlar

APK yığmaq üçün əlavə olundu:

- **Java 17 (Temurin)** → `C:\Program Files\Eclipse Adoptium\` — winget ilə
- **Android SDK** → `Z:\android-sdk\` — silmək üçün qovluğu silmək kifayətdir

Flutter onlara `flutter config` ilə yönəldilib.

Qeyd: layihə `Z:` diskindədir və Kotlin-in artımlı keşi orada işləmir,
ona görə `android/gradle.properties` faylında `kotlin.incremental=false` var.
