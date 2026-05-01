-- 0009_player_market.sql
-- Phase 9: Player-to-player market — the first shared exchange layer.
--
-- Model: simple sell-offer board (gold-for-goods).
--   - A seller lists N units of a resource at a price-per-unit in gold.
--   - Goods are escrowed from the seller's inventory on creation.
--   - Any other player can fulfill (buy) the offer, paying gold.
--   - Seller can cancel to reclaim escrowed goods.
--   - Requires a trade_depot building (same gate as NPC trade).
--
-- Tables:
--   player_trade_offers — open/completed/cancelled sell orders
--
-- RPCs:
--   create_player_offer(resource_key, amount, price_per_unit)
--   cancel_player_offer(offer_id)
--   fulfill_player_offer(offer_id)
--   get_market_offers()  — all open offers in the player's world

-- ── 1. Player trade offers table ─────────────────────────
create table if not exists public.player_trade_offers (
  id uuid primary key default gen_random_uuid(),
  world_id uuid not null references public.worlds(id) on delete cascade,
  seller_id uuid not null references public.player_profiles(id) on delete cascade,
  seller_name text,
  resource_key text not null references public.resource_types(key),
  amount integer not null check (amount > 0),
  price_per_unit integer not null check (price_per_unit > 0),
  total_gold integer not null check (total_gold > 0),
  status text not null default 'open' check (status in ('open','fulfilled','cancelled')),
  buyer_id uuid references public.player_profiles(id) on delete set null,
  fulfilled_at timestamptz,
  created_at timestamptz not null default now()
);

-- RLS: all authenticated users can read open offers
alter table public.player_trade_offers enable row level security;
drop policy if exists "pto_read" on public.player_trade_offers;
create policy "pto_read" on public.player_trade_offers
  for select to authenticated using (true);

-- Index for fast open-offer queries
create index if not exists idx_pto_open on public.player_trade_offers (world_id, status) where status = 'open';


