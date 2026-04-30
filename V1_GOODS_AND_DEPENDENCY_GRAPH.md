# V1 Goods and Dependency Graph

## Purpose
This document defines the first playable goods economy for v1.

The goal is not to model the full long-term dream yet.
The goal is to create a small but real supply-chain web that proves:
- specialization
- interdependence
- player trade
- external-city trade
- meaningful progression bottlenecks

---

## Design Goal
V1 should feel like:
- you can produce meaningful things yourself
- you cannot efficiently cover the whole economy alone
- you regularly want goods from other players or outside cities
- buildings and upgrades pull from a shared economic language

---

## V1 Size Recommendation
Use **15 goods** for v1.

That is enough to create real dependencies without turning the game into unreadable spreadsheet soup.

---

## V1 Goods Catalog

## A. Raw Goods
These are the basic extracted materials.

1. **Timber**
2. **Stone**
3. **Grain**
4. **Clay**
5. **Iron Ore**

### Role
- early specialization identity
- base inputs for almost everything else
- key import/export items in the early game

---

## B. Refined / Construction Goods
These support building growth and infrastructure.

6. **Wood Planks**
7. **Cut Stone**
8. **Bricks**
9. **Iron Bars**

### Role
- construction and expansion goods
- inputs for mid-tier buildings and upgrades
- common cross-specialization bottlenecks

---

## C. Food / Workforce Goods
These support population growth and city stability.

10. **Flour**
11. **Bread**

### Role
- population support
- worker sustainability
- district development pressure

---

## D. Industrial / Utility Goods
These help unlock better production and more advanced city functions.

12. **Tools**
13. **Pottery**

### Role
- efficiency / utility / production support
- common requirement for upgrades and better-quality buildings

---

## E. Prestige / Development Goods
These push the city beyond survival into growth and distinction.

14. **Furniture**
15. **Fine Goods**

### Role
- higher-tier development
- prestige, desirability, district advancement
- strong export candidates

---

## Goods by Production Chain

### Timber chain
- Timber
- Wood Planks
- Furniture

### Stone chain
- Stone
- Cut Stone
- Fine Goods (shared end-use candidate via crafted/monumental luxury path)

### Grain chain
- Grain
- Flour
- Bread

### Clay chain
- Clay
- Bricks
- Pottery

### Iron chain
- Iron Ore
- Iron Bars
- Tools

---

## Important Note on Fine Goods
For v1, **Fine Goods** is a deliberately abstract prestige/luxury bucket.

Why:
- it gives us one aspirational higher-tier category without overcommitting to a huge luxury taxonomy yet
- it can later split into ceramics, sculpture, jewelry, fine foods, textiles, etc.

For now it is a design abstraction, not a final lore commitment.

---

## Specialization Mapping
Each player chooses a **primary specialization**.
That specialization determines what they produce most efficiently.

### Timber specialist
Best at:
- Timber
- Wood Planks
- Furniture

### Stone specialist
Best at:
- Stone
- Cut Stone
- Fine Goods (stone-themed prestige path for now)

### Grain specialist
Best at:
- Grain
- Flour
- Bread

### Clay specialist
Best at:
- Clay
- Bricks
- Pottery

### Iron specialist
Best at:
- Iron Ore
- Iron Bars
- Tools

### Design rule
A specialization should give:
- lower build costs or stronger output in its lane
- easier progression in its lane
- visual/theme identity

But not complete self-sufficiency.

---

## Acquisition Channels
Every good can come from one or more of these channels:

1. **Self-production**
2. **Player trade**
3. **External-city trade**

### Intent
- core lane goods are easiest to self-produce
- adjacent goods are often easiest to trade for
- rarer or missing goods can be imported from external cities at a cost or limit

---

## Producer Buildings (V1)
This is the first-pass producer list.

### Tier 1 — Extraction
- Lumber Camp -> Timber
- Quarry -> Stone
- Grain Farm -> Grain
- Clay Pit -> Clay
- Iron Mine -> Iron Ore

### Tier 2 — Refining
- Sawmill -> Wood Planks
- Mason Yard -> Cut Stone
- Mill -> Flour
- Kiln Yard -> Bricks
- Smelter -> Iron Bars

