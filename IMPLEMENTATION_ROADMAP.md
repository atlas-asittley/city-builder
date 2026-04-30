# Implementation Roadmap — Multiplayer City Builder V1

## Goal
Turn the canonical plan into a real build order that avoids premature complexity.

This roadmap is intentionally opinionated. It is designed to get to a playable, persistent, mobile-friendly prototype without wandering.

---

## Guiding Principle
Build in this order:

**identity -> persistence -> smallest fun loop -> multiplayer value -> depth**

If we skip that order, we will build a pile of UI and theory with no durable game.

---

## Phase 0 — Project reset and framing

### Outcome
The repo stops pretending to be a static single-player Pharaoh clone and starts becoming the real app.

### Tasks
- keep the current prototype as a reference/mechanics sandbox
- align naming in UI/docs around "multiplayer city builder" instead of Pharaoh
- decide whether to evolve `projects/city-builder` as the main implementation target
- define the initial theme as flexible / placeholder

### Deliverables
- canonical game plan
- schema plan
- implementation roadmap

---

## Phase 1 — Auth and app shell

### Outcome
A player can register, log in, log out, and land in the app shell on mobile.

### Scope
- Supabase client setup
- session persistence
- login screen
- registration screen
- auth guard
- logged-in home/dashboard shell
- mobile-friendly navigation shell

### UI screens
- landing / welcome
- login
- register
- loading/session restore
- post-login dashboard

### Deliverables
- working Supabase auth flow
- authenticated app shell deployed locally
- no gameplay required yet

### Why first
Because until identity exists, nothing else is real.

---

## Phase 2 — Player onboarding

### Outcome
A first-time player gets a profile, selects a specialization, and receives a district/world assignment.

### Scope
- create `player_profiles` row on first login
- choose specialization/resource
- assign world + district
- initialize treasury/inventory/population state
- redirect into game view

### Deliverables
- first-login onboarding flow
- persisted player profile
- assigned district visible in database

### Key rule
This should be mostly one-time setup logic, not mixed chaotically into every screen.

---

## Phase 3 — Shared world read model

### Outcome
A logged-in player can load and view the world and their district on mobile.

### Scope
- load tiles, districts, and buildings from Supabase
- render the map in browser
- clearly show owned district vs surrounding world
- support touch-friendly camera/panning/selection
- make side panels mobile-safe from day one

### Deliverables
- map renderer backed by Supabase data
- district boundaries visible
- building and tile data loading correctly

### Important note
At this point, read-only is fine. Don’t rush writes before the world can be viewed clearly.

---

## Phase 4 — Core placement loop

### Outcome
The player can place a valid building in their district and see it persist.

### Scope
- building catalog (very small at first)
- placement preview on map
- server-validated place-building mutation
- deduct treasury cost
- save building row
- refresh/realtime update visible immediately

### Initial building set
- road
- one housing building or housing placeholder mechanic
- one extraction building per starting resource
- one storage building

### Deliverables
- first end-to-end gameplay loop:
  - open game
  - choose building
  - place building
  - building persists after refresh

### This is the first true milestone
If this works, the project starts feeling real.

---

## Phase 5 — Production and persistence

### Outcome
Buildings actually do something over time.

### Scope
- simple production logic
- inventory changes over time
- treasury and/or upkeep updates
- population/worker gating kept simple
- offline catch-up based on `last_tick_at`

### Deliverables
- extraction buildings produce resources
- stockpiles visibly increase
- refreshing later reflects elapsed time

### Strong recommendation
Start with coarse simulation. Do not begin with per-second precision obsession.

---

## Phase 6 — Economy UI

### Outcome
Players can understand their state without drowning in panels.

### Scope
- mobile-first HUD
- treasury display
- inventory panel
- district summary
- worker/population summary
- notifications/inbox

### Deliverables
- phone-friendly game HUD
- collapsible panels
- clear resource and money readouts

### Why this matters
A city builder dies if the player can’t read the system.

---

## Phase 7 — First multiplayer value

### Outcome
Players can interact economically instead of just coexisting.

### Scope
- create trade offers
- browse available offers
- accept trade
- create notifications for completed trades
- optionally show nearby/shared district economy context

### Deliverables
- player-to-player trade MVP
- async interaction with real multiplayer meaning

### Why this before fancy social systems
Because trade is actual gameplay. Chat alone is not.

---

## Phase 8 — Expansion systems

### Outcome
The game gains medium-depth progression.

### Scope
- processing buildings
- specialization bonuses
- better storage/logistics
- district progression
- research/unlock layer
- light service/desirability systems

### Deliverables
- second-order strategy
- more reasons to specialize and collaborate

---

## Phase 9 — World depth

### Outcome
The shared world feels alive rather than merely persistent.

### Scope
- NPC trade partners
- world events
- landmarks / shared infrastructure
- richer population/happiness simulation
- district/world bonuses

### Deliverables
- meaningful macro goals
- stronger world identity

---

## Recommended Technical Order of Operations

### Right now
1. schema SQL draft
2. RLS policy draft
3. auth shell implementation
4. onboarding flow
5. world loading
6. building placement mutation

### Not right now
- advanced hazards
- deep theming polish
- giant building trees
- overengineered realtime simulation
- combat or unrelated side systems

---

## Suggested V1 Resource/Building Scope
To keep this sane, begin with:

### Resources
- timber
- stone
- grain

### Building types
- road
- camp/quarry/farm
- warehouse
- basic housing placeholder
- market later

That’s enough to prove the loop.

---

## Repo Strategy Recommendation
Use `projects/city-builder` as the main implementation repo for this pivot.

Reason:
- it already aligns with the shared city-builder direction better than `pharaoh-tycoon`
- it already contains Supabase-oriented intent in `CLAUDE.md`
- it avoids forcing the new product through the old identity

The Pharaoh prototype can remain a donor/reference for mechanics and mobile UI ideas.

---

## Definition of Success for V1
V1 is successful if a player can:
- register/login on phone
- create profile and specialization
- enter a persistent world
- place buildings in their district
- generate/store resources
- come back later and still have progress
- trade with at least one other player or trade offer system

If that works, the foundation is real.

---

## What I Would Do Immediately Next
The next concrete build step should be:

**Create the SQL migration draft and RLS policy draft, then hand Claude the auth-shell implementation.**

That order is disciplined.
If we skip straight to frontend code, we’ll just be improvising against a blurry backend.
