/// Storilər — 24 saatlıq paylaşımlar.
///
/// Anlardan fərqi: stori lentdə qalmır, 24 saatdan sonra itir və
/// kimin baxdığı görünür. Maneə aşağıdır — adam "bu lentdə qalacaq"
/// deyə düşünmür, ona görə daha tez-tez paylaşır.
///
/// Vaxt hesablaması burada ayrıca saxlanılır ki, ekrandan asılı
/// olmadan yoxlanıla bilsin.
library;

/// Stori bu qədər saat yaşayır.
const int storyHours = 24;

/// Bir stori.
class Story {
  const Story({
    required this.id,
    required this.ownerUid,
    required this.ownerName,
    required this.createdAt,
    this.ownerPhoto = '',
    this.imageUrl = '',
    this.videoUrl = '',
    this.caption = '',
    this.viewCount = 0,
  });

  final String id;
  final String ownerUid;
  final String ownerName;
  final String ownerPhoto;
  final DateTime createdAt;

  final String imageUrl;
  final String videoUrl;
  final String caption;
  final int viewCount;

  bool get isVideo => videoUrl.trim().isNotEmpty;

  /// Hələ yaşayırmı?
  bool alive({DateTime? now}) =>
      (now ?? DateTime.now()).difference(createdAt).inHours < storyHours;

  /// Neçə saat qalıb (0..24).
  int hoursLeft({DateTime? now}) {
    final passed = (now ?? DateTime.now()).difference(createdAt).inHours;
    return (storyHours - passed).clamp(0, storyHours);
  }

  factory Story.from(String id, Map<String, dynamic> data) {
    final at = data['createdAt'];
    DateTime created;

    if (at is DateTime) {
      created = at;
    } else {
      try {
        created = (at as dynamic).toDate() as DateTime;
      } catch (_) {
        // Tarixi olmayan sənəd köhnə sayılır və siyahıdan düşür.
        created = DateTime.fromMillisecondsSinceEpoch(0);
      }
    }

    return Story(
      id: id,
      ownerUid: '${data['ownerUid'] ?? ''}',
      ownerName: '${data['ownerName'] ?? 'VIBE'}',
      ownerPhoto: '${data['ownerPhoto'] ?? ''}',
      createdAt: created,
      imageUrl: '${data['imageUrl'] ?? ''}',
      videoUrl: '${data['videoUrl'] ?? ''}',
      caption: '${data['caption'] ?? ''}',
      viewCount: int.tryParse('${data['viewCount'] ?? 0}') ?? 0,
    );
  }
}

/// Bir adamın storiləri.
class StoryGroup {
  const StoryGroup({
    required this.ownerUid,
    required this.ownerName,
    required this.ownerPhoto,
    required this.stories,
    required this.allSeen,
  });

  final String ownerUid;
  final String ownerName;
  final String ownerPhoto;
  final List<Story> stories;

  /// Hamısına baxılıbsa halqa sönük olur.
  final bool allSeen;

  Story get first => stories.first;
}

/// Storiləri sahiblərinə görə qruplaşdırır.
///
/// Sıra: əvvəlcə baxılmamışlar, sonra baxılanlar. Hər qrupun içində
/// köhnədən təzəyə — hekayə ardıcıl oxunsun deyə.
///
/// [me] siyahının əvvəlinə keçir: öz storini görmək ən asan olmalıdır.
List<StoryGroup> groupStories(
  Iterable<Story> stories, {
  required String me,
  Set<String> seen = const {},
  DateTime? now,
}) {
  final alive = stories.where((s) => s.alive(now: now)).toList();

  final byOwner = <String, List<Story>>{};
  for (final story in alive) {
    if (story.ownerUid.isEmpty) continue;
    byOwner.putIfAbsent(story.ownerUid, () => []).add(story);
  }

  final groups = <StoryGroup>[];

  byOwner.forEach((uid, list) {
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    groups.add(StoryGroup(
      ownerUid: uid,
      ownerName: list.last.ownerName,
      ownerPhoto: list.last.ownerPhoto,
      stories: list,
      allSeen: list.every((s) => seen.contains(s.id)),
    ));
  });

  groups.sort((a, b) {
    // Öz storim həmişə birinci.
    if (a.ownerUid == me) return -1;
    if (b.ownerUid == me) return 1;

    // Baxılmamışlar öndə.
    if (a.allSeen != b.allSeen) return a.allSeen ? 1 : -1;

    // Sonra təzədən köhnəyə.
    return b.stories.last.createdAt.compareTo(a.stories.last.createdAt);
  });

  return groups;
}
