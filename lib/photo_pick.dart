/// Şəkli qalereyadan seçmək.
///
/// Vebdə `image_picker` paketi `accept` sahəsinə uzun MIME siyahısı
/// yazır. iOS Safari bu siyahını görəndə "Foto kitabxanası" seçimini
/// göstərmir, birbaşa Fayllar tətbiqini açır — və məhz Fayllar yolu
/// "tam giriş" icazəsini hər dəfə soruşur. Sadə `image/*` isə düzgün
/// menyunu verir.
///
/// İkinci fərq: paketin veb seçicisi bir şəkil qaytarır. Burada
/// `multiple` açıqdır — Instagram kimi bir dəfəyə bir neçə şəkil
/// seçmək olur.
///
/// Mobildə paketin öz seçicisi qalır: orada belə problem yoxdur.
library;

export 'photo_pick_io.dart'
    if (dart.library.js_interop) 'photo_pick_web.dart';
