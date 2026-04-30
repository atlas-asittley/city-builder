-- 0007_housing_evolution.sql
-- Phase 7: Housing evolution and district progression.
--
-- Adds:
--   1. upgrade_housing(p_building_id) — upgrades housing in-place
--      housing_1 → housing_2: costs 3 wood_planks, 2 bricks, 50 gold
--      housing_2 → housing_3: costs 2 furniture, 2 pottery, 2 bread, 80 gold
--      Changes building_type_key on the building row.
--
--   2. upgrade_district() — checks tier-up conditions and bumps tier
--      Tier 1 → 2: requires district_hall + 3 housing_2 buildings
--      Tier 2 → 3: requires civic_center_upgrade + 2 housing_3 buildings
--
--   3. get_district_progress() — returns current tier, requirements,
--      and progress toward next tier for the calling player.

-- ── 1. upgrade_housing ──────────────────────────────────
create or replace function public.upgrade_housing(p_building_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_player_id uuid;
  v_building record;
  v_next_type text;
  v_next_bt record;
  v_upgrade_costs jsonb;
  v_cost_key text;
  v_cost_amount integer;
  v_have_amount numeric;
  v_gold_cost integer;
  v_gold integer;
  v_materials_spent jsonb := '{}'::jsonb;
begin
  v_player_id := auth.uid();
  if v_player_id is null then
    raise exception 'Not authenticated';
  end if;

  -- Load the building
  select * into v_building
  from public.buildings
  where id = p_building_id
    and owner_player_id = v_player_id
    and status = 'active';

  if v_building is null then
    raise exception 'Building not found or not owned by you';
  end if;

  -- Determine upgrade path
  case v_building.building_type_key
    when 'housing_1' then
      v_next_type := 'housing_2';
      v_upgrade_costs := '{"gold": 50, "wood_planks": 3, "bricks": 2}'::jsonb;
    when 'housing_2' then
      v_next_type := 'housing_3';
      v_upgrade_costs := '{"gold": 80, "furniture": 2, "pottery": 2, "bread": 2}'::jsonb;
    else
      raise exception 'This building cannot be upgraded further';
  end case;

  -- Check district tier supports the target housing type
  declare
    v_district record;
    v_required_tier integer;
  begin
    select * into v_district
    from public.districts
    where id = v_building.district_id;

    select bt.build_rules->>'districtTierRequired'
    into v_required_tier
    from public.building_types bt
    where bt.key = v_next_type;

    v_required_tier := coalesce(v_required_tier, 1);

    if v_district.tier < v_required_tier then
      raise exception 'District tier % required for % (currently tier %)',
        v_required_tier, v_next_type, v_district.tier;
    end if;
  end;

  -- Check and deduct gold
  v_gold_cost := (v_upgrade_costs->>'gold')::integer;
  select gold into v_gold
  from public.player_treasuries
  where player_id = v_player_id;

  if v_gold is null or v_gold < v_gold_cost then
    raise exception 'Not enough gold. Need %, have %', v_gold_cost, coalesce(v_gold, 0);
  end if;

  update public.player_treasuries
  set gold = gold - v_gold_cost
  where player_id = v_player_id;

  -- Check and deduct material costs
  for v_cost_key in select jsonb_object_keys(v_upgrade_costs) loop
    if v_cost_key = 'gold' then continue; end if;

    v_cost_amount := (v_upgrade_costs->>v_cost_key)::integer;
    if v_cost_amount is null or v_cost_amount <= 0 then continue; end if;

    select amount into v_have_amount
    from public.player_inventories
    where player_id = v_player_id and resource_key = v_cost_key;

    if v_have_amount is null or v_have_amount < v_cost_amount then
      -- Refund gold before failing
      update public.player_treasuries
      set gold = gold + v_gold_cost
      where player_id = v_player_id;
      raise exception 'Not enough %. Need %, have %',
        v_cost_key, v_cost_amount, coalesce(v_have_amount, 0);
    end if;

    update public.player_inventories
    set amount = amount - v_cost_amount, updated_at = now()
    where player_id = v_player_id and resource_key = v_cost_key;

    v_materials_spent := v_materials_spent || jsonb_build_object(v_cost_key, v_cost_amount);
  end loop;

  -- Upgrade the building type in-place
  update public.buildings
  set building_type_key = v_next_type,
      level = level + 1,
      updated_at = now()
  where id = p_building_id;

  return jsonb_build_object(
    'success', true,
    'building_id', p_building_id,
    'previous_type', v_building.building_type_key,
    'new_type', v_next_type,
    'gold_spent', v_gold_cost,
    'gold_remaining', v_gold - v_gold_cost,
    'materials_spent', v_materials_spent,
    'inventory', (
      select coalesce(jsonb_object_agg(resource_key, amount), '{}'::jsonb)
      from public.player_inventories
      where player_id = v_player_id
    )
  );
end;
$$;

grant execute on function public.upgrade_housing(uuid) to authenticated;


-- ── 2. get_district_progress ────────────────────────────
create or replace function public.get_district_progress()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_player_id uuid;
  v_district record;
  v_current_tier integer;
  v_next_tier integer;
  v_requirements jsonb := '[]'::jsonb;
  v_housing_1_count integer;
  v_housing_2_count integer;
  v_housing_3_count integer;
  v_has_district_hall boolean;
  v_has_civic_center boolean;
  v_total_buildings integer;
  v_can_upgrade boolean := false;
begin
  v_player_id := auth.uid();
  if v_player_id is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_district
  from public.districts
  where owner_player_id = v_player_id and status = 'active'
  limit 1;

  if v_district is null then
    raise exception 'No active district found';
  end if;

  v_current_tier := v_district.tier;
  v_next_tier := v_current_tier + 1;

  -- Count buildings
  select count(*) into v_housing_1_count
  from public.buildings
  where district_id = v_district.id and status = 'active'
    and building_type_key = 'housing_1';

  select count(*) into v_housing_2_count
  from public.buildings
  where district_id = v_district.id and status = 'active'
    and building_type_key = 'housing_2';

  select count(*) into v_housing_3_count
  from public.buildings
  where district_id = v_district.id and status = 'active'
    and building_type_key = 'housing_3';

  select exists(
    select 1 from public.buildings
    where district_id = v_district.id and status = 'active'
      and building_type_key = 'district_hall'
  ) into v_has_district_hall;

  select exists(
    select 1 from public.buildings
    where district_id = v_district.id and status = 'active'
      and building_type_key = 'civic_center_upgrade'
  ) into v_has_civic_center;

  select count(*) into v_total_buildings
  from public.buildings
  where district_id = v_district.id and status = 'active';

  -- Build requirements for next tier
  if v_current_tier = 1 then
    v_can_upgrade := v_has_district_hall and v_housing_2_count >= 3;
    v_requirements := jsonb_build_array(
      jsonb_build_object(
        'label', 'District Hall',
        'met', v_has_district_hall,
        'have', case when v_has_district_hall then 1 else 0 end,
        'need', 1
      ),
      jsonb_build_object(
        'label', 'Housing II',
        'met', v_housing_2_count >= 3,
        'have', v_housing_2_count,
        'need', 3
      )
    );
  elsif v_current_tier = 2 then
    v_can_upgrade := v_has_civic_center and v_housing_3_count >= 2;
    v_requirements := jsonb_build_array(
      jsonb_build_object(
        'label', 'Civic Center',
        'met', v_has_civic_center,
        'have', case when v_has_civic_center then 1 else 0 end,
        'need', 1
      ),
      jsonb_build_object(
        'label', 'Upper Housing',
        'met', v_housing_3_count >= 2,
        'have', v_housing_3_count,
        'need', 2
      )
    );
  else
    -- Tier 3 is max for v1
    v_requirements := '[]'::jsonb;
    v_can_upgrade := false;
  end if;

  return jsonb_build_object(
    'district_id', v_district.id,
    'district_name', v_district.name,
    'current_tier', v_current_tier,
    'next_tier', case when v_current_tier < 3 then v_next_tier else null end,
    'can_upgrade', v_can_upgrade,
    'requirements', v_requirements,
    'building_counts', jsonb_build_object(
      'housing_1', v_housing_1_count,
      'housing_2', v_housing_2_count,
      'housing_3', v_housing_3_count,
      'total', v_total_buildings,
      'has_district_hall', v_has_district_hall,
      'has_civic_center', v_has_civic_center
    )
  );
end;
$$;

grant execute on function public.get_district_progress() to authenticated;


-- ── 3. upgrade_district ─────────────────────────────────
create or replace function public.upgrade_district()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_player_id uuid;
  v_district record;
  v_progress jsonb;
  v_can_upgrade boolean;
  v_new_tier integer;
begin
  v_player_id := auth.uid();
  if v_player_id is null then
    raise exception 'Not authenticated';
  end if;

  -- Use get_district_progress to check conditions
  v_progress := public.get_district_progress();
  v_can_upgrade := (v_progress->>'can_upgrade')::boolean;

  if not v_can_upgrade then
    raise exception 'District tier-up requirements not met';
  end if;

  v_new_tier := (v_progress->>'next_tier')::integer;
  if v_new_tier is null then
    raise exception 'District is already at maximum tier';
  end if;

  -- Get the district
  select * into v_district
  from public.districts
  where owner_player_id = v_player_id and status = 'active'
  limit 1;

  -- Upgrade the district tier
  update public.districts
  set tier = v_new_tier
  where id = v_district.id;

  return jsonb_build_object(
    'success', true,
    'district_id', v_district.id,
    'previous_tier', v_district.tier,
    'new_tier', v_new_tier
  );
end;
$$;

grant execute on function public.upgrade_district() to authenticated;
