# Patch Notes

## [1.0.0] — 2026-08-31

### Added

- Complete Gabriel / The Colony civilization definition, leader personality, city list, spies, Civilopedia, strategy, Dawn of Man text, and custom diplomacy.
- Independent, game-speed-scaled Colony Node timers for every city.
- Human Node placement panel with map highlighting, cycling, camera focus, deferral, and gameplay-side revalidation.
- Full Colony Network dashboard with live Node, readiness, unit coverage, city connection, Nexus, and preparation status.
- Deterministic AI Node scoring and automatic placement.
- Persistent neutral-Node builder ownership and foreign-claim dismantling.
- CP-native Node yields and radius-one vision.
- Dynamic nonstacking military Network promotion and Swarm Reinforcement.
- Six-tier adjacent-Node Science/defense city scaling.
- Colony Nexus University replacement with inherited CP effects, +1 Great Scientist Point, Node Science, and connected detection.
- Swarm Host Composite Bowman replacement with inherited CP data and exactly -1 Ranged Combat Strength.
- Three-tier, two-turn Infestation with battle-participant damage verification, refresh, save/load state, and upgrade handling.
- Complete custom DDS screens, civilization/alpha/leader/object atlases, and reproducible art build script.
- Database/atlas/XML validation script and in-game test matrix.

### Changed

- None; initial release.

### Balance

- Canonical balanced values: 30 Standard turns, radius-one vision/influence, +3% Combat Strength, +5% attacking strength, +3 healing, +1% Science/defense per adjacent Node, +8% Swarm Reinforcement, and -5% Infestation per stack up to -15%.

### Fixed

- Completed the Civilization and leader Civilopedia key families so every history, strategy, title, and fact section renders correctly.
- Matched the standard Community Patch starting-unit package, removing the additional custom starting unit.

### Technical

- Targets Community Patch 5.4.2 / mod version 151 without requiring full Vox Populi.
- Uses acquisition-safe city save keys and local-radius checks to avoid city-ID reuse and per-turn full-map scans.
- Declares single-player support until the placement UI is verified under network synchronization.
