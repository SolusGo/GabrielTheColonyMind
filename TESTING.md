# In-Game Test Matrix

Code-level validation is automated by:

```powershell
python Tools/build_art.py
python Tools/validate_database.py "<path-to>/cache/Civ5DebugDatabase.db"
```

The following checks require Civ V itself and are not claimed complete until manually marked.

## Initialization

- [ ] Civ and leader appear in setup with correct color and icons.
- [ ] Starting units/technology/palace are correct.
- [ ] Silent Dawn of Man screen renders without America/Washington remnants.
- [ ] Database.log, XML.log, and Lua.log contain no Gabriel errors.

## Nodes and Timers

- [ ] First/multiple cities independently produce at 20/30/45/90 turns.
- [ ] Captured, liberated, razed, and refounded cities begin from zero.
- [ ] One pending Node pauses only its city's timer.
- [ ] Placement panel highlights every legal plot and rejects stale/illegal choices.
- [ ] AI places Nodes without opening UI.
- [ ] Owned/neutral placement, foreign claim, pillage, and repair behave correctly.
- [ ] No-legal-plot state remains safely pending.
- [ ] Save/load preserves timers, pending placements, and neutral builder ownership.

## Network Effects

- [ ] Node tile yield preview shows +1 Science/+1 Production.
- [ ] Active Node reveals exactly itself and adjacent plots.
- [ ] Unit entering/leaving overlapping coverage receives/removes one Network promotion.
- [ ] +3% combat, +5% attack-only strength, and +3 legitimate healing apply.
- [ ] Adjacent Nodes grant cities exactly +1–6% Science and defense.
- [ ] Pillage disables vision, unit, city, Nexus, and detection effects.
- [ ] Embarked, naval, and air units receive only mechanically valid behavior.

## Swarm Host and Infestation

- [ ] Tech tree/production/Civilopedia use custom icon and current CP Composite Bowman data.
- [ ] Ranged Combat Strength equals current Composite Bowman minus one.
- [ ] Swarm Reinforcement applies only to actual Swarm Hosts in coverage.
- [ ] Ranged/melee defensive damage applies Infestation only after actual military-unit damage.
- [ ] Multiple hosts produce -5/-10/-15%, never multiple tier promotions.
- [ ] Fourth hit refreshes duration without exceeding -15%.
- [ ] Expiration gives approximately two full victim turns.
- [ ] Death, deletion, upgrade, capture/gift edge cases do not leak state.
- [ ] Save/load preserves active tier and duration.

## Colony Nexus

- [ ] Inherits every active CP University effect and prerequisite.
- [ ] Adds exactly one Great Scientist Point, not one per Node.
- [ ] Adds exactly +1 flat Science per active adjacent Node.
- [ ] Construct/sell/capture/pillage changes connected detection immediately after reconciliation.
- [ ] Standard submarines are detectable only inside connected coverage.

## Compatibility and Presentation

- [ ] Policies, ideologies, research agreements, espionage, religion, trade, World Congress, and Great Scientists behave normally.
- [ ] City-States/barbarians/team checks do not receive Colony-only effects.
- [ ] Tech tree, production, Civilopedia, unit flags, diplomacy, map, and Dawn of Man art render correctly at several resolutions.
- [ ] Long game/Huge map turn processing remains responsive.
