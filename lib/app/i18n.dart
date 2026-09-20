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
};
