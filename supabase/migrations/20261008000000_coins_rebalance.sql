-- Coins rebalance: new players start with 300 coins and the daily bonus is
-- 50 (was 500 and 200).
alter table public.profiles alter column coins set default 300;

-- Everyone restarts at 300 so the leaderboard is fair under the new rules.
-- (Delete this line to keep the coins players already have.)
update public.profiles set coins = 300;

create or replace function public.claim_daily_coins()
returns jsonb
language plpgsql
security definer set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  bonus int := 0;
  total int;
begin
  if uid is null then raise exception 'not signed in'; end if;
  update public.profiles
     set coins = coins + 50, coins_claimed_on = current_date
   where id = uid
     and coins_claimed_on is distinct from current_date;
  if found then bonus := 50; end if;
  select coins into total from public.profiles where id = uid;
  return jsonb_build_object('coins', total, 'bonus', bonus);
end;
$$;

-- (create or replace keeps the earlier grants: only signed-in players can
-- call it.)
