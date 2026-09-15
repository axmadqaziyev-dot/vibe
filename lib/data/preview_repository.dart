import 'dart:async';
import '../domain/models.dart';
import 'repository.dart';

/// Explicit, volatile sandbox. Never authenticates a real account or charges money.
class PreviewRepository implements VibeRepository {
  Profile profile = const Profile(id: 'preview', name: 'Alex', age: 24, country: 'Azerbaijan',
    bio: 'Here to meet the world.', interests: ['Music', 'Travel']);
  final _events = StreamController<void>.broadcast();
  final Map<String, List<ChatMessage>> _messages = {};
  final Set<String> _conversations = {}, _blocked = {}, _giftRequests = {};
  final List<WalletEntry> _ledger = [];
  int _balance = 500;
  @override bool get isPreview => true;
  @override String get userId => profile.id;
  @override Stream<void> get authChanges => const Stream.empty();
  @override Future<bool> signUp({required String email, required String password,
    required String name, required DateTime birthDate, required String country,
    required String language}) async => throw StateError('Preview does not create accounts.');
  @override Future<void> signIn(String email, String password) async =>
    throw StateError('Preview does not authenticate accounts.');
  @override Future<void> signOut() async {}
  @override Future<Profile> myProfile() async => profile;
  @override Future<void> saveProfile(Profile value) async { profile = value; }
  @override Future<List<Profile>> discover() async =>
    previewProfiles.where((p) => !_blocked.contains(p.id)).toList();
  @override Future<List<Conversation>> conversations() async => previewProfiles
    .where((p) => _conversations.contains(p.id) && !_blocked.contains(p.id))
    .map((p) => Conversation(id: p.id, peer: p)).toList();
  @override Future<String> startConversation(String peerId) async {
    if (_blocked.contains(peerId)) throw StateError('User is blocked.');
    _conversations.add(peerId);
    return peerId;
  }
  Stream<List<ChatMessage>> _watch(String key) async* {
    yield List.unmodifiable(_messages[key] ?? []);
    yield* _events.stream.map((_) => List<ChatMessage>.unmodifiable(_messages[key] ?? []));
  }
  void _send(String key, String body) {
    if (body.trim().isEmpty || body.trim().length > 2000) {
      throw ArgumentError('Message must contain 1–2000 characters.');
    }
    (_messages[key] ??= []).add(ChatMessage(id: DateTime.now().microsecondsSinceEpoch.toString(),
      sender: userId, body: body.trim(), at: DateTime.now()));
    _events.add(null);
  }
  @override Stream<List<ChatMessage>> messages(String conversationId) => _watch(conversationId);
  @override Future<void> sendMessage(String conversationId, String body) async {
    if (_blocked.contains(conversationId)) throw StateError('User is blocked.');
    _send(conversationId, body);
  }
  @override Future<List<SocialRoom>> rooms() async => previewRooms;
  @override Stream<List<ChatMessage>> roomMessages(String roomId) => _watch('room:$roomId');
  @override Future<void> sendRoomMessage(String roomId, String body) async => _send('room:$roomId', body);
  @override Future<void> report(String userId, String reason) async {}
  @override Future<void> block(String userId) async { _blocked.add(userId); _events.add(null); }
  @override Future<List<Profile>> blockedProfiles() async =>
    previewProfiles.where((p) => _blocked.contains(p.id)).toList();
  @override Future<void> unblock(String userId) async { _blocked.remove(userId); }
  @override Future<int> balance() async => _balance;
  @override Future<List<WalletEntry>> ledger() async => List.unmodifiable(_ledger.reversed);
  @override Future<void> sendGift(String peerId, String giftId, String requestId) async {
    if (_giftRequests.contains(requestId)) return;
    if (_blocked.contains(peerId)) throw StateError('User is blocked.');
    final cost = {'rose': 10, 'star': 50, 'crown': 100}[giftId];
    if (cost == null || _balance < cost) throw StateError('Not enough coins.');
    _balance -= cost;
    _giftRequests.add(requestId);
    _ledger.add(WalletEntry(amount: -cost, kind: giftId, at: DateTime.now()));
  }
  @override Future<void> deleteAccount() async {}
  @override Future<void> dispose() => _events.close();
}

