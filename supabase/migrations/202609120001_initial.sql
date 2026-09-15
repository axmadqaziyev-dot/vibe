-- Apply once to a NEW Supabase project using the SQL editor.
begin;
create table public.profiles (
  id uuid primary key references auth.users on delete cascade,
  display_name text not null check (char_length(trim(display_name)) between 2 and 40),
  age integer not null check (age between 18 and 120),
  country text not null check (char_length(trim(country)) between 2 and 60),
  bio text not null default '' check (char_length(bio) <= 300),
  language text not null default 'English' check (language in ('English','Azərbaycan','Türkçe')),
  interests text[] not null default '{}' check (cardinality(interests) <= 6),
  avatar integer not null default 0 check (avatar between 0 and 5),
  suspended boolean not null default false,
  created_at timestamptz not null default now()
);
create table public.private_profiles (
  user_id uuid primary key references public.profiles on delete cascade,
  birth_date date not null,
  terms_version text not null,
  accepted_at timestamptz not null default now()
);
create table public.blocks (
  blocker_id uuid references public.profiles on delete cascade,
  blocked_id uuid references public.profiles on delete cascade,
  primary key (blocker_id, blocked_id), check (blocker_id <> blocked_id)
);
create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  user_a uuid not null references public.profiles on delete cascade,
  user_b uuid not null references public.profiles on delete cascade,
  created_at timestamptz not null default now(),
  unique(user_a, user_b), check (user_a < user_b)
);
create table public.messages (
  id bigint generated always as identity primary key,
  conversation_id uuid not null references public.conversations on delete cascade,
  sender_id uuid not null references public.profiles on delete cascade,
  body text not null check (char_length(trim(body)) between 1 and 2000),
  created_at timestamptz not null default now()
);
create index messages_conversation_time on public.messages(conversation_id, created_at);
create table public.rooms (
  id uuid primary key default gen_random_uuid(),
  title text not null, topic text not null, language text not null,
  description text not null, created_at timestamptz not null default now()
);
create table public.room_messages (
  id bigint generated always as identity primary key,
  room_id uuid not null references public.rooms on delete cascade,
  sender_id uuid not null references public.profiles on delete cascade,
  body text not null check (char_length(trim(body)) between 1 and 2000),
  created_at timestamptz not null default now()
);
create index room_messages_room_time on public.room_messages(room_id, created_at);
create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid references public.profiles on delete set null,
  target_id uuid references public.profiles on delete set null,
  reason text not null check (reason in ('Harassment','Spam','Inappropriate content','Underage','Other')),
  status text not null default 'open' check (status in ('open','reviewing','resolved')),
  created_at timestamptz not null default now(),
  check (reporter_id <> target_id)
);
create table public.wallets (
  user_id uuid primary key references public.profiles on delete cascade,
  balance bigint not null default 0 check (balance >= 0)
);
create table public.wallet_ledger (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles on delete cascade,
  amount bigint not null check (amount <> 0),
  kind text not null,
  request_key text not null unique,
  created_at timestamptz not null default now()
);
create table public.gifts (
  id text primary key, cost integer not null check (cost > 0)
);
insert into public.gifts values ('rose',10),('star',50),('crown',100);
create table public.gift_events (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid references public.profiles on delete set null,
  recipient_id uuid references public.profiles on delete set null,
  gift_id text not null references public.gifts,
  request_key text not null unique,
  created_at timestamptz not null default now()
);

create function public.active_user() returns boolean language sql stable security definer
set search_path = '' as $$
  select exists(select 1 from public.profiles where id = auth.uid() and not suspended);
$$;
create function public.can_interact(peer uuid) returns boolean language sql stable security definer
set search_path = '' as $$
  select public.active_user()
    and exists(select 1 from public.profiles where id = peer and not suspended)
    and not exists(select 1 from public.blocks
      where (blocker_id = auth.uid() and blocked_id = peer)
         or (blocker_id = peer and blocked_id = auth.uid()));
$$;

create function public.on_signup() returns trigger language plpgsql security definer
set search_path = '' as $$
declare birthday date; years integer;
begin
  birthday := (new.raw_user_meta_data->>'birth_date')::date;
  years := extract(year from age(current_date, birthday));
  if birthday is null or years < 18 or years > 120 then
    raise exception 'An adult date of birth is required';
  end if;
  if new.raw_user_meta_data->>'terms_version' is distinct from '2026-09-12' then
    raise exception 'Community terms must be accepted';
  end if;
  insert into public.profiles(id,display_name,age,country,language)
  values(new.id,trim(new.raw_user_meta_data->>'display_name'),years,
    trim(new.raw_user_meta_data->>'country'),coalesce(new.raw_user_meta_data->>'language','English'));
  insert into public.private_profiles(user_id,birth_date,terms_version)
    values(new.id,birthday,'2026-09-12');
  insert into public.wallets(user_id) values(new.id);
  return new;
