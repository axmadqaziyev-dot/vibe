import '../domain/models.dart';

abstract class VibeRepository {
  bool get isPreview;
  String? get userId;
  Stream<void> get authChanges;
  Future<bool> signUp({required String email, required String password, required String name,
    required DateTime birthDate, required String country, required String language});
  Future<void> signIn(String email, String password);
  Future<void> signOut();
  Future<Profile?> myProfile();
  Future<void> saveProfile(Profile profile);
  Future<List<Profile>> discover();
  Future<List<Conversation>> conversations();
  Future<String> startConversation(String peerId);
  Stream<List<ChatMessage>> messages(String conversationId);
  Future<void> sendMessage(String conversationId, String body);
  Future<List<SocialRoom>> rooms();
  Stream<List<ChatMessage>> roomMessages(String roomId);
  Future<void> sendRoomMessage(String roomId, String body);
  Future<void> report(String userId, String reason);
  Future<void> block(String userId);
  Future<List<Profile>> blockedProfiles();
  Future<void> unblock(String userId);
  Future<int> balance();
  Future<List<WalletEntry>> ledger();
  Future<void> sendGift(String peerId, String giftId, String requestId);
  Future<void> deleteAccount();
  Future<void> dispose();
}

