/// Səhifəni təzələmək və işləyən versiyanın damğasını oxumaq.
///
/// Hər ikisi yalnız vebdə mümkündür, ona görə platformaya görə
/// ayrılır — mobil yığım brauzer kitabxanasını görməməlidir.
library;

export 'reload_page_io.dart'
    if (dart.library.js_interop) 'reload_page_web.dart';
