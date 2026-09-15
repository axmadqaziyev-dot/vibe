class Profile {
  const Profile({required this.id, required this.name, required this.age,
    required this.country, this.bio = '', this.language = 'English',
    this.interests = const [], this.avatar = 0});
  final String id, name, country, bio, language;
  final int age, avatar;
  final List<String> interests;
  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
    id: j['id'] as String, name: j['display_name'] as String,
    age: (j['age'] as num).toInt(), country: j['country'] as String,
    bio: j['bio'] as String? ?? '', language: j['language'] as String? ?? 'English',
    avatar: (j['avatar'] as num?)?.toInt() ?? 0,
    interests: List<String>.from(j['interests'] as List? ?? []));
}
class ChatMessage {
  const ChatMessage({required this.id, required this.sender, required this.body, required this.at});
  final String id, sender, body;
  final DateTime at;
  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
    id: j['id'].toString(), sender: j['sender_id'] as String,
    body: j['body'] as String, at: DateTime.parse(j['created_at'] as String));
}
class Conversation {
  const Conversation({required this.id, required this.peer});
  final String id;
  final Profile peer;
}
class SocialRoom {
  const SocialRoom({required this.id, required this.title, required this.topic,
    required this.language, required this.description});
  final String id, title, topic, language, description;
  factory SocialRoom.fromJson(Map<String, dynamic> j) => SocialRoom(
    id: j['id'] as String, title: j['title'] as String, topic: j['topic'] as String,
    language: j['language'] as String, description: j['description'] as String);
}
class WalletEntry {
  const WalletEntry({required this.amount, required this.kind, required this.at});
  final int amount;
  final String kind;
  final DateTime at;
}
const previewProfiles = [
  Profile(id: 'aya', name: 'Aya', age: 24, country: 'Japan', bio: 'Coffee, city walks and little adventures. Tell me your favorite place!',
    language: 'English', interests: ['Travel', 'Music'], avatar: 1),
  Profile(id: 'deniz', name: 'Deniz', age: 26, country: 'Türkiye', bio: 'Making playlists and meeting people from everywhere.',
    language: 'Türkçe', interests: ['Music', 'Gaming'], avatar: 2),
  Profile(id: 'sofia', name: 'Sofia', age: 23, country: 'Spain', bio: 'One more book, one more trip. Always curious.',
    language: 'English', interests: ['Art', 'Travel'], avatar: 3),
  Profile(id: 'leo', name: 'Leo', age: 27, country: 'Brazil', bio: 'Football, good food and a good conversation.',
    language: 'English', interests: ['Sports', 'Food'], avatar: 4),
];
const previewRooms = [
  SocialRoom(id: 'lounge', title: 'The global lounge', topic: 'Travel', language: 'English',
    description: 'A little corner of the world. Share a story from your city.'),
  SocialRoom(id: 'music', title: 'One more song', topic: 'Music', language: 'English',
    description: 'What is on repeat? Exchange songs and discover a new favorite.'),
  SocialRoom(id: 'gaming', title: 'After the game', topic: 'Gaming', language: 'Türkçe',
    description: 'Meet other players, share your wins and plan your next game.'),
];
const interests = ['Music', 'Travel', 'Gaming', 'Art', 'Sports', 'Food'];

