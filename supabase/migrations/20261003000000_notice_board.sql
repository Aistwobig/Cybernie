-- Notice board in Bernie's Tavern: short notes players pin for everyone.
-- Run this once in Supabase: SQL Editor > New query > paste > Run.

create table public.notice_notes (
  id         bigint generated always as identity primary key,
  room_id    text not null references public.rooms (id) on delete cascade,
  author_id  uuid not null references public.profiles (id) on delete cascade,
  body       text not null check (char_length(body) between 1 and 140),
  created_at timestamptz not null default now()
);

create index notice_notes_room_created_idx
  on public.notice_notes (room_id, created_at desc);

alter table public.notice_notes enable row level security;

create policy "Signed-in players can read the notice board"
  on public.notice_notes for select to authenticated
  using (true);

create policy "Players pin notes as themselves"
  on public.notice_notes for insert to authenticated
  with check (author_id = auth.uid());

create policy "Players take down their own notes"
  on public.notice_notes for delete to authenticated
  using (author_id = auth.uid());

revoke all on public.notice_notes from anon, authenticated;
grant select, delete on public.notice_notes to authenticated;
grant insert (room_id, author_id, body) on public.notice_notes to authenticated;
