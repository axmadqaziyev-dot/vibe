# VIBE zənglərinin quraşdırılması

Tətbiq Firebase Auth və Firestore istifadə edir. `lib/data` altındakı köhnə
Supabase repository hazırkı `main.dart` axınında istifadə olunmur.

## Firestore

`firestore.calls.rules.example` blokunu mövcud Firestore qaydalarına birləşdirin.
Mövcud users/chats qaydalarını əvəz etməyin. Zəng qaydaları istifadəçi icazəsi ilə vibe-f9d13 layihəsində yayımlanıb; aktiv tam qaydalar firestore.rules faylındadır. Əvvəlki qaydalar firestore.remote.backup.json faylında saxlanır.
Gələn zəng sorğusu üçün iştirakçı yoxlaması ilə uyğun filtr lazımdır:
`members arrayContains uid`; tətbiq sonra callee sahəsini yoxlayır.
İstifadəçi yalnız öz `users/{uid}` aktivlik sahələrini dəyişə bilməlidir.
Qaydaları Firebase Emulator ilə yoxlamadan istehsala yayımlamayın.

## Media bağlantısı

WebRTC mikrofon/kamera ilə real media bağlantısı qurur; Firestore offer,
answer və ICE məlumatlarını ötürür. Vebdə HTTPS və ya localhost lazımdır.
Android/iOS mikrofon və kamera icazələri əlavə edilib.

STUN başlanğıc olaraq konfiqurasiya olunub. Fərqli mobil/operator və qapalı
şəbəkələrdə etibarlı zənglər üçün TURN əlavə edin:

```powershell
flutter run -d chrome --dart-define=TURN_URL=turn:YOUR_SERVER:3478 --dart-define=TURN_USERNAME=USER --dart-define=TURN_CREDENTIAL=TOKEN
```

Bu parametrlər müştəriyə daxil olur. İstehsalda uzunmüddətli TURN sirri əvəzinə
autentifikasiya olunmuş backend-dən qısaömürlü TURN məlumatları alınmalıdır.
Hazırda gələn zəng yalnız tətbiq açıq olanda görünür; bağlı tətbiqə zəng üçün
FCM/APNs və mobil zəng inteqrasiyası ayrıca lazımdır. Qəbul edilməyən zəng
60 saniyədən sonra bitir. Çox cihazlı presence aqreqasiyası əlavə edilməyib.

## Yoxlama

İki ayrı hesab və iki cihaz/brauzer profili ilə: girişdə Yadda saxla seçimini
açıb/söndürüb yenidən açın; çıxışda aktivliyin sönməsini yoxlayın; səsli və
video zəngi qəbul/rədd edin; kamera və mikrofonu söndürün; icazəni rədd edin;
zəngi hər iki tərəfdən bitirin; ayrı şəbəkələrdə TURN ilə sınayın.
Parol SharedPreferences-də saxlanmır. Mobil platformada Yadda saxla bağlıdırsa
yeni tətbiq prosesinin başlanğıcında hesabdan çıxılır.

API mənbəyi: https://flutter-webrtc.org/docs/flutter-webrtc/api-docs/rtc-peerconnection/

