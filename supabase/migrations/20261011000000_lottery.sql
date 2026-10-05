-- The free lottery wheel: two spins a day, by Philippine time (UTC+8):
--   'am' opens at 12:00 AM and lasts until 7:59 PM,
--   'pm' opens at  8:00 PM and lasts until midnight.
-- A missed spin is gone; they don't pile up.
--
-- The prize is drawn here, so neither the phone's clock nor the app can
-- cheat it. Chances (they add up to 100):
--   1000 coins  1%      150 coins 11%      50 coins 34%
--    500 coins  2%      100 coins 21%
--    200 coins  4%       80 coins 27%
-- On average a spin pays about 104 coins.
-- (To use another time zone, change 'Asia/Manila' in lottery_slot.)

create table public.lottery_spins (
  user_id uuid not null references public.profiles (id) on delete cascade,
  -- e.g. '2026-10-11 pm'
  slot    text not null,
  prize   int  not null,
  spun_at timestamptz not null default now(),
  primary key (user_id, slot)
);

alter table public.lottery_spins enable row level security;
revoke all on public.lottery_spins from anon, authenticated;

-- The spin that's open right now, and when the next one opens.
create function public.lottery_slot(out slot text, out next_at timestamptz)
language sql stable
set search_path = ''
as $$
  select
    to_char(l, 'YYYY-MM-DD') || case when extract(hour from l) >= 20
                                     then ' pm' else ' am' end,
    case when extract(hour from l) >= 20
         then (date_trunc('day', l) + interval '1 day')
         else (date_trunc('day', l) + interval '20 hours')
    end at time zone 'Asia/Manila'
  from (select now() at time zone 'Asia/Manila' as l) t;
$$;

-- { "available": true, "slot": "2026-10-11 pm", "next_at": "..." }
create function public.lottery_status()
returns jsonb
language sql stable
security definer set search_path = ''
as $$
  select jsonb_build_object(
    'available', auth.uid() is not null and not exists (
      select 1 from public.lottery_spins
       where user_id = auth.uid() and slot = s.slot),
    'slot', s.slot,
    'next_at', s.next_at)
  from public.lottery_slot() s;
$$;

-- Spins the wheel once for the open slot: draws the prize, pays it, and
-- returns { "prize": 150, "coins": 450 }.
create function public.spin_lottery()
returns jsonb
language plpgsql
security definer set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  open_slot text := (select slot from public.lottery_slot());
  roll numeric := random() * 100;  -- 0 up to (not including) 100
  won int;
  total int;
begin
  if uid is null then raise exception 'not signed in'; end if;
  -- Walk up the chances: 0-1 is 1000, 1-3 is 500, 3-7 is 200, ...
  won := case
    when roll < 1  then 1000
    when roll < 3  then 500
    when roll < 7  then 200
    when roll < 18 then 150
    when roll < 39 then 100
    when roll < 66 then 80
    else 50
  end;
  insert into public.lottery_spins (user_id, slot, prize)
  values (uid, open_slot, won);
  update public.profiles set coins = coins + won
   where id = uid returning coins into total;
  return jsonb_build_object('prize', won, 'coins', total);
exception
  when unique_violation then raise exception 'already spun';
end;
$$;

revoke execute on function public.lottery_slot(), public.lottery_status(),
  public.spin_lottery() from public, anon, authenticated;
grant execute on function public.lottery_status(), public.spin_lottery()
  to authenticated;
