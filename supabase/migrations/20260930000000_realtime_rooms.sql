-- Live multiplayer in rooms (positions over Broadcast, who's-here over
-- Presence). Run this once in Supabase: SQL Editor > New query > paste > Run.
--
-- The app joins each room on a *private* Realtime channel named
-- "room:<room id>" (e.g. room:tavern). Private channels check these policies,
-- so signed-out visitors can't watch or send to a room. Nothing here is
-- stored: Broadcast and Presence messages pass straight through.

create policy "Signed-in players can receive room updates"
  on realtime.messages for select to authenticated
  using (
    (select realtime.topic()) like 'room:%'
    and realtime.messages.extension in ('broadcast', 'presence')
  );

create policy "Signed-in players can send room updates"
  on realtime.messages for insert to authenticated
  with check (
    (select realtime.topic()) like 'room:%'
    and realtime.messages.extension in ('broadcast', 'presence')
  );
