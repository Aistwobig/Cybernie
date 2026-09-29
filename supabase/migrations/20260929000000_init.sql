-- Cybernie initial schema.
-- Run this once in Supabase: Dashboard > SQL Editor > New query > paste > Run.
-- Every table has Row Level Security on, so the publishable key shipped in the
-- web build can only do what the policies below allow.
--
-- Table access is granted explicitly (see "Grants" at the bottom), so this
-- works with "Automatically expose new tables" switched off. Signed-out
-- visitors (the anon role) get no access to any table.

-- ---------------------------------------------------------------------------
-- Profiles: one row per user, created automatically on first Google sign-in.
-- ---------------------------------------------------------------------------
create table public.profiles (
  id              uuid primary key references auth.users (id) on delete cascade,
  username        text not null unique
                  check (username ~ '^[a-z0-9_]{3,20}$'),
  display_name    text not null default 'Player'
                  check (char_length(display_name) between 1 and 20),
  avatar_url      text,
  character_index int  not null default 1 check (character_index >= 0),
  level           int  not null default 1 check (level >= 1),
  xp              int  not null default 0 check (xp >= 0),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "Signed-in users can view profiles"
  on public.profiles for select to authenticated
  using (true);

create policy "Users can update their own profile"
  on public.profiles for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

create function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger profiles_touch_updated_at
  before update on public.profiles
  for each row execute function public.touch_updated_at();

-- Creates the profile when Google sign-in creates the auth user. Uses the
-- first name from Google as the display name, and a generated username the
-- player can change later (e.g. player_3f9a1c2b).
create function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
declare
  given_name text := coalesce(
    new.raw_user_meta_data ->> 'given_name',
    split_part(new.raw_user_meta_data ->> 'full_name', ' ', 1),
    'Player'
  );
begin
  insert into public.profiles (id, username, display_name)
  values (
    new.id,
    'player_' || substr(replace(new.id::text, '-', ''), 1, 8),
    coalesce(left(nullif(given_name, ''), 20), 'Player')
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- Friendships: one row per pair. 'pending' until the addressee accepts.
-- ---------------------------------------------------------------------------
create type public.friendship_status as enum ('pending', 'accepted');

create table public.friendships (
  requester_id uuid not null references public.profiles (id) on delete cascade,
  addressee_id uuid not null references public.profiles (id) on delete cascade,
  status       public.friendship_status not null default 'pending',
  created_at   timestamptz not null default now(),
  primary key (requester_id, addressee_id),
  check (requester_id <> addressee_id)
);

-- Stops A->B and B->A both existing.
create unique index friendships_pair_idx on public.friendships (
  least(requester_id, addressee_id),
  greatest(requester_id, addressee_id)
);

alter table public.friendships enable row level security;

create policy "Users see friendships they are part of"
  on public.friendships for select to authenticated
  using (auth.uid() in (requester_id, addressee_id));

create policy "Users send requests as themselves"
  on public.friendships for insert to authenticated
  with check (requester_id = auth.uid() and status = 'pending');

create policy "Only the addressee can accept"
  on public.friendships for update to authenticated
  using (addressee_id = auth.uid())
  with check (addressee_id = auth.uid());

create policy "Either side can decline or unfriend"
  on public.friendships for delete to authenticated
  using (auth.uid() in (requester_id, addressee_id));

-- ---------------------------------------------------------------------------
-- Rooms: read-only for players, managed from the dashboard.
-- Live player counts come from Realtime Presence, not from this table.
-- ---------------------------------------------------------------------------
create table public.rooms (
  id             text primary key,
  name           text not null,
  max_players    int  not null default 20,
  voice_channels int  not null default 1,
  created_at     timestamptz not null default now()
);

alter table public.rooms enable row level security;

create policy "Signed-in users can view rooms"
  on public.rooms for select to authenticated
  using (true);

insert into public.rooms (id, name, max_players, voice_channels)
values ('tavern', 'Bernie''s Tavern', 20, 1);

-- ---------------------------------------------------------------------------
-- Room chat messages.
-- ---------------------------------------------------------------------------
create table public.messages (
  id         bigint generated always as identity primary key,
  room_id    text not null references public.rooms (id) on delete cascade,
  sender_id  uuid not null references public.profiles (id) on delete cascade,
  body       text not null check (char_length(body) between 1 and 200),
  created_at timestamptz not null default now()
);

create index messages_room_created_idx on public.messages (room_id, created_at desc);

alter table public.messages enable row level security;

create policy "Signed-in users can read room chat"
  on public.messages for select to authenticated
  using (true);

create policy "Users post as themselves"
  on public.messages for insert to authenticated
  with check (sender_id = auth.uid());

alter publication supabase_realtime add table public.messages;

-- ---------------------------------------------------------------------------
-- Reports: players can file them but never read them back.
-- Review them in the dashboard (Table Editor > reports).
-- ---------------------------------------------------------------------------
create table public.reports (
  id          bigint generated always as identity primary key,
  reporter_id uuid not null references public.profiles (id) on delete cascade,
  reported_id uuid references public.profiles (id) on delete set null,
  room_id     text references public.rooms (id) on delete set null,
  message_id  bigint references public.messages (id) on delete set null,
  reason      text not null check (char_length(reason) between 1 and 500),
  created_at  timestamptz not null default now()
);

alter table public.reports enable row level security;

create policy "Users file reports as themselves"
  on public.reports for insert to authenticated
  with check (reporter_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Avatar photos: public to view, each user writes only to avatars/<their id>/.
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', true, 1048576, array['image/jpeg', 'image/png']);

-- Upserting (replacing avatar.jpg) needs select as well as insert and update.
create policy "Users see their own avatar files"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users upload their own avatar"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users replace their own avatar"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users delete their own avatar"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- ---------------------------------------------------------------------------
-- Grants: which operations signed-in players may attempt at all. The RLS
-- policies above then decide which rows. Anything not granted here is denied.
-- ---------------------------------------------------------------------------
revoke all on public.profiles, public.friendships, public.rooms,
  public.messages, public.reports from anon, authenticated;

grant select on public.profiles to authenticated;
-- Level and XP are game state: only the server may change them.
grant update (username, display_name, avatar_url, character_index)
  on public.profiles to authenticated;

grant select, insert, delete on public.friendships to authenticated;
-- Accepting only flips status; nobody can rewrite who the request is between.
grant update (status) on public.friendships to authenticated;

grant select on public.rooms to authenticated;

grant select on public.messages to authenticated;
grant insert (room_id, sender_id, body) on public.messages to authenticated;

grant insert (reporter_id, reported_id, room_id, message_id, reason)
  on public.reports to authenticated;
