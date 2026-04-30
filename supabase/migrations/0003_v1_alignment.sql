-- 0003_v1_alignment.sql
-- Aligns bootstrap/onboarding with the 15-good v1 seed model.
--
-- Changes:
--   1. Add tier column to districts (default 1, range 1-3)
--   2. Replace complete_onboarding RPC to:
--      - Accept all 5 specializations (timber, stone, grain, clay, iron)
--      - Initialize inventory rows for all 15 v1 goods
--      - Auto-create a Tier 1 district for the player
--      - Link home_district_id on player_profiles
--   3. Add RLS read policy on districts for authenticated users
--   4. Add RLS read policy on building_types and resource_types

-- ── 1. District tier support ────────────────────────────
alter table public.districts
  add column if not exists tier integer not null default 1;

-- Add check constraint for valid tier range (1-3 for v1)
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'districts_tier_range'
  ) then
    alter table public.districts
      add constraint districts_tier_range check (tier >= 1 and tier <= 3);
  end if;
end $$;

-- ── 2. Updated onboarding RPC ──────────────────────────
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
  -- Get the calling user's id
  v_player_id := auth.uid();
  if v_player_id is null then
    raise exception 'Not authenticated';
  end if;

  -- Validate display name
  if p_display_name is null or length(trim(p_display_name)) < 2 then
    raise exception 'Display name must be at least 2 characters';
  end if;
  if length(trim(p_display_name)) > 24 then
    raise exception 'Display name must be 24 characters or fewer';
  end if;

  -- Validate specialization is one of the 5 raw resource types
  if p_specialization_key not in ('timber', 'stone', 'grain', 'clay', 'iron_ore') then
    raise exception 'Invalid specialization. Must be timber, stone, grain, clay, or iron_ore.';
  end if;

  -- Check player hasn't already onboarded
  if exists (
    select 1 from public.player_profiles
    where id = v_player_id and specialization_key is not null
  ) then
    raise exception 'Player has already completed onboarding';
  end if;

  -- Get Alpha World id
  select id into v_world_id
  from public.worlds
  where slug = 'alpha-world' and status = 'active'
  limit 1;

  if v_world_id is null then
    raise exception 'No active world found';
  end if;

  -- Get email from auth.users
  select email into v_email
  from auth.users
  where id = v_player_id;

  -- ── Auto-create a Tier 1 district for this player ─────
  -- Find next available 8x8 slot in the 32x32 world grid.
  -- Slots are laid out left-to-right, top-to-bottom in 8x8 chunks.
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

  -- ── Upsert player profile (link district + world) ─────
  insert into public.player_profiles (id, email, display_name, specialization_key, home_world_id, home_district_id)
  values (v_player_id, v_email, trim(p_display_name), p_specialization_key, v_world_id, v_district_id)
  on conflict (id) do update set
    display_name = trim(p_display_name),
    specialization_key = p_specialization_key,
    home_world_id = v_world_id,
    home_district_id = v_district_id;

  -- ── Create treasury (500 starting gold) ───────────────
  insert into public.player_treasuries (player_id, gold, income_per_tick, expenses_per_tick)
  values (v_player_id, 500, 0, 0)
  on conflict (player_id) do nothing;

  -- ── Create inventory rows for ALL 15 v1 goods ─────────
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

  -- ── Create population state ───────────────────────────
  insert into public.population_state (player_id, district_id, total_population, housed_population, employed_population, unhoused_population, happiness)
  values (v_player_id, v_district_id, 0, 0, 0, 0, 50)
  on conflict (player_id) do nothing;

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

-- Re-grant execute (idempotent)
grant execute on function public.complete_onboarding(text, text) to authenticated;

-- ── 3. RLS policies for shared catalog/world reads ──────

-- Districts: any authenticated user can read (shared world data)
alter table public.districts enable row level security;
create policy if not exists "Authenticated users can read districts"
  on public.districts for select
  using (auth.role() = 'authenticated');

-- Building types: any authenticated user can read the catalog
alter table public.building_types enable row level security;
create policy if not exists "Authenticated users can read building types"
  on public.building_types for select
  using (auth.role() = 'authenticated');

-- Resource types: any authenticated user can read the catalog
alter table public.resource_types enable row level security;
create policy if not exists "Authenticated users can read resource types"
  on public.resource_types for select
  using (auth.role() = 'authenticated');

-- Worlds: any authenticated user can read active worlds
alter table public.worlds enable row level security;
create policy if not exists "Authenticated users can read active worlds"
  on public.worlds for select
  using (auth.role() = 'authenticated');
