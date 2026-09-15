import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/models.dart';
import 'repository.dart';

class SupabaseRepository implements VibeRepository {
  SupabaseRepository(this.client);
  final SupabaseClient client;
  @override bool get isPreview => false;
  @override String? get userId => client.auth.currentUser?.id;
  @override Stream<void> get authChanges => client.auth.onAuthStateChange.map((_) {});
  @override Future<bool> signUp({required String email, required String password,
    required String name, required DateTime birthDate, required String country,
    required String language}) async {
    final result = await client.auth.signUp(email: email, password: password, data: {
      'display_name': name, 'birth_date': birthDate.toIso8601String().split('T').first,
      'country': country, 'language': language, 'terms_version': '2026-09-12',
    });
    return result.session != null;
  }
  @override Future<void> signIn(String email, String password) async {
    await client.auth.signInWithPassword(email: email, password: password);
  }
  @override Future<void> signOut() => client.auth.signOut();
  @override Future<Profile?> myProfile() async {
    final row = await client.from('profiles').select().eq('id', userId!).maybeSingle();
    return row == null ? null : Profile.fromJson(row);
  }
  @override Future<void> saveProfile(Profile p) async {
    await client.from('profiles').update({'display_name': p.name, 'bio': p.bio,
      'country': p.country, 'language': p.language, 'interests': p.interests,
      'avatar': p.avatar}).eq('id', userId!);
  }
  @override Future<List<Profile>> discover() async {
    final rows = await client.from('profiles').select().neq('id', userId!).order('created_at', ascending: false).limit(100);
    return rows.map(Profile.fromJson).toList();
  }
  @override Future<List<Conversation>> conversations() async {
    final rows = await client.from('conversations').select()
      .or('user_a.eq.$userId,user_b.eq.$userId').order('created_at', ascending: false);
    final result = <Conversation>[];
    for (final row in rows) {
      final peerId = row['user_a'] == userId ? row['user_b'] : row['user_a'];
      final peer = await client.from('profiles').select().eq('id', peerId).maybeSingle();
      if (peer != null) result.add(Conversation(id: row['id'] as String, peer: Profile.fromJson(peer)));
    }
    return result;
  }
  @override Future<String> startConversation(String peerId) async =>
    await client.rpc('start_conversation', params: {'peer': peerId}) as String;
  @override Stream<List<ChatMessage>> messages(String conversationId) => client.from('messages')
    .stream(primaryKey: ['id']).eq('conversation_id', conversationId)
    .order('created_at').limit(200).map((rows) => rows.map(ChatMessage.fromJson).toList());
  @override Future<void> sendMessage(String conversationId, String body) async {
    await client.from('messages').insert({'conversation_id': conversationId,
      'sender_id': userId!, 'body': body.trim()});
  }
  @override Future<List<SocialRoom>> rooms() async =>
    (await client.from('rooms').select().order('created_at')).map(SocialRoom.fromJson).toList();
  @override Stream<List<ChatMessage>> roomMessages(String roomId) => client.from('room_messages')
    .stream(primaryKey: ['id']).eq('room_id', roomId).order('created_at').limit(200)
    .map((rows) => rows.map(ChatMessage.fromJson).toList());
  @override Future<void> sendRoomMessage(String roomId, String body) async {
    await client.from('room_messages').insert({'room_id': roomId, 'sender_id': userId!, 'body': body.trim()});
  }
  @override Future<void> report(String userId, String reason) async {
    await client.from('reports').insert({'reporter_id': this.userId!, 'target_id': userId, 'reason': reason});
  }
  @override Future<void> block(String userId) async {
    await client.from('blocks').upsert({'blocker_id': this.userId!, 'blocked_id': userId});
  }
  @override Future<List<Profile>> blockedProfiles() async =>
    (await client.rpc('blocked_profiles') as List).map((row) =>
      Profile.fromJson(Map<String, dynamic>.from(row as Map))).toList();
  @override Future<void> unblock(String userId) async {
    await client.from('blocks').delete().eq('blocker_id', this.userId!).eq('blocked_id', userId);
  }
  @override Future<int> balance() async {
    final row = await client.from('wallets').select('balance').eq('user_id', userId!).single();
    return (row['balance'] as num).toInt();
  }
  @override Future<List<WalletEntry>> ledger() async =>
    (await client.from('wallet_ledger').select().eq('user_id', userId!)
      .order('created_at', ascending: false).limit(100)).map((row) => WalletEntry(
        amount: (row['amount'] as num).toInt(), kind: row['kind'] as String,
        at: DateTime.parse(row['created_at'] as String))).toList();
  @override Future<void> sendGift(String peerId, String giftId, String requestId) async {
    await client.rpc('send_gift', params: {'recipient': peerId, 'gift': giftId, 'request_id': requestId});
  }
  @override Future<void> deleteAccount() async {
    await client.rpc('delete_my_account');
    await client.auth.signOut(scope: SignOutScope.local);
  }
  @override Future<void> dispose() async {}
}

