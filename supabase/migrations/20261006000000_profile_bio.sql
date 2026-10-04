-- A short "about me" players write on their Profile screen, shown on their
-- player card in the tavern. Empty until they write one.
alter table public.profiles
  add column bio text not null default ''
  check (char_length(bio) <= 150);

-- Players may edit their own bio (the update policy limits it to their row).
grant update (bio) on public.profiles to authenticated;
