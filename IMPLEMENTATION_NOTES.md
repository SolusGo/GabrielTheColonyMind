# Implementation Notes

## Mechanic Mapping

| Mechanic | Implementation |
| --- | --- |
| Node interval | Lua city ledger, scaled by `GameSpeeds.TrainPercent` |
| Human placement | Additive UI context; gameplay Lua revalidates every request |
| AI placement | Deterministic local scoring, no UI dependency |
| Node yields | `Improvement_Yields` |
| Node vision | CP `Improvements.GrantsVisionXTiles = 1` |
| Unit network | Dynamic promotion on movement and player-turn reconciliation |
| +5% outgoing identity | CP/base `UnitPromotions.AttackMod = 5` |
| +3 normal healing | `FriendlyHealChange`, `NeutralHealChange`, `EnemyHealChange` |
| City Science/defense | Six mutually exclusive dummy tiers using `Building_YieldModifiers` and CP `BuildingDefenseModifier` |
| Nexus inheritance | Full `Buildings` row copy plus active University relationship rows |
| Nexus Node Science | Six mutually exclusive flat-Science dummy tiers |
| Detection | Dynamic `SeeInvisible = INVISIBLE_SUBMARINE` promotion inside connected coverage |
| Infestation | CP battle participants + initial/final damage comparison + persistent duration |

## Save Keys

City keys contain player ID, city ID, acquisition turn, and coordinates. Infestation keys contain owner and unit ID; `UnitCreated` clears stale reused IDs, and `UnitUpgraded` migrates active duration. Node ownership is stored by plot index so neutral improvements retain a builder identity across save/load.

## Performance

The map is scanned once when the controller initializes to rebuild the small Node cache. Normal updates inspect radius one around units/cities and radius three only while choosing a placement. All Gabriel units/cities are reconciled once on Gabriel's own turn. There is no per-turn all-plot scan.

## Multiplayer

Static and AI logic is deterministic, but the human placement selection originates in a UI add-in. Version 1 therefore reports no multiplayer/hotseat support rather than overclaiming synchronization.

## Art Decisions

The supplied concept sheet is the canonical source for object portraits. A clean standalone leader scene is used for diplomacy, while the dedicated Colony Network map artwork is used for Dawn of Man. All DDS files are DXT5. Each atlas size is independently rendered from master source, with no resize cascade.

No landmark `.gr2` was supplied or generatable from raster art, so the Colony Node uses Trading Post landmark geometry. This affects only the world model, not its portrait, yields, visibility, or gameplay identity.
