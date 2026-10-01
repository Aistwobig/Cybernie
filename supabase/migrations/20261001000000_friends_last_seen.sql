-- Online status and "last active" for the Friends screens.
-- Run this once in Supabase: SQL Editor > New query > paste > Run.
--
-- While the app is open it calls touch_last_seen() about once a minute.
-- A player counts as online if they were seen in the last couple of
-- minutes; otherwise the app shows "Active 5 mins ago", "2 days ago", etc.

alter table public.profiles add column last_seen_at timestamptz;

-- Stamps the caller's own profile with the server's clock, so players can't
-- set someone else's time or fake their own.
create function public.touch_last_seen()
returns void
language sql
security definer set search_path = ''
as $$
  update public.profiles set last_seen_at = now() where id = auth.uid();
$$;

revoke execute on function public.touch_last_seen() from public, anon;
grant execute on function public.touch_last_seen() to authenticated;

-- Searching players by name or username on the Add Friends screen.
create extension if not exists pg_trgm with schema extensions;

create index profiles_display_name_search_idx on public.profiles
  using gin (display_name extensions.gin_trgm_ops);
create index profiles_username_search_idx on public.profiles
  using gin (username extensions.gin_trgm_ops);
