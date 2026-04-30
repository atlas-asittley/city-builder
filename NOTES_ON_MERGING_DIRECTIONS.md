# Notes on Merging the Two Directions

## The two ideas we need to combine

### 1. Pharaoh-style city sim strengths
- roads and pathing
- housing evolution
- service coverage
- desirability
- layered city-management feel
- physical map presence and placement strategy
- infrastructure pressure and maintenance

### 2. Multiplayer city-builder strengths
- persistent accounts and progression
- specialization by player
- shared world identity
- trade and economic interdependence
- return-later async play loop
- Supabase-backed persistence and social structure

---

## The right merge
The correct merge is **not**:
- build Pharaoh, then awkwardly bolt multiplayer onto it

The correct merge is:
- use Pharaoh-like mechanics as the **city simulation layer**
- use the multiplayer/shared-economy concept as the **game structure layer**

In other words:

**Pharaoh gives us the feel of managing a living city.**
**The multiplayer design gives us the reason the world matters beyond one player.**

---

## Clean merged vision
A player manages a district/city presence with roads, housing, services, workers, production chains, and desirability-like pressures — but does so inside a larger persistent multiplayer world where specialization and trade matter.

That is the actual synthesis.

---

## What probably belongs in the merged v1
- grid-based city building
- roads
- extraction/production buildings
- storage
- housing or population cap pressure
- simple service/infrastructure logic
- district ownership
- specialization choice
- trade offers / shared economy
- persistent progression

---

## What should probably wait until after v1
- deep walker simulation if it becomes too expensive/complex
- full Pharaoh-style service agent fidelity
- too many hazards/disasters
- giant resource trees
- complex diplomacy/factions

---

## Design caution
The danger is trying to merge them literally instead of structurally.

Bad merge:
- copy Pharaoh mechanics one-for-one
- also add multiplayer trade because it sounds cool

Better merge:
- ask which Pharaoh-like systems actually create good multiplayer city-management decisions
- keep those
- simplify or drop the rest

---

## Likely product shape
The game should feel like:
- a living city sim when you are managing your district
- a multiplayer economy/world when you zoom out and think strategically

That tension is good. It gives both intimacy and scale.

---

## Best future discussion question
When we sit down to discuss the merge more deeply, the key question should be:

**Which Pharaoh mechanics create the most interesting multiplayer consequences?**

That question will save us from cargo-cult design.
