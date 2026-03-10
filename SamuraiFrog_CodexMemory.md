# Samurai Frog Codex Memory

Purpose: persistent project memory distilled from `SamuraiFrog_Architecture.md` (v2.0) for future Codex sessions.

## Project Identity
- Engine: Godot 4 (2D pixel-art action platformer).
- Core fantasy: samurai frog movement + combat with expandable powers, weapons, and combos.
- Primary quality bar: player feel (jump/dash responsiveness) before content scale.

## Non-Negotiable Architecture Decisions
- Player behavior is state-machine driven.
- Player tuning is data-driven via `PlayerStats` resource and `PowerUpManager.active_stats`.
- Power-ups, weapons, and dialogue are content resources (`.tres`), not hardcoded logic.
- Cross-system communication uses signals (especially HUD, PlayerData, SaveSystem).
- Enemy design is component-based (`MovementComponent`, `AttackComponent`, optional `PhaseComponent`).
- Scene transitions should route through `SceneTransition` autoload.

## Baseline Setup Rules
- Window: `640x360`, stretch mode `canvas_items`, aspect `keep` (or `keep_height` for vertical levels).
- Pixel art safety: set texture filter to Nearest globally and per imported UI assets.
- Input actions expected:
  - `move_left`, `move_right`, `move_down`, `jump`, `dash`, `attack`, `tongue`, `swap_weapon`, `use_weapon`, `special`, `interact`, `pause`.
- Physics layers:
  - 1 World, 2 Player, 3 Enemies, 4 PlayerProjectiles, 5 EnemyProjectiles, 6 Collectibles, 7 Hazards.

## Canonical Folder Intent
- `assets/` sprites/tilemaps/audio/fonts.
- `scenes/` player, enemies(+components), levels, ui, weapons, world.
- `scripts/` player(+states), enemies(+components), systems, ui.
- `resources/` `.tres`/`.res` data definitions.
- `autoloads/` global singletons.

## Autoload Contract
Expected autoload list and role:
- `GameManager`: scene flow, pause/restart, level lifecycle signals.
- `SaveSystem`: ConfigFile persistence at `user://savegame.cfg`.
- `PlayerData`: runtime health/special/weapon signal bus.
- `DialogueManager`: dialogue orchestration and pause/unpause flow.
- `SceneTransition` (tscn): fade in/out wrapper for scene changes.
- `ShopUI` (tscn): global shop overlay.

Save data shape (key expectations):
- `currency`
- `levels_completed`
- `levels_unlocked` (starts with `level_01`)
- `weapons_collected` (starts with `sword`)
- `cards_collected`
- `power_ups_collected`
- `checkpoint_level`
- `checkpoint_position`

## Player Architecture Memory
Required player child systems:
- `PowerUpManager`, `InputBuffer`, `ComboMatcher`, `WeaponManager`, `StateMachine`.
- Utility nodes: `CoyoteTimer`, `JumpBufferTimer`, `AttackHitbox`, `Hurtbox`, `TongueRay`, `TongueAnchor`.

State priority (build order importance):
- Priority 1: `Idle`, `Run`, `Jump`, `Fall`
- Priority 2: `Dash`, `Attack`, `AirAttack`, `Hurt`, `Dead`
- Priority 3: `Tongue`, `Special`

Runtime flags expected on player:
- `is_dashing`, `is_attacking`, `is_on_tongue`, `is_invincible`, `facing_direction`, `air_jumps_remaining`.

Jump feel principles:
- Three-zone gravity: rise, apex float, fall.
- Variable jump height on early release.
- Coyote time + jump buffer.
- Optional air jump through power-up ability/stat.
- Optional fast-fall via `move_down` while airborne.

## Data-Driven Stats + Power-Ups
Core resources:
- `PlayerStats`: movement, jump, dash, combat, tongue, defense tunables.
- `StatModifier`: additive or multiplicative modifier on named stat.
- `PowerUp`: id, display metadata, icon, modifiers, `grants_ability`, special flag.

Stat rebuild order is intentional:
- Apply additive modifiers first.
- Apply multiplicative modifiers second.

Power-up extensibility rule:
- New power-up should be addable via a new `.tres` file with no code changes.

## Input Buffer + Combo Contract
- Buffer stores recent actions with timestamps (short age window).
- Matcher checks recent tail vs combo definitions with context flags (`airborne` etc.).
- Known combos include: `double_slash`, `finisher`, `dash_slash`, `aerial_slash`, `aerial_double`, `aerial_dash_slash`, `ground_slam`, `tongue_combo`.
- Attack hit windows should be animation-keyed (AnimationPlayer), not timer-driven.

## Enemy System Contract
Enemy core:
- `EnemyBase` + pluggable components.
- Movement modes: patrol, chase, flying patrol, stationary, charge.
- Attack modes: melee, ranged, aoe, leap.
- Boss-only `PhaseComponent` with health threshold signals (example 66%, 33%).

On enemy death:
- Grant currency via `SaveSystem`.
- Grant special energy via `PlayerData`.
- Play death animation and await completion before `queue_free`.

Template archetypes:
- Monkey Warrior: patrol melee.
- Tengu Archer: stationary ranged.
- Oni Lord: boss with phase swaps.

