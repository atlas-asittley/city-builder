# Supabase Schema Plan — V1 Multiplayer City Builder

## Purpose
This document defines the recommended Supabase/Postgres shape for v1.

The goal is not to model every dream feature yet. The goal is to support the first real playable loop:

**auth -> profile -> world access -> building placement -> production -> persistence -> trade -> return later**

---

## V1 Architecture Assumptions
- Supabase Auth handles login and signup
- Postgres stores persistent game state
- Realtime is used for subscriptions to world/district/building changes where useful
- Important mutations should move toward controlled server-side execution
- Mobile browser client is the main UI

---

## Core V1 Product Choice
For v1, use a **shared world with player-owned districts/plots**.

Why:
- keeps the multiplayer identity
- avoids total shared-map chaos
- is much easier to secure and reason about than free-for-all placement everywhere

So the schema should support:
- one or more worlds
- districts/plots inside a world
- each district owned by one player
- buildings and tiles associated with a district/world

---

## Main Entities

### Identity
- `auth.users` (managed by Supabase)
- `player_profiles`

### World state
- `worlds`
- `districts`
- `tiles`
- `buildings`

### Economy / simulation
- `resource_types`
- `player_inventories`
- `building_storage`
- `production_jobs` or production-state fields on buildings
- `player_treasuries`
- `population_state`

### Multiplayer systems
- `trade_offers`
- `trade_transactions`
- `player_notifications`
- `player_presence` (optional / later)

### Progression
- `player_specializations`
- `research_progress` (later in v1 or v1.1)

---

## Table Plan

## 1) player_profiles
One row per authenticated player.