### Tier 3 — Production
- Carpentry Works -> Furniture
- Bakery -> Bread
- Pottery Works -> Pottery
- Forge Works -> Tools
- Artisan Studio / Monument Works -> Fine Goods

---

## Consumer Logic
Goods should matter because buildings, upgrades, and district growth consume them.

There are three main kinds of demand:

### 1. Construction demand
Used to place buildings or upgrade them.

### 2. Population/service demand
Used to support population, workers, or district quality.

### 3. Advancement demand
Used to unlock better city tiers, prestige, or efficient production.

---

## Suggested V1 Dependency Rules

## Construction goods
These should be broadly needed across many specializations.

- **Wood Planks** -> housing, storage, workshops, roads/infrastructure upgrades
- **Cut Stone** -> civic buildings, stronger infrastructure, district upgrades
- **Bricks** -> housing upgrades, service buildings, storage, markets
- **Iron Bars** -> industrial upgrades, advanced workshops, trade infrastructure

### Why
These become shared bottleneck goods that naturally drive trade.

---

## Workforce / city stability goods
- **Bread** -> population support, worker growth, development stability
- **Pottery** -> household quality, market/civic progression, desirability-style pressure
- **Tools** -> production efficiency, workshop upgrades, advanced building requirements

### Why
These create reasons to trade for non-construction goods too.
Otherwise the economy becomes all building materials and nothing else.

---

## Prestige / development goods
- **Furniture** -> higher-tier housing, district advancement, desirability/prestige
- **Fine Goods** -> prestige buildings, advanced district milestones, strong export value

### Why
These give the mid/late-v1 economy something aspirational.

---

## Example Building Requirements
These are not final numeric costs — just dependency direction.

### Housing II
Requires:
- Wood Planks
- Bricks

### Market
Requires:
- Wood Planks
- Pottery

### Warehouse
Requires:
- Wood Planks
- Bricks

### Workshop Upgrade II
Requires:
- Cut Stone
- Tools

### Trade Depot
Requires:
- Cut Stone
- Iron Bars
- Pottery

### District Hall / Civic Center Upgrade
Requires:
- Cut Stone
- Furniture
- Fine Goods

### Bakery
Requires:
- Wood Planks
- Mill access / Flour supply

### Forge Works
Requires:
- Bricks
- Iron Bars

### Prestige Housing / Upper District Upgrade
Requires:
- Furniture
- Pottery
- Bread

---

## Example Progression Bottlenecks
These are intentional.

### Timber player
Can easily produce:
- Timber
- Wood Planks
- Furniture

Likely needs imports/trade for:
- Bricks
- Tools
- Bread

### Grain player
Can easily produce:
- Grain
- Flour
- Bread

Likely needs imports/trade for:
- Wood Planks
- Cut Stone
- Tools

### Iron player
Can easily produce:
- Iron Ore
- Iron Bars
- Tools

Likely needs imports/trade for:
- Bread
- Bricks
- Furniture

This is good. This is the whole point.

---

## External City Trade Role in V1
External trade should not replace player trade, but it should stabilize the economy.

### Best use cases
- import missing goods when players are offline or unavailable
- export surplus refined/prestige goods for gold
- create route-based planning and opportunity

### Good external imports
- Bread
- Pottery
- Tools
- Fine Goods
- occasionally construction materials

### Good external exports
- Timber
- Stone
- Furniture
- Pottery
- Fine Goods

### Design guardrail
External trade should usually be:
- slower
- capped
- more expensive or less efficient than a good player trade relationship

Otherwise players will just ignore each other.

---

## Why This Goods Set Works
This v1 set works because it creates:

### Early game
- obvious specialization identity
- simple raw extraction

### Mid game
- refining and cross-specialization dependency

### Late-v1 game
- prestige goods
- better trade incentives
- broader city development requirements

And importantly, it is still small enough to reason about.

---

## What to Add Later (Not V1)
Possible future goods:
- preserved foods
- sculptural goods
- glass
- textiles
- paper
- ink
- wine/oil/spices
- luxury ceramics
- weapons or military supplies
- religious/civic goods

These should come later, not now.

---

## Final Recommendation
For v1, build around:
- 15 goods
- 5 specialization lanes
- 3 acquisition channels
- a dependency graph where no one can efficiently do everything alone

That gives the project the right kind of economic spine without drowning the first playable version.
