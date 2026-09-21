// ÇOXDİLLİ DƏSTƏK — Azərbaycan, Türk, İngilis.
//
// İstifadə:  t('home')  →  seçilmiş dildəki mətn
// Dil dəyişəndə `appLanguage` bütün ekranları yeniləyir.
//
// Tərcüməsi olmayan açar Azərbaycan variantına düşür — yarımçıq
// tərcümə heç vaxt boş mətn göstərmir.

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLang { az, tr, en }

/// Seçilmiş dil. Dəyişəndə `VibeApp` yenidən qurulur.
final ValueNotifier<AppLang> appLanguage = ValueNotifier<AppLang>(AppLang.az);

const _prefsKey = 'appLanguage';

/// Tətbiq açılanda yadda saxlanmış dili yükləyir.
Future<void> loadLanguage(SharedPreferences? prefs) async {
  final code = prefs?.getString(_prefsKey);
  appLanguage.value = switch (code) {
    'tr' => AppLang.tr,
    'en' => AppLang.en,
    _ => AppLang.az,
  };
}

Future<void> setLanguage(AppLang lang) async {
  appLanguage.value = lang;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, lang.name);
  } catch (_) {}
}

String languageLabel(AppLang lang) => switch (lang) {
  AppLang.az => 'Azərbaycan',
  AppLang.tr => 'Türkçe',
  AppLang.en => 'English',
};

/// Açarı hazırkı dilə çevirir.
String t(String key) {
  final table = _translations[key];
  if (table == null) return key;
  return table[appLanguage.value] ?? table[AppLang.az] ?? key;
}

/// Bir dəyişəni olan mətnlər üçün: t1('greetUser', 'Aysel')
String t1(String key, Object value) => t(key).replaceFirst('{0}', '$value');

