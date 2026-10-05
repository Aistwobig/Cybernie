-- Tavern coins and Bernie's blackjack table.
--
-- Coins live on the profile and only these functions change them (players
-- can't update the column themselves). Every blackjack hand is shuffled and
-- dealt here, and Bernie's face-down card never leaves the database until
-- the hand is over, so nobody can peek at it or fake a win.
--
-- Cards are numbers 0-51: suit = card / 13 (0 hearts, 1 diamonds, 2 clubs,
-- 3 spades) and rank = card % 13 (0 ace, 1-9 two to ten, 10 jack, 11 queen,
-- 12 king), matching the rows and columns of assets/images/cat_cards.jpg.

alter table public.profiles
  add column coins int not null default 500 check (coins >= 0),
  add column coins_claimed_on date;
-- (Not added to the profile update grant: players can't edit their coins.)

create table public.blackjack_hands (
  user_id    uuid primary key references public.profiles (id) on delete cascade,
  deck       smallint[] not null,
  player     smallint[] not null,
  dealer     smallint[] not null,
  bet        int not null check (bet > 0),
  playing    boolean not null default true,
  outcome    text check (outcome in
               ('win', 'blackjack', 'dealer_bust', 'lose', 'dealer_blackjack',
                'bust', 'push')),
  payout     int not null default 0,
  updated_at timestamptz not null default now()
);

-- Only the functions below touch hands (they run as the table owner).
alter table public.blackjack_hands enable row level security;
revoke all on public.blackjack_hands from anon, authenticated;

-- ---------------------------------------------------------------------------
-- Helpers (not callable by players).
-- ---------------------------------------------------------------------------

-- Best total of a hand: aces count 11, or 1 when 11 would bust.
create function public.bj_value(cards smallint[])
returns int
language sql immutable
set search_path = ''
as $$
  select case
    when s.total <= 21 then s.total
    else s.total - 10 * least(s.aces, ceil((s.total - 21) / 10.0)::int)
  end
  from (
    select
      coalesce(sum(case
        when c % 13 = 0 then 11
        when c % 13 >= 9 then 10
        else c % 13 + 1
      end), 0)::int as total,
      count(*) filter (where c % 13 = 0)::int as aces
    from unnest(cards) as c
  ) s;
$$;

-- What the player may see: Bernie's second card stays hidden (-1) while the
-- hand is being played.
create function public.bj_view(uid uuid)
returns jsonb
language sql stable
security definer set search_path = ''
as $$
  select jsonb_build_object(
    'coins', (select p.coins from public.profiles p where p.id = uid),
    'hand', (
      select jsonb_build_object(
        'player', h.player,
        'dealer', case when h.playing
                    then array[h.dealer[1], -1::smallint]
                    else h.dealer end,
        'bet', h.bet,
        'playing', h.playing,
        'outcome', h.outcome,
        'payout', h.payout
      )
      from public.blackjack_hands h where h.user_id = uid
    )
  );
$$;

-- Ends the hand: Bernie draws to 17 (if [dealer_plays]), then the bet is
-- settled and any winnings paid out.
create function public.bj_finish(uid uuid, dealer_plays boolean)
returns void
language plpgsql
security definer set search_path = ''
as $$
declare
  h public.blackjack_hands;
  pv int;
  dv int;
  player_bj boolean;
  dealer_bj boolean;
  result text;
  pay int;
begin
  select * into h from public.blackjack_hands where user_id = uid for update;
  pv := public.bj_value(h.player);
  if dealer_plays and pv <= 21 then
    while public.bj_value(h.dealer) < 17 loop
      h.dealer := h.dealer || h.deck[1];
      h.deck := h.deck[2:];
    end loop;
  end if;
  dv := public.bj_value(h.dealer);
  player_bj := pv = 21 and cardinality(h.player) = 2;
  dealer_bj := dv = 21 and cardinality(h.dealer) = 2;

  if pv > 21 then
    result := 'bust'; pay := 0;
  elsif player_bj and dealer_bj then
    result := 'push'; pay := h.bet;
  elsif player_bj then
    result := 'blackjack'; pay := h.bet + (h.bet * 3) / 2;
  elsif dealer_bj then
    result := 'dealer_blackjack'; pay := 0;
  elsif dv > 21 then
    result := 'dealer_bust'; pay := h.bet * 2;
  elsif pv > dv then
    result := 'win'; pay := h.bet * 2;
  elsif pv < dv then
    result := 'lose'; pay := 0;
  else
    result := 'push'; pay := h.bet;
  end if;

  update public.blackjack_hands
     set dealer = h.dealer, deck = h.deck, playing = false,
         outcome = result, payout = pay, updated_at = now()
   where user_id = uid;
  update public.profiles set coins = coins + pay where id = uid;
end;
$$;

-- ---------------------------------------------------------------------------
-- What players call.
-- ---------------------------------------------------------------------------

-- Once a day (UTC), entering the tavern adds 200 coins. Returns the coins
-- and how many were just added (0 if already claimed today).
create function public.claim_daily_coins()
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
     set coins = coins + 200, coins_claimed_on = current_date
   where id = uid
     and coins_claimed_on is distinct from current_date;
  if found then bonus := 200; end if;
  select coins into total from public.profiles where id = uid;
  return jsonb_build_object('coins', total, 'bonus', bonus);
end;
$$;

-- The current (or last) hand and the player's coins.
create function public.blackjack_state()
returns jsonb
language plpgsql
security definer set search_path = ''
as $$
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  return public.bj_view(auth.uid());
end;
$$;

-- Bets [p_bet] coins (10-500) and deals a new hand.
create function public.blackjack_deal(p_bet int)
returns jsonb
language plpgsql
security definer set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  have int;
  shuffled smallint[];
begin
  if uid is null then raise exception 'not signed in'; end if;
  select coins into have from public.profiles where id = uid for update;
  if exists (select 1 from public.blackjack_hands
              where user_id = uid and playing) then
    raise exception 'a hand is already being played';
  end if;
  if p_bet is null or p_bet < 10 or p_bet > 500 or p_bet > have then
    raise exception 'invalid bet';
  end if;

  update public.profiles set coins = coins - p_bet where id = uid;
  select array_agg(c::smallint order by gen_random_uuid())
    into shuffled from generate_series(0, 51) as c;

  insert into public.blackjack_hands
    (user_id, deck, player, dealer, bet, playing, outcome, payout, updated_at)
  values
    (uid, shuffled[5:], array[shuffled[1], shuffled[3]],
     array[shuffled[2], shuffled[4]], p_bet, true, null, 0, now())
  on conflict (user_id) do update
    set deck = excluded.deck, player = excluded.player,
        dealer = excluded.dealer, bet = excluded.bet, playing = true,
        outcome = null, payout = 0, updated_at = now();

  -- A natural blackjack on either side ends the hand straight away.
  if public.bj_value(array[shuffled[1], shuffled[3]]) = 21
     or public.bj_value(array[shuffled[2], shuffled[4]]) = 21 then
    perform public.bj_finish(uid, false);
  end if;
  return public.bj_view(uid);
end;
$$;

-- Takes another card. Over 21 loses; exactly 21 stands automatically.
create function public.blackjack_hit()
returns jsonb
language plpgsql
security definer set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  h public.blackjack_hands;
  v int;
begin
  if uid is null then raise exception 'not signed in'; end if;
  select * into h from public.blackjack_hands
   where user_id = uid and playing for update;
  if not found then raise exception 'no hand in play'; end if;

  update public.blackjack_hands
     set player = player || deck[1], deck = deck[2:], updated_at = now()
   where user_id = uid
  returning public.bj_value(player) into v;

  if v > 21 then
    perform public.bj_finish(uid, false);
  elsif v = 21 then
    perform public.bj_finish(uid, true);
  end if;
  return public.bj_view(uid);
end;
$$;

-- Keeps the hand: Bernie plays his, then the bet is settled.
create function public.blackjack_stand()
returns jsonb
language plpgsql
security definer set search_path = ''
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then raise exception 'not signed in'; end if;
  if not exists (select 1 from public.blackjack_hands
                  where user_id = uid and playing) then
    raise exception 'no hand in play';
  end if;
  perform public.bj_finish(uid, true);
  return public.bj_view(uid);
end;
$$;

-- Doubles the bet on the first two cards, takes exactly one more card and
-- stands.
create function public.blackjack_double()
returns jsonb
language plpgsql
security definer set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  h public.blackjack_hands;
  have int;
begin
  if uid is null then raise exception 'not signed in'; end if;
  select coins into have from public.profiles where id = uid for update;
  select * into h from public.blackjack_hands
   where user_id = uid and playing for update;
  if not found then raise exception 'no hand in play'; end if;
  if cardinality(h.player) <> 2 then raise exception 'too late to double'; end if;
  if have < h.bet then raise exception 'not enough coins'; end if;

  update public.profiles set coins = coins - h.bet where id = uid;
  update public.blackjack_hands
     set bet = bet * 2, player = player || deck[1], deck = deck[2:],
         updated_at = now()
   where user_id = uid;
  perform public.bj_finish(uid, true);
  return public.bj_view(uid);
end;
$$;

-- Functions run for everyone by default: lock the helpers away and let
-- signed-in players call only the game itself.
revoke execute on function
  public.bj_value(smallint[]), public.bj_view(uuid),
  public.bj_finish(uuid, boolean), public.claim_daily_coins(),
  public.blackjack_state(), public.blackjack_deal(int),
  public.blackjack_hit(), public.blackjack_stand(), public.blackjack_double()
  from public, anon, authenticated;
grant execute on function
  public.claim_daily_coins(), public.blackjack_state(),
  public.blackjack_deal(int), public.blackjack_hit(),
  public.blackjack_stand(), public.blackjack_double()
  to authenticated;
