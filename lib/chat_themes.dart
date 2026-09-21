import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'ui/vibe_design.dart';

/// Söhbət mövzuları — fon və baloncuq rəngi.
///
/// Mövzu söhbət sənədində saxlanılır, istifadəçidə yox: Instagram-da
/// olduğu kimi hər iki tərəf eyni fonu görür. Biri dəyişəndə o biri
/// də dərhal görür — söhbətin ortaq əhvalı olur.
class ChatTheme {
  const ChatTheme({
    required this.id,
    required this.name,
    required this.background,
    required this.mine,
    this.dark = true,
  });

  final String id;
  final String name;

  /// Ekranın fonu.
  final List<Color> background;

  /// Mənim mesajlarımın baloncuğu.
  final List<Color> mine;

  /// Fon tünddürsə mətn ağ olur.
  final bool dark;

  LinearGradient get backgroundGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: background,
      );

  LinearGradient get mineGradient => LinearGradient(colors: mine);
}

const chatThemes = <ChatTheme>[
  ChatTheme(
    id: 'default',
    name: 'VIBE',
    background: [Color(0xff080611), Color(0xff0d0917)],
    mine: [vPurple, vPink],
  ),
  ChatTheme(
    id: 'night',
    name: 'Gecə',
    background: [Color(0xff0a1024), Color(0xff050810)],
    mine: [Color(0xff2f7bff), Color(0xff6b4bff)],
  ),
  ChatTheme(
    id: 'sunset',
    name: 'Gün batımı',
    background: [Color(0xff2a1020), Color(0xff140812)],
    mine: [Color(0xffff8a3d), Color(0xffff3b6b)],
  ),
  ChatTheme(
    id: 'forest',
    name: 'Meşə',
    background: [Color(0xff07190f), Color(0xff040d09)],
    mine: [Color(0xff2de28a), Color(0xff1aa06e)],
  ),
  ChatTheme(
    id: 'candy',
    name: 'Şirin',
    background: [Color(0xff2b0f28), Color(0xff160714)],
    mine: [Color(0xffff5bd6), Color(0xffff9fe4)],
  ),
  ChatTheme(
    id: 'gold',
    name: 'Qızıl',
    background: [Color(0xff241b06), Color(0xff120d03)],
    mine: [Color(0xffffd458), Color(0xffff8a3d)],
  ),
  ChatTheme(
    id: 'ocean',
    name: 'Dəniz',
    background: [Color(0xff041d24), Color(0xff020f13)],
    mine: [Color(0xff22a7ff), Color(0xff2de2d0)],
  ),
  ChatTheme(
    id: 'paper',
    name: 'Kağız',
    background: [Color(0xfff3efe7), Color(0xffe8e2d6)],
    mine: [Color(0xff2a2140), Color(0xff3a2d52)],
    dark: false,
  ),
];

/// Açardan mövzunu tapır; tanınmasa ilk mövzu qayıdır.
ChatTheme chatThemeOf(Object? id) {
  final key = '$id';
  for (final theme in chatThemes) {
    if (theme.id == key) return theme;
  }
  return chatThemes.first;
}

/// Mövzu seçimi vərəqi.
///
/// Seçim söhbətin sənədinə yazılır — qarşı tərəf də eyni fonu görür.
Future<void> showChatThemeSheet(
  BuildContext context, {
  required String chatId,
  required ChatTheme current,
  FirebaseFirestore? database,
}) async {
  final db = database ?? FirebaseFirestore.instance;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xff151020),
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Söhbət mövzusu',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Hər iki tərəf eyni fonu görəcək.',
              style: TextStyle(color: vMuted, fontSize: 12.5),
            ),
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: .72,
              ),
              itemCount: chatThemes.length,
              itemBuilder: (context, i) {
                final theme = chatThemes[i];
                final selected = theme.id == current.id;

                return GestureDetector(
                  onTap: () async {
                    Navigator.pop(sheet);
                    try {
                      await db.collection('chats').doc(chatId).set(
                        {'theme': theme.id},
                        SetOptions(merge: true),
                      );
                    } catch (_) {}
                  },
                  child: Column(
                    children: [
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: theme.backgroundGradient,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected ? vPink : Colors.white12,
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: Center(
                            child: Container(
                              width: 34,
                              height: 16,
                              decoration: BoxDecoration(
                                gradient: theme.mineGradient,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        theme.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected ? vPink : vMuted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}
