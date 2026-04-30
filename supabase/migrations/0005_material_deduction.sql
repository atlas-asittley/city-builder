-- 0005_material_deduction.sql
-- Phase 5: Server-side material deduction during building placement.
--
-- Changes:
--   1. Replaces place_building() to deduct material costs from
--      player_inventories alongside gold from player_treasuries.
--   2. Material costs are read from building_types.build_rules->'buildCosts'.
--   3. Returns materials_spent in the response for client sync.

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
  v_build_costs jsonb;
  v_gold_cost integer;
  v_required_tier integer;
  v_bx integer;
  v_by integer;
  v_tile record;
  v_building_id uuid;
  v_cost_key text;
  v_cost_amount integer;
  v_have_amount numeric;
  v_materials_spent jsonb := '{}'::jsonb;
  v_updated_inventory jsonb := '{}'::jsonb;
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
  v_build_costs := coalesce(v_build_rules->'buildCosts', '{}'::jsonb);

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

  -- ── Validate and deduct gold ──────────────────────────
  v_gold_cost := coalesce((v_build_costs->>'gold')::integer, v_bt.cost_gold);
  select gold into v_gold from public.player_treasuries where player_id = v_player_id;
  if v_gold is null or v_gold < v_gold_cost then
    raise exception 'Not enough gold. Need %, have %', v_gold_cost, coalesce(v_gold, 0);
  end if;

  update public.player_treasuries
  set gold = gold - v_gold_cost
  where player_id = v_player_id;

  -- ── Validate and deduct material costs ────────────────
  -- Iterate over every key in buildCosts that is not 'gold'.
  -- For each, check player_inventories has enough and deduct.
  for v_cost_key in select jsonb_object_keys(v_build_costs) loop
    if v_cost_key = 'gold' then
      continue;
    end if;

    v_cost_amount := (v_build_costs->>v_cost_key)::integer;
    if v_cost_amount is null or v_cost_amount <= 0 then
      continue;
    end if;

    -- Check inventory
    select amount into v_have_amount
    from public.player_inventories
    where player_id = v_player_id and resource_key = v_cost_key;

    if v_have_amount is null or v_have_amount < v_cost_amount then
      raise exception 'Not enough %. Need %, have %',
        v_cost_key, v_cost_amount, coalesce(v_have_amount, 0);
    end if;

    -- Deduct
    update public.player_inventories
    set amount = amount - v_cost_amount,
        updated_at = now()
    where player_id = v_player_id and resource_key = v_cost_key;

    -- Track what was spent for the response
    v_materials_spent := v_materials_spent || jsonb_build_object(v_cost_key, v_cost_amount);
  end loop;

  -- ── Insert building ───────────────────────────────────
  insert into public.buildings (world_id, district_id, owner_player_id, building_type_key, anchor_x, anchor_y, level, status)
  values (v_district.world_id, v_district.id, v_player_id, p_building_type_key, p_anchor_x, p_anchor_y, 1, 'active')
  returning id into v_building_id;

  -- ── Build updated inventory snapshot for response ─────
  select jsonb_object_agg(resource_key, amount)
  into v_updated_inventory
  from public.player_inventories
  where player_id = v_player_id;

  return jsonb_build_object(
    'success', true,
    'building_id', v_building_id,
    'building_type', p_building_type_key,
    'anchor_x', p_anchor_x,
    'anchor_y', p_anchor_y,
    'gold_spent', v_gold_cost,
    'gold_remaining', v_gold - v_gold_cost,
    'materials_spent', v_materials_spent,
    'inventory', coalesce(v_updated_inventory, '{}'::jsonb)
  );
end;
$$;

grant execute on function public.place_building(text, integer, integer) to authenticated;
