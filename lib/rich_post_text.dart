/// Paylaşımın mətni — toxunula bilən hissələrlə.
///
/// Threads-in mətni adi yazı deyil: `@ad` profilə, `#söz` axtarışa,
/// link isə brauzerə aparır. Bizdə mətn sadəcə yazı idi — adamın
/// adını yazsan da heç nə olmurdu, hashtag isə sadəcə rəngsiz söz
/// qalırdı.
///
/// Bu fayl mətni hissələrə ayırır və hər hissəyə öz davranışını
/// verir. Ayırma təmiz Dart-dır — sınaqdan asan keçir.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'ui/vibe_design.dart';

/// Mətn hissəsinin növü.
enum SpanKind { plain, mention, hashtag, link }

class TextPart {
  const TextPart(this.kind, this.text);

  final SpanKind kind;
  final String text;

  /// `@` və ya `#` olmadan dəyər.
  String get value =>
      kind == SpanKind.plain || kind == SpanKind.link ? text : text.substring(1);

  @override
  bool operator ==(Object other) =>
      other is TextPart && other.kind == kind && other.text == text;

  @override
  int get hashCode => Object.hash(kind, text);

  @override
  String toString() => '${kind.name}:$text';
}

/// Hərf sayılan simvollar.
///
/// Azərbaycan və türk hərfləri ASCII-dən kənardadır — `\w` onları
/// tutmur. Ona görə diapazonları əl ilə yazırıq, yoxsa "#səhər"
/// yarıda kəsilərdi.
const _wordChars =
    r'0-9a-zA-ZəƏıIİiöÖüÜşŞçÇğĞ_';

/// Diqqət: burada xam sətir (`r'...'`) yalnız link hissəsindədir.
/// `@` və `#` hissələrində `$_wordChars` dəyəri sətrə qoşulmalıdır —
/// xam sətirdə `$` açılmır və şablon heç nə tutmurdu.
///
/// `(?<![...])` lazımdır: `asif@gmail.com` yazısında `@` sözün
/// ortasındadır, ad deyil. Onsuz hər e-poçt profil linkinə çevrilirdi.
final _pattern = RegExp(
  // Link
  r'(https?://[^\s]+|www\.[^\s]+)'
  // Ad
  '|((?<![$_wordChars])@[$_wordChars]{2,30})'
  // Hashtag
  '|((?<![$_wordChars])#[$_wordChars]{1,40})',
  unicode: true,
);

/// Mətni hissələrə ayırır.
List<TextPart> parsePostText(String text) {
  if (text.isEmpty) return const [];

  final parts = <TextPart>[];
  var index = 0;

  for (final match in _pattern.allMatches(text)) {
    if (match.start > index) {
      parts.add(TextPart(SpanKind.plain, text.substring(index, match.start)));
    }

    final value = match[0]!;
    final kind = switch (value[0]) {
      '@' => SpanKind.mention,
      '#' => SpanKind.hashtag,
      _ => SpanKind.link,
    };

    parts.add(TextPart(kind, value));
    index = match.end;
  }

  if (index < text.length) {
    parts.add(TextPart(SpanKind.plain, text.substring(index)));
  }

  return parts;
}

/// Hashtagı axtarış üçün normal şəklə salır.
///
/// Sadə `toLowerCase()` kifayət etmir: Unicode qaydasına görə `İ`
/// hərfi `i` + ayrıca nöqtə işarəsinə çevrilir. Nəticədə `#İlkin`
/// və `#ilkin` **fərqli** hashtag olurdu və axtarış tapmırdı.
/// Türk `I` hərfi də `ı`-ya deyil, `i`-yə düşürdü.
String normalizeTag(String raw) => raw
    .replaceAll('İ', 'i')
    .replaceAll('I', 'ı')
    .toLowerCase()
    // Qalan birləşən nöqtələr silinir.
    .replaceAll('̇', '');

/// Mətndəki bütün hashtagları qaytarır (kiçik hərflə, təkrarsız).
///
/// Paylaşım yaradılanda sənədə yazılır — axtarış bunun üzərindən
/// gedir, hər dəfə mətni oxumaq lazım gəlmir.
List<String> hashtagsIn(String text) {
  final out = <String>{};

  for (final part in parsePostText(text)) {
    if (part.kind == SpanKind.hashtag) out.add(normalizeTag(part.value));
  }

  return out.toList(growable: false);
}

/// Mətndəki adları qaytarır.
List<String> mentionsIn(String text) {
  final out = <String>{};

  for (final part in parsePostText(text)) {
    if (part.kind == SpanKind.mention) out.add(part.value);
  }

  return out.toList(growable: false);
}

/// Toxunula bilən paylaşım mətni.
class RichPostText extends StatefulWidget {
  const RichPostText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.onMention,
    this.onHashtag,
    this.onLink,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;

  final void Function(String name)? onMention;
  final void Function(String tag)? onHashtag;
  final void Function(String url)? onLink;

  @override
  State<RichPostText> createState() => _RichPostTextState();
}

class _RichPostTextState extends State<RichPostText> {
  /// Tanıyıcılar `dispose` olunmalıdır — hər yenidən qurulanda
  /// yenisini yaratsaq, köhnələr sızır.
  final _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();

    final base = widget.style ??
        const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.45);

    final parts = parsePostText(widget.text);

    // Toxunulası heç nə yoxdursa adi mətn qaytarırıq — bir neçə
    // yüz paylaşımda bu, lazımsız obyektə qənaətdir.
    if (parts.every((p) => p.kind == SpanKind.plain)) {
      return Text(
        widget.text,
        style: base,
        maxLines: widget.maxLines,
        overflow: widget.maxLines == null ? null : TextOverflow.ellipsis,
      );
    }

    return RichText(
      maxLines: widget.maxLines,
      overflow: widget.maxLines == null
          ? TextOverflow.clip
          : TextOverflow.ellipsis,
      text: TextSpan(
        style: base,
        children: [
          for (final part in parts) _span(part, base),
        ],
      ),
    );
  }

  InlineSpan _span(TextPart part, TextStyle base) {
    if (part.kind == SpanKind.plain) {
      return TextSpan(text: part.text);
    }

    final handler = switch (part.kind) {
      SpanKind.mention => widget.onMention,
      SpanKind.hashtag => widget.onHashtag,
      _ => widget.onLink,
    };

    if (handler == null) return TextSpan(text: part.text);

    final recognizer = TapGestureRecognizer()
      ..onTap = () => handler(
            part.kind == SpanKind.link ? part.text : part.value,
          );
    _recognizers.add(recognizer);

    return TextSpan(
      text: part.text,
      recognizer: recognizer,
      style: base.copyWith(
        color: part.kind == SpanKind.hashtag ? vBlue : vPink,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