## Level + Camera Memory
Level template includes:
- `ParallaxBackground` with layered depth speeds.
- `TileMap` with separate background/collision/foreground layers.
- `Entities` container (player, enemies, collectibles, checkpoints, interactables).
- `Hazards` with kill zones.
- `LevelManager` for camera limits.

Checkpoint rule:
- Saves level name + position; can restore activation state silently when revisiting.

Kill zone rule:
- Instant player death (consume current health).

## UI/HUD Memory
Asset direction:
- Primary UI pack: Ninja Adventure style (pixel art Japanese-compatible theme).
- Font guidance: pixel fonts (m5x7, Silver, monogram), no system fonts.

Critical import settings:
- UI textures: `Filter=Nearest`, `Mipmaps=Off`, `Compression=Lossless`.
- Pixel fonts: disable antialiasing/hinting/subpixel.

HUD expectations:
- Heart container, special meter, currency display, weapon display, boss bar.
- HUD listens to signals (`PlayerData`, `SaveSystem`) instead of polling player.

Menu flow:
- Main menu: new game / continue / quit.
- Pause menu overlay under HUD.
- Shop UI opened after qualifying NPC dialogue.
- Dialogue UI consumes `interact` to advance.
- Scene transitions should use global fade autoload.

## Weapons Contract
`WeaponData` resource fields:
- `weapon_id`, `display_name`, `icon`, `projectile_scene`, `cooldown`, `damage`, `power_card`.

Weapon manager behavior:
- Load collected weapons from save.
- Support swap cycling and cooldown-governed firing.
- Emit `weapon_changed` signal through `PlayerData`.

## NPC + Dialogue Contract
`DialogueData` resource fields:
- `npc_name`, `portrait`, `lines`, `opens_shop`, `shop_inventory`.

Dialogue flow:
- `DialogueManager.start_dialogue` pauses tree and emits start.
- `advance` iterates lines then ends and emits `dialogue_ended(opens_shop)`.
- NPCs show interaction prompt near player and can trigger ShopUI after dialogue.

## Delivery Roadmap (Execution Order)
1. Core movement feel (must be excellent before expansion).
2. Power-up foundation.
3. Combat + combos.
4. First enemy.
5. Level structure + checkpoint/kill zone.
6. HUD/UI + transitions + shop loop.
7. Tongue mechanic.
8. Weapons system.
9. NPC/dialogue.
10. Full multi-level content.
11. Boss fight and boss HUD.
12. Polish/audio/VFX/beta export.

## Godot Implementation Principles
- Use `move_and_slide()` for CharacterBody2D actors.
- Use groups (`player`, `player_attack`, `enemy`, `enemy_attack`) for clean collision routing.
- Use signals for cross-system updates.
- Keep enemy stats exported and scene-authored.
- Prefer resources for new content; avoid branching code for each new item.

## Scalability Rules To Preserve
- New power-up: new `PowerUp.tres`.
- New modifiable stat: add exported property to `PlayerStats`.
- New combo: dictionary entry + animation.
- New enemy: duplicate scene and tune component exports.
- New boss: add `PhaseComponent` + override phase-change handler.
- New NPC/shop stock: update `DialogueData.tres`.
- New weapon: `WeaponData.tres` + projectile scene.

## Codex Session Usage Note
- If future tasks conflict with this memory file, prefer the newest explicit user instruction.
- If implementation differs from this memory, update this file to keep project memory current.

## Persistent User Workflow Preference
- Prefer editor-authored, explicit assets/scenes/resources over runtime script generation for content setup.
- Specifically for animation, tilesets, tilemap layers, and similar authoring systems:
  - Favor `.tscn`/`.tres` definitions wired in the editor.
  - Avoid relying on scripts to create these definitions at runtime except as temporary migration tools.
- When script-assisted generation is used temporarily, finish by baking results into explicit editor-visible assets.

## Persistent Movement Feel Preference
- Default future platformer movement/mechanic updates to include standard responsiveness/QoL systems unless the user asks otherwise.
- Baseline expected QoL set: coyote time, jump input buffering (ground + wall), brief contact grace on unstable collision edges, and forgiving wall-jump timing.
- Prioritize responsiveness and consistency over strict/raw collision timing when these trade off.

## Persistent Architecture Preference
- Implement state machines by default for all future NPC behavior and character action systems.
- Prefer explicit state scripts + transition logic over monolithic update functions for gameplay actors.
- Model gameplay state in layers: use one mutually-exclusive locomotion state, plus orthogonal condition flags (e.g., `jumping`, `attacking`, `dashing`, `being_hit`) that can be active simultaneously.
- Standardize animation flow for gameplay characters around `AnimationTree` as runtime playback, with `AnimationPlayer` clips as authored source assets.
- Default to blend-space driven locomotion in AnimationTree (`Move`, `Air`, `Wall`) to avoid dense all-to-all transition graphs.
- For shared mechanics (jump/dash/attack/hit reactions), prefer dedicated helper modules callable from multiple states instead of duplicating logic in each state script.
- Require explicit typing on newly added GDScript members and local variables in gameplay/state logic.

## Persistent Animation Constant Preference
- All animation references (animation node names, clip names, and related source-state name tokens used by animation flow) must be centralized in samurai-frog/scripts/constants/animation_constants.gd.
- Gameplay/state scripts should preload this constants file and reference named constants instead of inline animation string literals.

## Persistent Export Annotation Preference
- Do not use @export_range(...) in this project going forward.
- Use plain @export var declarations instead.
