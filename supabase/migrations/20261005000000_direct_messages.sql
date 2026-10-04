-- Private messages between friends (Friends > chat, and Messages in the
-- tavern). Run this once in Supabase: SQL Editor > New query > paste > Run.
--
-- Each message is either text (body) or one of the game's emotes (emote).
-- Only friends can message each other. Only the sender can edit (text) or
-- delete a message; deleting removes it for both players.

create table public.direct_messages (
  id           bigint generated always as identity primary key,
  sender_id    uuid not null references public.profiles (id) on delete cascade,
  recipient_id uuid not null references public.profiles (id) on delete cascade,
  body         text check (char_length(body) between 1 and 500),
  emote        text check (char_length(emote) between 1 and 16),
  created_at   timestamptz not null default now(),
  edited_at    timestamptz,
  check (sender_id <> recipient_id),
  -- Exactly one of text or emote.
  check ((body is null) <> (emote is null))
);

create index direct_messages_pair_idx
  on public.direct_messages (sender_id, recipient_id, created_at desc);
create index direct_messages_recipient_idx
  on public.direct_messages (recipient_id, created_at desc);

alter table public.direct_messages enable row level security;

create policy "Players read their own conversations"
  on public.direct_messages for select to authenticated
  using (auth.uid() in (sender_id, recipient_id));

create policy "Players message their friends as themselves"
  on public.direct_messages for insert to authenticated
  with check (
    sender_id = auth.uid()
    and edited_at is null
    and exists (
      select 1 from public.friendships f
      where f.status = 'accepted'
        and (
          (f.requester_id = auth.uid() and f.addressee_id = recipient_id)
          or (f.addressee_id = auth.uid() and f.requester_id = recipient_id)
        )
    )
  );

create policy "Players edit their own messages"
  on public.direct_messages for update to authenticated
  using (sender_id = auth.uid())
  with check (sender_id = auth.uid());

create policy "Players delete their own messages"
  on public.direct_messages for delete to authenticated
  using (sender_id = auth.uid());

revoke all on public.direct_messages from anon, authenticated;
grant select, delete on public.direct_messages to authenticated;
grant insert (sender_id, recipient_id, body, emote)
  on public.direct_messages to authenticated;
-- Editing changes the text and marks it edited; nothing else.
grant update (body, edited_at) on public.direct_messages to authenticated;

-- New, edited and deleted messages arrive live.
alter publication supabase_realtime add table public.direct_messages;
