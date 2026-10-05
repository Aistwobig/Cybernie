-- Inventory and tasks.
--
-- * Drinks bought from Bernie go into the player's inventory (buy_drink now
--   stores them instead of being drunk at once); use_item takes one out.
-- * Tasks pay coins once each, when claimed. Whether a task is done is
--   checked here from the player's real data, so claims can't be faked.

create table public.player_items (
  user_id  uuid not null references public.profiles (id) on delete cascade,
  item_id  text not null,
  quantity int  not null default 0 check (quantity >= 0),
  primary key (user_id, item_id)
);

create table public.task_claims (
  user_id    uuid not null references public.profiles (id) on delete cascade,
  task_id    text not null,
  claimed_at timestamptz not null default now(),
  primary key (user_id, task_id)
);

-- Only the functions below change these (they run as the table owner).
alter table public.player_items enable row level security;
alter table public.task_claims enable row level security;
revoke all on public.player_items, public.task_claims from anon, authenticated;

-- ---------------------------------------------------------------------------
-- Inventory
-- ---------------------------------------------------------------------------

-- The player's items: { "ale": 2, "cider": 1 }.
create function public.my_items()
returns jsonb
language sql stable
security definer set search_path = ''
as $$
  select coalesce(jsonb_object_agg(item_id, quantity), '{}'::jsonb)
  from public.player_items
  where user_id = auth.uid() and quantity > 0;
$$;

-- Buying a drink now puts it in the inventory. Returns the coins left.
create or replace function public.buy_drink(p_drink text)
returns int
language plpgsql
security definer set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  price int := case p_drink
    when 'ale' then 10
    when 'berry' then 15
    when 'moon' then 25
    when 'cider' then 25
  end;
  left_over int;
begin
  if uid is null then raise exception 'not signed in'; end if;
  if price is null then raise exception 'unknown drink'; end if;
  update public.profiles
     set coins = coins - price
   where id = uid and coins >= price
  returning coins into left_over;
  if not found then raise exception 'not enough coins'; end if;
  insert into public.player_items (user_id, item_id, quantity)
  values (uid, p_drink, 1)
  on conflict (user_id, item_id)
  do update set quantity = public.player_items.quantity + 1;
  return left_over;
end;
$$;

-- Takes one [p_item] out of the inventory (to drink it). Fails if there's
-- none.
create function public.use_item(p_item text)
returns jsonb
language plpgsql
security definer set search_path = ''
as $$
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  update public.player_items
     set quantity = quantity - 1
   where user_id = auth.uid() and item_id = p_item and quantity > 0;
  if not found then raise exception 'item not owned'; end if;
  return public.my_items();
end;
$$;

-- ---------------------------------------------------------------------------
-- Tasks
-- ---------------------------------------------------------------------------

-- Whether [uid] has done task [p_task].
create function public.task_done(uid uuid, p_task text)
returns boolean
language sql stable
security definer set search_path = ''
as $$
  select case p_task
    when 'bio' then exists (
      select 1 from public.profiles
       where id = uid and char_length(trim(bio)) > 0)
    when 'photo' then exists (
      select 1 from public.profiles
       where id = uid and coalesce(avatar_url, '') <> '')
    when 'friend' then exists (
      select 1 from public.friendships
       where requester_id = uid or (addressee_id = uid and status = 'accepted'))
    when 'message' then exists (
        select 1 from public.messages where sender_id = uid)
      or exists (
        select 1 from public.direct_messages where sender_id = uid)
    else false
  end;
$$;

-- Each task with whether it's done and claimed:
-- [{ "id": "bio", "done": true, "claimed": false }, ...]
create function public.my_tasks()
returns jsonb
language sql stable
security definer set search_path = ''
as $$
  select jsonb_agg(jsonb_build_object(
           'id', t.id,
           'done', public.task_done(auth.uid(), t.id),
           'claimed', exists (
             select 1 from public.task_claims c
              where c.user_id = auth.uid() and c.task_id = t.id)
         ) order by t.ord)
  from (values ('bio', 1), ('photo', 2), ('friend', 3), ('message', 4))
       as t (id, ord);
$$;

-- Claims [p_task]'s reward once it's done. Returns the coins afterwards.
create function public.claim_task(p_task text)
returns int
language plpgsql
security definer set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  reward int := case p_task
    when 'bio' then 20
    when 'photo' then 50
    when 'friend' then 10
    when 'message' then 10
  end;
  total int;
begin
  if uid is null then raise exception 'not signed in'; end if;
  if reward is null then raise exception 'unknown task'; end if;
  if not public.task_done(uid, p_task) then
    raise exception 'task not done';
  end if;
  insert into public.task_claims (user_id, task_id) values (uid, p_task);
  update public.profiles set coins = coins + reward
   where id = uid returning coins into total;
  return total;
exception
  when unique_violation then raise exception 'already claimed';
end;
$$;

revoke execute on function
  public.my_items(), public.use_item(text), public.task_done(uuid, text),
  public.my_tasks(), public.claim_task(text)
  from public, anon, authenticated;
grant execute on function
  public.my_items(), public.use_item(text), public.my_tasks(),
  public.claim_task(text)
  to authenticated;
