/// Mikrofon icazəsini sessiya boyu saxlamaq.
///
/// Problem: iOS-da hər səs yazısında icazə pəncərəsi çıxırdı.
///
/// Səbəb brauzerin qaydasıdır — icazə yalnız **açıq axın varkən**
/// qüvvədə qalır. `record` paketi yazını bitirəndə axını tam
/// bağlayır, ona görə növbəti dəfə hər şey sıfırdan başlayır və
/// pəncərə yenidən çıxır.
///
/// Həll: öz axınımızı bir dəfə açıb saxlayırıq. Trek **söndürülür**
/// (`enabled = false`) — yəni heç nə eşidilmir və yazılmır, sadəcə
/// icazə qüvvədə qalır. Bundan sonra paketin öz sorğusu pəncərəsiz
/// keçir.
///
/// Açıq deyim: iOS ekranın yuxarısında narıncı nöqtə göstərir —
/// "mikrofon açıqdır" deməkdir. Ona görə axın tətbiq arxa plana
/// keçəndə dərhal bağlanır.
library;

export 'mic_keepalive_io.dart'
    if (dart.library.js_interop) 'mic_keepalive_web.dart';
