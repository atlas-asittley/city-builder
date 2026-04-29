# City Builder - Multiplayer Tycoon Game

## Overview
A multiplayer city-building game (Pharaoh-style) where players work together to build a shared city. Each player specializes in an industry, producing raw materials that can be refined into advanced goods. Players trade resources and manage relationships with NPC trade partners through gifting. The game runs in real-time and is sandbox-style with no win condition.

**Core focus:** Managing production efficiently, trading strategically, building trade partner relationships through gifting, and maximizing use of available resources.

---

## World & Map

### Map System
- **Grid-based shared world** — all players build in the same city
- **Resource tiles** — tiles with resources that players must build on/near to extract
- **Fog of war** — outer tiles start blacked out; as the city expands, new tiles are revealed
- **Revealed tiles** — randomly spawn resources based on what players are currently using
- **City center** — fixed central point; housing must be within a certain radius of center
- **Building placement** — grid-snapped, various sizes (small, medium, large)
- **Citizens auto-relocate** — if you build on a tile with housing, citizens move to another available spot
- **Map growth** — starts small, expands as more buildings are placed and city radius grows

### City Radius
- Tiles within city radius are available for all building types
- Tiles outside radius remain fogged until the city expands

---

## Resources (Starting List)

5 starting resources, each following the same building tree:

1. **Clay** — earthy, pottery/bricks
2. **Timber** — wood, lumber
3. **Stone** — quarry, construction
4. **Iron** — metal, tools/weapons
5. **Corn** — farming, food

**Extensibility:** New resources can be added later as the player base grows.

---

## Industry System

Each player chooses one resource as their industry at the start. They follow the same building tree as all other players — only the names differ based on their resource.

---

## Building Tree (Per Resource)

Costs scale 3x per tier. Each tier has 2-3 building options to add strategic choice.

### Tier 1 — Raw Extraction ($100)

| Building | Output | Risk/Reward |
|----------|--------|-------------|
| [Resource] Pit/Camp/Mine/Farm | Steady, reliable | Low risk, moderate output |
| [Resource] Deep extraction | +50% capacity | Slower to build, higher cost |
| [Resource] Rush operation | +30% speed | Higher maintenance cost |

**Example names:** Clay Pit, Lumber Camp, Quarry, Iron Mine, Corn Farm

### Tier 2 — Basic Processing ($300)

| Building | Output | Special |
|----------|--------|---------|
| [Resource] Workshop | Standard processed goods | Balanced |
| [Resource] Guild | +variety of processed goods | Can produce 2 types |
| [Resource] Mill | Higher efficiency | Requires steady input |

**Example names:** Pottery Workshop, Sawmill, Masonry, Forge, Mill

### Tier 3 — Advanced Processing ($900)

| Building | Output | Special |
|----------|--------|---------|
| [Resource] Factory | Standard advanced goods | Mainstream choice |
| [Resource] Artisan Collective | Quality goods, higher sale price | Slower but commands premium |
| [Resource] Assembly Line | Bulk production | Needs high input volume |

**Example names:** Brick Factory, Furniture Workshop, Stoneworks, Steel Mill, Bakery

### Tier 4 — Luxury Production ($2,700)

| Building | Output | Special |
|----------|--------|---------|
| [Resource] Artisan District | Premium luxury goods | Top quality, high margin |
| [Resource] Specialty House | Unique goods | Can unlock special trade deals |
| [Resource] Export Center | Focus on exporting | Better prices on bulk sales |

**Example names:** Ceramic Artisan, Cabinetmaker, Sculptor, Blacksmith, Specialty Foods

### Building Upgrades
Upgrading production buildings costs 50% of original build cost and increases efficiency by 50%.

---

## Research System

- **Research Lab** building can be constructed (cost: $500)
- Research unlocks higher tiers
- Upgrade costs: Tier 2 = $300, Tier 3 = $900, Tier 4 = $2,700 (3x scaling)

---

## Combined Goods (Cross-Player Recipes)

When two players produce goods that combine well, they can unlock special buildings. Either player can build the combined building once the inputs are available.

### Combined Buildings

| Building | Input 1 | Input 2 | Benefit |
|----------|---------|---------|---------|
| **Library** | Paper | Ink | Increases city happiness |
| **Toolmaker** | Iron | Timber | Boosts all player production efficiency |
| **Tavern** | Corn | Clay | Increases citizen satisfaction |
| **Marketplace** | [Any Advanced] | [Any Advanced] | Improves trade income |

**Extensibility:** More combined buildings can be added as the game grows.

---

## Buildings

### Categories
1. **Resource Production** — Tier 1-4 extraction and processing buildings (branching options)
2. **Housing** — shelter for citizens (organic growth, not player-placed)
3. **Trade** — trade posts for managing NPC trade
4. **Research** — laboratory for unlocking higher tiers
5. **Landmarks** — expensive city-wide buildings for money sinks

### Housing
- Citizens organically build housing within city radius on empty tiles
- Housing evolves based on city conditions (happiness + population)
- Higher tier housing holds more citizens
- Players can build on housing tiles (citizens auto-relocate)
- Housing tiers: Shacks → Houses → Apartments → Mansions

