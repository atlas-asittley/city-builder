-- 0008_npc_trade.sql
-- Phase 8: NPC trade partners and server-authoritative trade execution.
--
-- Adds:
--   1. external_trade_partners — NPC cities that buy/sell goods
--   2. trade_transactions — audit log of all completed trades
--   3. get_trade_partners() — returns available NPC partners + their catalogs
--   4. execute_npc_trade(partner_id, resource_key, direction, amount)
--      — server-authoritative buy/sell against an NPC partner
--
-- Trade rules:
--   - Each NPC partner has a buy catalog and a sell catalog (jsonb)
--   - Buy = player sells goods TO the NPC for gold
--   - Sell = player buys goods FROM the NPC for gold
--   - Prices are fixed per partner (no dynamic pricing in v1)
--   - Trades are atomic: inventory and treasury update in one transaction
--   - Requires a trade_depot building in the player's district

-- ── 1. External trade partners table ──────────────────
create table if not exists public.external_trade_partners (
  id uuid primary key default gen_random_uuid(),
  world_id uuid not null references public.worlds(id) on delete cascade,
  name text not null,
  description text,
  -- buy_catalog: goods this NPC will BUY from the player
  -- format: { "timber": { "price": 8, "max_per_trade": 20 }, ... }
  buy_catalog jsonb not null default '{}'::jsonb,
  -- sell_catalog: goods this NPC will SELL to the player
  -- format: { "bread": { "price": 15, "max_per_trade": 10 }, ... }
  sell_catalog jsonb not null default '{}'::jsonb,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

-- RLS: all authenticated users can read
alter table public.external_trade_partners enable row level security;
drop policy if exists "trade_partners_read" on public.external_trade_partners;
create policy "trade_partners_read" on public.external_trade_partners
  for select to authenticated using (true);

-- ── 2. Trade transactions audit log ───────────────────
-- Drop the old trade_transactions table from initial schema (different columns, empty)
drop table if exists public.trade_transactions;
create table public.trade_transactions (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.player_profiles(id) on delete cascade,
  partner_id uuid references public.external_trade_partners(id) on delete set null,
  partner_name text,
  direction text not null check (direction in ('buy', 'sell')),
  resource_key text not null references public.resource_types(key),
  amount integer not null check (amount > 0),
  price_per_unit integer not null,
  total_gold integer not null,
  created_at timestamptz not null default now()
);

-- RLS: players can read their own transactions
alter table public.trade_transactions enable row level security;
drop policy if exists "trade_tx_read_own" on public.trade_transactions;
create policy "trade_tx_read_own" on public.trade_transactions
  for select to authenticated using (player_id = auth.uid());

-- ── 3. get_trade_partners() ───────────────────────────
create or replace function public.get_trade_partners()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_player_id uuid;
  v_profile record;
  v_has_depot boolean;
  v_partners jsonb;
begin
  v_player_id := auth.uid();
  if v_player_id is null then
    raise exception 'Not authenticated';
  end if;

  -- Load player profile for world reference
  select * into v_profile
  from public.player_profiles
  where id = v_player_id;

  if v_profile is null then
    raise exception 'Player profile not found';
  end if;

  -- Check if player has a trade depot
  select exists(
    select 1 from public.buildings b
    where b.owner_player_id = v_player_id
      and b.status = 'active'
      and b.building_type_key = 'trade_depot'
  ) into v_has_depot;

  -- Get all active partners in the player's world
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', p.id,
      'name', p.name,
      'description', p.description,
      'buy_catalog', p.buy_catalog,
      'sell_catalog', p.sell_catalog
    )
  ), '[]'::jsonb)
  into v_partners
  from public.external_trade_partners p
  where p.world_id = v_profile.home_world_id
    and p.is_active = true;

  return jsonb_build_object(
    'has_trade_depot', v_has_depot,
    'partners', v_partners
  );
end;
$$;

grant execute on function public.get_trade_partners() to authenticated;


