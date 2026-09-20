-- VIBE — server tərəfdəki əməliyyatlar.
--
-- Bunlar Firestore-dakı runTransaction bloklarının qarşılığıdır.
-- Sikkə hesabı müştəridə aparıla bilməz: adam öz balansını yaza bilsə,
-- pulsuz hədiyyə göndərər. Ona görə bu funksiyalar security definer-dir
-- və RLS-i keçir, amma içəridə hər şərti özü yoxlayır.

-- ── Hədiyyə göndərmə ──
create or replace function send_gift(
  p_to       uuid,
  p_gift_id  text,
  p_emoji    text,
  p_quantity int,
  p_unit     int,
  p_room_id  uuid default null,
  p_moment_id uuid default null,
  p_chat_id  uuid default null
) returns bigint
language plpgsql security definer set search_path = public as $$
declare
  me      uuid := app_uid();
  cost    bigint;
  balance bigint;
  row_id  bigint;
begin
  if me is null then
    raise exception 'giriş yoxdur' using errcode = '28000';
  end if;

  if p_quantity < 1 or p_unit < 0 then
    raise exception 'say və qiymət düzgün deyil' using errcode = '22023';
  end if;

  if me = p_to then
    raise exception 'özünə hədiyyə göndərmək olmaz' using errcode = '22023';
  end if;

  cost := p_quantity::bigint * p_unit::bigint;

  -- Balansı burada kilidləyirik ki, iki eyni anda basış ikiqat çıxmasın.
  select coins into balance from profiles where id = me for update;

  if balance is null or balance < cost then
    raise exception 'sikkə çatmır' using errcode = 'P0001';
  end if;

  update profiles
     set coins = coins - cost,
         gift_sent = gift_sent + cost
   where id = me;

  update profiles
     set coins = coins + cost,
         gift_received = gift_received + cost
   where id = p_to;

  insert into wallet_tx (profile_id, amount, reason, balance)
  values (me, -cost, 'gift', balance - cost);

  insert into wallet_tx (profile_id, amount, reason, balance)
  select p_to, cost, 'gift', coins from profiles where id = p_to;

  insert into gifts_sent (from_id, to_id, gift_id, emoji, quantity, total,
                          room_id, moment_id, chat_id)
  values (me, p_to, p_gift_id, p_emoji, p_quantity, cost,
          p_room_id, p_moment_id, p_chat_id)
  returning id into row_id;

  if p_room_id is not null then
    update rooms set gift_total = gift_total + cost where id = p_room_id;
  end if;

  if p_moment_id is not null then
    update moments set gift_total = gift_total + cost where id = p_moment_id;
  end if;

  return row_id;
end;
$$;

-- ── Gündəlik mükafat ──
-- Mükafat cədvəli: 1..7-ci gün.
create or replace function claim_daily_reward()
returns table (reward int, streak int)
language plpgsql security definer set search_path = public as $$
declare
  me       uuid := app_uid();
  last_at  timestamptz;
  old_days int;
  new_days int;
  gain     int;
  steps     int[] := array[20, 30, 40, 60, 80, 120, 200];
begin
  if me is null then
    raise exception 'giriş yoxdur' using errcode = '28000';
  end if;

  select profiles.last_reward_at, profiles.streak
    into last_at, old_days
    from profiles where id = me for update;

  -- Gün dəyişməyibsə ikinci dəfə vermirik.
  if last_at is not null and last_at::date = now()::date then
    raise exception 'bu gün artıq alınıb' using errcode = 'P0001';
  end if;

  -- Bir gün buraxılıbsa seriya sıfırlanır.
  if last_at is null or last_at::date < (now()::date - 1) then
    new_days := 1;
  else
    new_days := old_days + 1;
  end if;

  gain := steps[((new_days - 1) % 7) + 1];

  update profiles
     set coins = coins + gain,
         streak = new_days,
         last_reward_at = now()
   where id = me;

  insert into wallet_tx (profile_id, amount, reason, balance)
  select me, gain, 'daily', coins from profiles where id = me;

  return query select gain, new_days;
