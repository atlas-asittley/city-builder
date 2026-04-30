-- 0006_production_tick.sql
-- Phase 6: Server-authoritative production tick.
--
-- Adds run_production_tick() RPC that processes all active buildings
-- for the calling player. Each building with an output_resource_key
-- produces goods over time:
--
--   Extraction buildings: produce 1 unit per tick (no input consumed)
--   Refining/production buildings: consume inputs, produce 1 unit per tick
--
-- Tick gating:
--   - Minimum 60 seconds between ticks per player
--   - Offline catch-up: calculates elapsed ticks since last_tick_at
--   - Max catch-up capped at 60 ticks (~1 hour) to prevent abuse
--
-- Each tick = 1 production cycle per building.
-- Tick interval = 60 seconds.

create or replace function public.run_production_tick()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_player_id uuid;
  v_now timestamptz;
  v_tick_interval_sec integer := 60;   -- seconds per tick
  v_max_catchup_ticks integer := 60;   -- cap offline catch-up
  v_building record;
  v_bt record;
  v_consumes jsonb;
  v_input_key text;
  v_input_amount integer;
  v_have_amount numeric;
  v_ticks_earned integer;
  v_produced integer;
  v_consumed_summary jsonb := '[]'::jsonb;
  v_produced_summary jsonb := '[]'::jsonb;
  v_total_buildings integer := 0;
  v_total_produced integer := 0;
  v_total_starved integer := 0;
  v_oldest_tick timestamptz;
  v_can_produce boolean;
  v_output_key text;
  v_cycles integer;
begin
  v_player_id := auth.uid();
  if v_player_id is null then
    raise exception 'Not authenticated';
  end if;

  v_now := now();

  -- Process each active building that has production output
  for v_building in
    select b.id, b.building_type_key, b.last_tick_at, b.status,
           bt.output_resource_key, bt.required_resource_key, bt.category,
           bt.build_rules, bt.name as building_name
    from public.buildings b
    join public.building_types bt on bt.key = b.building_type_key
    where b.owner_player_id = v_player_id
      and b.status = 'active'
      and bt.output_resource_key is not null
    order by b.created_at
  loop
    v_total_buildings := v_total_buildings + 1;
    v_output_key := v_building.output_resource_key;

    -- Calculate how many ticks this building has earned
    if v_building.last_tick_at is null then
      -- First tick: grant 1 cycle
      v_ticks_earned := 1;
    else
      v_ticks_earned := floor(extract(epoch from (v_now - v_building.last_tick_at)) / v_tick_interval_sec)::integer;
    end if;

    -- Cap catch-up ticks
    if v_ticks_earned > v_max_catchup_ticks then
      v_ticks_earned := v_max_catchup_ticks;
    end if;

    -- Skip if no ticks earned yet
    if v_ticks_earned < 1 then
      continue;
    end if;

    -- Determine input requirements from build_rules.consumes
    v_consumes := coalesce(v_building.build_rules->'consumes', '{}'::jsonb);

    -- Run production cycles
    v_cycles := 0;
    for i in 1..v_ticks_earned loop
      v_can_produce := true;

      -- Check and deduct all inputs for this cycle
      if v_consumes != '{}'::jsonb then
        -- First pass: check all inputs are available
        for v_input_key in select jsonb_object_keys(v_consumes) loop
          v_input_amount := (v_consumes->>v_input_key)::integer;
          if v_input_amount is null or v_input_amount <= 0 then
            continue;
          end if;

          select amount into v_have_amount
          from public.player_inventories
          where player_id = v_player_id and resource_key = v_input_key;

          if v_have_amount is null or v_have_amount < v_input_amount then
            v_can_produce := false;
            exit; -- break out of input check loop
          end if;
        end loop;

        -- Second pass: deduct inputs if all available
        if v_can_produce then
          for v_input_key in select jsonb_object_keys(v_consumes) loop
            v_input_amount := (v_consumes->>v_input_key)::integer;
            if v_input_amount is null or v_input_amount <= 0 then
              continue;
            end if;

            update public.player_inventories
            set amount = amount - v_input_amount,
                updated_at = v_now
            where player_id = v_player_id and resource_key = v_input_key;
          end loop;
        end if;
      end if;

      -- If we can produce, add output
      if v_can_produce then
        update public.player_inventories
        set amount = amount + 1,
            updated_at = v_now
        where player_id = v_player_id and resource_key = v_output_key;

        -- If no inventory row exists, insert one
        if not found then
          insert into public.player_inventories (player_id, resource_key, amount, updated_at)
          values (v_player_id, v_output_key, 1, v_now)
          on conflict (player_id, resource_key) do update
          set amount = player_inventories.amount + 1, updated_at = v_now;
        end if;

        v_cycles := v_cycles + 1;
      else
        -- Starved: stop producing for this building this tick
        v_total_starved := v_total_starved + 1;
        exit; -- stop trying more cycles for this building
      end if;
    end loop;

    -- Update last_tick_at on the building
    update public.buildings
    set last_tick_at = v_now,
        production_progress = v_cycles,
        updated_at = v_now
    where id = v_building.id;

    -- Track summary
    if v_cycles > 0 then
      v_total_produced := v_total_produced + v_cycles;
      v_produced_summary := v_produced_summary || jsonb_build_array(
        jsonb_build_object(
          'building', v_building.building_name,
          'building_id', v_building.id,
          'output', v_output_key,
          'amount', v_cycles,
          'ticks_available', v_ticks_earned
        )
      );
    end if;
  end loop;

  -- Build updated inventory snapshot
  return jsonb_build_object(
    'success', true,
    'tick_time', v_now,
    'buildings_processed', v_total_buildings,
    'total_produced', v_total_produced,
    'buildings_starved', v_total_starved,
    'production', v_produced_summary,
    'inventory', (
      select coalesce(jsonb_object_agg(resource_key, amount), '{}'::jsonb)
      from public.player_inventories
      where player_id = v_player_id
    ),
    'gold', (
      select gold from public.player_treasuries where player_id = v_player_id
    )
  );
end;
$$;

grant execute on function public.run_production_tick() to authenticated;
