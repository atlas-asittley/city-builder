-- 0002_onboarding_rpc.sql
-- Server-side RPC for player onboarding bootstrap
-- Creates player_profile, treasury, inventory rows, and population_state atomically.

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
  v_email text;
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

  -- Validate specialization is a raw resource
  if p_specialization_key not in ('timber', 'stone', 'grain') then
    raise exception 'Invalid specialization. Must be timber, stone, or grain.';
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

  -- Upsert player profile
  insert into public.player_profiles (id, email, display_name, specialization_key, home_world_id)
  values (v_player_id, v_email, trim(p_display_name), p_specialization_key, v_world_id)
  on conflict (id) do update set
    display_name = trim(p_display_name),
    specialization_key = p_specialization_key,
    home_world_id = v_world_id;

  -- Create treasury (500 starting gold)
  insert into public.player_treasuries (player_id, gold, income_per_tick, expenses_per_tick)
  values (v_player_id, 500, 0, 0)
  on conflict (player_id) do nothing;

  -- Create inventory rows for all raw resources (start at 0)
  insert into public.player_inventories (player_id, resource_key, amount)
  values
    (v_player_id, 'timber', 0),
    (v_player_id, 'stone', 0),
    (v_player_id, 'grain', 0)
  on conflict (player_id, resource_key) do nothing;

  -- Create population state
  insert into public.population_state (player_id, total_population, housed_population, employed_population, unhoused_population, happiness)
  values (v_player_id, 0, 0, 0, 0, 50)
  on conflict (player_id) do nothing;

  return jsonb_build_object(
    'success', true,
    'player_id', v_player_id,
    'display_name', trim(p_display_name),
    'specialization', p_specialization_key,
    'world_id', v_world_id
  );
end;
$$;

-- Allow authenticated users to call this function
grant execute on function public.complete_onboarding(text, text) to authenticated;

-- Basic RLS policies needed for onboarding flow
-- Players can read their own profile
create policy if not exists "Players can read own profile"
  on public.player_profiles for select
  using (id = auth.uid());

-- Players can read their own treasury
create policy if not exists "Players can read own treasury"
  on public.player_treasuries for select
  using (player_id = auth.uid());

-- Players can read their own inventory
create policy if not exists "Players can read own inventory"
  on public.player_inventories for select
  using (player_id = auth.uid());

-- Players can read their own population state
create policy if not exists "Players can read own population"
  on public.population_state for select
  using (player_id = auth.uid());

-- Enable RLS on tables (idempotent-safe with if not exists on policies)
alter table public.player_profiles enable row level security;
alter table public.player_treasuries enable row level security;
alter table public.player_inventories enable row level security;
alter table public.population_state enable row level security;