end;
$$;

-- ── Kürsüyə oturma ──
-- Boş kürsünü atomik tutur; dolu olsa yalan qaytarır.
create or replace function take_seat(p_room uuid, p_idx int)
returns boolean
language plpgsql security definer set search_path = public as $$
declare
  me      uuid := app_uid();
  changed int;
begin
  if me is null or not is_room_member(p_room) then
    return false;
  end if;

  if exists (select 1 from room_bans where room_id = p_room and profile_id = me) then
    return false;
  end if;

  -- Əvvəlki kürsünü boşaldırıq.
  update room_seats set profile_id = null, taken_at = null
   where room_id = p_room and profile_id = me;

  update room_seats
     set profile_id = me, taken_at = now(), muted = false
   where room_id = p_room
     and idx = p_idx
     and profile_id is null
     and not locked;

  get diagnostics changed = row_count;

  if changed > 0 then
    insert into room_events (room_id, profile_id, type, data)
    values (p_room, me, 'seat', jsonb_build_object('idx', p_idx));
  end if;

  return changed > 0;
end;
$$;

-- ── Sayğaclar ──
-- Firestore-da FieldValue.increment əl ilə yazılırdı; burada tətik özü saxlayır.

create or replace function bump_counter() returns trigger
language plpgsql as $$
begin
  if tg_table_name = 'moment_likes' then
    update moments set like_count = like_count + tg_argv[0]::int
     where id = coalesce(new.moment_id, old.moment_id);
  elsif tg_table_name = 'video_likes' then
    update videos set like_count = like_count + tg_argv[0]::int
     where id = coalesce(new.video_id, old.video_id);
  elsif tg_table_name = 'moment_comments' then
    update moments set comment_count = comment_count + tg_argv[0]::int
     where id = coalesce(new.moment_id, old.moment_id);
  elsif tg_table_name = 'video_comments' then
    update videos set comment_count = comment_count + tg_argv[0]::int
     where id = coalesce(new.video_id, old.video_id);
  elsif tg_table_name = 'room_members' then
    update rooms set member_count = greatest(0, member_count + tg_argv[0]::int)
     where id = coalesce(new.room_id, old.room_id);
  end if;
  return null;
end;
$$;

do $$
declare t text;
begin
  foreach t in array array[
    'moment_likes','video_likes','moment_comments','video_comments','room_members'
  ] loop
    execute format(
      'drop trigger if exists %1$s_up on %1$s;
       create trigger %1$s_up after insert on %1$s
       for each row execute function bump_counter(''1'');
       drop trigger if exists %1$s_down on %1$s;
       create trigger %1$s_down after delete on %1$s
       for each row execute function bump_counter(''-1'')', t);
  end loop;
end $$;

-- ── Canlı yayım ──
-- Firestore snapshot dinləyicilərinin qarşılığı.
-- Yalnız lazım olan cədvəllər: hər cədvəl açıq qalsa əlavə trafik yaranır.

do $$
declare t text;
begin
  foreach t in array array[
    'messages','message_media','chats','chat_members',
    'room_messages','room_seats','room_members','room_events','room_rtc',
    'rooms','calls','call_candidates','domino_matches','notifications','gifts_sent'
  ] loop
    begin
      execute format('alter publication supabase_realtime add table %I', t);
    exception when duplicate_object then null;
    end;
  end loop;
end $$;

-- Realtime sətirlərin köhnə halını da göndərsin (silinmə hadisələri üçün).
alter table messages       replica identity full;
alter table room_seats     replica identity full;
alter table room_members   replica identity full;
alter table chat_members   replica identity full;

-- ── Sayğacların bərpası ──
-- Köçürmədən sonra bir dəfə çağırılır: hazır məlumat tətiklərdən keçmir,
-- ona görə bəyənmə/şərh sayları burada bir dəfə yenidən hesablanır.
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
