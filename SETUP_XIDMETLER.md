# VIBE — sənin tərəfindən edilməli qurulmalar

Kod tərəfi hazırdır. Aşağıdakılar hesab/panel işidir — heç biri ödəniş tələb etmir.

---

## 1. Supabase: video yaddaşı — HAZIRDIR ✅

Video və səsli mesajlar Firebase Storage (pullu Blaze planı) əvəzinə
Supabase Storage-da saxlanılır.

Layihə: `txjqqohqownpfcokscep` (Frankfurt, pulsuz plan).
Bucket-lər: `videos` və `voice-messages` — hər ikisi public.
İcazə qaydaları `storage.objects` üzərində qurulub.

Yoxlanılıb: yükləmə, oxuma və silmə işləyir.

**Gələcək üçün qeyd:** hazırda yükləmə icazəsi açıqdır — tətbiqin açarı
istifadəçilərin cihazındadır, ona görə onu götürən kənar adam da fayl ata
bilər. İstifadəçi sayı artanda yükləməni Edge Function üzərindən keçirmək
lazım gələcək (push funksiyası kimi).

---

## 2. Push bildirişlər (pulsuz yol)

Firebase Cloud Functions Blaze planı tələb edir. Onun əvəzinə eyni işi görən
Supabase Edge Function yazıldı: `supabase/functions/send-push/index.ts`.

```bash
npm install -g supabase
supabase login
supabase link --project-ref txjqqohqownpfcokscep
```

Sonra iki sirr əlavə et:

1. Firebase Console → **Project settings → Service accounts** →
   *Generate new private key* → JSON faylı endir.
2. Firebase Console → **Project settings → General** → *Web API Key* kopyala.

```bash
supabase secrets set FIREBASE_SERVICE_ACCOUNT="$(cat service-account.json)"
supabase secrets set FIREBASE_API_KEY="<Web API Key>"
supabase functions deploy send-push
```

Alınan URL-i `lib/push_send.dart` faylındakı `pushFunctionUrl` sabitinə yaz:

```dart
const String pushFunctionUrl =
    'https://txjqqohqownpfcokscep.supabase.co/functions/v1/send-push';
```

**Vacib:** JSON açar faylını repoya əlavə etmə — yalnız `supabase secrets`-də saxla.

iOS üçün əlavə olaraq Apple Developer hesabında **APNs Auth Key** yaradıb
Firebase Console → Cloud Messaging bölməsinə yükləmək lazımdır.

---

## 3. Canlı səs (artıq işləyir, limiti bil)

Otaqlarda səs WebRTC "mesh" ilə qurulub — əlavə xidmət, hesab və ödəniş yoxdur.
Siqnallaşma Firestore üzərindən gedir, qaydalar yayımlandı.

Limit: eyni anda **8 birbaşa bağlantı** (`RoomAudio.maxPeers`). Kiçik otaqlar
üçün kifayətdir. Otaqlar böyüyəndə (20+ dinləyici) SFU lazım olacaq —
Agora/LiveKit/ZEGOCLOUD-un kartsız pulsuz tarifi var. O halda yalnız
`lib/voice/room_audio.dart` dəyişəcək, qalan kod olduğu kimi qalır.

Brauzerdə səs yalnız HTTPS-də işləyir — hosting onsuz da HTTPS-dir.

---

## 4. Crashlytics və Analytics

Kod qoşulub, Firebase-in pulsuz Spark planına daxildir. Əlavə iş yoxdur.
İlk çökmə hesabatı üçün tətbiqi telefonda aç və bağla —
Firebase Console → Crashlytics bölməsində görünəcək.

Qeyd: Crashlytics veb-də işləmir, yalnız iOS/Android.

---

## 5. Apple Developer (mağaza üçün)

- Apple Developer Program üzvlüyü (illik 99 USD) — yalnız App Store-a çıxmaq üçün
- Sign in with Apple konfiqurasiyası: `SETUP_AUTH.md`
- Buraxılış addımları: `RELEASE.md`
