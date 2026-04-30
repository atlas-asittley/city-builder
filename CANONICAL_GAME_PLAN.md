# Canonical Game Plan — Multiplayer City Builder

## Purpose
This document is the new source of truth for the game direction.

It supersedes the vague "Pharaoh clone" framing and pulls together the earlier city-builder ideas, the Supabase-first plan, and the lessons from the current prototype.

---

## One-Sentence Vision
A mobile-friendly multiplayer city builder where players log in, claim a role in a shared world, build production chains, grow cities, trade with each other, and shape a persistent economy over time.

---

## What This Game Is
- **A multiplayer city builder**
- **Playable in a mobile browser first**
- **Persistent online world** with accounts, saved progress, and shared systems
- **Inspired by Pharaoh-style mechanics** without trying to literally be Pharaoh
- **Built around Supabase** for auth, database, and realtime sync

---

## What We Keep from Pharaoh-Style Games
These are the mechanics worth keeping because they are strong, not because we want to copy the theme.

- Grid-based building placement
- Roads and pathing
- Housing evolution
- Worker/population pressure
- Service coverage and desirability
- Production chains
- Treasury / maintenance / taxes / expenses
- Hazards / upkeep / infrastructure stress
- Layered city management instead of a simple idle game

---

## What We Drop
- Direct Pharaoh identity
- Ancient Egypt as a mandatory full-theme constraint
- Heavy keyboard dependence
- Desktop-only interaction assumptions
- Single-player-first thinking
- Anything that feels too close to "just remake Pharaoh"

---

## Product Direction

### Core fantasy
Players are not just decorating a town. They are helping build and sustain a living economic city/world.

### Core loop
1. Log in
2. Build or expand your city presence
3. Produce resources and goods
4. Solve labor / housing / service / logistics constraints
5. Trade with players and NPC systems
6. Improve efficiency and unlock higher tiers
7. Contribute to a larger persistent world

### Why this is interesting
The fun should come from:
- balancing growth with stability
- choosing what to specialize in
- cooperating and competing economically
- seeing the world persist while players come and go

---

## Multiplayer Direction

## Recommended model for v1
**Async persistent multiplayer**, not twitch realtime gameplay.

That means:
- Players share a world and affect the same economy/map/systems
- Progress persists while offline
- Actions resolve through stored state, timers, and periodic simulation
- Realtime is used for updates/presence/events, not action combat or frame-perfect coordination

### Why
This is the right level of ambition.
Fully realtime multiplayer city simulation is expensive, fragile, and likely to waste time early.

---

## World Structure
Two valid models exist:

### Option A — Separate cities per player
- easiest technically
- good for early iteration
- weaker multiplayer identity

### Option B — Shared world / shared regional city
- stronger identity
- more interesting economically and socially
- more complex technically

## Recommendation
Build toward **shared world multiplayer**, but structure v1 so we can start with limited ownership zones or districts.

A practical hybrid:
- One world map
- Players own/build primarily in assigned plots, districts, or influence zones
- Shared trade, infrastructure, economy, and expansion systems

This preserves multiplayer identity without creating total placement chaos on day one.

---

## Theme Direction
Theme is still open.

The game does **not** need to stay Egyptian.
We can keep a historical/classical/civilization-building feel, or move to a more original setting.

What matters more than the exact skin:
- readable buildings
- satisfying progression
- clear economic fantasy
- strong multiplayer interactions

For now, theme should remain **flexible** while systems are designed.

---

## Platform Direction

## Primary platform
- Mobile browser

## Secondary platform
- Desktop browser

## UX implications
- Touch-first controls
- No keyboard-required gameplay
- Panels must collapse/hide cleanly
- Important actions must be reachable with thumb-friendly controls
- HUD must work on narrow screens
- Desktop shortcuts can exist, but only as optional power-user conveniences

---

## Supabase Architecture
Supabase is the right backend for this project.

### Use Supabase for
- **Auth** — email/password signup and login
- **Database** — core game state
- **Realtime** — shared updates, presence, event subscriptions
- **Storage** — optional assets, avatars, screenshots, future uploads
- **Edge Functions** — server-authoritative mutations and simulation logic where needed

### High-level flow
1. Player registers or logs in with Supabase Auth
2. Frontend loads player profile and game state from Supabase
3. Player actions call controlled write paths
4. Database updates persist the new state
5. Realtime broadcasts relevant changes to connected clients

---

## Auth & Account Model
Each player should be able to:
- register
- log in
- maintain a persistent profile
- own progression and city/game state

### Initial auth approach
- Supabase email/password auth
- basic profile row linked to auth user id
- optional display name / faction / chosen industry

### Do not overcomplicate v1 with
- social login
- elaborate account linking
- overbuilt profile cosmetics

Get account creation and persistence working first.

---

## Gameplay Pillars

### 1. City simulation
A city should feel like a system, not just a canvas.

Systems to emphasize:
- housing
- jobs/workers
- resource flow
- service coverage
- upkeep costs
- growth constraints

### 2. Specialization
Players should have **strong identity without unequal core power**.

The guiding principle is:
**symmetric mechanics, asymmetric flavor.**

That means:
- every player follows the same advancement structure
- every player has the same rough power ceiling
- every player gets equivalent progression roles by tier
- what changes is the resource theme, building names, visuals, and produced goods flavor

Players are choosing an identity, not a stronger class.

The important refinement is that the game should use a **shared global goods economy**.
A player's specialization is their **primary production identity**, not their entire economic universe.

In practice:
- Timber, Stone, Grain, or future resources should map onto the same advancement template
- each specialization should have a comparable raw tier, refined tier, advanced tier, and prestige/export tier
- the world should contain a broader pool of goods than any one player can efficiently produce alone
- balance should live in the shared template, not in hidden resource favoritism

