# RLS Policy Draft — Multiplayer City Builder V1

## Purpose
This document defines the first-pass Row Level Security strategy for the Supabase backend.

The big rule:

**Clients should be able to read what they need, but should not be trusted to directly mutate important shared game state.**

If we get lazy here, we are basically building a cheating UI.

---

## Security Posture

### Client can safely do
- authenticate
- read shared world data
- read their own profile/state
- create a very small number of low-risk self-owned records where explicitly allowed

### Client should not freely do
- spend gold by updating treasury directly
- place or delete buildings directly in shared tables
- modify tile ownership freely
- grant themselves inventory/resources
- accept trades by editing records directly

### Preferred mutation pattern
Use one of:
- SQL RPC functions
- Supabase Edge Functions
- server-side actions with service role

The browser should request actions. It should not authoritatively decide outcomes.

---

## Table-by-Table Policy Direction

## 1) player_profiles

### Read
- authenticated users can read their own profile
- optionally authenticated users can read limited public profile fields for other players later

### Write
- users can insert their own row on first login
- users can update limited fields on their own row (`display_name`, maybe `specialization_key` during onboarding)
- users cannot update another player’s row

### Draft policy shape
- `select`: `auth.uid() = id`
- `insert`: `auth.uid() = id`
- `update`: `auth.uid() = id`

### Caveat
If specialization assignment becomes part of a controlled onboarding function, remove direct client update access for that field.

---

## 2) worlds

### Read
- authenticated users can read active worlds

### Write
- no client write access
- admin/service role only

### Draft policy shape
- `select`: authenticated and `status = 'active'`
- no insert/update/delete for normal clients

---

## 3) districts

### Read
- authenticated users can read districts in active worlds

### Write
- no direct client writes for ownership assignment
- district claiming should happen through a controlled function

### Draft policy shape
- `select`: authenticated
- no client insert/update/delete

### Why
Direct district writes would let players steal land.

---

## 4) tiles

### Read
- authenticated users can read world tiles relevant to gameplay

### Write
- no direct client writes

### Draft policy shape
- `select`: authenticated
- no client insert/update/delete

### Why
Tile ownership/buildability/resource changes are game-authoritative state.

---

## 5) building_types

### Read
- anyone authenticated can read

### Write
- admin/service role only

### Draft policy shape
- `select`: authenticated
- no client insert/update/delete

---

## 6) buildings

### Read
- authenticated users can read buildings in accessible worlds/districts

### Write
- no raw client insert/update/delete
- building placement/demolition should go through RPC or Edge Function

### Draft policy shape
- `select`: authenticated
- no direct client insert/update/delete

### Why
If clients can insert buildings directly, they can bypass cost, placement, and ownership rules.

---

## 7) player_treasuries

### Read
- player can read own treasury

### Write
- no direct client update
- treasury changes should be produced by controlled game actions

### Draft policy shape
- `select`: `auth.uid() = player_id`
- no direct insert/update/delete for clients

### Why
Otherwise a client can just give itself infinite money.

---

## 8) player_inventories

### Read
- player can read own inventory
- maybe partial public visibility later if market UI needs it

### Write
- no direct client update
- inventory changes should come from production/trade/build actions via controlled server-side logic

### Draft policy shape
- `select`: `auth.uid() = player_id`
- no direct insert/update/delete for clients

### Why
Otherwise the player can mint resources at will.

---

## 9) population_state

### Read
- player can read own population state

### Write
- no direct client update

### Draft policy shape
- `select`: `auth.uid() = player_id`
- no direct insert/update/delete for clients

---

## 10) trade_offers

### Read
- authenticated users can read open offers in their world
- authenticated users can read offers they created
- authenticated users can read offers directed to them

### Write
Two viable options:

#### Safer option (recommended)
- create offers through RPC/Edge Function only
- accept/cancel through RPC/Edge Function only

#### Simpler early option
- allow direct insert only if `from_player_id = auth.uid()`
- disallow direct status changes except maybe cancellation by creator
- accept trade through controlled function

### Recommendation
Use the safer option.

---

## 11) trade_transactions

### Read
- authenticated users can read transactions involving them
- maybe world market history later

### Write
- no client inserts
- only controlled trade acceptance flow writes these rows

