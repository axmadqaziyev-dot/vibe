# Firebase → Supabase keçidi

Tətbiqin bütün məlumatı Firestore-dadır. Hədəf: hər şeyi Supabase-ə keçirmək.
Bu sənəd nəyin hazır olduğunu və növbəti addımı göstərir.

## Nə hazırdır

| Fayl | Nə edir |
|---|---|
| `supabase/migrations/0001_schema.sql` | 36 cədvəl — Firestore-dakı 31 kolleksiyanın qarşılığı |
| `supabase/migrations/0002_rls.sql` | Təhlükəsizlik qaydaları — `firestore.rules` faylının əvəzi |
| `supabase/migrations/0003_functions.sql` | Hədiyyə, gündəlik mükafat, kürsü tutma, sayğaclar, canlı yayım |
| `tools/migrate_firestore.mjs` | Firestore-dakı məlumatı oxuyub Supabase-ə yazır |

Üç SQL faylı Postgres analizatorundan keçirilib, sintaksis səhvi yoxdur.

## Nə dəyişir

Firestore sənəd saxlayır, Postgres cədvəl. Bir neçə yer qəsdən başqa cür qurulub:

- **Kürsülər.** Əvvəl otaq sənədinin içində xəritə idi (`seats: {"0": {...}}`).
  İki nəfər eyni anda basanda ikincisi birincinin üstünə yazırdı.
  İndi `room_seats` ayrı cədvəldir, unikal şərtlə — ikinci basış sadəcə qayıdır.
- **Sikkələr.** Əvvəl müştəri öz balansını yazırdı. İndi `send_gift()` və
  `claim_daily_reward()` server funksiyalarıdır; balansı yalnız onlar dəyişir.
  Beləcə pulsuz hədiyyə göndərmək mümkün deyil.
- **İzləmə/blok.** `followers` + `following` iki kolleksiya idi, indi bir cədvəl.
- **Sayğaclar.** Bəyənmə sayı əl ilə artırılırdı; indi tətik özü saxlayır.

## ✅ 1-ci addım: cədvəlləri yarat — BİTDİ

Panelə gir → **SQL Editor** → faylları **ardıcıllıqla** yapışdırıb işə sal:

1. `supabase/migrations/0001_schema.sql`
2. `supabase/migrations/0002_rls.sql`
3. `supabase/migrations/0003_functions.sql`

Sıra vacibdir — ikincisi birincinin cədvəllərinə baxır.
Xəta çıxsa mətnini mənə göndər.

## ✅ 2-ci addım: məlumatı köçür — BİTDİ

21.09.2026 tarixində köçürüldü: 12 profil, 12 söhbət, 76 mesaj,
24 üzvlük, 16 sikkə hərəkəti, 7 bildiriş, 3 izləmə, 2 otaq, 14 kürsü.
Təkrar lazım olsa əvvəlcə `supabase/temizle_ve_duzelt.sql` işə salınmalıdır,
yoxsa sətirlər ikiləşər.

<details><summary>Necə edilmişdi</summary>

Firebase açarı lazımdır:
**Firebase konsolu → Project settings → Service accounts → Generate new private key.**
Yüklənən JSON faylı **repoya qoyma və mənə göndərmə** — kompüterində saxla.

Supabase `service_role` açarı: **Project Settings → API**. O da gizlidir.

```bash
cd tools
npm install
```

Əvvəl sınaq (heç nə yazılmır, yalnız say göstərir):

```bash
FIREBASE_KEY="C:/yol/service-account.json" SUPABASE_URL="https://txjqqohqownpfcokscep.supabase.co" SUPABASE_SERVICE_KEY="..." node migrate_firestore.mjs --dry
```

Saylar düz görünürsə `--dry` olmadan təkrar işə sal.

</details>

## 3-cü addım: giriş sistemi — HİBRİD

Qərar: **giriş Firebase-də qalır, məlumat Supabase-də olur.**

Səbəb: Supabase-də nömrə ilə giriş üçün pullu SMS xidməti (Twilio və s.)
bağlamaq lazımdır. Firebase-də isə bu pulsuzdur və artıq işləyir.
Google/Apple girişini də sıfırdan qurmağa ehtiyac qalmır.

Supabase bunu rəsmi olaraq dəstəkləyir — **Third-Party Auth**.
Pulsuz planda 50 000 aylıq aktiv istifadəçiyə qədər ödənişsizdir.

Necə işləyir:

1. Tətbiq Firebase-ə girir və ID token alır.
2. `Supabase.initialize(accessToken: ...)` hər sorğuda o tokeni ötürür.
3. Supabase tokeni yoxlayır və `sub` sahəsindən Firebase ID-sini çıxarır.
4. `app_uid()` funksiyası onu `profiles.firebase_uid` ilə tutuşdurur.

Bir incəlik: Firebase tokenində `role` sahəsi olmadığı üçün sorğu Supabase-ə
`anon` rolu ilə gəlir. Ona görə qaydalar həm `anon`, həm `authenticated`
rollarına verilib — qoruma rolda deyil, hər qaydadakı `app_uid()` şərtindədir.
Tokeni olmayan adam üçün `app_uid()` boşdur, yəni heç bir sətir açılmır.

## 4-cü addım: tətbiq kodu

Ən böyük hissə: 51 Dart faylı Firestore çağırır. Bunlar mərhələ-mərhələ
Supabase-ə keçiriləcək. 1–3-cü addımlar bitməyincə bu başlamır, çünki
kodu yazmaq üçün cədvəllərin işlədiyini görmək lazımdır.

Keçid bitənə qədər tətbiq Firebase ilə işləməyə davam edir — sınmır.