```sql
create table public.player_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  display_name text,
  specialization_key text,
  home_world_id uuid,
  home_district_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

### Notes
- `specialization_key` might be `timber`, `stone`, `grain`, etc.
- Store a copy of email only if useful for app UI/admin convenience
- `home_world_id` and `home_district_id` should be nullable until onboarding completes

---

## 2) worlds
Represents a shared game world.

```sql
create table public.worlds (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  status text not null default 'active',
  width integer not null,
  height integer not null,
  tick_version integer not null default 1,
  created_at timestamptz not null default now()
);
```

### Notes
- Start with one active world if desired
- `status` could later support `active`, `archived`, `maintenance`

---

## 3) districts
A player-owned zone within a world.

```sql
create table public.districts (
  id uuid primary key default gen_random_uuid(),
  world_id uuid not null references public.worlds(id) on delete cascade,
  owner_player_id uuid unique references public.player_profiles(id) on delete set null,
  name text,
  origin_x integer not null,
  origin_y integer not null,
  width integer not null,
  height integer not null,
  status text not null default 'active',
  created_at timestamptz not null default now()
);
```

### Notes
- V1 can reserve rectangular plots
- `owner_player_id unique` enforces one primary district per player for now
- If later you want multiple districts per player, remove the uniqueness

---

## 4) resource_types
Lookup table so the game is data-driven.

```sql
create table public.resource_types (
  key text primary key,
  name text not null,
  category text not null,
  base_value numeric not null default 0,
  is_active boolean not null default true
);
```

### Example rows
- `timber`
- `stone`
- `grain`
- `wood_planks`
- `masonry`
- `flour`

---

## 5) tiles
Persistent map tiles.

```sql
create table public.tiles (
  id bigint generated always as identity primary key,
  world_id uuid not null references public.worlds(id) on delete cascade,
  district_id uuid references public.districts(id) on delete set null,
  x integer not null,
  y integer not null,
  terrain_key text not null,
  resource_key text references public.resource_types(key),
  is_revealed boolean not null default true,
  is_buildable boolean not null default true,
  owner_player_id uuid references public.player_profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (world_id, x, y)
);
```

### Notes
- `owner_player_id` can help simplify policy checks
- `district_id` groups tiles by district
- Do not store transient UI-only values here

---

## 6) building_types
Data table for building definitions.

```sql
create table public.building_types (
  key text primary key,
  name text not null,
  category text not null,
  footprint_w integer not null default 1,
  footprint_h integer not null default 1,
  cost_gold integer not null,
  maintenance_gold integer not null default 0,
  required_resource_key text references public.resource_types(key),
  output_resource_key text references public.resource_types(key),
  build_rules jsonb not null default '{}'::jsonb,
  is_active boolean not null default true
);
```

### Why this matters
This keeps rules out of hardcoded client-only constants long-term.

---

## 7) buildings
Actual placed buildings.

```sql
create table public.buildings (
  id uuid primary key default gen_random_uuid(),
  world_id uuid not null references public.worlds(id) on delete cascade,
  district_id uuid references public.districts(id) on delete set null,
  owner_player_id uuid not null references public.player_profiles(id) on delete cascade,
  building_type_key text not null references public.building_types(key),
  anchor_x integer not null,
  anchor_y integer not null,
  level integer not null default 1,
  status text not null default 'active',
  workers_assigned integer not null default 0,
  production_progress numeric not null default 0,
  last_tick_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

### Notes
- `anchor_x/anchor_y` is the origin tile for footprint placement
- `production_progress` supports offline catch-up
- `last_tick_at` helps compute production since last simulation pass

---

## 8) player_treasuries
Separate finance table keeps money logic cleaner.

```sql
create table public.player_treasuries (
  player_id uuid primary key references public.player_profiles(id) on delete cascade,
  gold integer not null default 500,
  income_per_tick integer not null default 0,
  expenses_per_tick integer not null default 0,
  updated_at timestamptz not null default now()
);
```

---

## 9) player_inventories
One row per player/resource pair.

```sql
create table public.player_inventories (
  player_id uuid not null references public.player_profiles(id) on delete cascade,
  resource_key text not null references public.resource_types(key),
  amount numeric not null default 0,
  capacity numeric,
  updated_at timestamptz not null default now(),
  primary key (player_id, resource_key)
);
```

### Why not a jsonb blob?
Because relational rows are easier to query, validate, aggregate, and trade against.

---

## 10) population_state
Simple per-player district population summary for v1.

```sql
create table public.population_state (
  player_id uuid primary key references public.player_profiles(id) on delete cascade,
  district_id uuid references public.districts(id) on delete cascade,
  total_population integer not null default 0,
  housed_population integer not null default 0,
  employed_population integer not null default 0,
  unhoused_population integer not null default 0,
  happiness numeric not null default 50,
  updated_at timestamptz not null default now()
);
```

### Notes
- Start aggregated
- Individual simulated citizens can wait until much later, if ever

---

## 11) trade_offers
For player-to-player trade.

```sql
create table public.trade_offers (
  id uuid primary key default gen_random_uuid(),
  world_id uuid not null references public.worlds(id) on delete cascade,
  from_player_id uuid not null references public.player_profiles(id) on delete cascade,
  to_player_id uuid references public.player_profiles(id) on delete cascade,
  offer_resource_key text not null references public.resource_types(key),
  offer_amount numeric not null,
  want_resource_key text references public.resource_types(key),
  want_amount numeric,
  ask_gold integer,
  status text not null default 'open',
  created_at timestamptz not null default now(),
  expires_at timestamptz
);
```

### Notes
- Supports open market or direct player offers
- `status`: `open`, `accepted`, `cancelled`, `expired`, `rejected`

---

## 12) trade_transactions
Audit log of accepted trades.

```sql
create table public.trade_transactions (
  id uuid primary key default gen_random_uuid(),
  trade_offer_id uuid references public.trade_offers(id) on delete set null,
  seller_player_id uuid not null references public.player_profiles(id) on delete cascade,
  buyer_player_id uuid not null references public.player_profiles(id) on delete cascade,
  resource_key text not null references public.resource_types(key),
  amount numeric not null,
  gold_total integer,
  created_at timestamptz not null default now()
);
```

---

## 13) player_notifications
Lightweight in-game inbox for async events.

```sql
create table public.player_notifications (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.player_profiles(id) on delete cascade,
  kind text not null,
  title text not null,
  body text,
  payload jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now()
);
```

### Use cases
- trade accepted
- district assigned
- building finished
- not enough workers
- storage full

---

## Relationships Summary
- `auth.users -> player_profiles`
- `worlds -> districts -> tiles/buildings`
- `player_profiles -> player_treasuries / player_inventories / population_state`
- `player_profiles -> districts` (ownership)
- `buildings -> building_types`
- `tiles/buildings/inventories/trades` all reference shared `resource_types`

---

## Row-Level Security Direction
RLS matters here. Otherwise this becomes a cheating simulator.

## Player-owned tables
Players should only be able to directly read/write their own rows for:
- `player_profiles` (own row)
- `player_treasuries` (own row, likely read-only to client in practice)
- `player_inventories` (own rows, ideally server-controlled writes)
- `population_state` (own row, mostly read-only)
- `player_notifications` (own rows)

## Shared world tables
Players can read shared world state for relevant world/district data:
- `worlds`
- `districts`
- `tiles`
- `buildings`
- `building_types`
- `resource_types`

But write access should be heavily constrained.

## Recommendation
For important state changes, do **not** let the client freely `insert/update/delete` shared tables.
Use either:
- Postgres functions / RPC
- Edge Functions
- tightly controlled policies for narrowly safe inserts

---

## Mutation Strategy

### Good candidates for controlled server-side mutation
- claim district
- place building
- demolish building
- spend gold
- accept trade
- run production tick catch-up
- assign specialization

### Why
These all affect competitive or persistent state.
If the browser can freely spoof them, the game is dead on arrival.

---

## Realtime Strategy
Use Realtime selectively.

### Good realtime subscriptions for v1
- buildings in a world/district
- trade offers in a world
- player notifications for current user
- district ownership changes

### Avoid realtime overkill
Do not stream every simulation micro-change if polling or on-demand refresh is enough.

---

## Minimal Seed Data Needed
At minimum, seed:
- 1 world
- starting districts/plots
- resource types
- building types
- initial tile map with terrain/resources

---

## First Migration Set
Recommended first migration order:
1. `resource_types`
2. `building_types`
3. `worlds`
4. `districts`
5. `player_profiles`
6. `tiles`
7. `buildings`
8. `player_treasuries`
9. `player_inventories`
10. `population_state`
11. `trade_offers`
12. `trade_transactions`
13. `player_notifications`

---

## V1 Simplifications to Keep
To avoid self-sabotage, keep these simplifications:
- one world
- one district per player
- aggregated population instead of individual citizens
- three starting resources
- limited building catalog
- simple trade model
- async simulation rather than high-frequency lockstep realtime

---

## Immediate Next Step After This Doc
Create:
1. SQL migration draft
2. RLS policy draft
3. frontend implementation roadmap for auth -> onboarding -> map -> place building
