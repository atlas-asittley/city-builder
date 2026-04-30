-- 0004_world_view_and_placement.sql
-- Phase 4: District tile seeding, building placement RPC, and supporting RLS.
--
-- Changes:
--   1. seed_district_tiles() — creates 64 tiles for an 8x8 district
--      with resource nodes biased toward the owner's specialization.
--   2. Updates complete_onboarding to call seed_district_tiles.
--   3. place_building() — server-authoritative building placement RPC.
--   4. RLS read policies for tiles and buildings tables.

-- ── 1. seed_district_tiles ────────────────────────────────
-- Generates tiles for a district. Resource distribution:
--   ~6 tiles of the player's specialization resource
--   ~2 tiles of a secondary resource
--   ~1 tile of a third resource
--   remaining tiles are plain (no resource)
-- Terrain: all 'grass' for now (can diversify later).

create or replace function public.seed_district_tiles(
  p_district_id uuid,
  p_specialization_key text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_district record;
  v_world_id uuid;
  v_spec_resource text;
  v_secondary_resource text;
  v_tertiary_resource text;
  v_all_raw text[] := array['timber', 'stone', 'grain', 'clay', 'iron_ore'];
  v_others text[];
  v_dx int;
  v_dy int;
  v_abs_x int;
  v_abs_y int;
  v_tile_index int;
  v_resource text;
  v_terrain text;
  v_seed int;
begin
  -- Load district
  select * into v_district from public.districts where id = p_district_id;
  if v_district is null then
    raise exception 'District not found';
  end if;
  v_world_id := v_district.world_id;

  -- Map specialization_key to resource_key (iron_ore uses iron_ore)
  v_spec_resource := p_specialization_key;

  -- Pick secondary and tertiary resources (deterministic by district position)
  v_others := array[]::text[];
  for i in 1..array_length(v_all_raw, 1) loop
    if v_all_raw[i] != v_spec_resource then
      v_others := v_others || v_all_raw[i];
    end if;
  end loop;
  -- Use origin coords as a simple seed for selection
  v_seed := (v_district.origin_x * 7 + v_district.origin_y * 13) % array_length(v_others, 1);
  v_secondary_resource := v_others[(v_seed % array_length(v_others, 1)) + 1];
  v_tertiary_resource := v_others[((v_seed + 1) % array_length(v_others, 1)) + 1];

  -- Generate 8x8 = 64 tiles
  for v_dy in 0..v_district.height - 1 loop
    for v_dx in 0..v_district.width - 1 loop
      v_abs_x := v_district.origin_x + v_dx;
      v_abs_y := v_district.origin_y + v_dy;
      v_tile_index := v_dy * v_district.width + v_dx;

      -- Resource placement pattern (deterministic, using tile index):
      -- Indices 10,11,18,19,26,34 → primary resource (6 tiles)
      -- Indices 5,44            → secondary resource (2 tiles)
      -- Index  37               → tertiary resource (1 tile)
      v_resource := null;
      if v_tile_index in (10, 11, 18, 19, 26, 34) then
        v_resource := v_spec_resource;
      elsif v_tile_index in (5, 44) then
        v_resource := v_secondary_resource;
      elsif v_tile_index = 37 then
        v_resource := v_tertiary_resource;
      end if;

      -- Terrain: resource tiles get matching terrain hint, others get grass
      if v_resource is not null then
        v_terrain := v_resource;
      else
        v_terrain := 'grass';
      end if;

      insert into public.tiles (world_id, district_id, x, y, terrain_key, resource_key, is_revealed, is_buildable, owner_player_id)
      values (v_world_id, p_district_id, v_abs_x, v_abs_y, v_terrain, v_resource, true, true, v_district.owner_player_id)
      on conflict (world_id, x, y) do nothing;
    end loop;
  end loop;
end;
$$;


-- ── 2. Update complete_onboarding to seed tiles ───────────
create or replace function public.complete_onboarding(
  p_display_name text,
  p_specialization_key text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_player_id uuid;
  v_world_id uuid;
  v_district_id uuid;
  v_email text;
  v_district_slot record;
begin
  v_player_id := auth.uid();
  if v_player_id is null then
    raise exception 'Not authenticated';
  end if;

  if p_display_name is null or length(trim(p_display_name)) < 2 then
    raise exception 'Display name must be at least 2 characters';
  end if;
  if length(trim(p_display_name)) > 24 then
    raise exception 'Display name must be 24 characters or fewer';
  end if;

  if p_specialization_key not in ('timber', 'stone', 'grain', 'clay', 'iron_ore') then
    raise exception 'Invalid specialization. Must be timber, stone, grain, clay, or iron_ore.';
  end if;

  if exists (
    select 1 from public.player_profiles
    where id = v_player_id and specialization_key is not null
  ) then
    raise exception 'Player has already completed onboarding';
  end if;

  select id into v_world_id
  from public.worlds
  where slug = 'alpha-world' and status = 'active'
  limit 1;

  if v_world_id is null then
    raise exception 'No active world found';
  end if;

  select email into v_email
  from auth.users
  where id = v_player_id;

  -- Upsert player profile first (needed before district FK)
  insert into public.player_profiles (id, email, display_name, specialization_key, home_world_id, home_district_id)
  values (v_player_id, v_email, trim(p_display_name), p_specialization_key, v_world_id, null)
  on conflict (id) do update set
    display_name = trim(p_display_name),
    specialization_key = p_specialization_key,
    home_world_id = v_world_id;

  -- Auto-create a Tier 1 district
  select
    (s.slot_index % 4) * 8 as ox,
    (s.slot_index / 4) * 8 as oy
  into v_district_slot
  from generate_series(0, 15) as s(slot_index)
  where not exists (
    select 1 from public.districts d
    where d.world_id = v_world_id
      and d.origin_x = (s.slot_index % 4) * 8
      and d.origin_y = (s.slot_index / 4) * 8
  )
  order by s.slot_index
  limit 1;

  if v_district_slot is null then
    raise exception 'No district slots available in the world';
  end if;

  insert into public.districts (world_id, owner_player_id, name, origin_x, origin_y, width, height, tier, status)
  values (v_world_id, v_player_id, trim(p_display_name) || '''s District', v_district_slot.ox, v_district_slot.oy, 8, 8, 1, 'active')
  returning id into v_district_id;

  -- Link district back to profile
  update public.player_profiles
  set home_district_id = v_district_id
  where id = v_player_id;

  -- Create treasury
  insert into public.player_treasuries (player_id, gold, income_per_tick, expenses_per_tick)
  values (v_player_id, 500, 0, 0)
  on conflict (player_id) do nothing;

  -- Create inventory rows for all 15 v1 goods
  insert into public.player_inventories (player_id, resource_key, amount)
  values
    (v_player_id, 'timber', 0),
    (v_player_id, 'stone', 0),
    (v_player_id, 'grain', 0),
    (v_player_id, 'clay', 0),
    (v_player_id, 'iron_ore', 0),
    (v_player_id, 'wood_planks', 0),
    (v_player_id, 'cut_stone', 0),
    (v_player_id, 'bricks', 0),
    (v_player_id, 'iron_bars', 0),
    (v_player_id, 'flour', 0),
    (v_player_id, 'bread', 0),
    (v_player_id, 'tools', 0),
    (v_player_id, 'pottery', 0),
    (v_player_id, 'furniture', 0),
    (v_player_id, 'fine_goods', 0)
  on conflict (player_id, resource_key) do nothing;

  -- Create population state
  insert into public.population_state (player_id, district_id, total_population, housed_population, employed_population, unhoused_population, happiness)
  values (v_player_id, v_district_id, 0, 0, 0, 0, 50)
  on conflict (player_id) do nothing;

  -- Seed district tiles with resource distribution
  perform public.seed_district_tiles(v_district_id, p_specialization_key);

  return jsonb_build_object(
    'success', true,
    'player_id', v_player_id,
    'display_name', trim(p_display_name),
    'specialization', p_specialization_key,
    'world_id', v_world_id,
    'district_id', v_district_id,
    'district_tier', 1
  );
end;
$$;

grant execute on function public.complete_onboarding(text, text) to authenticated;


-- ── 3. place_building RPC ─────────────────────────────────
-- Server-authoritative building placement.
-- Validates: auth, district ownership, tier unlock, position bounds,
-- tile buildability, resource match, footprint collision, gold cost.
-- Deducts gold and inserts building row.
-- Resource material costs (wood_planks, etc.) are NOT deducted yet —
-- that requires inventory deduction which will be wired in the next pass.

create or replace function public.place_building(
  p_building_type_key text,
  p_anchor_x integer,
  p_anchor_y integer
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_player_id uuid;
  v_bt record;
  v_district record;
  v_profile record;
  v_gold integer;
  v_build_rules jsonb;
  v_gold_cost integer;
  v_required_tier integer;
  v_bx integer;
  v_by integer;
  v_tile record;
  v_building_id uuid;
begin
  v_player_id := auth.uid();
  if v_player_id is null then
    raise exception 'Not authenticated';
  end if;

  -- Load building type
  select * into v_bt from public.building_types where key = p_building_type_key and is_active = true;
  if v_bt is null then
    raise exception 'Unknown or inactive building type: %', p_building_type_key;
  end if;
  v_build_rules := v_bt.build_rules;

  -- Load player profile
  select * into v_profile from public.player_profiles where id = v_player_id;
  if v_profile is null then
    raise exception 'Player profile not found';
  end if;

  -- Load player's district
  select * into v_district from public.districts where id = v_profile.home_district_id and owner_player_id = v_player_id;
  if v_district is null then
    raise exception 'No owned district found';
  end if;

  -- Check district tier requirement
  v_required_tier := coalesce((v_build_rules->>'districtTierRequired')::integer, 1);
  if v_district.tier < v_required_tier then
    raise exception 'District tier % required (have tier %)', v_required_tier, v_district.tier;
  end if;

  -- Check position is within district bounds (anchor + footprint)
  for v_by in p_anchor_y .. p_anchor_y + v_bt.footprint_h - 1 loop
    for v_bx in p_anchor_x .. p_anchor_x + v_bt.footprint_w - 1 loop
      if v_bx < v_district.origin_x
         or v_bx >= v_district.origin_x + v_district.width
         or v_by < v_district.origin_y
         or v_by >= v_district.origin_y + v_district.height then
        raise exception 'Position (%, %) is outside your district', v_bx, v_by;
      end if;

      -- Check tile exists and is buildable
      select * into v_tile
      from public.tiles
      where world_id = v_district.world_id and x = v_bx and y = v_by;

      if v_tile is null then
        raise exception 'No tile at (%, %)', v_bx, v_by;
      end if;

      if not v_tile.is_buildable then
        raise exception 'Tile (%, %) is not buildable', v_bx, v_by;
      end if;

      -- Check no existing active building occupies this tile
      if exists (
        select 1 from public.buildings b
        join public.building_types bt2 on bt2.key = b.building_type_key
        where b.world_id = v_district.world_id
          and b.status = 'active'
          and v_bx >= b.anchor_x and v_bx < b.anchor_x + bt2.footprint_w
          and v_by >= b.anchor_y and v_by < b.anchor_y + bt2.footprint_h
      ) then
        raise exception 'Tile (%, %) is already occupied by another building', v_bx, v_by;
      end if;
    end loop;
  end loop;

  -- Check resource match for extraction buildings
  if coalesce((v_build_rules->>'mustMatchResource')::boolean, false) then
    select * into v_tile
    from public.tiles
    where world_id = v_district.world_id and x = p_anchor_x and y = p_anchor_y;

    if v_tile.resource_key is null or v_tile.resource_key != v_bt.required_resource_key then
      raise exception 'This building requires a % resource tile', v_bt.required_resource_key;
    end if;
  end if;

  -- Check gold cost
  v_gold_cost := coalesce((v_build_rules->'buildCosts'->>'gold')::integer, v_bt.cost_gold);
  select gold into v_gold from public.player_treasuries where player_id = v_player_id;
  if v_gold is null or v_gold < v_gold_cost then
    raise exception 'Not enough gold. Need %, have %', v_gold_cost, coalesce(v_gold, 0);
  end if;

  -- Deduct gold
  update public.player_treasuries
  set gold = gold - v_gold_cost
  where player_id = v_player_id;

  -- Insert building
  insert into public.buildings (world_id, district_id, owner_player_id, building_type_key, anchor_x, anchor_y, level, status)
  values (v_district.world_id, v_district.id, v_player_id, p_building_type_key, p_anchor_x, p_anchor_y, 1, 'active')
  returning id into v_building_id;

  return jsonb_build_object(
    'success', true,
    'building_id', v_building_id,
    'building_type', p_building_type_key,
    'anchor_x', p_anchor_x,
    'anchor_y', p_anchor_y,
    'gold_spent', v_gold_cost,
    'gold_remaining', v_gold - v_gold_cost
  );
end;
$$;

grant execute on function public.place_building(text, integer, integer) to authenticated;


-- ── 4. RLS read policies for tiles and buildings ──────────

-- Tiles: authenticated users can read tiles (shared world data)
alter table public.tiles enable row level security;
do $$
begin
  if not exists (
    select 1 from pg_policies where tablename = 'tiles' and policyname = 'Authenticated users can read tiles'
  ) then
    create policy "Authenticated users can read tiles"
      on public.tiles for select
      using (auth.role() = 'authenticated');
  end if;
end $$;

-- Buildings: authenticated users can read buildings (shared world data)
alter table public.buildings enable row level security;
do $$
begin
  if not exists (
    select 1 from pg_policies where tablename = 'buildings' and policyname = 'Authenticated users can read buildings'
  ) then
    create policy "Authenticated users can read buildings"
      on public.buildings for select
      using (auth.role() = 'authenticated');
  end if;
end $$;

-- Player treasuries: players can read own treasury
alter table public.player_treasuries enable row level security;
do $$
begin
  if not exists (
    select 1 from pg_policies where tablename = 'player_treasuries' and policyname = 'Players can read own treasury'
  ) then
    create policy "Players can read own treasury"
      on public.player_treasuries for select
      using (auth.uid() = player_id);
  end if;
end $$;

-- Player inventories: players can read own inventory
alter table public.player_inventories enable row level security;
do $$
begin
  if not exists (
    select 1 from pg_policies where tablename = 'player_inventories' and policyname = 'Players can read own inventory'
  ) then
    create policy "Players can read own inventory"
      on public.player_inventories for select
      using (auth.uid() = player_id);
  end if;
end $$;

-- Player profiles: players can read own profile (needed for game view)
alter table public.player_profiles enable row level security;
do $$
begin
  if not exists (
    select 1 from pg_policies where tablename = 'player_profiles' and policyname = 'Players can read own profile'
  ) then
    create policy "Players can read own profile"
      on public.player_profiles for select
      using (auth.uid() = id);
  end if;
end $$;

-- Population state: players can read own population
alter table public.population_state enable row level security;
do $$
begin
  if not exists (
    select 1 from pg_policies where tablename = 'population_state' and policyname = 'Players can read own population'
  ) then
    create policy "Players can read own population"
      on public.population_state for select
      using (auth.uid() = player_id);
  end if;
end $$;
