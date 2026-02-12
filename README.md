# TowerDefenseMVP (Godot 4)

A small **Godot 4** tower-defense MVP built to be iterated on quickly.

- **Engine**: Godot 4.x (project currently marked with feature `4.6` in `project.godot`)
- **Main scene**: `res://main/Main.tscn`
- **Style**: minimalist visuals (procedural shapes) + lightweight synthesized SFX

This repo is intentionally a “clean foundation” for evolving toward:
- Pure TD content growth (more towers/enemies/waves)
- Hybrid TD + controllable hero (top-down)

---

## Quick Start

1. Install **Godot 4.x**.
2. Open the project folder in Godot (select `project.godot`).
3. Press Play.

The project is configured to run:
- `run/main_scene="res://main/Main.tscn"`

---

## Gameplay (Current MVP)

### Objective
Defend your base by building towers on predefined **BuildSpots**. Enemies follow the path and damage the base if they reach the end.

### Core Loop
- Place towers before or between waves.
- Start the wave.
- Earn gold by killing enemies.
- Upgrade or delete towers between waves.
- Win after all waves are cleared; lose if base HP reaches 0.

---

## Controls

### Global
- `R`
  - Restart the current scene.

### Simulation
- `P`
  - Toggle pause.
- `T`
  - Toggle speed (1x / 2x).

### Building
- Left-click a **BuildSpot**
  - Opens the build popup.

### Popups
- `Esc`
  - Close build/upgrade popup.
- Right-click
  - Close build/upgrade popup.
- Left-click outside popup
  - Close build/upgrade popup.

### Tower selection / upgrades
- Left-click a tower
  - Select it and open the upgrade popup.
- Upgrade buttons (if available)
  - Swap the tower’s `TowerDef` to the selected upgrade `TowerDef`.
- Delete tower
  - Refunds **50%** of the tower’s current `TowerDef.cost` (between waves only).

---

## What’s Implemented

### Towers
- **Basic Tower**
  - Single-target projectile.
  - Upgrades into:
    - `Rapid Basic`
    - `Heavy Basic`
- **Splash Tower**
  - Projectile that deals AoE damage on impact.
  - Upgrades into:
    - `Wide Splash`
    - `Heavy Splash`

### Tower upgrades (data-driven)
Upgrades are modeled as a **def swap**:
- Base tower has `upgrade_option_a` / `upgrade_option_b` (both `TowerDef` resources)
- Upgrade costs are `upgrade_cost_a` / `upgrade_cost_b`
- Upgrading replaces the tower’s `tower_def` and applies the new stats

Upgrades are disabled during a wave (between-waves only).

### Targeting policy (internal, data-driven)
Each `TowerDef` exports an integer `targeting_policy`:
- `0`: FIRST (default)
- `1`: LAST
- `2`: STRONG

The selection logic is implemented inside `Tower.gd` (see “Code Architecture”).

### Enemies
- **Runner**
  - Faster, low HP.
- **Tank**
  - Slower, high HP.
  - Has a light mitigation trait: `flat_damage_reduction = 2`.

### Damage mitigation trait (flat DR)
Damage is centralized via `Enemy.apply_damage(amount)`:
- Applies `flat_damage_reduction` (clamped to >= 0)
- If damage was reduced, a subtle mitigation flash triggers

### Waves
Waves are stored in `LevelDef.waves` as dictionaries.
Supported shapes:
- `composition` format
  - Example: `[{ type: "runner", count: 4 }, { type: "tank", count: 2 }]`
- `weights` format
  - Example: `{ count: 8, weights: { runner: 0.7, tank: 0.3 } }`

### Wave preview HUD
HUD includes a **Next Wave** panel that reads `LevelDef.waves` and shows a preview (counts/percentages where possible).

---

## Project Structure

Top-level folders (most relevant):
- `main/`
  - Orchestration and game session state.
- `levels/`
  - Level scene, build spots, spawner, camera rig, path visualization.
- `towers/`
  - Tower scene + tower combat logic + tower resource defs.
- `enemies/`
  - Enemy scene + enemy logic + enemy resource defs.
- `ui/`
  - HUD, build popup, upgrade popup, win/lose overlay, wave preview helper.
- `audio/`
  - `AudioManager` generates simple beep SFX at runtime.

---

## Key Scenes / Entry Points

- `res://main/Main.tscn`
  - Main playable entry scene.
- `res://levels/Level01.tscn`
  - Current level used by default.
- `res://main/GameSessionHarness.tscn`
  - A harness scene for spawning a `GameSession` + UI + level (useful for isolated testing).

---

## Data-Driven Content

### Towers: `TowerDef`
Path: `res://towers/TowerDef.gd`

`TowerDef` is a Resource describing tower stats + upgrade graph:
- `id`, `display_name`, `cost`
- `damage`, `range`, `shots_per_second`, `cooldown_sec`, `projectile_speed`
- `splash_radius`, `splash_multiplier`
- `targeting_policy`
- `upgrade_option_a`, `upgrade_option_b`
- `upgrade_cost_a`, `upgrade_cost_b`