### Landmarks (Money Sinks)
Expensive buildings ($10,000 - $100,000) that provide city-wide bonuses. Creates aspirational goals and removes excess money from economy.

| Landmark | Cost | Bonus |
|----------|------|-------|
| **Grand Plaza** | $20,000 | +10 city happiness |
| **Trade Guild Hall** | $30,000 | +15% trade partner capacity |
| **University** | $50,000 | Unlocks advanced combined buildings |
| **Monument** | $100,000 | +25 city happiness, prestige marker |

### Building Placement
- Buildings occupy grid tiles (size varies by tier)
- Must be placed on/near relevant resource tiles (for extraction) or within city radius (for other buildings)
- Visual variety based on building type and tier

---

## Citizens

### Population
- Citizens live in housing and work in production buildings
- Population grows when happiness is high; shrinks when unhappy

### Happiness Factors
- **Employment** — jobs available for citizens (unemployment decreases happiness)
- **Access to goods** — city produces variety of resources
- **Housing quality** — average tier of housing
- **City amenities** — landmarks, trade infrastructure

### Happiness Formula (Draft)
```
Happiness = Base (50) 
  - Unemployment Penalty (+10 per 10% unemployment)
  + Access Bonus (+5 per unique resource type in city)
  + Housing Quality (+1 to +20 based on average tier)
  + Landmark Bonus (+bonuses from landmarks)
```

### Migration
- Citizens freely move between available housing based on conditions
- Better conditions attract more citizens
- Citizens relocate when their housing tile is used for another building

---

## Economy & Resources

### Player Budget
- Each player has their own budget
- Budget is part of the city's overall wealth (can see city total, but manage only your own)
- Players earn by selling goods to trade partners or directly to other players

### Production Loop
1. Build Tier 1 extraction building on a resource tile
2. Workers produce raw material
3. Raw material feeds Tier 2+ processing (or sold directly)
4. Refined goods sold/traded or used for advanced products
5. Higher tiers generate more profit

### Pricing (Fixed, Not Volatile)
- NPC prices are stable with minor variance only
- Market doesn't crash or spike based on supply
- Strategy is about optimizing production and trade relationships, not timing markets

---

## Trade System

### Player-to-Player Trade
- Players can trade resources directly with each other
- Simple bilateral trade: "I offer X for Y"
- Can happen anytime, no constraints

### NPC Trade Partners

**Partner Personalities:**
- Each NPC partner has preferences for certain resources
- Partners like to receive gifts of resources they need
- Better relationship = better trade terms

**Relationship Mechanics:**
- Each partner has a relationship score (starts at 50/100)
- Give them a wanted resource → +5 to +15 relationship points (based on how much they need it)
- Relationship decays slowly over time (-2 per game week)
- When relationship is high: they bring more goods, visit more frequently, give slightly better prices
- When relationship is low: they bring less, visit rarely, barely trade

**Partner Roster (Starting):**

| Partner | Personality | Wants | Base Visit Frequency |
|---------|-------------|-------|---------------------|
| **River Traders** | Balanced | Corn, Iron | Every 2 weeks |
| **Desert Caravan** | Luxury lover | Stone, Clay | Every 3 weeks |
| **Mountain Folk** | Metal focused | Timber, Iron | Every 2 weeks |
| **Coastal Merchants** | Foodies | Processed Corn, Stone | Every 4 weeks |

**Upgrading Partners:**
- Pay to expand trade with each partner:
  - More resource slots: $500 per slot
  - More frequent visits: $1,000 for +1 frequency increase
  - Higher carrying capacity: $500 per +25 capacity

### Trade Menu
- Players configure which resources to sell/buy from each partner
- Set quantity limits for each resource per visit

---

## Real-Time Systems

### Game Clock
- Game runs in real-time continuously (24/7)
- 1 real-time week = 1 game "year"
- Trade partners visit on weekly cycles

### Offline Play
- Game continues running when you're offline
- Citizens keep working
- Trade partners keep visiting (and will leave gifts/messages if relationship is good)
- Resources accumulate

---

## Messaging System

### In-Game Mail
- Players can send messages to each other
- Recipients check inbox at their convenience
- Simple asynchronous messaging (not real-time chat)

---

## Starting Conditions

### New Player
1. Choose an industry (one of the 5 resources)
2. Receive $500 starting budget
3. Build first Tier 1 extraction building ($100)
4. Citizens begin arriving as production starts
5. Sell goods to earn money for more buildings

---

## Technical Notes

### Supabase
- **Auth** — email/password signup/login (already configured)
- **Database** — city state, player data, resources, buildings, citizens
- **Realtime** — live updates across all players
- **Storage** — for game assets if needed

### Data to Store
- Player profiles (industry, budget, location)
- City map state (tiles, buildings, fog)
- Resource production rates and stockpiles per player
- Trade partner relationships and configurations
- Messages
- Research/unlock progress

---

## Next Steps
1. Review and approve this spec
2. Create database schema for Supabase
3. Hand off to Claude Code for implementation