-- ── 2. create_player_offer ───────────────────────────────
-- Escrows goods from seller inventory immediately.
create or replace function public.create_player_offer(
  p_resource_key text,
  p_amount integer,
  p_price_per_unit integer
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_player_id uuid;
  v_profile record;
  v_has_depot boolean;
  v_have numeric;
  v_total integer;
  v_offer_id uuid;
  v_display_name text;
begin
  v_player_id := auth.uid();
  if v_player_id is null then
    raise exception 'Not authenticated';
  end if;

  if p_amount < 1 then
    raise exception 'Amount must be at least 1';
  end if;
  if p_price_per_unit < 1 then
    raise exception 'Price per unit must be at least 1 gold';
  end if;

  -- Load profile
  select * into v_profile
  from public.player_profiles
  where id = v_player_id;
  if v_profile is null then
    raise exception 'Player profile not found';
  end if;

  -- Require trade depot
  select exists(
    select 1 from public.buildings
    where owner_player_id = v_player_id
      and status = 'active'
      and building_type_key = 'trade_depot'
  ) into v_has_depot;
  if not v_has_depot then
    raise exception 'You need a Trade Depot to list offers on the market';
  end if;

  -- Check inventory
  select amount into v_have
  from public.player_inventories
  where player_id = v_player_id and resource_key = p_resource_key;
  if v_have is null or v_have < p_amount then
    raise exception 'Not enough %. Need %, have %', p_resource_key, p_amount, coalesce(v_have, 0);
  end if;

  v_total := p_amount * p_price_per_unit;
  v_display_name := coalesce(v_profile.display_name, split_part(v_profile.email, '@', 1));

  -- Escrow: deduct goods from inventory
  update public.player_inventories
  set amount = amount - p_amount, updated_at = now()
  where player_id = v_player_id and resource_key = p_resource_key;

  -- Create the offer
  insert into public.player_trade_offers
    (world_id, seller_id, seller_name, resource_key, amount, price_per_unit, total_gold, status)
  values
    (v_profile.home_world_id, v_player_id, v_display_name, p_resource_key, p_amount, p_price_per_unit, v_total, 'open')
  returning id into v_offer_id;

  return jsonb_build_object(
    'success', true,
    'offer_id', v_offer_id,
    'resource', p_resource_key,
    'amount', p_amount,
    'price_per_unit', p_price_per_unit,
    'total_gold', v_total,
    'inventory', (
      select coalesce(jsonb_object_agg(resource_key, amount), '{}'::jsonb)
      from public.player_inventories
      where player_id = v_player_id
    )
  );
end;
$$;

grant execute on function public.create_player_offer(text, integer, integer) to authenticated;


-- ── 3. cancel_player_offer ───────────────────────────────
-- Returns escrowed goods to the seller.
create or replace function public.cancel_player_offer(
  p_offer_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_player_id uuid;
  v_offer record;
begin
  v_player_id := auth.uid();
  if v_player_id is null then
    raise exception 'Not authenticated';
  end if;

  -- Load and lock the offer
  select * into v_offer
  from public.player_trade_offers
  where id = p_offer_id
  for update;

  if v_offer is null then
    raise exception 'Offer not found';
  end if;
  if v_offer.seller_id <> v_player_id then
    raise exception 'You can only cancel your own offers';
  end if;
  if v_offer.status <> 'open' then
    raise exception 'Offer is already %', v_offer.status;
  end if;

  -- Return escrowed goods
  insert into public.player_inventories (player_id, resource_key, amount, updated_at)
  values (v_player_id, v_offer.resource_key, v_offer.amount, now())
  on conflict (player_id, resource_key)
  do update set amount = player_inventories.amount + v_offer.amount, updated_at = now();

  -- Mark cancelled
  update public.player_trade_offers
  set status = 'cancelled'
  where id = p_offer_id;

  return jsonb_build_object(
    'success', true,
    'offer_id', p_offer_id,
    'returned_resource', v_offer.resource_key,
    'returned_amount', v_offer.amount,
    'inventory', (
      select coalesce(jsonb_object_agg(resource_key, amount), '{}'::jsonb)
      from public.player_inventories
      where player_id = v_player_id
    )
  );
end;
$$;

grant execute on function public.cancel_player_offer(uuid) to authenticated;


-- ── 4. fulfill_player_offer ──────────────────────────────
-- Buyer pays gold, seller receives gold, buyer receives goods.
create or replace function public.fulfill_player_offer(
  p_offer_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_buyer_id uuid;
  v_offer record;
  v_buyer_gold integer;
  v_has_depot boolean;
begin
  v_buyer_id := auth.uid();
  if v_buyer_id is null then
    raise exception 'Not authenticated';
  end if;

  -- Load and lock the offer
  select * into v_offer
  from public.player_trade_offers
  where id = p_offer_id
  for update;

  if v_offer is null then
    raise exception 'Offer not found';
  end if;
  if v_offer.status <> 'open' then
    raise exception 'Offer is no longer available';
  end if;
  if v_offer.seller_id = v_buyer_id then
    raise exception 'You cannot buy your own offer';
  end if;

  -- Buyer needs trade depot too
  select exists(
    select 1 from public.buildings
    where owner_player_id = v_buyer_id
      and status = 'active'
      and building_type_key = 'trade_depot'
  ) into v_has_depot;
  if not v_has_depot then
    raise exception 'You need a Trade Depot to buy from the market';
  end if;

  -- Check buyer has enough gold
  select gold into v_buyer_gold
  from public.player_treasuries
  where player_id = v_buyer_id;
  if v_buyer_gold is null or v_buyer_gold < v_offer.total_gold then
    raise exception 'Not enough gold. Need %, have %', v_offer.total_gold, coalesce(v_buyer_gold, 0);
  end if;

  -- Deduct gold from buyer
  update public.player_treasuries
  set gold = gold - v_offer.total_gold, updated_at = now()
  where player_id = v_buyer_id;

  -- Add gold to seller
  update public.player_treasuries
  set gold = gold + v_offer.total_gold, updated_at = now()
  where player_id = v_offer.seller_id;

  -- Give goods to buyer (escrowed goods transfer)
  insert into public.player_inventories (player_id, resource_key, amount, updated_at)
  values (v_buyer_id, v_offer.resource_key, v_offer.amount, now())
  on conflict (player_id, resource_key)
  do update set amount = player_inventories.amount + v_offer.amount, updated_at = now();

  -- Mark offer fulfilled
  update public.player_trade_offers
  set status = 'fulfilled',
      buyer_id = v_buyer_id,
      fulfilled_at = now()
  where id = p_offer_id;

  -- Record in trade_transactions for audit
  insert into public.trade_transactions
    (player_id, partner_id, partner_name, direction, resource_key, amount, price_per_unit, total_gold)
  values
    (v_buyer_id, null, v_offer.seller_name, 'buy', v_offer.resource_key, v_offer.amount, v_offer.price_per_unit, v_offer.total_gold);

  return jsonb_build_object(
    'success', true,
    'offer_id', p_offer_id,
    'resource', v_offer.resource_key,
    'amount', v_offer.amount,
    'total_gold', v_offer.total_gold,
    'seller', v_offer.seller_name,
    'gold', (select gold from public.player_treasuries where player_id = v_buyer_id),
    'inventory', (
      select coalesce(jsonb_object_agg(resource_key, amount), '{}'::jsonb)
      from public.player_inventories
      where player_id = v_buyer_id
    )
  );
end;
$$;

grant execute on function public.fulfill_player_offer(uuid) to authenticated;


-- ── 5. get_market_offers ─────────────────────────────────
-- Returns all open offers in the caller's world, plus the caller's own
-- non-open offers from the last 24h for status visibility.
create or replace function public.get_market_offers()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_player_id uuid;
  v_profile record;
  v_has_depot boolean;
  v_offers jsonb;
  v_my_recent jsonb;
begin
  v_player_id := auth.uid();
  if v_player_id is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_profile
  from public.player_profiles
  where id = v_player_id;
  if v_profile is null then
    raise exception 'Player profile not found';
  end if;

  -- Check depot
  select exists(
    select 1 from public.buildings
    where owner_player_id = v_player_id
      and status = 'active'
      and building_type_key = 'trade_depot'
  ) into v_has_depot;

  -- All open offers in this world
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', o.id,
      'seller_id', o.seller_id,
      'seller_name', o.seller_name,
      'resource_key', o.resource_key,
      'amount', o.amount,
      'price_per_unit', o.price_per_unit,
      'total_gold', o.total_gold,
      'created_at', o.created_at,
      'is_mine', (o.seller_id = v_player_id)
    ) order by o.created_at desc
  ), '[]'::jsonb)
  into v_offers
  from public.player_trade_offers o
  where o.world_id = v_profile.home_world_id
    and o.status = 'open';

  -- My recent non-open offers (last 24h) for status display
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', o.id,
      'resource_key', o.resource_key,
      'amount', o.amount,
      'price_per_unit', o.price_per_unit,
      'total_gold', o.total_gold,
      'status', o.status,
      'buyer_id', o.buyer_id,
      'fulfilled_at', o.fulfilled_at,
      'created_at', o.created_at
    ) order by o.created_at desc
  ), '[]'::jsonb)
  into v_my_recent
  from public.player_trade_offers o
  where o.seller_id = v_player_id
    and o.status <> 'open'
    and o.created_at > now() - interval '24 hours';

  return jsonb_build_object(
    'has_trade_depot', v_has_depot,
    'offers', v_offers,
    'my_recent', v_my_recent
  );
end;
$$;

grant execute on function public.get_market_offers() to authenticated;
