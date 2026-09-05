# Gabriel — The Colony Mind

## Overview

Gabriel leads **The Colony**, a Community Patch civilization built around defensive Science, territorial preparation, vision, attrition, and counterattack. The gameplay loop is:

**Prepare → Connect → Observe → Weaken → Counterattack**

The civilization is strongest on ground prepared with Colony Nodes and intentionally ordinary away from that network. Its preferred victories are Science and Diplomacy; Domination is best pursued after an enemy has exhausted itself attacking prepared territory.

## Leader

**Gabriel, the Colony Mind** is a patient myrmecologist and distributed strategist. His AI strongly values Science, defense, reconnaissance, ranged units, tile improvements, and durable diplomacy. He dislikes reckless war and does not receive early-rush tools.

## Unique Ability — Colony Network

Every Colony city independently prepares a Colony Node. The interval scales through the active game speed's normal training percentage:

| Speed | Turns |
| --- | ---: |
| Quick | 20 |
| Standard | 30 |
| Epic | 45 |
| Marathon | 90 |

Newly founded and captured cities begin at zero. A city with one unplaced Node pauses its timer.

Active Colony Nodes influence their own plot and adjacent plots. Colony military units within that radius receive:

- +3% Combat Strength;
- +5% attacking strength (the CP `AttackMod` implementation of outgoing damage);
- +3 HP whenever they normally heal.

Coverage does not stack. Pillaged Nodes provide no network effects.

Each active Node directly adjacent to a Colony city adds +1% Science and +1% City Defensive Strength, up to the natural six-hex maximum. These city bonuses do stack by Node.

## Unique Unit — Swarm Host

The **Swarm Host** replaces the Composite Bowman and dynamically copies its current Community Patch cost, movement, range, prerequisites, AI roles, upgrade path, combat class, resources, and inherited promotions. Its Ranged Combat Strength is exactly one point lower.

Damaging an enemy military unit applies **Infestation** for approximately two full victim turns:

- 1 stack: -5% Combat Strength;
- 2 stacks: -10%;
- 3 stacks: -15%.

Further successful hits add a stack up to three and refresh the duration. The target holds only one tier promotion at a time. Infestation is tracked against CP battle participants, persists through saves, follows an upgrade when its promotion survives, and is cleared by expiration/death/unit-ID initialization.

Inside active Node influence, an actual Swarm Host also gains **Swarm Reinforcement**: +8% Combat Strength.

## Unique Building — Colony Nexus

The **Colony Nexus** replaces the University. Its database row and every University relationship row are copied from the active CP definition at load time, so it retains current CP effects instead of recreating obsolete vanilla values.

It adds:

- +1 Great Scientist Point per turn;
- +1 flat Science per active adjacent Colony Node;
- a detection network around those connected Nodes.

Connected Colony military units can detect submarines while standing within the influence of a Node adjacent to a city with a Nexus.

## Unique Improvement — Colony Node

A Colony Node provides +1 Science, +1 Production, and CP-native radius-one vision. Human players receive a placement panel that cycles, highlights, and focuses legal plots within three tiles of the generating city. AI players score and place Nodes automatically, prioritizing city adjacency, hills, enemy-facing borders, and network continuity.

Human Gabriel players also receive a Colony Network dashboard in the upper-right HUD. It summarizes active and pillaged Nodes, ready cities, covered military units, and every city's preparation progress, adjacent connections, percentage bonuses, Nexus Science, and placement state.

Legal placement excludes foreign territory, cities, water, mountains, impassable tiles, natural wonders, resources, and protected improvements such as Great Person, civilization-unique, permanent, ruin, or barbarian-camp improvements. An ordinary Farm, Mine, Trading Post, or similar improvement may be replaced deliberately. Neutral placement is supported. Builder ownership is saved separately; a neutral Node remains active until another civilization claims the tile, at which point it is removed.

## Unique Promotions

- **Inside the Colony Network:** +3% Combat Strength, +5% attacking strength, +3 normal healing.
- **Swarm Reinforcement:** +8% Combat Strength for Swarm Hosts inside the network.
- **Infestation I–III:** mutually exclusive -5/-10/-15% target debuffs.
- **Nexus Detection Network:** detects submarines within connected coverage.

## Core Gameplay Loop

Place some Nodes beside cities for Science and city defense, then extend others toward chokepoints and likely invasion routes. Use their vision to identify an attack early, rotate units through improved healing positions, and focus Swarm Host fire on the enemy's most dangerous units. Counterattack only after Infestation and attrition have changed the odds.

## Early Game Strategy

Gabriel's Ancient opening uses the standard Community Patch starting package with no additional custom unit. Scout likely borders, settle defensible city sites, and keep workers available to repair future Nodes. The first Nodes are precious; an opponent that attacks before the 30-turn Standard interval can deny the network's strongest terrain.

## Mid Game Strategy

The Medieval era is the first major spike. Swarm Hosts can debuff an invading army while Node positions improve every defender. Avoid spreading fire across too many targets: three focused hits produce the full -15% penalty. Education begins the second spike as Colony Nexuses turn adjacent Nodes into flat Science.

## Late Game Strategy

Maintain repair access and a mobile reserve for multiple fronts. Mature cities can reach +6% Science and defense from adjacent Nodes, but their military coverage remains binary rather than stacking. Convert secure research into a Science victory, diplomatic leverage, or a technologically superior counteroffensive.

