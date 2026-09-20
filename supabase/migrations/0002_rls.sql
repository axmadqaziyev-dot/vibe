-- VIBE — sətir səviyyəsində təhlükəsizlik.
-- firestore.rules faylının Postgres qarşılığı.
--
-- Qayda: hər cədvəldə RLS açıqdır. Açıq qalan cədvəl = açıq baza.

-- ── Giriş: Firebase ──
--
-- Giriş Firebase-də qalır, məlumat Supabase-dədir.
-- Supabase paneli Firebase-in imzaladığı JWT-ni tanıyır (Third-Party Auth),
-- biz də oradakı "sub" sahəsini profiles.firebase_uid ilə tutuşdururuq.
--
-- DİQQƏT: qaydalarda Supabase-in öz istifadəçi funksiyasını çağırmaq olmaz.
-- O funksiya "sub" sahəsini uuid-ə çevirir, Firebase ID-si isə uuid formatında
-- deyil — sorğu dərhal xəta verir. Ona görə hər yerdə app_uid() işlənir.

create or replace function app_uid() returns uuid
language sql stable security definer set search_path = public as $$
  select p.id from profiles p
   where p.firebase_uid = nullif(auth.jwt() ->> 'sub', '')
   limit 1
$$;

-- Yeni istifadəçinin ilk profili.
-- Profil sətri olmayana qədər app_uid() boşdur, yəni adam heç nə yaza bilmir.
-- Bu funksiya qaydaları keçərək ilk sətri yaradır, amma ID-ni özü deyil,
-- JWT-dən götürür — başqasının adına profil açmaq mümkün deyil.
create or replace function ensure_profile(
  p_name  text default null,
  p_email text default null,
  p_photo text default null
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  fuid text := nullif(auth.jwt() ->> 'sub', '');
  pid  uuid;
begin
  if fuid is null then
    raise exception 'giriş yoxdur' using errcode = '28000';
  end if;

  select id into pid from profiles where firebase_uid = fuid;
  if pid is not null then
    return pid;
  end if;

  insert into profiles (firebase_uid, name, email, photo_url, coins)
  values (fuid, coalesce(nullif(p_name, ''), 'VIBE istifadəçisi'),
          nullif(p_email, ''), nullif(p_photo, ''), 100)
  returning id into pid;

  return pid;
end;
$$;

-- ── Köməkçi yoxlamalar ──
-- security definer olmalıdır: qayda öz cədvəlinə baxsa sonsuz dövr yaranır.

create or replace function is_chat_member(target uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from chat_members
     where chat_id = target and profile_id = app_uid()
  )
$$;

create or replace function is_room_member(target uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from room_members
     where room_id = target and profile_id = app_uid()
  )
$$;

create or replace function can_moderate_room(target uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from rooms
     where id = target
       and (host_id = app_uid() or app_uid() = any(moderators))
  )
$$;

-- Bloklanmış adamın məzmunu görünməsin.
create or replace function is_blocked_with(other uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from blocks
     where (blocker_id = app_uid() and blocked_id = other)
        or (blocker_id = other and blocked_id = app_uid())
  )
$$;

-- ── RLS-i bütün cədvəllərdə aç ──

do $$
declare t text;
begin
  foreach t in array array[
    'profiles','follows','blocks','notifications','push_tokens','wallet_tx','gallery',
    'chats','chat_members','messages','message_media','calls','call_candidates',
    'moments','moment_likes','moment_comments','moment_comment_likes',
    'videos','video_likes','video_reposts','video_comments','video_comment_likes','video_marks',
    'rooms','room_seats','room_members','room_bans','room_messages','room_events',
    'room_seat_invites','room_mic_requests','room_rtc',
    'gifts_sent','domino_matches','match_history','reports'
  ] loop
    execute format('alter table %I enable row level security', t);
  end loop;
end $$;

-- Köhnə qaydaları silirik ki, fayl təkrar işə salına bilsin.
-- Postgres-də "create policy if not exists" yoxdur, ona görə əl ilə təmizləyirik.
do $$
declare r record;
begin
  for r in
    select schemaname, tablename, policyname
      from pg_policies
     where schemaname = 'public'
  loop
    execute format('drop policy if exists %I on %I.%I',
                   r.policyname, r.schemaname, r.tablename);
  end loop;
end $$;

-- ── Profil ──

create policy "profil hamıya görünür" on profiles
  for select to anon, authenticated using (app_uid() is not null);

create policy "öz profilini dəyişir" on profiles
  for update to anon, authenticated
  using (id = app_uid()) with check (id = app_uid());

-- ── İzləmə və blok ──

create policy "izləmələr görünür" on follows
  for select to anon, authenticated using (app_uid() is not null);

create policy "özün izləyirsən" on follows
  for insert to anon, authenticated with check (follower_id = app_uid());

create policy "öz izləməni silirsən" on follows
  for delete to anon, authenticated using (follower_id = app_uid());

create policy "öz bloklarını görürsən" on blocks
  for select to anon, authenticated using (blocker_id = app_uid() or blocked_id = app_uid());

create policy "özün bloklayırsan" on blocks
  for insert to anon, authenticated with check (blocker_id = app_uid());

create policy "öz blokunu açırsan" on blocks
  for delete to anon, authenticated using (blocker_id = app_uid());

-- ── Bildiriş ──

create policy "öz bildirişlərin" on notifications
  for select to anon, authenticated using (profile_id = app_uid());

create policy "bildiriş göndərirsən" on notifications
  for insert to anon, authenticated with check (from_id = app_uid());

create policy "oxundu işarələyirsən" on notifications
  for update to anon, authenticated using (profile_id = app_uid());

create policy "öz bildirişini silirsən" on notifications
  for delete to anon, authenticated using (profile_id = app_uid());

create policy "öz cihaz açarların" on push_tokens
  for all to anon, authenticated
  using (profile_id = app_uid()) with check (profile_id = app_uid());

-- ── Pul kisəsi ──
-- Yalnız oxumaq. Sikkə dəyişikliyi server tərəfdəki funksiyalardan keçir.

create policy "öz hesab hərəkətlərin" on wallet_tx
  for select to anon, authenticated using (profile_id = app_uid());

create policy "qalereya görünür" on gallery
  for select to anon, authenticated using (app_uid() is not null);

create policy "öz qalereyan" on gallery
  for all to anon, authenticated
  using (profile_id = app_uid()) with check (profile_id = app_uid());

-- ── Söhbət ──

create policy "üzv olduğun söhbətlər" on chats
  for select to anon, authenticated using (is_chat_member(id));

create policy "söhbət yaradırsan" on chats
  for insert to anon, authenticated with check (true);

create policy "söhbəti yeniləyirsən" on chats
  for update to anon, authenticated using (is_chat_member(id));

create policy "söhbət üzvləri görünür" on chat_members
  for select to anon, authenticated using (is_chat_member(chat_id) or profile_id = app_uid());

create policy "söhbətə üzv əlavə" on chat_members
  for insert to anon, authenticated with check (profile_id = app_uid() or is_chat_member(chat_id));

create policy "öz üzvlüyünü yeniləyirsən" on chat_members
  for update to anon, authenticated using (profile_id = app_uid());

create policy "söhbətdən çıxırsan" on chat_members
  for delete to anon, authenticated using (profile_id = app_uid());

create policy "söhbət mesajları" on messages
  for select to anon, authenticated using (is_chat_member(chat_id));

create policy "mesaj yazırsan" on messages
  for insert to anon, authenticated
  with check (sender_id = app_uid() and is_chat_member(chat_id));

-- Geri götürmə və "oxundu" eyni yoldan gedir.
create policy "mesajı yeniləyirsən" on messages
  for update to anon, authenticated using (is_chat_member(chat_id));

create policy "öz mesajını silirsən" on messages
  for delete to anon, authenticated using (sender_id = app_uid());

create policy "mesaj faylları" on message_media
  for select to anon, authenticated using (is_chat_member(chat_id));

create policy "fayl əlavə edirsən" on message_media
  for insert to anon, authenticated with check (is_chat_member(chat_id));

create policy "fayl silirsən" on message_media
  for delete to anon, authenticated using (is_chat_member(chat_id));

-- ── Zəng ──

create policy "öz zənglərin" on calls
  for select to anon, authenticated using (caller_id = app_uid() or callee_id = app_uid());

create policy "zəng edirsən" on calls
  for insert to anon, authenticated with check (caller_id = app_uid());

create policy "zəngi yeniləyirsən" on calls
  for update to anon, authenticated using (caller_id = app_uid() or callee_id = app_uid());

create policy "zəng namizədləri" on call_candidates
  for select to anon, authenticated using (
    exists (select 1 from calls c
             where c.id = call_id
               and (c.caller_id = app_uid() or c.callee_id = app_uid()))
  );

create policy "namizəd əlavə" on call_candidates
  for insert to anon, authenticated with check (
    exists (select 1 from calls c
             where c.id = call_id
               and (c.caller_id = app_uid() or c.callee_id = app_uid()))
  );

-- ── Anlar ──

create policy "anlar görünür" on moments
  for select to anon, authenticated using (
    not is_blocked_with(author_id)
    and (
      visibility = 'public'
      or author_id = app_uid()
      or (visibility = 'followers' and exists (
            select 1 from follows
             where follower_id = app_uid() and followee_id = author_id))
    )
  );

create policy "an paylaşırsan" on moments
  for insert to anon, authenticated with check (author_id = app_uid());

create policy "öz anını dəyişirsən" on moments
  for update to anon, authenticated using (author_id = app_uid());

create policy "öz anını silirsən" on moments
  for delete to anon, authenticated using (author_id = app_uid());

create policy "an bəyənmələri" on moment_likes
  for select to anon, authenticated using (app_uid() is not null);

create policy "an bəyənirsən" on moment_likes
  for insert to anon, authenticated with check (profile_id = app_uid());

create policy "an bəyənməsini götürürsən" on moment_likes
  for delete to anon, authenticated using (profile_id = app_uid());

create policy "an şərhləri" on moment_comments
  for select to anon, authenticated using (not is_blocked_with(author_id));

create policy "ana şərh yazırsan" on moment_comments
  for insert to anon, authenticated with check (author_id = app_uid());

create policy "şərhi silirsən" on moment_comments
  for delete to anon, authenticated using (
    author_id = app_uid()
    or exists (select 1 from moments m where m.id = moment_id and m.author_id = app_uid())
  );

create policy "şərh bəyənmələri" on moment_comment_likes
  for select to anon, authenticated using (app_uid() is not null);

create policy "şərh bəyənirsən" on moment_comment_likes
  for all to anon, authenticated
  using (profile_id = app_uid()) with check (profile_id = app_uid());

-- ── Video ──

create policy "videolar görünür" on videos
  for select to anon, authenticated using (
    not is_blocked_with(author_id)
    and (visibility = 'public' or author_id = app_uid())
  );

create policy "video yükləyirsən" on videos
  for insert to anon, authenticated with check (author_id = app_uid());

create policy "öz videonu dəyişirsən" on videos
  for update to anon, authenticated using (author_id = app_uid());

create policy "öz videonu silirsən" on videos
  for delete to anon, authenticated using (author_id = app_uid());

create policy "video bəyənmələri" on video_likes
  for select to anon, authenticated using (app_uid() is not null);

create policy "video bəyənirsən" on video_likes
  for all to anon, authenticated
  using (profile_id = app_uid()) with check (profile_id = app_uid());

create policy "paylaşımlar görünür" on video_reposts
  for select to anon, authenticated using (app_uid() is not null);

create policy "videonu paylaşırsan" on video_reposts
  for all to anon, authenticated
  using (profile_id = app_uid()) with check (profile_id = app_uid());

create policy "video şərhləri" on video_comments
  for select to anon, authenticated using (not is_blocked_with(author_id));

create policy "videoya şərh yazırsan" on video_comments
  for insert to anon, authenticated with check (author_id = app_uid());

create policy "video şərhini silirsən" on video_comments
  for delete to anon, authenticated using (
    author_id = app_uid()
    or exists (select 1 from videos v where v.id = video_id and v.author_id = app_uid())
  );

create policy "video şərh bəyənmələri" on video_comment_likes
  for select to anon, authenticated using (app_uid() is not null);

create policy "video şərhini bəyənirsən" on video_comment_likes
  for all to anon, authenticated
  using (profile_id = app_uid()) with check (profile_id = app_uid());

-- Yadda saxlanan / gizlədilən / baxılan — yalnız sahibinə görünür.
create policy "öz video işarələrin" on video_marks
  for all to anon, authenticated
  using (profile_id = app_uid()) with check (profile_id = app_uid());

-- ── Otaqlar ──

create policy "otaqlar görünür" on rooms
  for select to anon, authenticated using (app_uid() is not null);

create policy "otaq açırsan" on rooms
  for insert to anon, authenticated with check (host_id = app_uid());

create policy "otağı idarə edirsən" on rooms
  for update to anon, authenticated using (can_moderate_room(id));

create policy "öz otağını bağlayırsan" on rooms
  for delete to anon, authenticated using (host_id = app_uid());

create policy "kürsülər görünür" on room_seats
  for select to anon, authenticated using (app_uid() is not null);

-- Kürsüyə yalnız özün otura bilərsən; başqasını qaldırmaq moderatorun işidir.
create policy "kürsüyə oturursan" on room_seats
  for update to anon, authenticated
  using (
    can_moderate_room(room_id)
    or profile_id = app_uid()
    or profile_id is null
  )
  with check (
    can_moderate_room(room_id)
    or profile_id = app_uid()
    or profile_id is null
  );

create policy "kürsü yaradılır" on room_seats
  for insert to anon, authenticated with check (can_moderate_room(room_id));

create policy "otaq üzvləri görünür" on room_members
  for select to anon, authenticated using (app_uid() is not null);

create policy "otağa girirsən" on room_members
  for insert to anon, authenticated with check (
    profile_id = app_uid()
    and not exists (
      select 1 from room_bans b
       where b.room_id = room_members.room_id and b.profile_id = app_uid())
  );

create policy "otaqdan çıxırsan" on room_members
  for delete to anon, authenticated using (profile_id = app_uid() or can_moderate_room(room_id));

create policy "qadağalar görünür" on room_bans
  for select to anon, authenticated using (app_uid() is not null);

create policy "otaqdan atırsan" on room_bans
  for all to anon, authenticated
  using (can_moderate_room(room_id)) with check (can_moderate_room(room_id));

create policy "otaq söhbəti" on room_messages
  for select to anon, authenticated using (app_uid() is not null);

create policy "otaqda yazırsan" on room_messages
  for insert to anon, authenticated
  with check (sender_id = app_uid() and is_room_member(room_id));

create policy "otaq mesajını silirsən" on room_messages
  for delete to anon, authenticated using (sender_id = app_uid() or can_moderate_room(room_id));

create policy "otaq hadisələri" on room_events
  for select to anon, authenticated using (app_uid() is not null);

create policy "hadisə yazırsan" on room_events
  for insert to anon, authenticated with check (profile_id = app_uid());

create policy "öz dəvətlərin" on room_seat_invites
  for select to anon, authenticated using (profile_id = app_uid() or can_moderate_room(room_id));

create policy "masaya dəvət edirsən" on room_seat_invites
  for insert to anon, authenticated with check (can_moderate_room(room_id));

create policy "dəvəti bağlayırsan" on room_seat_invites
  for delete to anon, authenticated using (profile_id = app_uid() or can_moderate_room(room_id));

create policy "mikrofon sorğuları" on room_mic_requests
  for select to anon, authenticated using (app_uid() is not null);

create policy "mikrofon istəyirsən" on room_mic_requests
  for insert to anon, authenticated with check (profile_id = app_uid() and is_room_member(room_id));

create policy "sorğunu bağlayırsan" on room_mic_requests
  for delete to anon, authenticated using (profile_id = app_uid() or can_moderate_room(room_id));

-- WebRTC: yalnız sənə ünvanlanan siqnal görünür.
create policy "öz siqnalların" on room_rtc
  for select to anon, authenticated using (to_id = app_uid() or from_id = app_uid());

create policy "siqnal göndərirsən" on room_rtc
  for insert to anon, authenticated with check (from_id = app_uid() and is_room_member(room_id));

create policy "siqnalı silirsən" on room_rtc
  for delete to anon, authenticated using (to_id = app_uid() or from_id = app_uid());

-- ── Hədiyyə, oyun, şikayət ──

create policy "hədiyyələr görünür" on gifts_sent
  for select to anon, authenticated using (app_uid() is not null);

-- Sətri yalnız server funksiyası yazır: sikkə çıxılmadan hədiyyə görünməsin.
-- Buna görə burada insert qaydası yoxdur.

create policy "oyunların görünür" on domino_matches
  for select to anon, authenticated using (app_uid() = any(players));

create policy "oyun açırsan" on domino_matches
  for insert to anon, authenticated with check (app_uid() = any(players));

create policy "oyunu oynayırsan" on domino_matches
  for update to anon, authenticated using (app_uid() = any(players));

create policy "öz nəticələrin" on match_history
  for select to anon, authenticated using (profile_id = app_uid());

create policy "nəticə yazılır" on match_history
  for insert to anon, authenticated with check (profile_id = app_uid());

-- Şikayət yazılır, amma geri oxunmur — yalnız idarə paneli (service_role) görür.
create policy "şikayət edirsən" on reports
  for insert to anon, authenticated with check (reporter_id = app_uid());
