/// Videonu qalereyadan seçmək.
///
/// Vebdə `image_picker` paketi `accept` sahəsinə uzun siyahı yazır:
/// `video/3gpp,video/x-m4v,video/mp4,video/*`. iOS Safari bu siyahını
/// görəndə "Foto kitabxanası" seçimini göstərmir və birbaşa Fayllar
/// tətbiqini açır. Sadə `video/*` isə düzgün menyunu verir.
///
/// Ona görə vebdə öz seçicimizi işlədirik, mobildə isə paket qalır.
library;

export 'video_pick_io.dart'
    if (dart.library.js_interop) 'video_pick_web.dart';