## Recommended Technologies

Prioritize the normal economic foundations, then Construction for Composite Bowman timing, Education for Colony Nexuses, and the research/production technologies appropriate to a Science victory. Do not delay military technologies merely because prepared territory is strong.

## Recommended Policies

Tradition supports a compact, heavily prepared core. Progress can support broader Node generation if the player can defend several developing fronts. Rationalism is the natural mid/late-game choice. Statecraft is attractive for Diplomatic victories; defensive Ideological tenets complement the network but are not required by code.

## Victory Conditions

- **Science — Excellent:** percentage city Science, Nexus flat Science, and secure territory reinforce the full victory path.
- **Diplomatic — Strong:** defense and information protect an economy that can invest abroad.
- **Domination — Viable:** best through attrition and counterattack rather than surprise conquest.
- **Culture — Viable:** security helps, but the kit supplies no direct Tourism or Great Writer/Artist/Musician specialization.

## Strengths

- Excellent prepared defense and recovery.
- Strong local information and anti-submarine coverage.
- Scalable but geometry-capped Science.
- Focused enemy debuffing without instant -30% spikes.
- AI-capable Node placement.

## Weaknesses

- No immediate Ancient military spike.
- Pillaging disables every Node-derived effect.
- Unit bonuses vanish away from the network.
- Multiple unprepared fronts dilute the value of preparation.
- Long-range and air warfare can pressure positions without entering every Node's influence.

## Synergies

Adjacent Nodes improve city Science/defense; Colony Nexuses add flat Science and detection; Node coverage improves Swarm Host combat; Swarm Hosts reduce the strength of units trying to pillage or break the network. None of these pieces is exceptional alone.

## Counters

Rush before the first network matures, pillage Nodes, attack from several directions, force Gabriel to project power beyond prepared territory, and use range/air/naval pressure to avoid predictable chokepoints.

## Community Patch Requirement

Requires **(1) Community Patch**, mod ID `d1b6328c-ff44-4b0d-aad7-c657f83610cd`. Development and code-level validation targeted local CP version 151 / release 5.4.2. Full Vox Populi is not required.

## Installation

1. Copy the project folder into `Documents/My Games/Sid Meier's Civilization 5/MODS`.
2. Ensure the Community Patch is installed and enabled.
3. Enable **Gabriel — The Colony Mind** in the Mods menu.
4. Start a new game; the mod affects saved-game data and should not be added mid-campaign.

## ModBuddy

Open `GabrielTheColonyMind.civ5proj` in the Civilization V SDK's ModBuddy. The project uses the existing mod ID and version, declares the Community Patch dependency, and reproduces the SQL activation order, UI add-ins, and VFS import settings from the checked-in `.modinfo`.

Use the **Default** configuration to package and deploy, **Package Only** to build without deploying, or **Deploy Only** to deploy without packaging. The project is configured for the local Civ V installation at `G:\SteamLibrary\steamapps\common\Sid Meier's Civilization V` and user data under `Documents\My Games\Sid Meier's Civilization 5`.

## Known Limitations

- The human placement panel is UI-driven, so this release declares single-player support. AI placement is deterministic, but multiplayer synchronization of human placement has not been claimed.
- CP's stable `AttackMod = 5` is used for the canonical offensive-only +5% outgoing-damage identity. This modifies attack strength rather than multiplying final post-combat HP damage by exactly 1.05.
- Civ V promotions expose one `SeeInvisible` type. The shipped detection promotion covers the standard submarine invisibility type; arbitrary invisibility types introduced by other mods are not automatically discovered.
- The supplied concept sheet provides complete portrait/icon imagery but no Civ V `.gr2` landmark model. The Node therefore uses stock Fort landmark geometry as a clear on-map marker, with a custom Colony Node portrait and unchanged custom gameplay.
- This environment supported database execution, Lua static checks, XML parsing, DDS decoding, and asset inspection, but not an actual launched Civ V session. The in-game matrix in `TESTING.md` remains the release gate.

## Technical Notes

Persistent state uses `Modding.OpenSaveData`. City keys include owner, city ID, acquisition turn, and coordinates so capture/raze/ID reuse cannot inherit a nearly complete timer. Neutral Node builder ownership is stored per plot index. Node influence and placement inspect only small local radii; no full-map scan occurs per turn. A one-time cache rebuild scans the map on Lua initialization.

The canonical +1% city defense uses CP's `BuildingDefenseModifier`. Dynamic city bonuses are represented by mutually exclusive six-tier dummy buildings. Infestation is applied from `BattleStarted`/`BattleJoined`/`BattleFinished`, never from guessed killer IDs or UI animation state.

## Art & Presentation

- Custom Gabriel diplomacy uses the generated standalone leader master, while Dawn of Man uses the dedicated Colony Network map artwork.
- The supplied dedicated Swarm Host, civilization, and Colony Nexus icons are used directly across all required atlas sizes.
- Custom civilization alpha atlases include all required sizes.
- Leader portrait atlases include 256/128/64.
- Swarm Host, Colony Nexus, Colony Node, and promotion atlases include 256/128/80/64/45/32 in a four-column layout.
- All portrait icons use a clean gold circular Civ V-style frame.
- Swarm Hosts retain the Composite Bowman's stock 3D unit model and flag formation while using custom portraits.

The reproducible art pipeline is `Tools/build_art.py`.