-- ── 4. execute_npc_trade() ────────────────────────────
-- direction = 'sell' means player SELLS goods to NPC (player loses goods, gains gold)
-- direction = 'buy'  means player BUYS goods from NPC (player gains goods, loses gold)
create or replace function public.execute_npc_trade(
  p_partner_id uuid,
  p_resource_key text,
  p_direction text,
  p_amount integer
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_player_id uuid;
  v_profile record;
  v_partner record;
  v_has_depot boolean;
  v_catalog jsonb;
  v_entry jsonb;
  v_price integer;
  v_max_per_trade integer;
  v_total_gold integer;
  v_gold integer;
  v_have_amount numeric;
  v_partner_name text;
begin
  v_player_id := auth.uid();
  if v_player_id is null then
    raise exception 'Not authenticated';
  end if;

  -- Validate direction
  if p_direction not in ('buy', 'sell') then
    raise exception 'Invalid trade direction: %', p_direction;
  end if;

  -- Validate amount
  if p_amount < 1 then
    raise exception 'Trade amount must be at least 1';
  end if;

  -- Load player profile
  select * into v_profile
  from public.player_profiles
  where id = v_player_id;

  if v_profile is null then
    raise exception 'Player profile not found';
  end if;

  -- Check trade depot exists
  select exists(
    select 1 from public.buildings b
    where b.owner_player_id = v_player_id
      and b.status = 'active'
      and b.building_type_key = 'trade_depot'
  ) into v_has_depot;

  if not v_has_depot then
    raise exception 'You need a Trade Depot to trade with external partners';
  end if;

  -- Load partner
  select * into v_partner
  from public.external_trade_partners
  where id = p_partner_id
    and world_id = v_profile.home_world_id
    and is_active = true;

  if v_partner is null then
    raise exception 'Trade partner not found or not available';
  end if;

  v_partner_name := v_partner.name;

  -- Look up the resource in the appropriate catalog
  if p_direction = 'sell' then
    -- Player sells TO NPC → look in NPC's buy_catalog
    v_catalog := v_partner.buy_catalog;
  else
    -- Player buys FROM NPC → look in NPC's sell_catalog
    v_catalog := v_partner.sell_catalog;
  end if;

  v_entry := v_catalog->p_resource_key;
  if v_entry is null then
    raise exception '% does not trade % in this direction', v_partner_name, p_resource_key;
  end if;

  v_price := (v_entry->>'price')::integer;
  v_max_per_trade := coalesce((v_entry->>'max_per_trade')::integer, 50);

  if v_price is null or v_price < 1 then
    raise exception 'Invalid price configuration for this trade';
  end if;

  if p_amount > v_max_per_trade then
    raise exception 'Maximum % units per trade (requested %)', v_max_per_trade, p_amount;
  end if;

  v_total_gold := v_price * p_amount;

  -- Execute the trade based on direction
  if p_direction = 'sell' then
    -- Player sells goods → lose goods, gain gold
    -- Check player has enough goods
    select amount into v_have_amount
    from public.player_inventories
    where player_id = v_player_id and resource_key = p_resource_key;

    if v_have_amount is null or v_have_amount < p_amount then
      raise exception 'Not enough %. Need %, have %',
        p_resource_key, p_amount, coalesce(v_have_amount, 0);
    end if;

    -- Deduct goods
    update public.player_inventories
    set amount = amount - p_amount, updated_at = now()
    where player_id = v_player_id and resource_key = p_resource_key;

    -- Add gold
    update public.player_treasuries
    set gold = gold + v_total_gold, updated_at = now()
    where player_id = v_player_id;

  else
    -- Player buys goods → lose gold, gain goods
    select gold into v_gold
    from public.player_treasuries
    where player_id = v_player_id;

    if v_gold is null or v_gold < v_total_gold then
      raise exception 'Not enough gold. Need %, have %',
        v_total_gold, coalesce(v_gold, 0);
    end if;

    -- Deduct gold
    update public.player_treasuries
    set gold = gold - v_total_gold, updated_at = now()
    where player_id = v_player_id;

    -- Add goods (upsert)
    insert into public.player_inventories (player_id, resource_key, amount, updated_at)
    values (v_player_id, p_resource_key, p_amount, now())
    on conflict (player_id, resource_key)
    do update set amount = player_inventories.amount + p_amount, updated_at = now();
  end if;

  -- Record transaction
  insert into public.trade_transactions
    (player_id, partner_id, partner_name, direction, resource_key, amount, price_per_unit, total_gold)
  values
    (v_player_id, p_partner_id, v_partner_name, p_direction, p_resource_key, p_amount, v_price, v_total_gold);

  -- Return updated state
  return jsonb_build_object(
    'success', true,
    'direction', p_direction,
    'partner', v_partner_name,
    'resource', p_resource_key,
    'amount', p_amount,
    'price_per_unit', v_price,
    'total_gold', v_total_gold,
    'gold', (select gold from public.player_treasuries where player_id = v_player_id),
    'inventory', (
      select coalesce(jsonb_object_agg(resource_key, amount), '{}'::jsonb)
      from public.player_inventories
      where player_id = v_player_id
    )
  );
end;
$$;

grant execute on function public.execute_npc_trade(uuid, text, text, integer) to authenticated;


-- ── 5. Seed NPC trade partners for alpha-world ────────
-- Four trade partners with distinct personalities, matching the design docs.
-- Prices are deliberately less efficient than player-to-player trade would be.
do $$
declare
  v_world_id uuid;
begin
  select id into v_world_id from public.worlds where slug = 'alpha-world' limit 1;
  if v_world_id is null then
    raise notice 'No alpha-world found, skipping NPC partner seeding';
    return;
  end if;

  -- River Traders: raw material buyers, food sellers
  insert into public.external_trade_partners (world_id, name, description, buy_catalog, sell_catalog)
  values (
    v_world_id,
    'River Traders',
    'Barge merchants who haul raw goods downstream. They pay fair prices for timber and grain, and carry surplus bread upriver.',
    '{
      "timber": {"price": 8, "max_per_trade": 20},
      "grain": {"price": 7, "max_per_trade": 20},
      "clay": {"price": 6, "max_per_trade": 15}
    }'::jsonb,
    '{
      "bread": {"price": 18, "max_per_trade": 10},
      "flour": {"price": 12, "max_per_trade": 10}
    }'::jsonb
  )
  on conflict do nothing;

  -- Mountain Folk: stone and iron buyers, tool sellers
  insert into public.external_trade_partners (world_id, name, description, buy_catalog, sell_catalog)
  values (
    v_world_id,
    'Mountain Folk',
    'Hardy miners from the northern ranges. They trade in stone, ore, and the finest forged tools.',
    '{
      "stone": {"price": 9, "max_per_trade": 20},
      "iron_ore": {"price": 10, "max_per_trade": 15},
      "cut_stone": {"price": 18, "max_per_trade": 10}
    }'::jsonb,
    '{
      "tools": {"price": 25, "max_per_trade": 8},
      "iron_bars": {"price": 16, "max_per_trade": 10}
    }'::jsonb
  )
  on conflict do nothing;

  -- Desert Caravan: construction material buyers, luxury sellers
  insert into public.external_trade_partners (world_id, name, description, buy_catalog, sell_catalog)
  values (
    v_world_id,
    'Desert Caravan',
    'Exotic merchants crossing the southern wastes. They prize construction goods and offer pottery and fine goods in return.',
    '{
      "wood_planks": {"price": 14, "max_per_trade": 15},
      "bricks": {"price": 13, "max_per_trade": 15},
      "iron_bars": {"price": 15, "max_per_trade": 10}
    }'::jsonb,
    '{
      "pottery": {"price": 22, "max_per_trade": 8},
      "fine_goods": {"price": 35, "max_per_trade": 5}
    }'::jsonb
  )
  on conflict do nothing;

  -- Coastal Merchants: prestige buyers, construction sellers
  insert into public.external_trade_partners (world_id, name, description, buy_catalog, sell_catalog)
  values (
    v_world_id,
    'Coastal Merchants',
    'Wealthy sea traders with an appetite for luxury goods. They bring surplus construction materials from port cities.',
    '{
      "furniture": {"price": 22, "max_per_trade": 10},
      "pottery": {"price": 18, "max_per_trade": 10},
      "fine_goods": {"price": 30, "max_per_trade": 8}
    }'::jsonb,
    '{
      "wood_planks": {"price": 18, "max_per_trade": 12},
      "bricks": {"price": 17, "max_per_trade": 12},
      "cut_stone": {"price": 22, "max_per_trade": 8}
    }'::jsonb
  )
  on conflict do nothing;
end;
$$;
