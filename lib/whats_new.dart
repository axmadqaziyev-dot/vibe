/// "Yeniliklər" vərəqi.
///
/// Problem: yeni funksiyalar menyuların, uzun basmaların və kiçik
/// ikonların arxasında qalır. İstifadəçi onları tapmır və tətbiq
/// olduğundan kasıb görünür.
///
/// Bu vərəq versiya dəyişəndə bir dəfə açılır və nəyin harada olduğunu
/// deyir. Bir dəfə göstərilir, sonra bir daha çıxmır.
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ui/vibe_design.dart';
import 'app/i18n.dart';

/// Siyahı dəyişəndə bu rəqəm artırılır — vərəq yenidən göstərilir.
const int whatsNewVersion = 3;

class NewsItem {
  const NewsItem({
    required this.emoji,
    required this.title,
    required this.text,
    required this.where,
  });

  final String emoji;
  final String title;
  final String text;

  /// Harada tapılır — istifadəçi axtarmasın.
  final String where;
}

const whatsNewItems = <NewsItem>[
  NewsItem(
    emoji: '#️⃣',
    title: 'Hashtag və ad',
    text: 'Mətndə #söz yazsan lent açılır, @ad yazsan profil açılır.',
    where: 'Anlarda mətnin içində — toxun',
  ),
  NewsItem(
    emoji: '💬',
    title: 'Şərhə cavab',
    text: 'Hər şərhə ayrıca cavab yaz, bəyən. Cavablar alt-alta düzülür.',
    where: 'Anın şərhlərində → "Cavab ver"',
  ),
  NewsItem(
    emoji: '🖼️',
    title: 'Otağın fonu',
    text: 'Otağını seçilən et — hazır mənzərə və ya öz şəklin.',
    where: 'Otaqda menyu → "Otağın fonu"',
  ),
  NewsItem(
    emoji: '👑',
    title: 'Töhfə sıralaması',
    text: 'Otağa ən çox dəstək verənlər podiumda görünür.',
    where: 'Otaqda yuxarıdakı kubok',
  ),
  NewsItem(
    emoji: '✓',
    title: 'Görüldü',
    text: 'Mesajın oxunanda iki quş və "Görüldü" yazısı çıxır.',
    where: 'Söhbətdə öz mesajının altında',
  ),
  NewsItem(
    emoji: '📷',
    title: 'Bir dəfəyə çox şəkil',
    text: 'Qalereyaya bir dəfə gir, hamısını seç.',
    where: 'An paylaşanda və söhbətdə',
  ),
  NewsItem(
    emoji: '⚡',
    title: 'Storilər',
    text: '24 saatlıq paylaşım. Halqa rənglidirsə baxmamısan.',
    where: 'Anlar → yuxarıdakı zolaq → "Stori paylaş"',
  ),
  NewsItem(
    emoji: '🔔',
    title: 'Mesaj səsi',
    text: 'Tətbiq açıq olanda yeni mesaj gələndə səs çalır.',
    where: 'Öz-özünə işləyir',
  ),
  NewsItem(
    emoji: '🎙️',
    title: 'Səsli anlar',
    text: '60 saniyəlik səs paylaş. Şəkil çəkmək, işıq, hazırlıq lazım deyil.',
    where: 'Anlar → yeni an → "Səs"',
  ),
  NewsItem(
    emoji: '🎧',
    title: 'Gizli qulaq as',
    text: 'Otağa görünmədən gir. Adın siyahıda çıxmır, istəyəndə üzə çıxırsan.',
    where: 'Otağın üstünə uzun bas',
  ),
  NewsItem(
    emoji: '🎤',
    title: 'Söz döyüşü',
    text: 'Meyxana, atışma, freestyle. Ekranda söz çıxır, növbə ilə deyirsiniz.',
    where: 'Otaqda menyu → "Söz döyüşü"',
  ),
  NewsItem(
    emoji: '🤫',
    title: 'Pıçıltı',
    text: 'Anonim səs divarı. Adsız 20 saniyə, səs maskası ilə.',
    where: 'Anlar → yuxarıdakı ◉ işarəsi',
  ),
  NewsItem(
    emoji: '🌙',
    title: 'Bu axşam nə istəyirsən?',
    text: 'Niyyətini seç — danışmaq, dinləmək, oyun. Uyğun adamlar önə çıxır.',
    where: 'Ana səhifədə yuxarıda',
  ),
  NewsItem(
    emoji: '🛡️',
    title: 'Ailələr',
    text: 'Ailə qur, xəzinə yığ, səviyyə qazan.',
    where: 'Mesajlar → "Ailələr"',
  ),
  NewsItem(
    emoji: '⚔️',
    title: 'PK dörd tərəfli',
    text: 'Otaqda iki yerinə dörd tərəf yarışa bilər.',
    where: 'Otaqda "PK yarışı başlat"',
  ),
  NewsItem(
    emoji: '🎨',
    title: 'Söhbət mövzuları',
    text: 'Söhbətin fonunu dəyiş — hər iki tərəf eyni görür.',
    where: 'Söhbətdə palitra düyməsi',
  ),
];

/// Versiya dəyişibsə vərəqi bir dəfə göstərir.
Future<void> maybeShowWhatsNew(BuildContext context) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getInt('whatsNewSeen') ?? 0;
    if (seen >= whatsNewVersion) return;

    await prefs.setInt('whatsNewSeen', whatsNewVersion);
    if (!context.mounted) return;

    await showWhatsNew(context);
  } catch (_) {
    // Vərəq göstərilməsə də tətbiq normal işləməlidir.
  }
}

Future<void> showWhatsNew(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xff151020),
    showDragHandle: true,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .85,
    ),
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'VIBE-də yeniliklər',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Hər birinin yanında harada olduğu yazılıb.',
                style: TextStyle(color: vMuted, fontSize: 12.5),
              ),
            ),
          ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              itemCount: whatsNewItems.length,
              separatorBuilder: (_, _) => const SizedBox(height: 9),
              itemBuilder: (context, i) => _tile(whatsNewItems[i]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: GradientButton(
              label: t('Başla'),
              icon: Icons.rocket_launch_rounded,
              gradient: vBrand,
              height: 50,
              onPressed: () => Navigator.pop(sheet),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _tile(NewsItem item) => Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: vPanel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: vLine),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.text,
                  style: const TextStyle(
                    color: vMuted,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.my_location_rounded,
                        size: 12, color: vPink),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        item.where,
                        style: const TextStyle(
                          color: vPink,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
