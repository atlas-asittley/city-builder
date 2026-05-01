# V1 Building Set

## Purpose
This document defines the first buildable set of buildings for v1, based on the goods economy in `V1_GOODS_AND_DEPENDENCY_GRAPH.md`.

The goal is to create a city-builder that already feels like a system, without trying to ship the whole dream on day one.

---

## Design Principles
The v1 building set should:
- support the 15-good economy cleanly
- make specialization visible on the map
- create natural reasons to trade
- include enough non-production pressure that the game feels like a city builder, not just a factory list
- stay small enough to implement and balance

---

## V1 Building Categories
For v1, use 7 categories:

1. **Infrastructure**
2. **Housing**
3. **Extraction**
4. **Refining**
5. **Production**
6. **Storage & Trade**
7. **Civic / District Progression**

---

## 1. Infrastructure
These make the district function physically.

### Road
**Role:** foundational placement/pathing infrastructure
- Category: infrastructure
- Output: none directly
- Purpose: connects buildings, supports movement/logistics rules later
- Notes: should be cheap and common

### Paved Road Upgrade (later-v1 or v1.1)
**Role:** improved logistics / prestige road tier
- Category: infrastructure
- Requires: Wood Planks, Cut Stone
- Notes: optional to delay if base roads are enough for v1

---

## 2. Housing
Housing creates population pressure and a reason to care about non-production goods.

It also needs to be **visually legible and satisfying**.
Players should not just see a housing number go up. They should see homes and neighborhoods change on the map as conditions improve.

### Housing I
**Role:** basic worker shelter
- Category: housing
- Inputs to build: Wood Planks
- Supports: population cap increase
- Notes: first housing tier should be simple and cheap

### Housing II
**Role:** improved housing
- Category: housing
- Inputs to upgrade/build: Wood Planks, Bricks
- Supports: more residents, better district quality
- Notes: first meaningful development step for population
- Visual expectation: homes should visibly upgrade from basic dwellings into more established neighborhood structures

### Upper Housing / Housing III
**Role:** higher-quality housing
- Category: housing
- Inputs: Furniture, Pottery, Bread
- Supports: higher population quality / prestige / desirability-style pressure
- Notes: this is where non-construction goods start to matter visibly
- Visual expectation: this tier should feel noticeably more prosperous on the map, not just numerically better

---

## 3. Extraction Buildings
These define player specialization identity early.

### Lumber Camp
- Produces: Timber
- Specialization lane: Timber
- Build requirement: road access + valid timber tile/zone

### Quarry
- Produces: Stone
- Specialization lane: Stone
- Build requirement: road access + valid stone tile/zone

### Grain Farm
- Produces: Grain
- Specialization lane: Grain
- Build requirement: road access + valid fertile tile/zone

### Clay Pit
- Produces: Clay
- Specialization lane: Clay
- Build requirement: road access + valid clay tile/zone

### Iron Mine
- Produces: Iron Ore
- Specialization lane: Iron
- Build requirement: road access + valid iron tile/zone

### Extraction building rule
All extraction buildings should:
- be easy to understand
- establish early identity
- produce one raw good clearly
- benefit from specialization bonuses

---

## 4. Refining Buildings
These convert raw goods into shared construction bottlenecks.

### Sawmill
- Consumes: Timber
- Produces: Wood Planks
- Why it matters: core construction dependency

### Mason Yard
- Consumes: Stone
- Produces: Cut Stone
- Why it matters: civic and mid-tier construction dependency

### Mill
- Consumes: Grain
- Produces: Flour
- Why it matters: food chain entry point

### Kiln Yard
- Consumes: Clay
- Produces: Bricks
- Why it matters: housing and civic construction dependency

### Smelter
- Consumes: Iron Ore
- Produces: Iron Bars
- Why it matters: industrial and trade infrastructure dependency

### Refining building rule
Refining buildings should be the first place the player starts feeling the shared economy.
Even if they can refine their own lane, they should quickly want other refined goods from elsewhere.

---

## 5. Production Buildings
These turn refined goods into quality-of-life, utility, or prestige goods.

### Carpentry Works
- Consumes: Wood Planks
- Produces: Furniture
- Why it matters: higher housing and district development

### Bakery
- Consumes: Flour
- Produces: Bread
- Why it matters: population growth and worker stability

### Pottery Works
- Consumes: Clay or Bricks (final tuning later)
- Produces: Pottery
- Why it matters: household quality, market/civic progression

### Forge Works
- Consumes: Iron Bars
- Produces: Tools
- Why it matters: production efficiency and advanced upgrades

