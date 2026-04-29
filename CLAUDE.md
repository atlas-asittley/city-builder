# City Builder - Supabase Multiplayer Tycoon Game

## Overview
Multiplayer city-building game (Pharaoh-style). Players specialize in one resource industry, build production chains, trade with each other and NPC partners via gifting. Game runs real-time with no win condition.

## Supabase Config
- URL: https://igaulapupbtdcqqjobhs.supabase.co
- Anon key: sb_publishable_7yi3BNg-J-K5nralw5JSww_c71Pge6e
- Service role key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlnYXVsYXB1cGJ0ZGNxcWpvYmhzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NTY5MDA0OSwiZXhwIjoyMDkxMjY2MDQ5fQ.cBHD9DoLabwssZO--Inu72j2dtqBDWm43iBoRfJyh1E

## Full Spec
Read CITY_BUILDER_SPEC.md in the workspace root for complete details.

## Phase 1: Build MVP First

Build the smallest working version that demonstrates the core loop. We'll iterate after.

### MVP Features

1. **Auth** — use existing Supabase auth (email/password). Show landing page with login/register.

2. **Industry Selection** — on first login, choose one resource: Clay, Timber, Stone, Iron, or Corn.

3. **Basic Map** — 15x15 grid. Show city center. Show resource tiles. Fog on edges.

4. **4 Building Types (one per resource type)**:
   - Extraction building (Tier 1): costs $100, produces raw resource
   - Place by clicking a resource tile

5. **Citizens** — simple population display. Grows based on having jobs (buildings).

6. **Budget** — show player's money. Start with $500.

7. **Trade UI** — show 4 NPC partners with relationship bars. Configure what to sell/buy. Give gift button.

8. **Production** — buildings produce goods over time. Show inventory counts.

### Technical Stack
- Vanilla HTML/CSS/JS frontend
- Single HTML file for MVP
- Supabase JS client for auth and data

### Supabase Tables Needed

```sql
-- Player state
create table players (
  id uuid references auth.users primary key,
  email text,
  industry text not null,
  budget numeric default 500,
  created_at timestamptz default now()
);

-- City map tiles
create table tiles (
  id serial primary key,
  x int not null,
  y int not null,
  resource text,
  fog boolean default true,
  building_id uuid,
  unique(x,y)
);

-- Buildings
create table buildings (
  id uuid primary key default gen_random_uuid(),
  player_id uuid references players(id),
  type text not null, -- 'extraction', 'processing', etc.
  tier int default 1,
  tile_id int references tiles(id),
  resource text, -- what it produces
  created_at timestamptz default now()
);

-- Inventory
create table inventory (
  player_id uuid references players(id) primary key,
  resources jsonb default '{}' -- {"clay": 0, "timber": 0, etc.}
);

-- Trade partner relationships
create table trade_relationships (
  player_id uuid references players(id),
  partner text not null, -- 'river_traders', 'desert_caravan', etc.
  relationship int default 50,
  primary key (player_id, partner)
);
```

### MVP Layout

```
+------------------------------------------+
|  [Logo] City Builder    [Budget] [Logout] |
+------------------------------------------+
|  Industry: Clay        Population: 12     |
+------------------------------------------+
|                                          |
|           [MAP GRID 15x15]               |
|        (click tiles to build)           |
|                                          |
+------------------------------------------+
|  INVENTORY          |  TRADE PARTNERS    |
|  Clay: 5            |  [River Traders]   |
|  Processed Clay: 2  |  [Desert Caravan]  |
|                     |  [Mountain Folk]   |
|  BUILDINGS          |  [Coastal Merch]   |
|  [Clay Pit] $100     |                    |
+------------------------------------------+
```

### Implementation Notes
- Use Supabase auth.onAuthStateChange for session management
- Game loop runs on setInterval (every 1 second for MVP)
- Buildings produce resources automatically over time
- Citizens grow when employment > 0
- Map tiles generated procedurally with random resources

### Deploy
- Build to this directory: /home/atlas/.openclaw/workspace/projects/site/city-builder/
- Link from main index.html
- Push to git@github.com:atlas-asittley/atlas-asittley.github.io.git

### Git SSH
GIT_SSH_COMMAND="ssh -i ~/.ssh/id_ed25519_atlas"

Start with auth, then map, then buildings, then trade. Simple first.
