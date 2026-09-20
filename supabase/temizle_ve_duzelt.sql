-- Yarımçıq köçürməni təmizləyir və sayğac funksiyasını düzəldir.
--
-- DİQQƏT: bu, Supabase-dəki VIBE cədvəllərini boşaldır.
-- Firebase-dəki məlumata toxunmur — mənbə orada qalır.

truncate table
  profiles, follows, blocks, notifications, push_tokens, wallet_tx, gallery,
  chats, chat_members, messages, message_media, calls, call_candidates,
  moments, moment_likes, moment_comments, moment_comment_likes,
  videos, video_likes, video_reposts, video_comments, video_comment_likes, video_marks,
  rooms, room_seats, room_members, room_bans, room_messages, room_events,
  room_seat_invites, room_mic_requests, room_rtc,
  gifts_sent, domino_matches, match_history, reports
restart identity cascade;

-- Supabase-in "safe update" qoruması WHERE olmadan UPDATE-ə icazə vermir.
create or replace function recount_all() returns void
language sql security definer set search_path = public as $$
  update moments m set
    like_count    = (select count(*) from moment_likes    where moment_id = m.id),
    comment_count = (select count(*) from moment_comments where moment_id = m.id)
  where true;

  update videos v set
    like_count    = (select count(*) from video_likes    where video_id = v.id),
    comment_count = (select count(*) from video_comments where video_id = v.id)
  where true;

  update rooms r set
    member_count = (select count(*) from room_members where room_id = r.id)
  where true;
$$;

revoke execute on function recount_all() from public, anon, authenticated;