### Artisan Studio / Monument Works
- Consumes: Cut Stone plus selected supporting goods
- Produces: Fine Goods
- Why it matters: prestige, exports, advanced district milestones
- Note: keep this slightly abstract for v1 so the luxury layer can evolve later

---

## 6. Storage & Trade Buildings
These are crucial because the economy should not just be production without movement or exchange.

### Warehouse
**Role:** storage expansion
- Inputs to build: Wood Planks, Bricks
- Function: increases inventory capacity
- Why it matters: makes accumulation and trade possible

### Market
**Role:** local distribution / household support
- Inputs to build: Wood Planks, Pottery
- Function: supports housing quality or district service coverage
- Why it matters: ties economy to city-living conditions

### Trade Depot
**Role:** player trade + external-city trade anchor
- Inputs to build: Cut Stone, Iron Bars, Pottery
- Function:
  - enables or improves trade throughput
  - interfaces with outside-city trade routes
  - may increase buy/sell slots or trade capacity
- Why it matters: this is the multiplayer economy made visible on the map

### Granary (optional for v1, strong candidate for v1.1)
**Role:** food storage/distribution
- Inputs to build: Bricks, Wood Planks
- Function: supports larger food economy and population buffering
- Why it matters: very Pharaoh-feeling, but can be delayed if Warehouse + Bread logic is enough initially

---

## 7. Civic / District Progression Buildings
These stop the game from feeling like pure industry and give medium-term goals.

### District Hall
**Role:** district administration / progression anchor
- Inputs to build/upgrade: Cut Stone, Furniture
- Function:
  - tracks district tier
  - may gate certain advanced buildings
  - gives a visible development center
- Why it matters: creates a sense of city progression, not just production sprawl

### Civic Center Upgrade / Town Hall Upgrade
**Role:** mid-tier district milestone
- Inputs: Cut Stone, Furniture, Fine Goods
- Function: unlocks stronger district development or new building caps
- Why it matters: gives prestige goods a real non-export purpose

### Shrine / Plaza (optional, later-v1)
**Role:** desirability / prestige / civic identity
- Inputs: Bricks, Pottery, Fine Goods (tuning later)
- Function: district quality boost, happiness-style system hook
- Why it matters: opens the Pharaoh-like city feel without requiring full religious/service walker complexity yet

---

## Minimal First Implementation Set
If we want the smallest truly playable city-builder slice, start with these:

### Must-have
- Road
- Housing I
- Lumber Camp
- Quarry
- Grain Farm
- Clay Pit
- Iron Mine
- Sawmill
- Mason Yard
- Mill
- Kiln Yard
- Smelter
- Bakery
- Pottery Works
- Forge Works
- Warehouse
- Trade Depot
- District Hall

### Strong next additions
- Housing II
- Carpentry Works
- Artisan Studio / Monument Works
- Market

### Later-v1 / v1.1
- Upper Housing
- Granary
- Plaza / Shrine
- Paved Road Upgrade
- Civic Center Upgrade

---

## Why This Set Works
This building set works because it gives us:

### Early game
- identity through extraction
- obvious placement decisions
- simple first expansion

### Mid game
- refining chains
- storage pressure
- trade pressure
- population support needs

### Late-v1 game
- prestige/development goals
- district progression
- stronger reasons to import/export

And importantly, it still feels like a city, not just an abstract factory graph.

---

## Example Dependency Flow
A plausible early/mid-v1 district might work like this:

1. Build roads
2. Place extraction building in your specialization lane
3. Refine your raw material
4. Build housing for workers
5. Trade for missing construction or food goods
6. Build warehouse and trade depot
7. Add utility/production building
8. Upgrade housing / district hall
9. Start producing or importing prestige goods

That is a real city-builder loop.

---

## Building Design Guardrails
As implementation starts, keep these rules:

### 1. Every building should have a clear economic or civic job
No filler buildings.

### 2. Not every building needs unique simulation complexity immediately
Fake depth is better than broken overcomplexity early.

### 3. Trade-facing buildings should be visible and important
If trade is central, it should exist physically on the map.

### 4. Housing should consume the results of the economy
Otherwise citizens are just a number with no bite.

### 5. Housing should visibly evolve on the map
If homes do not visually change, we lose a big part of the emotional payoff.

### 6. District progression buildings should create medium-term goals
Otherwise the game becomes infinite raw throughput with no shape.

---

## Recommended Next Step After This Doc
After this, the best follow-up is:
1. map these buildings into `building_types` seed data
2. define which ones are available at game start vs unlocked later
3. define the first district advancement requirements

That will turn the design into directly implementable data.
