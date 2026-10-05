-- Bernie's drinks cost coins. Prices must match lib/constants/drinks.dart.
-- Returns the coins left; fails (and charges nothing) if they can't afford
-- it.
create function public.buy_drink(p_drink text)
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
  return left_over;
end;
$$;

revoke execute on function public.buy_drink(text) from public, anon, authenticated;
grant execute on function public.buy_drink(text) to authenticated;
