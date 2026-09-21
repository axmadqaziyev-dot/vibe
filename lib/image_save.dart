/// Şəkli cihaza yükləmək.
///
/// Instagram-da şəklə uzun basıb saxlaya bilirsən. Bizdə isə bu
/// mümkün deyildi və səbəbi gözlə görünmür: Flutter veb şəkli adi
/// `<img>` elementi kimi yox, kətanın üstünə **çəkir**. Brauzer orada
/// şəkil görmür, ona görə "Şəkli saxla" menyusu çıxmır.
///
/// Həll: şəkli özümüz fayla çeviririk.
library;

export 'image_save_io.dart'
    if (dart.library.js_interop) 'image_save_web.dart';