### Draft policy shape
- `select`: `auth.uid() in (seller_player_id, buyer_player_id)`
- no insert/update/delete for clients

---

## 12) player_notifications

### Read
- player can read own notifications

### Write
- client should not create arbitrary notifications for other players
- service-side code creates notifications
- maybe allow a player to mark their own notifications as read

### Draft policy shape
- `select`: `auth.uid() = player_id`
- `update`: `auth.uid() = player_id` but only for read-state-safe fields
- no client insert/delete

---

## Recommended First Policy Implementation Strategy

### Step 1: Turn on RLS for all gameplay tables
Do this immediately so nothing is accidentally left wide open.

### Step 2: Allow read access where needed
Open read paths intentionally for:
- shared reference data
- world/district/building/tile viewing
- own player state

### Step 3: Keep direct writes extremely narrow
Initially, direct client writes should be limited to:
- create/update own profile (or even less)
- mark own notifications read

### Step 4: Use RPC/Edge Functions for gameplay mutations
Start with controlled actions for:
- onboarding/setup profile
- claim district
- place building
- demolish building
- create trade offer
- accept trade

---

## Recommended Early RPC / Function List
- `complete_onboarding(display_name, specialization_key)`
- `claim_starting_district(world_slug)`
- `place_building(building_type_key, x, y)`
- `demolish_building(building_id)`
- `create_trade_offer(...)`
- `accept_trade_offer(trade_offer_id)`
- `mark_notification_read(notification_id)`

These should validate:
- auth identity
- ownership
- resource/gold sufficiency
- map placement rules
- trade validity

---

## Example SQL Policy Skeletons
These are illustrative, not final.

```sql
alter table public.player_profiles enable row level security;
alter table public.player_treasuries enable row level security;
alter table public.player_inventories enable row level security;
alter table public.population_state enable row level security;
alter table public.player_notifications enable row level security;
alter table public.worlds enable row level security;
alter table public.districts enable row level security;
alter table public.tiles enable row level security;
alter table public.building_types enable row level security;
alter table public.buildings enable row level security;
alter table public.trade_offers enable row level security;
alter table public.trade_transactions enable row level security;

create policy "profiles_select_own"
on public.player_profiles
for select
using (auth.uid() = id);

create policy "profiles_insert_own"
on public.player_profiles
for insert
with check (auth.uid() = id);

create policy "profiles_update_own"
on public.player_profiles
for update
using (auth.uid() = id)
with check (auth.uid() = id);

create policy "treasury_select_own"
on public.player_treasuries
for select
using (auth.uid() = player_id);

create policy "inventory_select_own"
on public.player_inventories
for select
using (auth.uid() = player_id);

create policy "population_select_own"
on public.population_state
for select
using (auth.uid() = player_id);

create policy "notifications_select_own"
on public.player_notifications
for select
using (auth.uid() = player_id);

create policy "notifications_update_own"
on public.player_notifications
for update
using (auth.uid() = player_id)
with check (auth.uid() = player_id);

create policy "worlds_select_active"
on public.worlds
for select
to authenticated
using (status = 'active');

create policy "districts_select_authenticated"
on public.districts
for select
to authenticated
using (true);

create policy "tiles_select_authenticated"
on public.tiles
for select
to authenticated
using (true);

create policy "building_types_select_authenticated"
on public.building_types
for select
to authenticated
using (true);

create policy "buildings_select_authenticated"
on public.buildings
for select
to authenticated
using (true);

create policy "trade_offers_select_relevant"
on public.trade_offers
for select
to authenticated
using (
  from_player_id = auth.uid()
  or to_player_id = auth.uid()
  or (to_player_id is null and status = 'open')
);

create policy "trade_transactions_select_relevant"
on public.trade_transactions
for select
to authenticated
using (
  seller_player_id = auth.uid()
  or buyer_player_id = auth.uid()
);
```

---

## Final Recommendation
Be stricter than feels convenient.

The trap is always the same: during prototyping, direct client writes feel fast and harmless. Then later you realize the whole model assumes honest clients. That’s a rotten foundation.

So for this game:
- shared reads are fine
- sensitive writes go through controlled actions
- treasury/inventory/buildings should never be casually client-authoritative