Tower defs live in:
- `res://towers/defs/*.tres`

### Enemies: `EnemyDef`
Path: `res://enemies/EnemyDef.gd`

`EnemyDef` is a Resource describing enemy stats:
- `id`, `max_hp`, `speed`
- `leak_damage`, `reward_gold`, `color`
- `flat_damage_reduction`

Enemy defs live in:
- `res://enemies/defs/*.tres`

### Levels: `LevelDef`
Path: `res://levels/defs/LevelDef.gd`

`LevelDef` is a Resource describing the run configuration:
- `starting_gold`
- `base_hp`
- `waves` (Array of dictionaries)

Level defs live in:
- `res://levels/defs/*.tres`

---

## Code Architecture (Practical Map)

This section focuses on “where to change things” rather than perfect purity.

### `main/Main.gd`
Role: **scene orchestration + UI wiring + tower selection/upgrade UI**
- Spawns `Level`.
- Creates and owns `GameSession`.
- Connects UI signals to `GameSession` and local upgrade/delete handlers.
- Tracks `selected_tower` and shows `UpgradePopup`.

### `main/GameSession.gd`
Role: **run-state owner**
- Owns:
  - `gold`, `base_hp`
  - `waves`, `wave_index`
  - `active_enemies`, `spawn_finished`, `game_over`
  - current build selection (`selected_build_spot`)
- Wires to:
  - `HUD` for display
  - `BuildPopup` for building
  - `WinLoseOverlay` for end state
- Provides economy helpers:
  - `try_spend_gold(amount)`
  - `add_gold(amount)`
- Emits gameplay/UI-facing signals:
  - `gold_changed(new_gold)`
  - `wave_state_changed(in_progress)`
  - `tower_built(tower)`

### `levels/Level.gd`
Role: **level composition / references**
- Exposes build spots via `get_build_spots()`.
- Provides spawner/base marker references.
- Ensures a fallback path if the `Path2D` has no curve.

### `levels/EnemySpawner.gd`
Role: **wave interpretation + enemy spawning**
- Loads `EnemyDef`s.
- Resolves wave dictionaries into a spawn queue.
- Spawns `Enemy` instances attached to a `PathFollow2D`.

### `towers/Tower.gd`
Role: **combat unit**
- Maintains `enemies_in_range` via an Area2D.
- Chooses targets using the `targeting_policy`.
- Creates projectiles; on impact calls `Enemy.apply_damage()`.

### `enemies/Enemy.gd`
Role: **movement + HP + damage handling**
- Moves via `PathFollow2D.progress`.
- Owns damage application (`apply_damage`) including mitigation.
- Emits:
  - `died(reward_gold)`
  - `escaped(leak_damage)`

### UI
- `ui/HUD.gd`
  - Displays gold/base HP/wave text and next-wave preview.
- `ui/BuildPopup.gd`
  - Two build options (basic/splash).
- `ui/UpgradePopup.gd`
  - Two upgrade options + delete.
- `ui/WavePreviewHelper.gd`
  - Parses wave dictionaries into a normalized preview model for HUD.

---

## Extending the Project

### Add a new tower
1. Create a new `TowerDef` resource in `res://towers/defs/`.
2. Give it a unique `id` and set stats (`damage`, `range`, etc.).
3. To make it buildable from the build popup:
   - Update `GameSession.gd` to load the def and add a new button in `BuildPopup` (current UI is 2-button).

### Add an upgrade path
- Set `upgrade_option_a` / `upgrade_option_b` on a base `TowerDef`.
- Set `upgrade_cost_a` / `upgrade_cost_b`.
- Upgrades work via def swap; no additional code changes required.

### Add a new enemy type
1. Create an `EnemyDef` resource in `res://enemies/defs/`.
2. Add a load path in `EnemySpawner.gd` (currently hardcoded for runner/tank).
3. Reference the enemy type in `LevelDef.waves` using its `id`.

### Edit waves
- Edit `res://levels/defs/Level01Def.tres` (or another level def).
- `waves` supports:
  - `composition` (explicit counts)
  - `weights` + `count` (randomized mix)

---

## Known Limitations / MVP Tradeoffs

- Enemy types are currently loaded via hardcoded paths in `EnemySpawner.gd`.
- Splash damage currently queries all enemies via the `"enemies"` group on impact (fine at MVP scale).
- Upgrade/build UI is simple and intentionally minimal.
- Input is implemented via direct key handling in `Main` and `SimController` (InputMap actions are not yet set up).

---

## Git / Repo Hygiene Notes

A `.gitignore` is included for common Godot and OS artifacts:
- `.import/`, `.godot/`, `.export/`, `export_presets.cfg`
- `.DS_Store`, `Thumbs.db`

---

## Next Direction (Planned)

The next major intended milestone is:
- **Hero v0 (Top-Down): movement + hotkey building constrained to hero-proximity BuildSpots**

This will be implemented additively so the existing mouse-based TD loop remains playable.
