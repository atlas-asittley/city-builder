# V1 Seed Plan and Starting Unlocks

## Purpose
This document maps the v1 design into implementation-ready seed data assumptions.

It answers two practical questions:
1. What should exist in `resource_types` and `building_types` for v1?
2. What should players have access to at the start versus later?

---

## Guiding Judgment
Do **not** start players with the whole catalog unlocked.
That kills progression immediately.

But also do **not** make the opening too starved or fussy.
If the first 15 minutes are miserable, the economy won’t get a chance to shine.

So the right approach is:
- broad goods catalog seeded in the database
- narrow starting unlock set
- progression gates tied to district development and imported/support goods

---

## V1 resource_types seed set
Use all 15 goods in the v1 catalog from day one.

### Raw
- timber
- stone
- grain
- clay
- iron_ore

### Construction
- wood_planks
- cut_stone
- bricks
- iron_bars

### Food
- flour
- bread

### Utility / industrial
- tools
- pottery

### Prestige
- furniture
- fine_goods

### Why seed all 15 immediately?
Because the world economy should have one shared language even if not every good is reachable on minute one.

---

## V1 building_types seed set
Seed the full first-pass building catalog now, even if some entries are locked behind district tier.

### Seed now
- road
- housing_1
- housing_2
- housing_3
- lumber_camp
- quarry
- grain_farm
- clay_pit
- iron_mine
- sawmill
- mason_yard
- mill
- kiln_yard
- smelter
- bakery
- pottery_works
- forge_works
- carpentry_works
- artisan_studio
- warehouse
- market
- trade_depot
- district_hall
- civic_center_upgrade

### Why seed locked buildings now?
Because:
- UI can read one catalog
- future unlock logic is simpler
- progression becomes a data problem, not a schema problem

---

## Starting unlock philosophy
A new player should start with enough to:
- establish a district
- enter their specialization lane
- produce at least one meaningful tradeable good
- begin connecting to the shared economy

They should **not** start with enough to:
- produce every tier immediately
- skip interdependence
- trivialize imports/trade

---

## Recommended starting unlocked buildings

### Always unlocked
- road
- housing_1
- warehouse
- trade_depot
- district_hall

### Conditionally unlocked by specialization context but visible in catalog
All Tier 1 extraction and Tier 2 refining buildings can exist in the global catalog, but the player should naturally be best positioned to use their own lane first.

For practical v1 UX, I recommend these be **globally visible** but with:
- stronger efficiency in the player’s specialization lane
- tile/resource constraints preventing nonsense placement
- costs and logistics naturally pushing identity

### Starting-usable production lane buildings
- lumber_camp
- quarry
- grain_farm
- clay_pit
- iron_mine
- sawmill
- mason_yard
- mill
- kiln_yard
- smelter

### Why this is the right call
If only one extraction/refining lane is visible, players may feel arbitrarily boxed in.
If all are visible but the player’s district and specialization strongly favor one lane, the world feels more systemic and less class-locked.

---

## Recommended tier gates
Use **district tier** as the main v1 unlock gate.

### District Tier 1
Available:
- road
- housing_1
- extraction buildings
- refining buildings
- warehouse
- trade_depot
- district_hall

### District Tier 2
Unlocks:
- housing_2
- bakery
- pottery_works
- forge_works
- carpentry_works
- market

### District Tier 3
Unlocks:
- housing_3
- artisan_studio
- civic_center_upgrade

This is clean and understandable.

---

## Why district tier is the right gate
Because it feels like city development, not arbitrary tech clicks.

That fits the game better.
You are not just unlocking recipes in a vacuum — your district is becoming more capable.

---

## Suggested starting player bootstrap
When onboarding completes, a player should receive:
- one district assignment
- starter treasury (already planned)
- empty inventory rows for all 15 goods
- district tier 1 status
- access to the base building catalog

### Optional nice touch
Seed a tiny amount of one or two starter construction goods only if the opening feels too slow in testing.
For now I would **not** do that by default.
Better to test the cleaner version first.

---

## Suggested unlock metadata approach
The current schema does not yet have a dedicated unlock table.
That is fine.

For v1, store unlock metadata in `building_types.build_rules`, such as:
- `startingUnlocked`
- `districtTierRequired`
- `specialization`
- `buildCosts`
- `consumes`
- `populationCap`
- `storageBonus`
- `tradeSlots`

This is good enough for now and keeps the implementation moving.

Later, if unlock logic becomes more complex, split it into dedicated tables.

---

## Important implementation judgment
Do not confuse:
- **seeded in the catalog**
with
- **available to use immediately without constraint**

Those are different things.

The catalog should be broad.
Player access should still feel staged.

---

## Recommended first unlock loop
A good early session should look like:
1. place roads
2. place extraction building in your favored lane
3. place refining building
4. add housing_1
5. build warehouse or trade_depot
6. trade for missing construction/support goods
7. upgrade district toward tier 2
8. unlock first production buildings

That is a healthy first loop.

---

## Resulting implementation shape
### `resource_types`
- seed all 15 now

### `building_types`
- seed the full v1 set now
- include unlock and cost data in `build_rules`

### player bootstrap
- initialize full inventory rows
- initialize district tier 1
- start with base unlock layer only

This is the most practical path: structured enough to scale, simple enough to ship.

---

## Best next step after this
After this, the cleanest follow-up is:
1. align the schema/migration strategy with district tier + unlock metadata
2. update onboarding/bootstrap logic to initialize inventory rows for the full goods set
3. prepare the first placement/build validation rules against this catalog