end;
$$;
create trigger signup_profile after insert on auth.users
  for each row execute function public.on_signup();

-- Owner/service job: run daily to keep public ages current without exposing birth dates.
create function public.refresh_ages() returns void language sql security definer set search_path = '' as $$
  update public.profiles p set age = extract(year from age(current_date, s.birth_date))
    from public.private_profiles s where s.user_id = p.id;
$$;

alter table public.profiles enable row level security;
alter table public.private_profiles enable row level security;
alter table public.blocks enable row level security;
alter table public.conversations enable row level security;
alter table public.messages enable row level security;
alter table public.rooms enable row level security;
alter table public.room_messages enable row level security;
alter table public.reports enable row level security;
alter table public.wallets enable row level security;
alter table public.wallet_ledger enable row level security;
alter table public.gifts enable row level security;
alter table public.gift_events enable row level security;

create policy profiles_read on public.profiles for select to authenticated
  using (id = auth.uid() or public.can_interact(id));
create policy profiles_update on public.profiles for update to authenticated
  using (id = auth.uid() and public.active_user()) with check (id = auth.uid());
create policy private_read on public.private_profiles for select to authenticated using (user_id = auth.uid());
create policy blocks_read on public.blocks for select to authenticated using (blocker_id = auth.uid());
create policy blocks_insert on public.blocks for insert to authenticated
  with check (blocker_id = auth.uid() and public.active_user());
create policy blocks_update on public.blocks for update to authenticated
  using (blocker_id = auth.uid()) with check (blocker_id = auth.uid());
create policy blocks_delete on public.blocks for delete to authenticated using (blocker_id = auth.uid());
create policy conversations_read on public.conversations for select to authenticated using (
  (user_a = auth.uid() and public.can_interact(user_b)) or
  (user_b = auth.uid() and public.can_interact(user_a)));
create policy messages_read on public.messages for select to authenticated using (
  exists(select 1 from public.conversations c where c.id = conversation_id));
create policy messages_insert on public.messages for insert to authenticated with check (
  sender_id = auth.uid() and public.active_user() and
  exists(select 1 from public.conversations c where c.id = conversation_id));
create policy rooms_read on public.rooms for select to authenticated using (public.active_user());
create policy room_messages_read on public.room_messages for select to authenticated using (
  public.can_interact(sender_id));
create policy room_messages_insert on public.room_messages for insert to authenticated with check (
  sender_id = auth.uid() and public.active_user());
create policy reports_insert on public.reports for insert to authenticated with check (
  reporter_id = auth.uid() and public.active_user());
create policy reports_read on public.reports for select to authenticated using (reporter_id = auth.uid());
create policy wallets_read on public.wallets for select to authenticated using (user_id = auth.uid());
create policy ledger_read on public.wallet_ledger for select to authenticated using (user_id = auth.uid());
create policy gifts_read on public.gifts for select to authenticated using (public.active_user());
create policy gift_events_read on public.gift_events for select to authenticated using (
  sender_id = auth.uid() or recipient_id = auth.uid());

-- Explicit column grants prevent clients from editing balances, age, or suspension flags.
revoke all on public.profiles, public.private_profiles, public.blocks, public.conversations,
  public.messages, public.rooms, public.room_messages, public.reports, public.wallets,
  public.wallet_ledger, public.gifts, public.gift_events from anon, authenticated;
grant select on public.profiles, public.private_profiles, public.blocks, public.conversations,
  public.messages, public.rooms, public.room_messages, public.reports, public.wallets,
  public.wallet_ledger, public.gifts, public.gift_events to authenticated;
grant update(display_name,country,bio,language,interests,avatar) on public.profiles to authenticated;
grant insert(blocker_id,blocked_id), update(blocker_id,blocked_id), delete on public.blocks to authenticated;
grant insert(conversation_id,sender_id,body) on public.messages to authenticated;
grant insert(room_id,sender_id,body) on public.room_messages to authenticated;
grant insert(reporter_id,target_id,reason) on public.reports to authenticated;
grant usage on sequence public.messages_id_seq, public.room_messages_id_seq to authenticated;