const _translations = <String, Map<AppLang, String>>{
  // ---- naviqasiya ----
  'nav.home': {AppLang.az: 'Ana səhifə', AppLang.tr: 'Ana sayfa', AppLang.en: 'Home'},
  'nav.moments': {AppLang.az: 'Anlar', AppLang.tr: 'Anlar', AppLang.en: 'Moments'},
  'nav.rooms': {AppLang.az: 'Otaqlar', AppLang.tr: 'Odalar', AppLang.en: 'Rooms'},
  'nav.messages': {AppLang.az: 'Mesajlar', AppLang.tr: 'Mesajlar', AppLang.en: 'Messages'},
  'nav.me': {AppLang.az: 'Mən', AppLang.tr: 'Ben', AppLang.en: 'Me'},

  // ---- ana səhifə ----
  'home.discover': {AppLang.az: 'Kəşf et', AppLang.tr: 'Keşfet', AppLang.en: 'Discover'},
  'home.nearby': {AppLang.az: 'Yaxınlıq', AppLang.tr: 'Yakınlık', AppLang.en: 'Nearby'},
  'home.online': {AppLang.az: 'Online', AppLang.tr: 'Çevrimiçi', AppLang.en: 'Online'},
  'home.popular': {AppLang.az: 'Popular', AppLang.tr: 'Popüler', AppLang.en: 'Popular'},
  'home.all': {AppLang.az: 'Hamısı', AppLang.tr: 'Hepsi', AppLang.en: 'All'},
  'home.girls': {AppLang.az: 'Qızlar', AppLang.tr: 'Kızlar', AppLang.en: 'Girls'},
  'home.boys': {AppLang.az: 'Oğlanlar', AppLang.tr: 'Erkekler', AppLang.en: 'Boys'},
  'home.heroTitle': {
    AppLang.az: 'Yeni dostlar\nYeni hekayələr\nVIBE-də ❤️',
    AppLang.tr: 'Yeni dostlar\nYeni hikâyeler\nVIBE’de ❤️',
    AppLang.en: 'New friends\nNew stories\nhere on VIBE ❤️',
  },
  'home.heroButton': {
    AppLang.az: 'İndi kəşf et  →',
    AppLang.tr: 'Hemen keşfet  →',
    AppLang.en: 'Start exploring  →',
  },
  'home.searchHint': {
    AppLang.az: 'Ad, şəhər, maraq, ID və ya əhval axtar',
    AppLang.tr: 'İsim, şehir, ilgi, ID veya mod ara',
    AppLang.en: 'Search name, city, interest, ID or mood',
  },
  'home.anyMood': {AppLang.az: 'Hər əhval', AppLang.tr: 'Tüm modlar', AppLang.en: 'Any mood'},
  'home.emptyFiltered': {
    AppLang.az: 'Bu filtrə uyğun kimsə yoxdur',
    AppLang.tr: 'Bu filtreye uygun kimse yok',
    AppLang.en: 'Nobody matches this filter',
  },
  'home.emptyNobody': {
    AppLang.az: 'Hələ başqa istifadəçi yoxdur',
    AppLang.tr: 'Henüz başka kullanıcı yok',
    AppLang.en: 'No other users yet',
  },
  'home.clearFilter': {
    AppLang.az: 'Filtri təmizlə',
    AppLang.tr: 'Filtreyi temizle',
    AppLang.en: 'Clear filter',
  },
  'home.invite': {
    AppLang.az: 'Dostunu dəvət et',
    AppLang.tr: 'Arkadaşını davet et',
    AppLang.en: 'Invite a friend',
  },

  // ---- mesajlar ----
  'messages.title': {AppLang.az: 'Mesajlar', AppLang.tr: 'Mesajlar', AppLang.en: 'Messages'},
  'messages.people': {AppLang.az: 'İnsanlar', AppLang.tr: 'Kişiler', AppLang.en: 'People'},
  'messages.unread': {AppLang.az: 'Oxunmamış', AppLang.tr: 'Okunmamış', AppLang.en: 'Unread'},
  'messages.following': {AppLang.az: 'İzlədiklərim', AppLang.tr: 'Takip ettiklerim', AppLang.en: 'Following'},
  'messages.notifications': {AppLang.az: 'Bildirişlər', AppLang.tr: 'Bildirimler', AppLang.en: 'Notifications'},
  'messages.newActivity': {
    AppLang.az: 'Yeni fəaliyyətlər',
    AppLang.tr: 'Yeni etkinlikler',
    AppLang.en: 'New activity',
  },
  'messages.room': {AppLang.az: 'Söhbət otağı', AppLang.tr: 'Sohbet odası', AppLang.en: 'Chat room'},
  'messages.roomSub': {
    AppLang.az: 'Otağa gir və dostlarınla danış',
    AppLang.tr: 'Odaya gir ve arkadaşlarınla konuş',
    AppLang.en: 'Join a room and talk with friends',
  },
  'messages.momentsSub': {
    AppLang.az: 'Düşüncələrini paylaş',
    AppLang.tr: 'Düşüncelerini paylaş',
    AppLang.en: 'Share your thoughts',
  },
  'messages.typing': {AppLang.az: 'yazır…', AppLang.tr: 'yazıyor…', AppLang.en: 'typing…'},
  'messages.empty': {
    AppLang.az: 'Söhbətlər burada başlayır',
    AppLang.tr: 'Sohbetler burada başlar',
    AppLang.en: 'Your chats start here',
  },
  'messages.emptySub': {
    AppLang.az: 'Kimsə ilə söhbətə başla — mesajların burada görünəcək.',
    AppLang.tr: 'Biriyle sohbete başla — mesajların burada görünecek.',
    AppLang.en: 'Start a chat — your messages will appear here.',
  },
  'messages.seePeople': {
    AppLang.az: 'İnsanlara bax',
    AppLang.tr: 'Kişilere bak',
    AppLang.en: 'Browse people',
  },
  'messages.message': {AppLang.az: 'Mesaj', AppLang.tr: 'Mesaj', AppLang.en: 'Message'},
  'messages.searchHint': {
    AppLang.az: 'Ad və ya mesaj axtar',
    AppLang.tr: 'İsim veya mesaj ara',
    AppLang.en: 'Search name or message',
  },

  // ---- anlar ----
  'moments.title': {AppLang.az: 'Anlar', AppLang.tr: 'Anlar', AppLang.en: 'Moments'},
  'moments.followingTab': {
    AppLang.az: 'Takip etdiklərim',
    AppLang.tr: 'Takip ettiklerim',
    AppLang.en: 'Following',
  },
  'moments.popular': {AppLang.az: 'Populyar', AppLang.tr: 'Popüler', AppLang.en: 'Popular'},
  'moments.share': {AppLang.az: 'Anını paylaş', AppLang.tr: 'Anını paylaş', AppLang.en: 'Share a moment'},
  'moments.you': {AppLang.az: 'Sən', AppLang.tr: 'Sen', AppLang.en: 'You'},
  'moments.empty': {
    AppLang.az: 'Hələ an paylaşılmayıb',
    AppLang.tr: 'Henüz an paylaşılmadı',
    AppLang.en: 'No moments yet',
  },
  'moments.emptySub': {
    AppLang.az: 'İlk anı sən paylaş — şəkil və ya bir cümlə kifayətdir.',
    AppLang.tr: 'İlk anı sen paylaş — bir fotoğraf ya da cümle yeter.',
    AppLang.en: 'Share the first one — a photo or a sentence is enough.',
  },

  // ---- profil ----
  'profile.edit': {AppLang.az: 'Profili düzəlt', AppLang.tr: 'Profili düzenle', AppLang.en: 'Edit profile'},
  'profile.posts': {AppLang.az: 'Paylaşım', AppLang.tr: 'Paylaşım', AppLang.en: 'Posts'},
  'profile.followers': {AppLang.az: 'İzləyici', AppLang.tr: 'Takipçi', AppLang.en: 'Followers'},
  'profile.followingCount': {AppLang.az: 'İzlənilən', AppLang.tr: 'Takip edilen', AppLang.en: 'Following'},
  'profile.likes': {AppLang.az: 'Bəyənmə', AppLang.tr: 'Beğeni', AppLang.en: 'Likes'},
  'profile.about': {AppLang.az: 'Haqqımda', AppLang.tr: 'Hakkımda', AppLang.en: 'About me'},
  'profile.info': {AppLang.az: 'Bilgi', AppLang.tr: 'Bilgi', AppLang.en: 'Info'},
  'profile.birthday': {AppLang.az: 'Doğum günü', AppLang.tr: 'Doğum günü', AppLang.en: 'Birthday'},
  'profile.zodiac': {AppLang.az: 'Bürc', AppLang.tr: 'Burç', AppLang.en: 'Zodiac'},
  'profile.joined': {AppLang.az: 'Qeydiyyat zamanı', AppLang.tr: 'Kayıt tarihi', AppLang.en: 'Joined'},
  'profile.notSet': {AppLang.az: 'Əlavə edilməyib', AppLang.tr: 'Eklenmedi', AppLang.en: 'Not set'},
  'profile.sayHi': {AppLang.az: 'Salam de', AppLang.tr: 'Merhaba de', AppLang.en: 'Say hi'},
  'profile.follow': {AppLang.az: 'Takip et', AppLang.tr: 'Takip et', AppLang.en: 'Follow'},
  'profile.following': {AppLang.az: 'İzlənilir', AppLang.tr: 'Takip ediliyor', AppLang.en: 'Following'},

  // ---- ümumi ----
  'common.cancel': {AppLang.az: 'Ləğv et', AppLang.tr: 'İptal', AppLang.en: 'Cancel'},
  'common.save': {AppLang.az: 'Yadda saxla', AppLang.tr: 'Kaydet', AppLang.en: 'Save'},
  'common.send': {AppLang.az: 'Göndər', AppLang.tr: 'Gönder', AppLang.en: 'Send'},
  'common.retry': {AppLang.az: 'Yenidən yoxla', AppLang.tr: 'Tekrar dene', AppLang.en: 'Try again'},
  'common.search': {AppLang.az: 'Axtar', AppLang.tr: 'Ara', AppLang.en: 'Search'},
  'common.settings': {AppLang.az: 'Ayarlar', AppLang.tr: 'Ayarlar', AppLang.en: 'Settings'},
  'common.language': {AppLang.az: 'Dil', AppLang.tr: 'Dil', AppLang.en: 'Language'},
  'common.offline': {
    AppLang.az: 'Bağlantını yoxla və yenidən sına.',
    AppLang.tr: 'Bağlantını kontrol et ve tekrar dene.',
    AppLang.en: 'Check your connection and try again.',
  },

  // ---- otaqlar ----
  'room.create': {AppLang.az: 'Otaq yarat', AppLang.tr: 'Oda oluştur', AppLang.en: 'Create room'},
  'room.guest': {AppLang.az: 'Qonaq', AppLang.tr: 'Konuk', AppLang.en: 'Guest'},
  'room.host': {AppLang.az: 'Otaq sahibi', AppLang.tr: 'Oda sahibi', AppLang.en: 'Host'},
  'room.quiet': {AppLang.az: 'Otaq sakitdir', AppLang.tr: 'Oda sessiz', AppLang.en: 'The room is quiet'},
  'room.quietSub': {
    AppLang.az: 'İlk mesajı sən yaz və ya mikrofona çıx 🎤',
    AppLang.tr: 'İlk mesajı sen yaz ya da mikrofona çık 🎤',
    AppLang.en: 'Write the first message or take a mic 🎤',
  },
  'room.messageHint': {AppLang.az: 'Mesaj yaz...', AppLang.tr: 'Mesaj yaz...', AppLang.en: 'Say something...'},
  'room.tools': {AppLang.az: 'Otaq alətləri', AppLang.tr: 'Oda araçları', AppLang.en: 'Room tools'},
  'room.gift': {AppLang.az: 'Hədiyyə', AppLang.tr: 'Hediye', AppLang.en: 'Gift'},
  'room.seats': {AppLang.az: 'Mikrofon sayı', AppLang.tr: 'Mikrofon sayısı', AppLang.en: 'Mic seats'},
  'room.leave': {AppLang.az: 'Çıxış', AppLang.tr: 'Çıkış', AppLang.en: 'Leave'},

  // ---- köçürülmüş sətirlər ----
  //
  // KÖÇÜRÜLMÜŞ SƏTİRLƏR: açar azərbaycanca mətnin özüdür.
  // Belə olanda köçürmə bir sətirlik dəyişiklikdir və tərcümə
  // tapılmasa ekranda yenə düzgün söz çıxır.
  'Ad günü': {AppLang.az: 'Ad günü', AppLang.tr: 'Doğum günü', AppLang.en: 'Birthday'},
  'Admin et': {AppLang.az: 'Admin et', AppLang.tr: 'Yönetici yap', AppLang.en: 'Make admin'},
  'Adı dəyiş': {AppLang.az: 'Adı dəyiş', AppLang.tr: 'Adı değiştir', AppLang.en: 'Rename'},
  'Agentlik': {AppLang.az: 'Agentlik', AppLang.tr: 'Ajans', AppLang.en: 'Agency'},
  'Agentlikdən çıx': {AppLang.az: 'Agentlikdən çıx', AppLang.tr: 'Ajanstan çık', AppLang.en: 'Leave agency'},
  'Ailələr': {AppLang.az: 'Ailələr', AppLang.tr: 'Aileler', AppLang.en: 'Families'},
  'Anlar': {AppLang.az: 'Anlar', AppLang.tr: 'Anlar', AppLang.en: 'Moments'},
  'Axtar': {AppLang.az: 'Axtar', AppLang.tr: 'Ara', AppLang.en: 'Search'},
  'Ayarlar': {AppLang.az: 'Ayarlar', AppLang.tr: 'Ayarlar', AppLang.en: 'Settings'},
  'Bağla': {AppLang.az: 'Bağla', AppLang.tr: 'Kapat', AppLang.en: 'Close'},
  'Bağlantını kopyala': {AppLang.az: 'Bağlantını kopyala', AppLang.tr: 'Bağlantıyı kopyala', AppLang.en: 'Copy link'},
  'Başla': {AppLang.az: 'Başla', AppLang.tr: 'Başla', AppLang.en: 'Start'},
  'Bildirişlər': {AppLang.az: 'Bildirişlər', AppLang.tr: 'Bildirimler', AppLang.en: 'Notifications'},
  'Bir dəfəlik şəkil': {AppLang.az: 'Bir dəfəlik şəkil', AppLang.tr: 'Tek seferlik fotoğraf', AppLang.en: 'View once photo'},
  'Bəli': {AppLang.az: 'Bəli', AppLang.tr: 'Evet', AppLang.en: 'Yes'},
  'Canlı konum': {AppLang.az: 'Canlı konum', AppLang.tr: 'Canlı konum', AppLang.en: 'Live location'},
  'Cavab ver': {AppLang.az: 'Cavab ver', AppLang.tr: 'Yanıtla', AppLang.en: 'Reply'},
  'Davam et': {AppLang.az: 'Davam et', AppLang.tr: 'Devam et', AppLang.en: 'Continue'},
  'Dil': {AppLang.az: 'Dil', AppLang.tr: 'Dil', AppLang.en: 'Language'},
  'Dəvət kodu': {AppLang.az: 'Dəvət kodu', AppLang.tr: 'Davet kodu', AppLang.en: 'Invite code'},
  'Emoji': {AppLang.az: 'Emoji', AppLang.tr: 'Emoji', AppLang.en: 'Emoji'},
  'Göndər': {AppLang.az: 'Göndər', AppLang.tr: 'Gönder', AppLang.en: 'Send'},
  'Göndərildi': {AppLang.az: 'Göndərildi', AppLang.tr: 'Gönderildi', AppLang.en: 'Sent'},
  'Görüldü': {AppLang.az: 'Görüldü', AppLang.tr: 'Görüldü', AppLang.en: 'Seen'},
  'Hamısı': {AppLang.az: 'Hamısı', AppLang.tr: 'Hepsi', AppLang.en: 'All'},
  'Hamısını oxu': {AppLang.az: 'Hamısını oxu', AppLang.tr: 'Tümünü oku', AppLang.en: 'Mark all read'},
  'Hamısını sil': {AppLang.az: 'Hamısını sil', AppLang.tr: 'Tümünü sil', AppLang.en: 'Clear all'},
  'Hədiyyə': {AppLang.az: 'Hədiyyə', AppLang.tr: 'Hediye', AppLang.en: 'Gift'},
  'Hər kəsdən sil': {AppLang.az: 'Hər kəsdən sil', AppLang.tr: 'Herkes için sil', AppLang.en: 'Delete for everyone'},
  'ID kopyala': {AppLang.az: 'ID kopyala', AppLang.tr: 'ID kopyala', AppLang.en: 'Copy ID'},
  'Kodla qoşul': {AppLang.az: 'Kodla qoşul', AppLang.tr: 'Kodla katıl', AppLang.en: 'Join with code'},
  'Konum göndər': {AppLang.az: 'Konum göndər', AppLang.tr: 'Konum gönder', AppLang.en: 'Send location'},
  'Kopyala': {AppLang.az: 'Kopyala', AppLang.tr: 'Kopyala', AppLang.en: 'Copy'},
  'Küçült': {AppLang.az: 'Küçült', AppLang.tr: 'Küçült', AppLang.en: 'Minimise'},
  'Loqonu dəyiş': {AppLang.az: 'Loqonu dəyiş', AppLang.tr: 'Logoyu değiştir', AppLang.en: 'Change logo'},
  'Ləğv et': {AppLang.az: 'Ləğv et', AppLang.tr: 'Vazgeç', AppLang.en: 'Cancel'},
  'Mesaj yaz...': {AppLang.az: 'Mesaj yaz...', AppLang.tr: 'Mesaj yaz...', AppLang.en: 'Write a message...'},
  'Mesajı sil': {AppLang.az: 'Mesajı sil', AppLang.tr: 'Mesajı sil', AppLang.en: 'Delete message'},
  'Mic istəkləri': {AppLang.az: 'Mic istəkləri', AppLang.tr: 'Mikrofon istekleri', AppLang.en: 'Mic requests'},
  'Mikrofon sayı': {AppLang.az: 'Mikrofon sayı', AppLang.tr: 'Mikrofon sayısı', AppLang.en: 'Seat count'},
  'Mətni kopyala': {AppLang.az: 'Mətni kopyala', AppLang.tr: 'Metni kopyala', AppLang.en: 'Copy text'},
  'Məxfilik siyasəti': {AppLang.az: 'Məxfilik siyasəti', AppLang.tr: 'Gizlilik politikası', AppLang.en: 'Privacy policy'},
  'Otaq alətləri': {AppLang.az: 'Otaq alətləri', AppLang.tr: 'Oda araçları', AppLang.en: 'Room tools'},
  'Otaq menyusu': {AppLang.az: 'Otaq menyusu', AppLang.tr: 'Oda menüsü', AppLang.en: 'Room menu'},
  'Otaqdakılar': {AppLang.az: 'Otaqdakılar', AppLang.tr: 'Odadakiler', AppLang.en: 'In the room'},
  'Otağın fonu': {AppLang.az: 'Otağın fonu', AppLang.tr: 'Oda arka planı', AppLang.en: 'Room background'},
  'Oyunlar': {AppLang.az: 'Oyunlar', AppLang.tr: 'Oyunlar', AppLang.en: 'Games'},
  'Paylaş': {AppLang.az: 'Paylaş', AppLang.tr: 'Paylaş', AppLang.en: 'Share'},
  'Profili düzəlt': {AppLang.az: 'Profili düzəlt', AppLang.tr: 'Profili düzenle', AppLang.en: 'Edit profile'},
  'Qoşul': {AppLang.az: 'Qoşul', AppLang.tr: 'Katıl', AppLang.en: 'Join'},
  'Qrup haqqında': {AppLang.az: 'Qrup haqqında', AppLang.tr: 'Grup hakkında', AppLang.en: 'About group'},
  'Qrupa yaz…': {AppLang.az: 'Qrupa yaz…', AppLang.tr: 'Gruba yaz…', AppLang.en: 'Message the group…'},
  'Qrupdan çıx': {AppLang.az: 'Qrupdan çıx', AppLang.tr: 'Gruptan çık', AppLang.en: 'Leave group'},
  'Qrupdan çıxar': {AppLang.az: 'Qrupdan çıxar', AppLang.tr: 'Gruptan çıkar', AppLang.en: 'Remove from group'},
  'Qrupu yarat': {AppLang.az: 'Qrupu yarat', AppLang.tr: 'Grubu oluştur', AppLang.en: 'Create group'},
  'Qrupun adı': {AppLang.az: 'Qrupun adı', AppLang.tr: 'Grup adı', AppLang.en: 'Group name'},
  'Ranking': {AppLang.az: 'Ranking', AppLang.tr: 'Sıralama', AppLang.en: 'Ranking'},
  'Saxla': {AppLang.az: 'Saxla', AppLang.tr: 'Kaydet', AppLang.en: 'Save'},
  'Seç': {AppLang.az: 'Seç', AppLang.tr: 'Seç', AppLang.en: 'Select'},
  'Sil': {AppLang.az: 'Sil', AppLang.tr: 'Sil', AppLang.en: 'Delete'},
  'Stiker': {AppLang.az: 'Stiker', AppLang.tr: 'Çıkartma', AppLang.en: 'Sticker'},
  'Stiker və oyunlar': {AppLang.az: 'Stiker və oyunlar', AppLang.tr: 'Çıkartma ve oyunlar', AppLang.en: 'Stickers and games'},
  'Stori': {AppLang.az: 'Stori', AppLang.tr: 'Hikaye', AppLang.en: 'Story'},
  'Stori paylaş': {AppLang.az: 'Stori paylaş', AppLang.tr: 'Hikaye paylaş', AppLang.en: 'Add to story'},
  'Storinə at': {AppLang.az: 'Storinə at', AppLang.tr: 'Hikayene ekle', AppLang.en: 'Add to your story'},
  'Sual ver': {AppLang.az: 'Sual ver', AppLang.tr: 'Soru sor', AppLang.en: 'Ask me'},
  'Söhbət mövzusu': {AppLang.az: 'Söhbət mövzusu', AppLang.tr: 'Sohbet teması', AppLang.en: 'Chat theme'},
  'Söhbət otağı': {AppLang.az: 'Söhbət otağı', AppLang.tr: 'Sohbet odası', AppLang.en: 'Chat room'},
  'Söhbətin başına sancaqla': {AppLang.az: 'Söhbətin başına sancaqla', AppLang.tr: 'Sohbete sabitle', AppLang.en: 'Pin to chat'},
  'Söz döyüşü': {AppLang.az: 'Söz döyüşü', AppLang.tr: 'Söz düellosu', AppLang.en: 'Word battle'},
  'Səs diaqnostikası': {AppLang.az: 'Səs diaqnostikası', AppLang.tr: 'Ses tanılama', AppLang.en: 'Audio diagnostics'},
  'Səsli mesaj': {AppLang.az: 'Səsli mesaj', AppLang.tr: 'Sesli mesaj', AppLang.en: 'Voice message'},
  'Səsli zəng': {AppLang.az: 'Səsli zəng', AppLang.tr: 'Sesli arama', AppLang.en: 'Voice call'},
  'Töhfə sıralaması': {AppLang.az: 'Töhfə sıralaması', AppLang.tr: 'Katkı sıralaması', AppLang.en: 'Top supporters'},
  'Təbrik': {AppLang.az: 'Təbrik', AppLang.tr: 'Tebrik', AppLang.en: 'Congrats'},
  'Təqdimat': {AppLang.az: 'Təqdimat', AppLang.tr: 'Tanıtım', AppLang.en: 'Announcement'},
  'Video zəng': {AppLang.az: 'Video zəng', AppLang.tr: 'Görüntülü arama', AppLang.en: 'Video call'},
  'Videonu endir': {AppLang.az: 'Videonu endir', AppLang.tr: 'Videoyu indir', AppLang.en: 'Download video'},
  'Xeyr': {AppLang.az: 'Xeyr', AppLang.tr: 'Hayır', AppLang.en: 'No'},
  'Yadda saxla': {AppLang.az: 'Yadda saxla', AppLang.tr: 'Kaydet', AppLang.en: 'Save'},
  'Yayımçılar': {AppLang.az: 'Yayımçılar', AppLang.tr: 'Yayıncılar', AppLang.en: 'Hosts'},
  'Yazı': {AppLang.az: 'Yazı', AppLang.tr: 'Yazı', AppLang.en: 'Text'},
  'Yeni qrup': {AppLang.az: 'Yeni qrup', AppLang.tr: 'Yeni grup', AppLang.en: 'New group'},
  'Yenidən düzəlt': {AppLang.az: 'Yenidən düzəlt', AppLang.tr: 'Yeniden düzenle', AppLang.en: 'Edit'},
  'Yenidən sına': {AppLang.az: 'Yenidən sına', AppLang.tr: 'Tekrar dene', AppLang.en: 'Try again'},
  'Yönləndir': {AppLang.az: 'Yönləndir', AppLang.tr: 'İlet', AppLang.en: 'Forward'},
  'Zəngə çağır': {AppLang.az: 'Zəngə çağır', AppLang.tr: 'Aramaya davet et', AppLang.en: 'Invite to call'},
  'yazır…': {AppLang.az: 'yazır…', AppLang.tr: 'yazıyor…', AppLang.en: 'typing…'},
  'Çıxış': {AppLang.az: 'Çıxış', AppLang.tr: 'Çıkış', AppLang.en: 'Exit'},
  'Öz agentliyini qur': {AppLang.az: 'Öz agentliyini qur', AppLang.tr: 'Kendi ajansını kur', AppLang.en: 'Create your agency'},
  'Özümdən sil': {AppLang.az: 'Özümdən sil', AppLang.tr: 'Kendim için sil', AppLang.en: 'Delete for me'},
  'Üzv əlavə et': {AppLang.az: 'Üzv əlavə et', AppLang.tr: 'Üye ekle', AppLang.en: 'Add members'},
  'İcma qaydaları': {AppLang.az: 'İcma qaydaları', AppLang.tr: 'Topluluk kuralları', AppLang.en: 'Community rules'},
  'İstifadə şərtləri': {AppLang.az: 'İstifadə şərtləri', AppLang.tr: 'Kullanım şartları', AppLang.en: 'Terms of use'},
  'Şanslı qutu': {AppLang.az: 'Şanslı qutu', AppLang.tr: 'Şanslı kutu', AppLang.en: 'Lucky box'},
  'Şikayət et': {AppLang.az: 'Şikayət et', AppLang.tr: 'Şikayet et', AppLang.en: 'Report'},
  'Şəkil': {AppLang.az: 'Şəkil', AppLang.tr: 'Fotoğraf', AppLang.en: 'Photo'},
  'Şəkil çək': {AppLang.az: 'Şəkil çək', AppLang.tr: 'Fotoğraf çek', AppLang.en: 'Take a photo'},
  'Şəkli dəyiş': {AppLang.az: 'Şəkli dəyiş', AppLang.tr: 'Fotoğrafı değiştir', AppLang.en: 'Change photo'},
  'Şəkli endir': {AppLang.az: 'Şəkli endir', AppLang.tr: 'Fotoğrafı indir', AppLang.en: 'Download photo'},
  'Şərh yaz…': {AppLang.az: 'Şərh yaz…', AppLang.tr: 'Yorum yaz…', AppLang.en: 'Write a comment…'},
  'Şərhlər': {AppLang.az: 'Şərhlər', AppLang.tr: 'Yorumlar', AppLang.en: 'Comments'},

};