Possible forms:
- chosen primary specialization/resource
- district bonuses
- research unlock bias kept within tight balance bounds
- trade positioning without making one specialization objectively superior

### 3. Economy and trade
Multiplayer meaning comes from exchange.

Core ideas:
- one shared global goods pool
- player-to-player trade
- NPC demand or trade partners
- resource chains feeding higher-value goods
- reasons to cooperate instead of playing as isolated single-player islands
- advancement that sometimes requires imported goods, not just self-production

The economy should be built on a **large shared goods catalog**.
Players specialize in producing a subset of goods efficiently, but buildings, upgrades, and development should draw from a much broader pool.
Goods can come from three channels:
- self-production
- player trade
- external-city imports

Trade should exist in two layers:

#### Player-to-player trade
Players should be able to trade with teammates or neighbors to get resources and goods they need for development.
This is the main expression of multiplayer interdependence.

Examples:
- I produce Timber and need Stone or Flour to continue developing
- another player produces Stone and needs Wood Planks from me
- we trade because neither of us should be fully self-sufficient at every step

#### External city trade
The world should also include non-player trade partners or outside cities.
This should work more like Pharaoh-style trade:
- outside cities buy and sell certain categories of goods
- trade routes, limits, demand, and availability matter
- they provide a sink/source beyond player-only exchange
- they help keep the economy alive even when not many players are online

Player trade creates the social economy.
External trade creates the world economy.

### 4. Persistent progression
Players should feel that their city and role matter over time.

Examples:
- unlock new tiers
- improve logistics
- expand territory
- increase production efficiency
- contribute to city/world-level infrastructure

---

## Recommended V1 Scope
V1 should be narrower than the full dream.

### V1 goal
Prove the core loop:
**login -> claim identity/place -> build -> produce -> persist -> trade -> return later**

### V1 features
- Supabase auth
- player profile creation
- one persistent world or district-based shared map
- grid-based tile/building system
- basic resource extraction and processing
- player budget / treasury
- simple population/worker model
- mobile-friendly UI
- persistence of buildings/resources/progress
- simple trade model
- a reduced v1 goods pool that proves the larger economic concept without overwhelming the game
- a concrete dependency graph where construction, food, utility, and prestige goods cross specialization lines
- a first building set that covers infrastructure, housing, extraction, refining, production, trade, and district progression

### V1 features to delay
- deep disasters/hazards
- large social systems
- combat
- advanced prestige politics
- a huge live goods catalog at full intended scale
- overly complex realtime simulation

---

## Suggested V1 Mechanical Slice
If we want the smallest meaningful playable version:

### Resources
Start with 3 instead of many.
Example:
- Timber
- Stone
- Grain

### Building groups
- roads
- housing
- extraction
- processing
- storage
- market/trade
- service/utility

### Minimal loop
- build road
- place extraction building near valid tile
- produce resource over time
- house workers
- move/store/sell goods
- earn money
- unlock better production

That is enough to validate the game without drowning in feature creep.

---

## Data Model Direction
This is not the full schema yet, but these are the main entities.

### Core entities
- users
- player_profiles
- worlds
- districts or plots
- tiles
- buildings
- inventories / stockpiles
- resource_types
- production_jobs or simulation state
- trades / trade_offers
- research_progress
- messages / notifications

### Important rule
The database model should reflect a **persistent simulation**, not just a local browser save.

---

## Authority Model
Do not trust the client with everything.

### Client should do
- rendering
- UI state
- local previews
- optimistic interaction where safe

### Server/backend should protect
- legal placements
- ownership rules
- resource spending
- production outcomes
- trade validation
- progression unlocks

Even if some logic starts on the client for speed, the long-term direction should be server-authoritative for important state.

---

## Relationship to the Current Pharaoh Prototype
The current prototype is useful as a **mechanical sandbox**, not as the final product identity.

### We should reuse
- grid/camera/building interaction ideas
- service/desirability concepts
- mobile UI lessons
- panel/control patterns that worked

### We should not assume
- current codebase is the final architecture
- static local-state implementation is enough
- Pharaoh theme should remain the product frame

Think of the prototype as a systems sketch, not sacred code.

---

## Naming / Branding Direction
Do not anchor future design decisions to the name "Pharaoh."

We should eventually choose a name that reflects:
- original identity
- online shared-world city building
- long-term extensibility

For now, use generic internal naming like:
- Multiplayer City Builder
- Shared City Builder
- City Builder Online

---

## Immediate Build Order

### Phase 1 — foundation
- finalize canonical design direction
- design initial database schema
- scaffold Supabase auth
- create login/register flow
- create post-login dashboard / entry screen

### Phase 2 — persistent city slice
- create world/district model
- store tiles/buildings in database
- implement place/remove building flow
- persist treasury/resources/workers

### Phase 3 — multiplayer value
- player identity/specialization
- trade or shared economy
- realtime updates where useful
- world-level interaction

### Phase 4 — depth
- more tiers/resources
- hazards and advanced services
- landmarks, progression, prestige
- richer social/economic systems

---

## Immediate Next Technical Tasks
1. Create the initial Supabase schema plan
2. Define v1 entities and ownership rules
3. Build auth screens and session handling
4. Decide whether v1 starts with shared world districts or separate player cities
5. Build the smallest persistent playable loop

---

## Final Direction Statement
This project is now defined as:

**A mobile-first multiplayer city builder with persistent progression, Supabase-backed accounts and data, and city-management systems inspired by Pharaoh but developed into an original online game.**