create function public.start_conversation(peer uuid) returns uuid language plpgsql security definer
set search_path = '' as $$
declare result uuid;
begin
  if peer = auth.uid() or not public.can_interact(peer) then raise exception 'Conversation unavailable'; end if;
  insert into public.conversations(user_a,user_b)
    values(least(auth.uid(),peer),greatest(auth.uid(),peer))
    on conflict(user_a,user_b) do update set user_a = excluded.user_a returning id into result;
  return result;
end;
$$;
create function public.blocked_profiles() returns setof public.profiles language sql stable security definer
set search_path = '' as $$
  select p.* from public.profiles p join public.blocks b on b.blocked_id = p.id
    where b.blocker_id = auth.uid();
$$;

-- Serializes sends per sender and imposes a basic server-side rate limit.
create function public.limit_message_rate() returns trigger language plpgsql security definer
set search_path = '' as $$
begin
  perform 1 from public.profiles where id = new.sender_id for update;
  if (select count(*) from public.messages where sender_id = new.sender_id
       and created_at > now() - interval '1 minute') +
     (select count(*) from public.room_messages where sender_id = new.sender_id
       and created_at > now() - interval '1 minute') >= 30 then
    raise exception 'Please slow down and try again shortly';
  end if;
  return new;
end;
$$;
create trigger message_rate before insert on public.messages for each row execute function public.limit_message_rate();
create trigger room_message_rate before insert on public.room_messages for each row execute function public.limit_message_rate();
create index messages_sender_time on public.messages(sender_id,created_at);
create index room_messages_sender_time on public.room_messages(sender_id,created_at);

create function public.send_gift(recipient uuid, gift text, request_id text) returns void
language plpgsql security definer set search_path = '' as $$
declare cost integer; coins bigint; key text;
begin
  if recipient = auth.uid() or not public.can_interact(recipient) then raise exception 'Recipient unavailable'; end if;
  if request_id is null or char_length(request_id) not between 16 and 100 then raise exception 'Invalid request'; end if;
  key := auth.uid()::text || ':' || request_id;
  select balance into coins from public.wallets where user_id = auth.uid() for update;
  if exists(select 1 from public.gift_events where request_key = key) then return; end if;
  select g.cost into cost from public.gifts g where g.id = gift;
  if cost is null or coins is null or coins < cost then raise exception 'Not enough coins'; end if;
  update public.wallets set balance = balance - cost where user_id = auth.uid();
  insert into public.wallet_ledger(user_id,amount,kind,request_key) values(auth.uid(),-cost,gift,key);
  insert into public.gift_events(sender_id,recipient_id,gift_id,request_key)
    values(auth.uid(),recipient,gift,key);
end;
$$;
-- No client RPC credits a wallet. A future VERIFIED payment processor must call
-- this service-role-only function with an immutable provider transaction id.
create function public.credit_verified_purchase(buyer uuid, coins integer, provider_transaction text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if coins <= 0 or provider_transaction is null or char_length(provider_transaction) < 8 then
    raise exception 'Invalid purchase';
  end if;
  perform 1 from public.wallets where user_id = buyer for update;
  if not found then raise exception 'Wallet missing'; end if;
  insert into public.wallet_ledger(user_id,amount,kind,request_key)
    values(buyer,coins,'purchase','purchase:' || provider_transaction) on conflict(request_key) do nothing;
  if found then update public.wallets set balance = balance + coins where user_id = buyer; end if;
end;
$$;
create function public.delete_my_account() returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  delete from auth.users where id = auth.uid();
end;
$$;
revoke execute on function public.active_user(), public.can_interact(uuid), public.on_signup(),
 public.refresh_ages(), public.start_conversation(uuid), public.blocked_profiles(), public.limit_message_rate(),
 public.send_gift(uuid,text,text), public.credit_verified_purchase(uuid,integer,text), public.delete_my_account()
 from public, anon, authenticated;
grant execute on function public.active_user(), public.can_interact(uuid), public.start_conversation(uuid),
 public.blocked_profiles(), public.send_gift(uuid,text,text), public.delete_my_account() to authenticated;
grant execute on function public.credit_verified_purchase(uuid,integer,text), public.refresh_ages() to service_role;

insert into public.rooms(title,topic,language,description) values
 ('The global lounge','Travel','English','Share a story from your city and meet the world.'),
 ('One more song','Music','English','Exchange songs and discover a new favorite.'),
 ('After the game','Gaming','Türkçe','Meet other players and plan your next game.');
alter publication supabase_realtime add table public.messages, public.room_messages;
commit;

