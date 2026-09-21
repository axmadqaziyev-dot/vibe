/// Şərhlərin sap quruluşu.
///
/// Əvvəl şərhlər düz siyahı idi: kim kimə cavab verir bilinmirdi və
/// beş nəfər danışanda söhbət anlaşılmaz olurdu. Threads-in bütün
/// mahiyyəti isə məhz budur — cavab cavaba bağlanır.
///
/// İki qayda qoyulub:
///
/// 1. **Yalnız iki pillə.** Cavabın cavabı daha dərinə getmir, eyni
///    kökə qoşulur və "kimə" yazısı ilə göstərilir. Sonsuz girinti
///    telefon ekranında oxunmaz olur — Instagram və Threads də belə
///    edir.
/// 2. **Kökü silinən cavab itmir.** Valideyn şərh silinsə, cavab
///    yuxarı səviyyəyə qalxır. Əks halda bir şərhi silməklə bütün
///    budaq gözdən yox olardı.
library;

class ThreadComment {
  const ThreadComment({
    required this.id,
    required this.uid,
    required this.name,
    required this.text,
    required this.createdAt,
    this.photo = '',
    this.parentId = '',
    this.replyToName = '',
    this.likeCount = 0,
    this.likedBy = const [],
  });

  final String id;
  final String uid;
  final String name;
  final String text;
  final DateTime createdAt;
  final String photo;

  /// Hansı şərhə cavabdır. Boşdursa yuxarı səviyyədir.
  final String parentId;

  /// Kimə ünvanlanıb — ikinci pillədə göstərilir.
  final String replyToName;

  final int likeCount;

  /// Kim bəyənib. Öz nişanımızı buradan bilirik — ayrıca sorğu
  /// getmir.
  final List<String> likedBy;

  static ThreadComment from(String id, Map<String, dynamic> data) {
    final raw = data['createdAt'];

    return ThreadComment(
      id: id,
      uid: '${data['uid'] ?? ''}',
      name: '${data['name'] ?? ''}',
      text: '${data['text'] ?? ''}',
      photo: '${data['photo'] ?? ''}',
      parentId: '${data['parentId'] ?? ''}',
      replyToName: '${data['replyToName'] ?? ''}',
      likeCount: int.tryParse('${data['likeCount'] ?? 0}') ?? 0,
      likedBy: [
        for (final uid in (data['likedBy'] as List?) ?? const []) '$uid',
      ],
      // Vaxt hələ serverdən gəlməyibsə indiki an götürülür: şərh
      // siyahıda düzgün yerdə görünsün.
      createdAt: raw is DateTime ? raw : DateTime.now(),
    );
  }
}

/// Bir kök şərh və ona gələn cavablar.
class ThreadNode {
  ThreadNode(this.comment, this.replies);

  final ThreadComment comment;
  final List<ThreadComment> replies;

  int get total => 1 + replies.length;
}

/// Düz siyahını saplara çevirir.
///
/// Köklər köhnədən yeniyə düzülür — söhbət yuxarıdan aşağı oxunur.
/// Cavablar da eyni qaydadadır.
List<ThreadNode> buildThread(Iterable<ThreadComment> comments) {
  final all = comments.toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  final ids = {for (final c in all) c.id};

  final roots = <ThreadComment>[];
  final children = <String, List<ThreadComment>>{};

  for (final comment in all) {
    final parent = comment.parentId;

    // Valideyni yoxdursa və ya silinibsə, özü kök olur.
    if (parent.isEmpty || !ids.contains(parent)) {
      roots.add(comment);
    } else {
      children.putIfAbsent(parent, () => []).add(comment);
    }
  }

  return [
    for (final root in roots)
      ThreadNode(root, children[root.id] ?? const <ThreadComment>[]),
  ];
}

/// Cavabın hansı kökə qoşulacağını tapır.
///
/// İkinci pillədəki şərhə cavab verəndə yeni pillə açılmır — cavab
/// eyni kökə gedir.
String rootIdFor(ThreadComment target) =>
    target.parentId.isEmpty ? target.id : target.parentId;

/// Şərhlərin ümumi sayı.
int countComments(List<ThreadNode> nodes) =>
    nodes.fold(0, (sum, node) => sum + node.total);
