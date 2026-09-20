-- VIBE — Firestore -> PostgreSQL sxemi.
--
-- Supabase panelində SQL Editor-a yapışdırıb işə sal.
-- Hər cədvəl bir Firestore kolleksiyasının qarşılığıdır.
--
-- İstifadəçi açarı haqqında:
--   profiles.id      — tətbiqin daxili açarı, bütün əlaqələr buna baxır.
--   profiles.auth_id — Supabase girişindəki hesab. İlk girişdə avtomatik bağlanır.
--   profiles.firebase_uid — köhnə Firebase ID-si, köçürmə üçün saxlanılır.
-- Bu üç sütun sayəsində məlumatı indi köçürmək, girişi isə sonra bağlamaq olur.

create extension if not exists "pgcrypto";

-- ─────────────────────────────  İSTİFADƏÇİ  ─────────────────────────────

create table if not exists profiles (
  id             uuid primary key default gen_random_uuid(),
  auth_id        uuid unique references auth.users(id) on delete set null,
  firebase_uid   text unique,

  name           text not null default '',
  email          text,
  phone          text,
  photo_url      text,
  about          text not null default '',

  city           text not null default '',
  country        text not null default '',
  country_code   text not null default '',
  gender         text,
  age            int,
  birth_date     date,

  interests      text[] not null default '{}',
  tags           text[] not null default '{}',

  level          int    not null default 1,
  coins          bigint not null default 0,
  gift_sent      bigint not null default 0,
  gift_received  bigint not null default 0,

  online         boolean not null default false,
  last_seen      timestamptz,

  -- Hazırda hansı otaqdadır (ana ekranda "sesli sohbetde" göstəricisi).
  active_room_id   uuid,
  active_room_name text,
  active_room_at   timestamptz,

  -- VIBE statusu: {mood, text, until}
  status         jsonb,

  -- Gündəlik mükafat seriyası.
  streak         int not null default 0,
  last_reward_at timestamptz,

  suspended        boolean not null default false,
  suspended_reason text,

  onboarded_at   timestamptz,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create index if not exists profiles_auth_idx     on profiles(auth_id);
create index if not exists profiles_online_idx   on profiles(online, last_seen desc);
create index if not exists profiles_country_idx  on profiles(country_code);
create index if not exists profiles_room_idx     on profiles(active_room_id) where active_room_id is not null;

-- followers + following bir cədvəldə.
create table if not exists follows (
  follower_id uuid not null references profiles(id) on delete cascade,
  followee_id uuid not null references profiles(id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (follower_id, followee_id),
  constraint follows_not_self check (follower_id <> followee_id)
);

create index if not exists follows_followee_idx on follows(followee_id, created_at desc);

-- blocked + blockedBy bir cədvəldə.
create table if not exists blocks (
  blocker_id uuid not null references profiles(id) on delete cascade,
  blocked_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id)
);

create index if not exists blocks_blocked_idx on blocks(blocked_id);

create table if not exists notifications (
  id         bigserial primary key,
  profile_id uuid not null references profiles(id) on delete cascade,
  type       text not null,
  title      text,
  body       text,
  from_id    uuid references profiles(id) on delete set null,
  -- Bildirişin apardığı yer: {videoId} / {roomId} / {chatId} ...
  data       jsonb not null default '{}',
  read       boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists notifications_inbox_idx on notifications(profile_id, created_at desc);

create table if not exists push_tokens (
  token      text primary key,
  profile_id uuid not null references profiles(id) on delete cascade,
  platform   text,
  created_at timestamptz not null default now()
);

create index if not exists push_tokens_profile_idx on push_tokens(profile_id);

-- Sikkə hərəkətləri — balans profiles.coins-dədir, bu jurnal.
create table if not exists wallet_tx (
  id         bigserial primary key,
  profile_id uuid not null references profiles(id) on delete cascade,
  amount     bigint not null,
  reason     text not null,
  balance    bigint,
  created_at timestamptz not null default now()
);

create index if not exists wallet_tx_profile_idx on wallet_tx(profile_id, created_at desc);

create table if not exists gallery (
  id         bigserial primary key,
  profile_id uuid not null references profiles(id) on delete cascade,
  url        text not null,
  position   int not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists gallery_profile_idx on gallery(profile_id, position);

-- ─────────────────────────────  SÖHBƏT  ─────────────────────────────

create table if not exists chats (
  id              uuid primary key default gen_random_uuid(),
  firebase_id     text unique,
  last_message    text,
  last_sender_id  uuid references profiles(id) on delete set null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index if not exists chats_updated_idx on chats(updated_at desc);

create table if not exists chat_members (
  chat_id      uuid not null references chats(id) on delete cascade,
  profile_id   uuid not null references profiles(id) on delete cascade,
  unread       int not null default 0,
  last_read_at timestamptz,
  muted        boolean not null default false,
  joined_at    timestamptz not null default now(),
  primary key (chat_id, profile_id)
);

-- "Mənim söhbətlərim" sorğusu bu indeksdən gedir.
create index if not exists chat_members_profile_idx on chat_members(profile_id);

create table if not exists messages (
  id          uuid primary key default gen_random_uuid(),
  chat_id     uuid not null references chats(id) on delete cascade,
  sender_id   uuid references profiles(id) on delete set null,
  -- text | photo | video | audio | sticker | gift | call | system
  type        text not null default 'text',
  text        text,
  reply_to    uuid references messages(id) on delete set null,
  read        boolean not null default false,
  -- Geri götürülmüş mesaj: mətn silinir, sətir qalır.
  deleted_at  timestamptz,
  created_at  timestamptz not null default now()
);

create index if not exists messages_chat_idx on messages(chat_id, created_at desc);

-- Bir mesajda bir neçə şəkil/video ola bilər.
create table if not exists message_media (
  id         bigserial primary key,
  message_id uuid not null references messages(id) on delete cascade,
  chat_id    uuid not null references chats(id) on delete cascade,
  url        text not null,
  kind       text not null default 'photo',
  width      int,
  height     int,
  duration   int,
  created_at timestamptz not null default now()
);

create index if not exists message_media_msg_idx on message_media(message_id);

-- ─────────────────────────────  ZƏNG  ─────────────────────────────

create table if not exists calls (
  id         uuid primary key default gen_random_uuid(),
  caller_id  uuid not null references profiles(id) on delete cascade,
  callee_id  uuid not null references profiles(id) on delete cascade,
  -- audio | video
  kind       text not null default 'audio',
  -- ringing | active | ended | declined | missed
  state      text not null default 'ringing',
  offer      jsonb,
  answer     jsonb,
  started_at timestamptz,
  ended_at   timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists calls_callee_idx on calls(callee_id, state, created_at desc);

-- callerCandidates + calleeCandidates bir cədvəldə.
create table if not exists call_candidates (
  id         bigserial primary key,
  call_id    uuid not null references calls(id) on delete cascade,
  -- caller | callee
  side       text not null,
  candidate  jsonb not null,
  created_at timestamptz not null default now()
);

create index if not exists call_candidates_call_idx on call_candidates(call_id, side);

-- ─────────────────────────────  ANLAR  ─────────────────────────────

create table if not exists moments (
  id            uuid primary key default gen_random_uuid(),
  firebase_id   text unique,
  author_id     uuid not null references profiles(id) on delete cascade,
  caption       text not null default '',
  -- Şəkil/video siyahısı: [{url, kind, width, height}]
  media         jsonb not null default '[]',
  -- public | followers | private
  visibility    text not null default 'public',
  like_count    int not null default 0,
  comment_count int not null default 0,
  gift_total    bigint not null default 0,
  created_at    timestamptz not null default now()
);

create index if not exists moments_feed_idx   on moments(created_at desc);
create index if not exists moments_author_idx on moments(author_id, created_at desc);

create table if not exists moment_likes (
  moment_id  uuid not null references moments(id) on delete cascade,
  profile_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (moment_id, profile_id)
);

create table if not exists moment_comments (
  id         uuid primary key default gen_random_uuid(),
  moment_id  uuid not null references moments(id) on delete cascade,
  author_id  uuid not null references profiles(id) on delete cascade,
  text       text not null default '',
  reply_to   uuid references moment_comments(id) on delete cascade,
  like_count int not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists moment_comments_idx on moment_comments(moment_id, created_at);

create table if not exists moment_comment_likes (
  comment_id uuid not null references moment_comments(id) on delete cascade,
  profile_id uuid not null references profiles(id) on delete cascade,
  primary key (comment_id, profile_id)
);

-- ─────────────────────────────  VİDEO  ─────────────────────────────

create table if not exists videos (
  id            uuid primary key default gen_random_uuid(),
  firebase_id   text unique,
  author_id     uuid not null references profiles(id) on delete cascade,
  video_url     text not null,
  thumb_url     text,
  caption       text not null default '',
  hashtags      text[] not null default '{}',
  music         jsonb,
  duration      int,
  views         bigint not null default 0,
  like_count    int not null default 0,
  comment_count int not null default 0,
  share_count   int not null default 0,
  visibility    text not null default 'public',
  created_at    timestamptz not null default now()
);

create index if not exists videos_feed_idx     on videos(created_at desc) where visibility = 'public';
create index if not exists videos_author_idx   on videos(author_id, created_at desc);
create index if not exists videos_hashtag_idx  on videos using gin(hashtags);

create table if not exists video_likes (
  video_id   uuid not null references videos(id) on delete cascade,
  profile_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (video_id, profile_id)
);

create table if not exists video_reposts (
  video_id   uuid not null references videos(id) on delete cascade,
  profile_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (video_id, profile_id)
);

create table if not exists video_comments (
  id         uuid primary key default gen_random_uuid(),
  video_id   uuid not null references videos(id) on delete cascade,
  author_id  uuid not null references profiles(id) on delete cascade,
  text       text not null default '',
  reply_to   uuid references video_comments(id) on delete cascade,
  like_count int not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists video_comments_idx on video_comments(video_id, created_at);

create table if not exists video_comment_likes (
  comment_id uuid not null references video_comments(id) on delete cascade,
  profile_id uuid not null references profiles(id) on delete cascade,
  primary key (comment_id, profile_id)
);

-- savedVideos / hiddenVideos / watchHistory — üçü də eyni formadadır.
create table if not exists video_marks (
  profile_id uuid not null references profiles(id) on delete cascade,
  video_id   uuid not null references videos(id) on delete cascade,
  -- saved | hidden | watched
  kind       text not null,
  created_at timestamptz not null default now(),
  primary key (profile_id, video_id, kind)
);

create index if not exists video_marks_kind_idx on video_marks(profile_id, kind, created_at desc);

-- ─────────────────────────────  OTAQLAR  ─────────────────────────────

create table if not exists rooms (
  id           uuid primary key default gen_random_uuid(),
  firebase_id  text unique,
  host_id      uuid not null references profiles(id) on delete cascade,
  title        text not null default '',
  topic        text not null default '',
  cover_url    text,
  theme        text not null default 'default',
  -- Görüntülü otaq.
  video        boolean not null default false,
  locked       boolean not null default false,
  password     text,
  seat_count   int not null default 8,
  member_count int not null default 0,
  gift_total   bigint not null default 0,
  moderators   uuid[] not null default '{}',
  -- Sinxron musiqi: {url, title, by, playing, started_at}
  music        jsonb,
  -- PK yarışı: {rival_room, points, ends_at}
  pk           jsonb,
  live         boolean not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index if not exists rooms_live_idx on rooms(live, member_count desc) where live;

-- Firestore-da seats otaq sənədinin içində xəritə idi.
-- Ayrıca cədvəl kürsünü atomik tutmağa imkan verir: iki nəfər eyni anda
-- basanda ikincisi unikal şərtdən qayıdır, üstünə yazmır.
create table if not exists room_seats (
  room_id    uuid not null references rooms(id) on delete cascade,
  idx        int  not null,
  profile_id uuid references profiles(id) on delete set null,
  muted      boolean not null default false,
  locked     boolean not null default false,
  taken_at   timestamptz,
  primary key (room_id, idx)
);

-- Bir adam eyni otaqda yalnız bir kürsüdə otura bilər.
create unique index if not exists room_seats_one_per_user
  on room_seats(room_id, profile_id) where profile_id is not null;

create table if not exists room_members (
  room_id    uuid not null references rooms(id) on delete cascade,
  profile_id uuid not null references profiles(id) on delete cascade,
  role       text not null default 'listener',
  joined_at  timestamptz not null default now(),
  primary key (room_id, profile_id)
);

create index if not exists room_members_profile_idx on room_members(profile_id);

create table if not exists room_bans (
  room_id    uuid not null references rooms(id) on delete cascade,
  profile_id uuid not null references profiles(id) on delete cascade,
  by_id      uuid references profiles(id) on delete set null,
  reason     text,
  created_at timestamptz not null default now(),
  primary key (room_id, profile_id)
);

create table if not exists room_messages (
  id         uuid primary key default gen_random_uuid(),
  room_id    uuid not null references rooms(id) on delete cascade,
  sender_id  uuid references profiles(id) on delete set null,
  text       text not null default '',
  type       text not null default 'text',
  created_at timestamptz not null default now()
);

create index if not exists room_messages_idx on room_messages(room_id, created_at desc);

-- Otağa giriş, kürsü dəyişikliyi, atılma — effekt lenti buradan oxunur.
create table if not exists room_events (
  id         bigserial primary key,
  room_id    uuid not null references rooms(id) on delete cascade,
  profile_id uuid references profiles(id) on delete set null,
  type       text not null,
  data       jsonb not null default '{}',
  created_at timestamptz not null default now()
);

create index if not exists room_events_idx on room_events(room_id, created_at desc);

create table if not exists room_seat_invites (
  id         bigserial primary key,
  room_id    uuid not null references rooms(id) on delete cascade,
  profile_id uuid not null references profiles(id) on delete cascade,
  by_id      uuid references profiles(id) on delete set null,
  seat_idx   int,
  created_at timestamptz not null default now()
);

create index if not exists room_seat_invites_idx on room_seat_invites(profile_id, created_at desc);

create table if not exists room_mic_requests (
  room_id    uuid not null references rooms(id) on delete cascade,
  profile_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (room_id, profile_id)
);

-- WebRTC siqnallaşması: hər cüt üçün bir sətir.
create table if not exists room_rtc (
  id         bigserial primary key,
  room_id    uuid not null references rooms(id) on delete cascade,
  from_id    uuid not null references profiles(id) on delete cascade,
  to_id      uuid not null references profiles(id) on delete cascade,
  -- offer | answer | candidate
  kind       text not null,
  payload    jsonb not null,
  created_at timestamptz not null default now()
);

create index if not exists room_rtc_inbox_idx on room_rtc(room_id, to_id, created_at);

-- ─────────────────────────────  HƏDİYYƏ VƏ OYUN  ─────────────────────────────

-- Göndərilən hər hədiyyə — həm otaqda, həm söhbətdə, həm anlarda.
create table if not exists gifts_sent (
  id         bigserial primary key,
  from_id    uuid not null references profiles(id) on delete cascade,
  to_id      uuid not null references profiles(id) on delete cascade,
  gift_id    text not null,
  emoji      text,
  quantity   int  not null default 1,
  total      bigint not null default 0,
  -- Hədiyyə harada verilib.
  room_id    uuid references rooms(id) on delete set null,
  moment_id  uuid references moments(id) on delete set null,
  chat_id    uuid references chats(id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists gifts_room_idx on gifts_sent(room_id, created_at desc);
create index if not exists gifts_to_idx   on gifts_sent(to_id, created_at desc);

create table if not exists domino_matches (
  id         uuid primary key default gen_random_uuid(),
  room_id    uuid references rooms(id) on delete cascade,
  chat_id    uuid references chats(id) on delete cascade,
  players    uuid[] not null default '{}',
  -- Oyun vəziyyəti: əl, masa, növbə, xal.
  state      jsonb not null default '{}',
  winner_id  uuid references profiles(id) on delete set null,
  finished   boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists domino_players_idx on domino_matches using gin(players);

-- Oyun nəticələri — profildə "qalibiyyət" sayğacı üçün.
create table if not exists match_history (
  id         bigserial primary key,
  profile_id uuid not null references profiles(id) on delete cascade,
  game       text not null,
  won        boolean not null default false,
  score      int not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists match_history_idx on match_history(profile_id, created_at desc);

-- ─────────────────────────────  ŞİKAYƏT  ─────────────────────────────

create table if not exists reports (
  id           bigserial primary key,
  reporter_id  uuid references profiles(id) on delete set null,
  target_id    uuid references profiles(id) on delete set null,
  -- user | video | moment | message | room
  target_type  text not null default 'user',
  target_ref   text,
  reason       text not null,
  note         text,
  handled      boolean not null default false,
  created_at   timestamptz not null default now()
);

create index if not exists reports_open_idx on reports(handled, created_at desc);

-- ─────────────────────────────  KÖMƏKÇİLƏR  ─────────────────────────────

-- Girmiş adamın tətbiq daxilindəki açarı.
-- Bütün RLS qaydaları bunun üstündə qurulur.
create or replace function app_uid() returns uuid
language sql stable security definer set search_path = public as $$
  select id from profiles where auth_id = auth.uid()
$$;

-- Yeni hesab açılanda profili bağlayır.
-- Köçürülmüş sətir varsa (eyni e-poçt) onu mənimsəyir, yoxdursa yenisini yaradır.
create or replace function handle_new_auth_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  claimed uuid;
begin
  update profiles
     set auth_id = new.id,
         updated_at = now()
   where auth_id is null
     and email is not null
     and lower(email) = lower(new.email)
  returning id into claimed;

  if claimed is null then
    insert into profiles (auth_id, email, phone, name, photo_url)
    values (
      new.id,
      new.email,
      new.phone,
      coalesce(new.raw_user_meta_data->>'full_name', 'VIBE istifadəçisi'),
      new.raw_user_meta_data->>'avatar_url'
    );
  end if;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_auth_user();

-- updated_at özü yenilənsin.
create or replace function touch_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

do $$
declare t text;
begin
  foreach t in array array['profiles','chats','rooms','domino_matches'] loop
    execute format(
      'drop trigger if exists touch_%1$s on %1$s;
       create trigger touch_%1$s before update on %1$s
       for each row execute function touch_updated_at()', t);
  end loop;
end $$;
