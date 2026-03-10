# Samurai Frog â€” Godot 4 Architecture & Development Guide
### Version 2.0 â€” Unified Reference Document

---

## Table of Contents

1. Project Setup
2. Autoloads (Global Singletons)
3. Player Architecture
4. Player Stats & Power-Up System
5. Input Buffer & Combo System
6. Enemy Architecture (Component-Based)
7. Level Architecture
8. Camera
9. UI / HUD
10. Weapons System
11. NPC & Dialogue System
12. Development Roadmap
13. Key Godot Tips
14. Scalability Quick Reference

---

## Part 1: Project Setup

### 1.1 Godot Project Settings

Open **Project > Project Settings** and configure:

```
Display > Window:
  Viewport Width:  640
  Viewport Height: 360
  Mode: Windowed
  Stretch Mode: canvas_items
  Stretch Aspect: keep   (or keep_height for vertical levels)

Rendering > Textures:
  Default Texture Filter: Nearest  â† CRITICAL for pixel art (prevents blurring)
```

### 1.2 Input Map

Define all actions in **Project > Project Settings > Input Map**:

```
move_left       â†’ A, Left Arrow
move_right      â†’ D, Right Arrow
jump            â†’ Space, W, Up Arrow
dash            â†’ Shift
attack          â†’ J
tongue          â†’ K
swap_weapon     â†’ Q
use_weapon      â†’ L
special         â†’ F
interact        â†’ E
pause           â†’ Escape
move_down       â†’ S, Down Arrow
```

### 1.3 Physics Layers

Define in **Project > Project Settings > Layer Names > 2D Physics**.
This prevents enemies detecting each other as players, projectiles hitting their source, etc.

```
Layer 1: World        (terrain, platforms)
Layer 2: Player
Layer 3: Enemies
Layer 4: PlayerProjectiles
Layer 5: EnemyProjectiles
Layer 6: Collectibles
Layer 7: Hazards
```

### 1.4 Folder Structure

```
res://
â”œâ”€â”€ assets/
â”‚   â”œâ”€â”€ sprites/
â”‚   â”‚   â”œâ”€â”€ player/
â”‚   â”‚   â”œâ”€â”€ enemies/
â”‚   â”‚   â”œâ”€â”€ environment/
â”‚   â”‚   â”œâ”€â”€ ui/
â”‚   â”‚   â”‚   â”œâ”€â”€ hud/          â† hearts, meters, coin icon, weapon frames
â”‚   â”‚   â”‚   â”œâ”€â”€ menus/        â† buttons, panels, backgrounds
â”‚   â”‚   â”‚   â”œâ”€â”€ dialogue/     â† dialogue box, portrait frames
â”‚   â”‚   â”‚   â””â”€â”€ shop/         â† shop panel, item slot frames
â”‚   â”‚   â””â”€â”€ effects/
â”‚   â”œâ”€â”€ tilemaps/
â”‚   â”œâ”€â”€ audio/
â”‚   â”‚   â”œâ”€â”€ music/
â”‚   â”‚   â””â”€â”€ sfx/
â”‚   â””â”€â”€ fonts/                â† .ttf files only
â”œâ”€â”€ scenes/
â”‚   â”œâ”€â”€ player/
â”‚   â”œâ”€â”€ enemies/
â”‚   â”‚   â””â”€â”€ components/
â”‚   â”œâ”€â”€ levels/
â”‚   â”œâ”€â”€ ui/
â”‚   â”œâ”€â”€ weapons/
â”‚   â””â”€â”€ world/
â”œâ”€â”€ scripts/
â”‚   â”œâ”€â”€ player/
â”‚   â”‚   â””â”€â”€ states/
â”‚   â”œâ”€â”€ enemies/
â”‚   â”‚   â””â”€â”€ components/
â”‚   â”œâ”€â”€ systems/
â”‚   â””â”€â”€ ui/
â”œâ”€â”€ resources/         â† Godot .tres / .res files (stats, weapon data, power-ups, dialogue)
â””â”€â”€ autoloads/         â† Singletons
```

---

## Part 2: Autoloads (Global Singletons)

Always available across all scenes. Add in **Project > Project Settings > Autoload** in this order:

```
Name                Path
â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
GameManager         res://autoloads/game_manager.gd
SaveSystem          res://autoloads/save_system.gd
PlayerData          res://autoloads/player_data.gd
DialogueManager     res://autoloads/dialogue_manager.gd
SceneTransition     res://scenes/ui/scene_transition.tscn
ShopUI              res://scenes/ui/shop_ui.tscn
```

### 2.1 GameManager (autoloads/game_manager.gd)

Central state hub. Handles scene transitions, level tracking, and game state.

```gdscript
extends Node

signal level_started(level_name: String)
signal level_completed(level_name: String)
signal game_paused(is_paused: bool)

var current_level: String = ""
var is_paused: bool = false

func go_to_level(level_path: String) -> void:
    SaveSystem.save_game()
    get_tree().change_scene_to_file(level_path)

func go_to_main_menu() -> void:
    get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func pause_game() -> void:
    is_paused = !is_paused
    get_tree().paused = is_paused
    emit_signal("game_paused", is_paused)

func restart_level() -> void:
    SaveSystem.load_checkpoint()
    get_tree().reload_current_scene()
```

### 2.2 SaveSystem (autoloads/save_system.gd)

All persistence via Godot's ConfigFile.

```gdscript
extends Node

const SAVE_PATH = "user://savegame.cfg"

var save_data: Dictionary = {
    "currency": 0,
    "levels_completed": [],
    "levels_unlocked": ["level_01"],
    "weapons_collected": ["sword"],
    "cards_collected": [],
    "power_ups_collected": [],
    "checkpoint_level": "",
    "checkpoint_position": Vector2.ZERO,
}

func save_game() -> void:
    var config = ConfigFile.new()
    for key in save_data:
        config.set_value("game", key, save_data[key])
    config.save(SAVE_PATH)

func load_game() -> void:
    var config = ConfigFile.new()
    if config.load(SAVE_PATH) != OK:
        return
    for key in save_data:
        if config.has_section_key("game", key):
            save_data[key] = config.get_value("game", key)

func save_checkpoint(level_name: String, position: Vector2) -> void:
    save_data["checkpoint_level"] = level_name
    save_data["checkpoint_position"] = position
    save_game()

func load_checkpoint() -> Dictionary:
    return {
        "level": save_data["checkpoint_level"],
        "position": save_data["checkpoint_position"]
    }

func add_currency(amount: int) -> void:
    save_data["currency"] += amount
    emit_signal("currency_changed", save_data["currency"])
    save_game()

func spend_currency(amount: int) -> bool:
    if save_data["currency"] >= amount:
        save_data["currency"] -= amount
        save_game()
        return true
    return false

func unlock_weapon(weapon_id: String) -> void:
    if weapon_id not in save_data["weapons_collected"]:
        save_data["weapons_collected"].append(weapon_id)
        save_game()

func unlock_power_up(power_up_id: String) -> void:
    if power_up_id not in save_data["power_ups_collected"]:
        save_data["power_ups_collected"].append(power_up_id)
        save_game()

func complete_level(level_name: String) -> void:
    if level_name not in save_data["levels_completed"]:
        save_data["levels_completed"].append(level_name)
    save_game()

signal currency_changed(new_amount: int)
```

### 2.3 PlayerData (autoloads/player_data.gd)

Runtime-only player state. Resets each level. Acts as signal bus between Player and HUD.

```gdscript
extends Node

signal health_changed(current: float, max_hp: float)
signal special_meter_changed(current: float, max_meter: float)
signal weapon_changed(weapon_id: String)

var max_health: float = 3.0
var current_health: float = 3.0
var special_meter: float = 0.0
var special_meter_max: float = 100.0
var active_weapon: String = "sword"

func take_damage(amount: float) -> void:
    current_health = max(0.0, current_health - amount)
    emit_signal("health_changed", current_health, max_health)
    if current_health <= 0.0:
        GameManager.restart_level()

func heal(amount: float) -> void:
    current_health = min(max_health, current_health + amount)
    emit_signal("health_changed", current_health, max_health)

func add_special_energy(amount: float) -> void:
    special_meter = min(special_meter_max, special_meter + amount)
    emit_signal("special_meter_changed", special_meter, special_meter_max)

func use_special() -> bool:
    if special_meter >= special_meter_max:
        special_meter = 0.0
        emit_signal("special_meter_changed", special_meter, special_meter_max)
        return true
    return false
```

### 2.4 DialogueManager (autoloads/dialogue_manager.gd)

Drives all NPC conversations. See Part 11 for full implementation.

---

## Part 3: Player Architecture
### 3.0 Implementation Standards (Required)

- Use a node-based state machine for character logic:
  - Character
  - PlayerStateMachine (or EnemyStateMachine)
  - child state nodes with one script per state
- Route reusable actions (jump, dash, attacks, damage handling) through shared helper scripts so multiple states call one implementation.
- Drive runtime animation with AnimationTree; use AnimationPlayer clips as authored source data.
- Prefer blend nodes to simplify animation graphs:
  - `Move` blend space for idle/walk/run
  - `Air` blend space for jump apex/fall
  - `Wall` blend space for contact/slide
- Keep state scripts focused on transitions, per-frame control, and calling shared action modules.
- Use explicit GDScript typing for member and local variables in gameplay code.
- Keep locomotion mutually exclusive (ground/air/wall/dead) and model overlays as orthogonal flags (attacking/dashing/being_hit/etc.).

The player uses a **State Machine** â€” the single most important architectural decision. Every behavior (idle, run, jump, attack, etc.) is an isolated state script. This keeps code clean and makes adding new states trivial.

### 3.1 Player Scene Structure

```
Player (CharacterBody2D)
â”œâ”€â”€ CollisionShape2D
â”œâ”€â”€ AnimatedSprite2D
â”œâ”€â”€ AnimationPlayer              â† drives hitbox timing via keyframes
â”œâ”€â”€ Camera2D
â”œâ”€â”€ Hurtbox (Area2D)             â† receives incoming damage
â”‚   â””â”€â”€ CollisionShape2D
â”œâ”€â”€ AttackHitbox (Area2D)        â† sword slash range
â”‚   â””â”€â”€ CollisionShape2D
â”œâ”€â”€ TongueRay (RayCast2D)        â† tongue aim and range detection
â”œâ”€â”€ TongueAnchor (Node2D)        â† grapple attachment point
â”œâ”€â”€ CoyoteTimer (Timer)          â† forgiving edge-jump window
â”œâ”€â”€ JumpBufferTimer (Timer)      â† pre-land jump input window
â”œâ”€â”€ PowerUpManager (Node)        â† manages stat modifiers (Part 4)
â”œâ”€â”€ InputBuffer (Node)           â† records recent inputs (Part 5)
â”œâ”€â”€ ComboMatcher (Node)          â† pattern-matches combos (Part 5)
â”œâ”€â”€ WeaponManager (Node)         â† active weapon and swap logic (Part 10)
â””â”€â”€ StateMachine (Node)
    â”œâ”€â”€ IdleState
    â”œâ”€â”€ RunState
    â”œâ”€â”€ JumpState
    â”œâ”€â”€ FallState
    â”œâ”€â”€ DashState
    â”œâ”€â”€ AttackState
    â”œâ”€â”€ AirAttackState
    â”œâ”€â”€ TongueState
    â”œâ”€â”€ HurtState
    â”œâ”€â”€ DeadState
    â””â”€â”€ SpecialState
```

### 3.2 State Machine Base Classes

**scripts/player/state_machine.gd**
```gdscript
extends Node
class_name StateMachine

@export var initial_state: State

var current_state: State
var states: Dictionary = {}

func _ready() -> void:
    for child in get_children():
        if child is State:
            states[child.name.to_lower()] = child
            child.state_machine = self
    if initial_state:
        initial_state.enter()
        current_state = initial_state

func _process(delta: float) -> void:
    if current_state:
        current_state.update(delta)

func _physics_process(delta: float) -> void:
    if current_state:
        current_state.physics_update(delta)

func transition_to(state_name: String) -> void:
    if not states.has(state_name):
        return
    if current_state:
        current_state.exit()
    current_state = states[state_name]
    current_state.enter()
```

**scripts/player/state.gd**
```gdscript
extends Node
class_name State

var state_machine: StateMachine
var player: CharacterBody2D

func _ready() -> void:
    await owner.ready
    player = owner as CharacterBody2D

func enter() -> void:
    pass

func exit() -> void:
    pass

func update(_delta: float) -> void:
    pass

func physics_update(_delta: float) -> void:
    pass
```

### 3.3 States to Implement (in priority order)

| State | Priority | Notes |
|---|---|---|
| Idle | 1 | Stand, breathe animation |
| Run | 1 | Horizontal movement, sprite flip |
| Jump | 1 | Variable height, coyote, buffer, apex float |
| Fall | 1 | Fast fall gravity, land detection |
| Dash | 2 | Burst velocity, brief iframes |
| Attack | 2 | Combo chain, hitbox via AnimationPlayer |
| AirAttack | 2 | Aerial slash variants |
| Hurt | 2 | Knockback, invincibility frames |
| Dead | 2 | Death anim, trigger restart |
| Tongue | 3 | Grapple physics, swing, ranged hit |
| Special | 3 | Power surge activation + duration |

### 3.4 Player Main Script (scripts/player/player.gd)

All movement values are read from `power_up_manager.active_stats` (see Part 4) â€” never hardcoded.

```gdscript
extends CharacterBody2D

# Runtime state flags â€” read by states
var is_dashing: bool = false
var is_attacking: bool = false
var is_on_tongue: bool = false
var is_invincible: bool = false
var facing_direction: float = 1.0
var air_jumps_remaining: int = 0   # set from active_stats.max_air_jumps

# Node references
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var hurtbox: Area2D = $Hurtbox
@onready var coyote_timer: Timer = $CoyoteTimer
@onready var jump_buffer_timer: Timer = $JumpBufferTimer
@onready var state_machine: StateMachine = $StateMachine
@onready var power_up_manager: PowerUpManager = $PowerUpManager
@onready var input_buffer: InputBuffer = $InputBuffer
@onready var combo_matcher: ComboMatcher = $ComboMatcher
@onready var weapon_manager: WeaponManager = $WeaponManager

func _ready() -> void:
    add_to_group("player")
    hurtbox.area_entered.connect(_on_hurtbox_area_entered)
    air_jumps_remaining = power_up_manager.active_stats.max_air_jumps

func flip_sprite() -> void:
    sprite.flip_h = facing_direction == -1

func apply_gravity(delta: float, multiplier: float = 1.0) -> void:
    var stats = power_up_manager.active_stats
    velocity.y += stats.gravity * multiplier * delta

func _on_hurtbox_area_entered(area: Area2D) -> void:
    if is_invincible:
        return
    if area.is_in_group("enemy_attack"):
        var damage = area.get_parent().attack.attack_damage
        PlayerData.take_damage(damage)
        state_machine.transition_to("hurt")
```

### 3.5 Jump State â€” Variable Height Implementation

This is the core of what makes the frog's jump feel great. Three separate gravity multipliers control rise, apex float, and fall.

```gdscript
# scripts/player/states/jump_state.gd
extends State

func enter() -> void:
    var stats = player.power_up_manager.active_stats
    player.velocity.y = stats.jump_velocity
    player.sprite.play("jump")

func physics_update(delta: float) -> void:
    var stats = player.power_up_manager.active_stats

    # Horizontal control (slightly reduced in air)
    var dir = Input.get_axis("move_left", "move_right")
    if dir != 0:
        player.facing_direction = dir
        player.flip_sprite()
    player.velocity.x = move_toward(
        player.velocity.x,
        dir * stats.run_speed,
        stats.acceleration * delta
    )

    # Three-zone gravity
    var grav_mult: float
    if abs(player.velocity.y) < stats.apex_threshold:
        grav_mult = stats.apex_gravity_multiplier   # float at top
    elif player.velocity.y > 0:
        grav_mult = stats.fall_gravity_multiplier   # fast fall down
    else:
        grav_mult = 1.0                             # normal rise

    # Holding move_down in the air triggers an accelerated fast-fall
    # (distinct from ground slam â€” slam requires move_down + attack)
    if Input.is_action_pressed("move_down") and player.velocity.y > 0:
        grav_mult = stats.fall_gravity_multiplier * 2.0

    player.velocity.y += stats.gravity * grav_mult * delta

    # Variable height: releasing jump early cuts upward velocity
    if not Input.is_action_pressed("jump") and player.velocity.y < stats.min_jump_velocity:
        player.velocity.y = stats.min_jump_velocity

    # Double jump â€” only if power-up grants it
    if Input.is_action_just_pressed("jump") and player.air_jumps_remaining > 0:
        player.velocity.y = stats.jump_velocity
        player.air_jumps_remaining -= 1
        player.sprite.play("double_jump")

    player.move_and_slide()

    # Land
    if player.is_on_floor():
        player.air_jumps_remaining = stats.max_air_jumps
        state_machine.transition_to("idle" if dir == 0 else "run")

    # Wall jump
    if player.is_on_wall() and Input.is_action_just_pressed("jump"):
        player.velocity.y = stats.jump_velocity
        player.velocity.x = -player.facing_direction * stats.run_speed
        player.facing_direction *= -1
        player.flip_sprite()
```

---

## Part 4: Player Stats & Power-Up System

All tunable player values live in a `PlayerStats` resource. `PowerUpManager` maintains a clean base copy and rebuilds a modified `active_stats` copy whenever power-ups are equipped or removed. The player always reads from `active_stats` â€” never from hardcoded constants.

**Adding a new power-up requires zero code changes â€” just a new `.tres` file.**

### 4.1 PlayerStats Resource (resources/player_stats.gd)

```gdscript
extends Resource
class_name PlayerStats

# Movement
@export var walk_speed: float = 120.0
@export var run_speed: float = 200.0
@export var acceleration: float = 800.0
@export var friction: float = 900.0

# Jump
@export var jump_velocity: float = -380.0       # applied on jump press
@export var min_jump_velocity: float = -180.0   # velocity floor when jump released early
@export var gravity: float = 900.0
@export var fall_gravity_multiplier: float = 1.4  # faster fall than rise
@export var apex_gravity_multiplier: float = 0.4  # floaty at top of arc
@export var apex_threshold: float = 80.0          # abs(vel.y) below this = "at apex"
@export var coyote_time: float = 0.10
@export var jump_buffer_time: float = 0.10
@export var max_air_jumps: int = 0              # 0 = no double jump; power-up raises to 1

# Dash
@export var dash_speed: float = 400.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 1.0
@export var max_dash_charges: int = 1

# Combat
@export var attack_damage: float = 1.0
@export var attack_speed_multiplier: float = 1.0
@export var combo_window: float = 0.5

# Tongue
@export var tongue_range: float = 180.0
@export var tongue_speed: float = 600.0
@export var tongue_damage: float = 0.5
@export var tongue_grapple_swing_force: float = 350.0

# Defense
@export var max_health: float = 3.0
@export var invincibility_duration: float = 0.8
@export var knockback_resistance: float = 0.0   # 0.0â€“1.0
```

Create `res://resources/base_player_stats.tres` in the Godot editor using this script and set your baseline values there.

### 4.2 StatModifier Resource (resources/stat_modifier.gd)

```gdscript
extends Resource
class_name StatModifier

enum ModifierType { ADDITIVE, MULTIPLICATIVE }

@export var stat_name: String = ""        # must exactly match a PlayerStats property name
@export var modifier_type: ModifierType = ModifierType.ADDITIVE
@export var value: float = 0.0           # ADDITIVE: flat bonus. MULTIPLICATIVE: 0.25 = +25%
```

### 4.3 PowerUp Resource (resources/power_up.gd)

```gdscript
extends Resource
class_name PowerUp

@export var power_up_id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var icon: Texture2D
@export var modifiers: Array[StatModifier] = []
@export var grants_ability: String = ""   # e.g. "double_jump", "wall_cling", "fire_breath"
@export var is_special_power: bool = false  # true = loadout special, not passive card
```

**Example power-up `.tres` files to create in the editor:**

```
# cloud_step.tres  (double jump card)
  power_up_id:    "double_jump"
  display_name:   "Cloud Step"
  grants_ability: "double_jump"
  modifiers:      []

# iron_legs.tres  (high jump card)
  power_up_id:   "high_jump"
  display_name:  "Iron Legs"
  modifiers:     [{ stat_name: "jump_velocity", type: MULTIPLICATIVE, value: 0.25 }]

# swift_blade.tres  (attack speed card)
  power_up_id:   "swift_blade"
  display_name:  "Swift Blade"
  modifiers:     [{ stat_name: "attack_speed_multiplier", type: MULTIPLICATIVE, value: 0.4 }]
```

### 4.4 PowerUpManager (scripts/systems/power_up_manager.gd)

Attach to Player node.

```gdscript
extends Node
class_name PowerUpManager

var base_stats: PlayerStats
var active_stats: PlayerStats
var active_modifiers: Array[StatModifier] = []
var granted_abilities: Array[String] = []
var equipped_power_ups: Array[PowerUp] = []

func _ready() -> void:
    base_stats = load("res://resources/base_player_stats.tres")
    _rebuild_stats()

func equip_power_up(power_up: PowerUp) -> void:
    equipped_power_ups.append(power_up)
    for modifier in power_up.modifiers:
        active_modifiers.append(modifier)
    if power_up.grants_ability != "":
        granted_abilities.append(power_up.grants_ability)
    _rebuild_stats()

func remove_power_up(power_up_id: String) -> void:
    equipped_power_ups = equipped_power_ups.filter(func(p): return p.power_up_id != power_up_id)
    _rebuild_all_modifiers()
    _rebuild_stats()

func has_ability(ability_name: String) -> bool:
    return ability_name in granted_abilities

func _rebuild_all_modifiers() -> void:
    active_modifiers.clear()
    granted_abilities.clear()
    for power_up in equipped_power_ups:
        for modifier in power_up.modifiers:
            active_modifiers.append(modifier)
        if power_up.grants_ability != "":
            granted_abilities.append(power_up.grants_ability)

func _rebuild_stats() -> void:
    active_stats = base_stats.duplicate()
    # Additive pass first
    for mod in active_modifiers:
        if mod.modifier_type == StatModifier.ModifierType.ADDITIVE:
            active_stats.set(mod.stat_name, active_stats.get(mod.stat_name) + mod.value)
    # Multiplicative pass second
    for mod in active_modifiers:
        if mod.modifier_type == StatModifier.ModifierType.MULTIPLICATIVE:
            active_stats.set(mod.stat_name, active_stats.get(mod.stat_name) * (1.0 + mod.value))
```

---

## Part 5: Input Buffer & Combo System

An **InputBuffer** records the last N inputs with timestamps. **ComboMatcher** checks whether the tail of the buffer matches any registered combo definition. Adding a new combo is one line in the `COMBOS` dictionary plus a matching animation â€” no structural changes needed.

### 5.1 InputBuffer (scripts/systems/input_buffer.gd)

```gdscript
extends Node
class_name InputBuffer

const BUFFER_SIZE: int = 6
const INPUT_MAX_AGE: float = 0.6   # discard inputs older than this

var _buffer: Array = []

const WATCHED_ACTIONS: Array = ["jump", "attack", "dash", "tongue", "use_weapon", "move_down"]

func _input(event: InputEvent) -> void:
    for action in WATCHED_ACTIONS:
        if event.is_action_pressed(action):
            _buffer.append({ "action": action, "time": Time.get_ticks_msec() / 1000.0 })
            if _buffer.size() > BUFFER_SIZE:
                _buffer.pop_front()

func get_recent(max_age: float = INPUT_MAX_AGE) -> Array:
    var now = Time.get_ticks_msec() / 1000.0
    return _buffer.filter(func(e): return (now - e["time"]) <= max_age)

func consume(action: String) -> void:
    for i in range(_buffer.size() - 1, -1, -1):
        if _buffer[i]["action"] == action:
            _buffer.remove_at(i)
            return

func clear() -> void:
    _buffer.clear()
```

### 5.2 ComboMatcher (scripts/systems/combo_matcher.gd)

```gdscript
extends Node
class_name ComboMatcher

# Add new combos here â€” no other code changes required.
# "airborne" and "holding_down" are context flags checked at match time.
const COMBOS: Dictionary = {
    "double_slash":       { "inputs": ["attack", "attack"],          "airborne": false },
    "finisher":           { "inputs": ["attack", "attack", "attack"],"airborne": false },
    "dash_slash":         { "inputs": ["dash", "attack"],            "airborne": false },
    "aerial_slash":       { "inputs": ["attack"],                    "airborne": true  },
    "aerial_double":      { "inputs": ["attack", "attack"],          "airborne": true  },
    "aerial_dash_slash":  { "inputs": ["dash", "attack"],            "airborne": true  },
    "ground_slam":        { "inputs": ["move_down", "attack"],       "airborne": true  },
    "tongue_combo":       { "inputs": ["tongue", "attack"],          "airborne": false },
}

func match_combo(buffer: InputBuffer, is_airborne: bool) -> String:
    var recent = buffer.get_recent()
    if recent.is_empty():
        return ""

    for combo_name in COMBOS:
        var combo = COMBOS[combo_name]
        if combo.get("airborne", false) != is_airborne:
            continue
        var seq: Array = combo["inputs"]
        if recent.size() < seq.size():
            continue
        var tail = recent.slice(recent.size() - seq.size())
        var matched = true
        for i in range(seq.size()):
            if tail[i]["action"] != seq[i]:
                matched = false
                break
        if matched:
            return combo_name

    return ""
```

**Using the combo matcher in the Attack state:**

```gdscript
# scripts/player/states/attack_state.gd
extends State

func enter() -> void:
    var is_airborne = not player.is_on_floor()
    var combo = player.combo_matcher.match_combo(player.input_buffer, is_airborne)

    match combo:
        "finisher":          player.sprite.play("attack_finisher")
        "double_slash":      player.sprite.play("attack_double")
        "dash_slash":        player.sprite.play("attack_dash")
        "ground_slam":       _begin_ground_slam()
        "aerial_slash":      player.sprite.play("attack_air")
        "aerial_double":     player.sprite.play("attack_air_double")
        "aerial_dash_slash": player.sprite.play("attack_air_dash")
        "tongue_combo":      player.sprite.play("attack_tongue_follow")
        _:                   player.sprite.play("attack_basic")

    # AnimationPlayer keyframes enable/disable AttackHitbox.monitoring
    # at the exact frames the hit should register

func _begin_ground_slam() -> void:
    # Spike velocity downward â€” player plunges straight down
    player.velocity.y = 600.0
    player.velocity.x = 0.0
    player.sprite.play("attack_slam")
    # On landing (is_on_floor() in physics_update), trigger slam shockwave hitbox
    # and transition back to idle/attack depending on whether an enemy was hit
```

---

## Part 6: Enemy Architecture (Component-Based)

Enemies are assembled from pluggable **components** set via `@export` in the editor. Adding a new enemy type means duplicating a scene and changing component values â€” no new base class logic required. Bosses add a `PhaseComponent` that fires a signal at health thresholds.

### 6.1 MovementComponent (scripts/enemies/components/movement_component.gd)

```gdscript
extends Node
class_name MovementComponent

enum MovementType { PATROL, CHASE, FLYING_PATROL, STATIONARY, CHARGE }

@export var movement_type: MovementType = MovementType.PATROL
@export var move_speed: float = 60.0
@export var aggro_range: float = 200.0
@export var patrol_distance: float = 80.0

var enemy: EnemyBase
var patrol_origin: Vector2
var patrol_direction: float = 1.0

func _ready() -> void:
    enemy = get_parent()
    patrol_origin = enemy.global_position

func execute(delta: float) -> void:
    match movement_type:
        MovementType.PATROL:        _patrol(delta)
        MovementType.CHASE:         _chase(delta)
        MovementType.FLYING_PATROL: _flying_patrol(delta)
        MovementType.CHARGE:        _charge(delta)
        MovementType.STATIONARY:    pass

func _patrol(_delta: float) -> void:
    enemy.velocity.x = move_speed * patrol_direction
    if abs(enemy.global_position.x - patrol_origin.x) > patrol_distance or enemy.is_on_wall():
        patrol_direction *= -1
    if enemy.player and enemy.global_position.distance_to(enemy.player.global_position) < aggro_range:
        movement_type = MovementType.CHASE

func _chase(_delta: float) -> void:
    if not enemy.player:
        return
    var dir = sign(enemy.player.global_position.x - enemy.global_position.x)
    enemy.velocity.x = move_speed * 1.5 * dir
    if enemy.player.global_position.distance_to(enemy.global_position) > aggro_range * 1.5:
        movement_type = MovementType.PATROL

func _flying_patrol(_delta: float) -> void:
    enemy.velocity.x = move_speed * patrol_direction
    enemy.velocity.y = sin(Time.get_ticks_msec() * 0.003) * 40.0
    if abs(enemy.global_position.x - patrol_origin.x) > patrol_distance:
        patrol_direction *= -1

func _charge(_delta: float) -> void:
    if not enemy.player:
        return
    var dir = sign(enemy.player.global_position.x - enemy.global_position.x)
    enemy.velocity.x = move_speed * 2.5 * dir
```

### 6.2 AttackComponent (scripts/enemies/components/attack_component.gd)

```gdscript
extends Node
class_name AttackComponent

enum AttackType { MELEE, RANGED, AOE, LEAP }

@export var attack_type: AttackType = AttackType.MELEE
@export var attack_range: float = 40.0
@export var attack_damage: float = 1.0
@export var attack_cooldown: float = 1.5
@export var projectile_scene: PackedScene
@export var leap_force: Vector2 = Vector2(150, -300)

var enemy: EnemyBase
var cooldown_timer: float = 0.0

func _ready() -> void:
    enemy = get_parent()

func update(delta: float) -> void:
    if cooldown_timer > 0:
        cooldown_timer -= delta

func can_attack() -> bool:
    if not enemy.player:
        return false
    return enemy.global_position.distance_to(enemy.player.global_position) <= attack_range \
        and cooldown_timer <= 0

func execute_attack() -> void:
    cooldown_timer = attack_cooldown
    match attack_type:
        AttackType.MELEE:  _melee()
        AttackType.RANGED: _ranged()
        AttackType.AOE:    _aoe()
        AttackType.LEAP:   _leap()

func _melee() -> void:
    enemy.animated_sprite.play("attack")
    # Hitbox timing controlled by AnimationPlayer keyframes

func _ranged() -> void:
    if not projectile_scene:
        return
    var proj = projectile_scene.instantiate()
    enemy.get_tree().current_scene.add_child(proj)
    proj.global_position = enemy.global_position
    proj.direction = (enemy.player.global_position - enemy.global_position).normalized()
    proj.damage = attack_damage
    enemy.animated_sprite.play("shoot")

func _aoe() -> void:
    enemy.animated_sprite.play("aoe")

func _leap() -> void:
    var dir = sign(enemy.player.global_position.x - enemy.global_position.x)
    enemy.velocity = Vector2(leap_force.x * dir, leap_force.y)
    enemy.animated_sprite.play("leap")
```

### 6.3 PhaseComponent â€” Bosses Only (scripts/enemies/components/phase_component.gd)

```gdscript
extends Node
class_name PhaseComponent

signal phase_changed(new_phase: int)

@export var phase_thresholds: Array[float] = [0.66, 0.33]
# e.g. [0.66, 0.33] â†’ phase 2 at 66% hp, phase 3 at 33% hp

var current_phase: int = 1
var enemy: EnemyBase

func _ready() -> void:
    enemy = get_parent()

func check_phase(health_percent: float) -> void:
    for i in range(phase_thresholds.size()):
        if health_percent <= phase_thresholds[i] and current_phase == i + 1:
            current_phase = i + 2
            emit_signal("phase_changed", current_phase)
            break
```

### 6.4 EnemyBase (scripts/enemies/enemy_base.gd)

```gdscript
extends CharacterBody2D
class_name EnemyBase

@export var max_health: float = 3.0
@export var currency_drop: int = 5
@export var special_energy_grant: float = 10.0

var current_health: float
var is_dead: bool = false
var player: CharacterBody2D

@onready var movement: MovementComponent = $MovementComponent
@onready var attack: AttackComponent = $AttackComponent
@onready var phase: PhaseComponent = $PhaseComponent   # null if not present (use has_node check)
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: Area2D = $Hurtbox

const GRAVITY: float = 900.0

func _ready() -> void:
    current_health = max_health
    add_to_group("enemy")
    player = get_tree().get_first_node_in_group("player")
    hurtbox.area_entered.connect(_on_hurtbox_area_entered)
    if has_node("PhaseComponent"):
        phase.phase_changed.connect(_on_phase_changed)

func _physics_process(delta: float) -> void:
    if is_dead:
        return
    if movement:
        movement.execute(delta)
    if attack:
        attack.update(delta)
        if attack.can_attack():
            attack.execute_attack()
    if not _is_flying():
        if not is_on_floor():
            velocity.y += GRAVITY * delta
    move_and_slide()
    _update_facing()

func _is_flying() -> bool:
    return movement and movement.movement_type == MovementComponent.MovementType.FLYING_PATROL

func _update_facing() -> void:
    if player:
        animated_sprite.flip_h = player.global_position.x < global_position.x

func _on_hurtbox_area_entered(area: Area2D) -> void:
    if area.is_in_group("player_attack"):
        take_damage(area.get_parent().power_up_manager.active_stats.attack_damage)

func take_damage(amount: float) -> void:
    if is_dead:
        return
    current_health -= amount
    if has_node("PhaseComponent"):
        phase.check_phase(current_health / max_health)
    if current_health <= 0:
        die()

func die() -> void:
    is_dead = true
    SaveSystem.add_currency(currency_drop)
    PlayerData.add_special_energy(special_energy_grant)
    animated_sprite.play("death")
    await animated_sprite.animation_finished
    queue_free()

func _on_phase_changed(new_phase: int) -> void:
    pass  # Override in boss subclass scripts
```

### 6.5 Enemy Scene Templates

```
# MONKEY WARRIOR
MonkeyWarrior (EnemyBase)  max_health=2, currency_drop=3
â”œâ”€â”€ MovementComponent       type=PATROL, speed=60, aggro_range=180, patrol_distance=80
â”œâ”€â”€ AttackComponent         type=MELEE, range=40, damage=1.0, cooldown=1.2
â”œâ”€â”€ AnimatedSprite2D
â”œâ”€â”€ Hurtbox (Area2D)
â””â”€â”€ CollisionShape2D

# TENGU ARCHER
TenguArcher (EnemyBase)    max_health=2, currency_drop=5
â”œâ”€â”€ MovementComponent       type=STATIONARY
â”œâ”€â”€ AttackComponent         type=RANGED, range=250, damage=0.5, cooldown=2.0, projectile=arrow.tscn
â”œâ”€â”€ AnimatedSprite2D
â”œâ”€â”€ Hurtbox (Area2D)
â””â”€â”€ CollisionShape2D

# ONI LORD (BOSS)
OniLord (EnemyBase + subclass script)  max_health=20, currency_drop=50
â”œâ”€â”€ MovementComponent       type=CHARGE, speed=120
â”œâ”€â”€ AttackComponent         type=MELEE, range=60, damage=1.5, cooldown=2.0
â”œâ”€â”€ PhaseComponent          thresholds=[0.66, 0.33]
â”œâ”€â”€ AnimatedSprite2D
â”œâ”€â”€ Hurtbox (Area2D)
â””â”€â”€ CollisionShape2D
# OniLord script only overrides _on_phase_changed() to swap component types per phase
```

---

## Part 7: Level Architecture

### 7.1 Level Scene Structure

```
Level_01 (Node2D)
â”œâ”€â”€ WorldEnvironment
â”œâ”€â”€ ParallaxBackground
â”‚   â”œâ”€â”€ ParallaxLayer  (motion_scale: 0.10, 0.05 â€” distant mountains/sky)
â”‚   â”œâ”€â”€ ParallaxLayer  (motion_scale: 0.20, 0.10 â€” mid fog/cliffs)
â”‚   â”œâ”€â”€ ParallaxLayer  (motion_scale: 0.50, 0.20 â€” trees/close cliffs)
â”‚   â””â”€â”€ ParallaxLayer  (motion_scale: 0.80, 0.40 â€” foreground detail)
â”œâ”€â”€ TileMap
â”‚   â”œâ”€â”€ Layer 0: Background decoration (no collision)
â”‚   â”œâ”€â”€ Layer 1: Main terrain (collision enabled in TileSet)
â”‚   â””â”€â”€ Layer 2: Foreground detail (no collision, renders in front)
â”œâ”€â”€ Entities (Node2D)
â”‚   â”œâ”€â”€ Player
â”‚   â”œâ”€â”€ Enemies (Node2D)
â”‚   â”œâ”€â”€ Collectibles (Node2D)
â”‚   â”œâ”€â”€ Checkpoints (Node2D)
â”‚   â””â”€â”€ Interactables (Node2D)   â† NPCs, shops
â”œâ”€â”€ Hazards (Node2D)
â”‚   â””â”€â”€ KillZone (Area2D)        â† pits, instant death
â”œâ”€â”€ Camera2D                     â† child of Player
â””â”€â”€ LevelManager (Node)
```

### 7.2 Checkpoint (scenes/world/checkpoint.gd)

```gdscript
extends Area2D

var is_activated: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
    body_entered.connect(_on_body_entered)
    # Silently restore if this was the saved checkpoint
    var cp = SaveSystem.load_checkpoint()
    if cp["level"] == get_tree().current_scene.name \
    and cp["position"].distance_to(global_position) < 10:
        _activate(false)

func _on_body_entered(body: Node2D) -> void:
    if body.is_in_group("player") and not is_activated:
        _activate(true)

func _activate(play_effect: bool) -> void:
    is_activated = true
    sprite.play("activate" if play_effect else "active")
    if play_effect:
        SaveSystem.save_checkpoint(get_tree().current_scene.name, global_position)
```

### 7.3 Kill Zone (scenes/world/kill_zone.gd)

```gdscript
extends Area2D

func _ready() -> void:
    body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
    if body.is_in_group("player"):
        PlayerData.take_damage(PlayerData.current_health)  # instant kill
```

---

## Part 8: Camera

### 8.1 Camera2D Setup

Place Camera2D as a child of the Player node. Configure in the Godot editor:

```
Position Smoothing: Enabled, Speed = 5.0
Drag Horizontal / Vertical: Enabled, small margins
Zoom: Vector2(1, 1)
Limits: Set by LevelManager at runtime
```

### 8.2 LevelManager (scripts/levels/level_manager.gd)

```gdscript
extends Node

@export var level_width: int = 3200
@export var level_height: int = 2880

func _ready() -> void:
    var player = get_tree().get_first_node_in_group("player")
    if player:
        var cam: Camera2D = player.get_node("Camera2D")
        cam.limit_left = 0
        cam.limit_right = level_width
        cam.limit_top = -level_height
        cam.limit_bottom = 0
```

---

## Part 9: UI / HUD

### 9.0 UI Asset Packs & Fonts

Before building any UI scene, source your visual assets first. The architecture uses
`@export var` textures throughout â€” you assign the actual images in the Godot editor
after importing. Below are the recommended packs for this game's theme.

#### Recommended UI Asset Packs

**[Ninja Adventure Asset Pack by pixel-boy](https://pixel-boy.itch.io/ninja-adventure-asset-pack)** â­ FREE (CC0)
The single most valuable UI find for this project. Despite the top-down RPG origin,
it includes a complete UI theme: dialogue boxes, menu panels, buttons, health bars,
hearts, HUD frames, item slots, and icons â€” all in a Japanese/ninja pixel art style
that matches your game's aesthetic directly. CC0 license means zero restrictions,
even commercially. This should be your primary UI source for the entire beta.

**[Basic Pixel Health Bar and Scroll Bar by BDragon1727](https://bdragons.itch.io/basic-pixel-health-bar)** FREE
Simple animated hearts (full, half, empty) and bar variants. Clean 16Ã—16 and 32Ã—32
versions available. Use if the Ninja Adventure hearts don't match your style.

**[Free Pixel Art Health Hearts 16Ã—16](https://itch.io/game-assets/free/tag-health/tag-pixel-art)**
Standalone heart sprites in multiple states. Good backup option.

**[Complete UI Essential Pack by Crusenho](https://crusenho.itch.io/complete-ui-essential-pack)** ~$5
32Ã—32 resizeable UI elements with Aseprite source files included. Useful if you want
to recolor or modify panel frames to better match your Japanese theme.

**[Pixel Fantasy RPG Icons (Free Collection)](https://itch.io/game-assets/free/tag-pixel-art/tag-icons)**
Consolidated free icon sheet â€” good source for weapon icons (sword, kunai, shuriken)
visible in the weapon slot on the HUD.

#### Recommended Fonts

Fonts are one of the most visible things in your UI and the most commonly neglected.
Never use a system font like Arial in a pixel art game â€” it will look immediately wrong.

**[m5x7 by Daniel Linssen](https://managore.itch.io/m5x7)** â­ FREE (CC0)
The single most-used indie game pixel font. Clean, readable at small sizes, with a
slightly calligraphic quality that suits a Japanese-themed game. Use this for all
body text: dialogue, menus, currency counter, damage numbers.

**[Silver by Nokta Games](https://noktabox.itch.io/silver)** FREE
Slightly more angular and bold than m5x7. Use for headings, boss names, level titles.
Pairs well with m5x7 as a complementary display font.

**[monogram by datagoblin](https://datagoblin.itch.io/monogram)** FREE
Elegant monospace pixel font. Good for numerical displays (currency, timers).

All three are TTF format. Import them into `res://assets/fonts/` and use them via
`FontFile` resources in your Theme or directly on Label nodes.

#### Godot Font Setup

```gdscript
# In your UI Theme resource (Project > Project Settings > GUI > Theme):
# Or directly on each Label node:
# Label > Control > Theme Overrides > Fonts > font â†’ load your .ttf

# CRITICAL import setting for pixel fonts â€” prevent blurring:
# Select the .ttf in FileSystem â†’ Import tab:
#   Antialiasing: None
#   Hinting: None
#   Subpixel Positioning: Disabled
#   Size: 16 (or 32 for large displays â€” always multiples of the base size)
```

---

#### CRITICAL: UI Texture Import Settings

Pixel art textures blur by default in Godot. Every UI image needs these import settings
or it will look smeared. Select the texture in the FileSystem panel â†’ Import tab:

```
Filter: Nearest          â† MOST IMPORTANT â€” prevents blurring
Mipmaps: Off
Compression: Lossless
```

You set this once per texture. For bulk changes, select multiple files â†’ Import tab â†’ Apply.
Creating a default import preset (Editor > Manage Import Presets) saves time when
importing many assets at once.

---

### 9.1 HUD Scene Structure

```
HUD (CanvasLayer)
â”œâ”€â”€ HeartContainer (HBoxContainer)     â† up to 5 TextureRect nodes (3 base + armor)
â”œâ”€â”€ SpecialMeter (TextureProgressBar)
â”œâ”€â”€ CurrencyDisplay (HBoxContainer)
â”‚   â”œâ”€â”€ CoinIcon (TextureRect)
â”‚   â””â”€â”€ CurrencyLabel (Label)          â† font: monogram
â”œâ”€â”€ WeaponDisplay (HBoxContainer)
â”‚   â”œâ”€â”€ WeaponFrame (TextureRect)      â† decorative slot border
â”‚   â””â”€â”€ ActiveWeaponIcon (TextureRect) â† weapon icon from WeaponData.icon
â””â”€â”€ BossHealthBar (VBoxContainer)      â† hidden until boss fight begins
    â”œâ”€â”€ BossNameLabel (Label)          â† font: Silver
    â””â”€â”€ BossBar (TextureProgressBar)
```

### 9.2 HUD Script (scripts/ui/hud.gd)

```gdscript
extends CanvasLayer

@onready var heart_container: HBoxContainer = $HeartContainer
@onready var special_meter: TextureProgressBar = $SpecialMeter
@onready var currency_label: Label = $CurrencyDisplay/CurrencyLabel
@onready var weapon_icon: TextureRect = $WeaponDisplay/ActiveWeaponIcon
@onready var boss_bar: VBoxContainer = $BossHealthBar

@export var full_heart: Texture2D
@export var half_heart: Texture2D
@export var empty_heart: Texture2D

func _ready() -> void:
    PlayerData.health_changed.connect(_on_health_changed)
    PlayerData.special_meter_changed.connect(_on_special_changed)
    SaveSystem.currency_changed.connect(_on_currency_changed)
    PlayerData.weapon_changed.connect(_on_weapon_changed)
    boss_bar.hide()
    _update_hearts(PlayerData.current_health, PlayerData.max_health)
    _on_currency_changed(SaveSystem.save_data["currency"])

func _update_hearts(current: float, maximum: float) -> void:
    var hearts = heart_container.get_children()
    var remaining = current
    for heart in hearts:
        if remaining >= 1.0:
            heart.texture = full_heart
        elif remaining == 0.5:
            heart.texture = half_heart
        else:
            heart.texture = empty_heart
        remaining -= 1.0

func _on_health_changed(current: float, maximum: float) -> void:
    _update_hearts(current, maximum)

func _on_special_changed(current: float, maximum: float) -> void:
    special_meter.value = (current / maximum) * 100.0

func _on_currency_changed(amount: int) -> void:
    currency_label.text = str(amount)

func _on_weapon_changed(weapon_id: String) -> void:
    var weapon_data = load("res://resources/weapons/%s.tres" % weapon_id) as WeaponData
    if weapon_data:
        weapon_icon.texture = weapon_data.icon

func show_boss_bar(boss_name: String) -> void:
    boss_bar.get_node("BossNameLabel").text = boss_name
    boss_bar.show()

func hide_boss_bar() -> void:
    boss_bar.hide()
```

---

### 9.3 Main Menu (scenes/ui/main_menu.tscn)

```
MainMenu (CanvasLayer)
â”œâ”€â”€ Background (TextureRect)          â† static art or parallax preview
â”œâ”€â”€ TitleLabel (Label)                â† "SAMURAI FROG", font: Silver, large
â”œâ”€â”€ ButtonContainer (VBoxContainer)
â”‚   â”œâ”€â”€ NewGameButton (Button)
â”‚   â”œâ”€â”€ ContinueButton (Button)       â† disabled if no save file exists
â”‚   â””â”€â”€ QuitButton (Button)
â””â”€â”€ VersionLabel (Label)              â† "v0.1 Beta", font: m5x7, small, bottom corner
```

```gdscript
# scripts/ui/main_menu.gd
extends CanvasLayer

@onready var continue_button: Button = $ButtonContainer/ContinueButton

func _ready() -> void:
    SaveSystem.load_game()
    # Disable Continue if no save exists
    var has_save = SaveSystem.save_data["levels_completed"].size() > 0 \
                or SaveSystem.save_data["checkpoint_level"] != ""
    continue_button.disabled = not has_save

func _on_new_game_button_pressed() -> void:
    # Wipe save and start fresh
    SaveSystem.save_data = {
        "currency": 0,
        "levels_completed": [],
        "levels_unlocked": ["level_01"],
        "weapons_collected": ["sword"],
        "cards_collected": [],
        "power_ups_collected": [],
        "checkpoint_level": "",
        "checkpoint_position": Vector2.ZERO,
    }
    SaveSystem.save_game()
    _transition_to("res://scenes/levels/level_01.tscn")

func _on_continue_button_pressed() -> void:
    var cp = SaveSystem.load_checkpoint()
    if cp["level"] != "":
        _transition_to("res://scenes/levels/%s.tscn" % cp["level"])
    else:
        _transition_to("res://scenes/levels/level_01.tscn")

func _on_quit_button_pressed() -> void:
    get_tree().quit()

func _transition_to(path: String) -> void:
    # Fade out then change scene â€” see Screen Transitions below
    $AnimationPlayer.play("fade_out")
    await $AnimationPlayer.animation_finished
    get_tree().change_scene_to_file(path)
```

---

### 9.4 Pause Menu (scenes/ui/pause_menu.tscn)

Add as a child of the HUD CanvasLayer so it overlays everything. Hidden by default.

```
PauseMenu (Control)                   â† child of HUD CanvasLayer
â”œâ”€â”€ Overlay (ColorRect)               â† semi-transparent black, full screen
â”œâ”€â”€ Panel (Panel)                     â† centered, uses Ninja Adventure panel sprite
â”‚   â”œâ”€â”€ PausedLabel (Label)           â† "PAUSED", font: Silver
â”‚   â”œâ”€â”€ ResumeButton (Button)
â”‚   â”œâ”€â”€ RestartButton (Button)
â”‚   â””â”€â”€ MainMenuButton (Button)
```

```gdscript
# scripts/ui/pause_menu.gd
extends Control

func _ready() -> void:
    hide()
    GameManager.game_paused.connect(_on_game_paused)

func _on_game_paused(is_paused: bool) -> void:
    visible = is_paused

func _on_resume_button_pressed() -> void:
    GameManager.pause_game()

func _on_restart_button_pressed() -> void:
    GameManager.pause_game()   # unpause first
    GameManager.restart_level()

func _on_main_menu_button_pressed() -> void:
    GameManager.pause_game()
    get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

# Wire the pause key to GameManager in the player or a dedicated input handler:
# func _unhandled_input(event):
#     if event.is_action_just_pressed("pause"):
#         GameManager.pause_game()
```

---

### 9.5 Shop UI (scenes/ui/shop_ui.tscn)

Opened by NPCBase after dialogue ends when `opens_shop = true`. Built as an autoload-
accessible CanvasLayer so any NPC can trigger it with their own inventory.

Add `ShopUI` to autoloads: `res://scenes/ui/shop_ui.tscn`

```
ShopUI (CanvasLayer)
â”œâ”€â”€ Panel (Panel)                     â† Ninja Adventure panel sprite
â”‚   â”œâ”€â”€ ShopTitleLabel (Label)        â† "SHOP", font: Silver
â”‚   â”œâ”€â”€ CurrencyLabel (Label)         â† "Gold: 39", font: m5x7
â”‚   â”œâ”€â”€ ItemGrid (GridContainer)      â† cols = 3, populated at runtime
â”‚   â””â”€â”€ CloseButton (Button)
â””â”€â”€ ItemTooltip (Panel)               â† shown on hover, hidden by default
    â”œâ”€â”€ TooltipName (Label)
    â”œâ”€â”€ TooltipDesc (Label)
    â””â”€â”€ TooltipPrice (Label)
```

```gdscript
# scenes/ui/shop_ui.gd
extends CanvasLayer

@onready var item_grid: GridContainer = $Panel/ItemGrid
@onready var currency_label: Label = $Panel/CurrencyLabel
@onready var tooltip: Panel = $ItemTooltip

# Preload the item slot scene â€” a small panel with icon + price label
const ITEM_SLOT = preload("res://scenes/ui/shop_item_slot.tscn")

var _inventory: Array[Resource] = []

func _ready() -> void:
    hide()

func open(inventory: Array[Resource]) -> void:
    _inventory = inventory
    _populate(inventory)
    currency_label.text = "Gold: %d" % SaveSystem.save_data["currency"]
    show()

func _populate(inventory: Array[Resource]) -> void:
    # Clear old slots
    for child in item_grid.get_children():
        child.queue_free()
    # Create a slot for each item
    for item in inventory:
        var slot = ITEM_SLOT.instantiate()
        item_grid.add_child(slot)
        slot.setup(item)
        slot.purchase_requested.connect(_on_purchase_requested.bind(item))
        slot.hovered.connect(_on_slot_hovered.bind(item))

func _on_purchase_requested(item: Resource) -> void:
    var price: int = item.get("price") if item.get("price") else 0
    if SaveSystem.spend_currency(price):
        if item is WeaponData:
            SaveSystem.unlock_weapon(item.weapon_id)
        elif item is PowerUp:
            SaveSystem.unlock_power_up(item.power_up_id)
        currency_label.text = "Gold: %d" % SaveSystem.save_data["currency"]
        _populate(_inventory)   # refresh to show sold-out state

func _on_slot_hovered(item: Resource) -> void:
    tooltip.get_node("TooltipName").text = item.get("display_name") if item.get("display_name") else ""
    tooltip.get_node("TooltipDesc").text = item.get("description") if item.get("description") else ""
    tooltip.get_node("TooltipPrice").text = "Cost: %d" % (item.get("price") if item.get("price") else 0)
    tooltip.show()

func _on_close_button_pressed() -> void:
    tooltip.hide()
    hide()
```

Add a `price: int` field to both `WeaponData` and `PowerUp` resources:
```gdscript
# Add to resources/weapon_data.gd and resources/power_up.gd:
@export var price: int = 20
```

**ShopItemSlot scene** (`scenes/ui/shop_item_slot.tscn`):
```
ShopItemSlot (Panel)
â”œâ”€â”€ ItemIcon (TextureRect)
â”œâ”€â”€ PriceLabel (Label)
â””â”€â”€ SoldOutOverlay (ColorRect)    â† semi-transparent, hidden unless already owned
```

```gdscript
# scenes/ui/shop_item_slot.gd
extends Panel

signal purchase_requested
signal hovered

func setup(item: Resource) -> void:
    $ItemIcon.texture = item.get("icon")
    $PriceLabel.text = str(item.get("price") if item.get("price") else 0)
    # Check if already owned
    var item_id = item.get("weapon_id") if item.get("weapon_id") else item.get("power_up_id")
    var owned = item_id in SaveSystem.save_data["weapons_collected"] \
             or item_id in SaveSystem.save_data["power_ups_collected"]
    $SoldOutOverlay.visible = owned

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        emit_signal("purchase_requested")

func _mouse_entered() -> void:
    emit_signal("hovered")
```

---

### 9.6 Dialogue UI (scenes/ui/dialogue_ui.tscn)

```
DialogueUI (CanvasLayer)
â”œâ”€â”€ DialogueBox (Panel)               â† Ninja Adventure dialogue panel sprite
â”‚   â”œâ”€â”€ Portrait (TextureRect)        â† NPC face, hidden if no portrait set
â”‚   â”œâ”€â”€ NameLabel (Label)             â† NPC name, font: Silver
â”‚   â”œâ”€â”€ TextLabel (RichTextLabel)     â† dialogue line, font: m5x7
â”‚   â””â”€â”€ AdvancePrompt (Label)         â† "â–¶ E to continue", font: m5x7, small
```

```gdscript
# scenes/ui/dialogue_ui.gd
extends CanvasLayer

@onready var name_label: Label = $DialogueBox/NameLabel
@onready var text_label: RichTextLabel = $DialogueBox/TextLabel
@onready var portrait_rect: TextureRect = $DialogueBox/Portrait
@onready var advance_prompt: Label = $DialogueBox/AdvancePrompt

func _ready() -> void:
    DialogueManager._dialogue_ui = self
    DialogueManager.dialogue_started.connect(func(): show())
    DialogueManager.dialogue_ended.connect(func(_s): hide())
    hide()

func _input(event: InputEvent) -> void:
    if visible and event.is_action_just_pressed("interact"):
        DialogueManager.advance()

func display_line(npc_name: String, line: String, portrait: Texture2D) -> void:
    name_label.text = npc_name
    text_label.text = line
    if portrait:
        portrait_rect.texture = portrait
        portrait_rect.show()
    else:
        portrait_rect.hide()
```

---

### 9.7 Screen Transitions

Add an `AnimationPlayer` and a full-screen `ColorRect` (black) as children of every
CanvasLayer that needs transitions. Animate the ColorRect's `modulate.a` (alpha):

```
SceneTransition (CanvasLayer) â€” layer = 100 (always on top)
â”œâ”€â”€ Overlay (ColorRect)         â† color black, full screen, anchored to full rect
â””â”€â”€ AnimationPlayer
    â”œâ”€â”€ "fade_in"   â†’ Overlay modulate.a: 1.0 â†’ 0.0 over 0.3s
    â””â”€â”€ "fade_out"  â†’ Overlay modulate.a: 0.0 â†’ 1.0 over 0.3s
```

Add `SceneTransition` as an **autoload** (`res://scenes/ui/scene_transition.tscn`) so
it persists across all scene changes and is always available.

```gdscript
# scenes/ui/scene_transition.gd
extends CanvasLayer

@onready var overlay: ColorRect = $Overlay
@onready var anim: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
    overlay.modulate.a = 0.0

func transition_to(path: String) -> void:
    anim.play("fade_out")
    await anim.animation_finished
    get_tree().change_scene_to_file(path)
    anim.play("fade_in")
```

Then replace all `get_tree().change_scene_to_file()` calls throughout the codebase
with `SceneTransition.transition_to(path)` for clean, consistent transitions.

Add to autoloads list:
```
SceneTransition    res://scenes/ui/scene_transition.tscn
```

---

## Part 10: Weapons System

### 10.1 WeaponData Resource (resources/weapon_data.gd)

```gdscript
extends Resource
class_name WeaponData

@export var weapon_id: String = ""
@export var display_name: String = ""
@export var icon: Texture2D
@export var projectile_scene: PackedScene
@export var cooldown: float = 0.5
@export var damage: float = 1.0
@export var power_card: PowerUp   # the single card equipped to this weapon (null if none)
```

Create one `.tres` per weapon in the editor: `kunai.tres`, `shuriken.tres`, `windmill_shuriken.tres`, etc.

### 10.2 WeaponManager (scripts/systems/weapon_manager.gd)

Attach to Player node.

```gdscript
extends Node
class_name WeaponManager

var collected_weapons: Array[WeaponData] = []
var active_index: int = 0
var cooldown_timer: float = 0.0

func _ready() -> void:
    # Load weapons from save data
    for weapon_id in SaveSystem.save_data["weapons_collected"]:
        var data = load("res://resources/weapons/%s.tres" % weapon_id)
        if data:
            collected_weapons.append(data)

func _process(delta: float) -> void:
    if cooldown_timer > 0:
        cooldown_timer -= delta

func get_active() -> WeaponData:
    if collected_weapons.is_empty():
        return null
    return collected_weapons[active_index]

func swap() -> void:
    if collected_weapons.size() <= 1:
        return
    active_index = (active_index + 1) % collected_weapons.size()
    PlayerData.emit_signal("weapon_changed", get_active().weapon_id)

func fire(spawn_point: Vector2, direction: Vector2) -> void:
    var weapon = get_active()
    if not weapon or cooldown_timer > 0:
        return
    cooldown_timer = weapon.cooldown
    if weapon.projectile_scene:
        var proj = weapon.projectile_scene.instantiate()
        get_tree().current_scene.add_child(proj)
        proj.global_position = spawn_point
        proj.direction = direction
        proj.damage = weapon.damage
```

---

## Part 11: NPC & Dialogue System

### 11.1 DialogueData Resource (resources/dialogue_data.gd)

```gdscript
extends Resource
class_name DialogueData

@export var npc_name: String = ""
@export var portrait: Texture2D
@export var lines: Array[String] = []
@export var opens_shop: bool = false
@export var shop_inventory: Array[Resource] = []  # WeaponData and/or PowerUp resources
```

Create one `.tres` per NPC: `elder_intro.tres`, `mountain_shopkeeper.tres`, etc. No code changes for new NPCs.

### 11.2 DialogueManager (autoloads/dialogue_manager.gd)

```gdscript
extends Node

signal dialogue_started
signal dialogue_ended(opens_shop: bool)

var is_active: bool = false
var _data: DialogueData = null
var _current_index: int = 0
var _dialogue_ui = null  # set by DialogueUI on ready

func start_dialogue(data: DialogueData) -> void:
    if is_active:
        return
    is_active = true
    _data = data
    _current_index = 0
    get_tree().paused = true
    emit_signal("dialogue_started")
    _show_current()

func advance() -> void:
    _current_index += 1
    if _current_index >= _data.lines.size():
        _end()
    else:
        _show_current()

func _show_current() -> void:
    if _dialogue_ui:
        _dialogue_ui.display_line(_data.npc_name, _data.lines[_current_index], _data.portrait)

func _end() -> void:
    is_active = false
    get_tree().paused = false
    var opens_shop = _data.opens_shop
    emit_signal("dialogue_ended", opens_shop)
```

### 11.3 NPCBase (scenes/world/npc_base.gd)

```gdscript
extends StaticBody2D
class_name NPCBase

@export var dialogue_data: DialogueData

@onready var interaction_zone: Area2D = $InteractionZone
@onready var prompt_label: Label = $PromptLabel

var player_nearby: bool = false

func _ready() -> void:
    interaction_zone.body_entered.connect(func(b): if b.is_in_group("player"): _show_prompt())
    interaction_zone.body_exited.connect(func(b): if b.is_in_group("player"): _hide_prompt())
    DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
    prompt_label.hide()

func _process(_delta: float) -> void:
    if player_nearby and Input.is_action_just_pressed("interact"):
        DialogueManager.start_dialogue(dialogue_data)

func _show_prompt() -> void:
    player_nearby = true
    prompt_label.show()

func _hide_prompt() -> void:
    player_nearby = false
    prompt_label.hide()

func _on_dialogue_ended(opens_shop: bool) -> void:
    if opens_shop and dialogue_data and dialogue_data.opens_shop:
        # Signal ShopUI to open â€” implement ShopUI as a CanvasLayer singleton
        pass
```

---

## Part 12: Development Roadmap

Work strictly in this order. Each phase depends on the previous one being solid.

### Phase 1 â€” Core Player Feel â­ MOST IMPORTANT (Week 1â€“2)
1. Godot project setup: resolution, input map, physics layers
2. Placeholder player sprite (colored rectangle is fine)
3. CharacterBody2D with gravity, walk, and run â€” reads from `PlayerStats`
4. Variable jump: three-zone gravity, tap vs hold height, coyote time, jump buffer
5. Wall jump
6. Dash with cooldown
7. Wire `StateMachine`: Idle â†’ Run â†’ Jump â†’ Fall â†’ Dash
8. **Playtest obsessively.** Jump and dash must feel great before anything else is touched.

### Phase 2 â€” Power-Up Foundation (Week 2)
1. Create `base_player_stats.tres` resource in editor
2. Implement `PowerUpManager` on Player
3. Verify that equipping a test `.tres` power-up changes jump height at runtime
4. This unlocks all future power-up content as pure data work

### Phase 3 â€” Combat & Combos (Week 2â€“3)
1. Implement `InputBuffer` and `ComboMatcher`
2. Wire Attack state: basic slash â†’ double slash â†’ finisher chain
3. Implement aerial slash, dash-slash, ground slam
4. Use `AnimationPlayer` keyframes to enable/disable `AttackHitbox.monitoring`
5. Add Hurt state: knockback + invincibility frames
6. Add Dead state + level restart

### Phase 4 â€” First Enemy (Week 3â€“4)
1. Build `MovementComponent` and `AttackComponent`
2. Build `EnemyBase` with component wiring
3. Implement Monkey Warrior scene (patrol â†’ aggro â†’ melee)
4. Wire enemy hitbox â†’ player damage
5. Wire player attack â†’ enemy damage
6. Implement death + currency drop + special energy grant

### Phase 5 â€” Level Structure (Week 4â€“5)
1. Set up TileMap with Japanese mountain tileset (3 layers)
2. Set up ParallaxBackground with 4 layers
3. Build small test level (1 screen) â€” verify tiles, collision, camera limits
4. Add Kill Zones and Checkpoints
5. Wire `SaveSystem` checkpoint saving

### Phase 6 â€” HUD & UI (Week 5)
1. Import Ninja Adventure UI pack assets â€” set all textures to Filter: Nearest in import tab
2. Import m5x7 and Silver fonts â€” disable antialiasing on import
3. Build `SceneTransition` autoload first â€” needed by all menus before anything else
4. Build Main Menu with fade transition (New Game, Continue, Quit)
5. Build HUD scene: assign heart textures, wire to `PlayerData` and `SaveSystem` signals
6. Build Pause Menu as child of HUD â€” test pause/resume/restart/main menu flow
7. Build `ShopItemSlot` scene and `ShopUI` autoload â€” test full NPC dialogue â†’ shop purchase flow

### Phase 7 â€” Tongue Mechanic (Week 6)
1. `RayCast2D` for tongue aim and range detection
2. Tongue grapple: attach, swing physics (pendulum), detach
3. Tongue as ranged attack (damages enemies on contact)
4. Tongue combo: tongue â†’ attack follow-up

### Phase 8 â€” Weapons & Swap (Week 6â€“7)
1. Build `WeaponManager` on Player
2. Create `kunai.tres` and kunai projectile scene
3. Create `shuriken.tres` and shuriken projectile scene
4. Wire weapon swap (Q) and fire (L)
5. Wire projectile â†’ enemy damage

### Phase 9 â€” NPC & Dialogue (Week 7)
1. Build `DialogueManager` autoload
2. Build `DialogueUI` CanvasLayer scene
3. Build `NPCBase` scene
4. Create `elder_intro.tres` dialogue resource
5. Create `mountain_shopkeeper.tres` with shop inventory
6. Test full dialogue â†’ shop flow

### Phase 10 â€” Full Level Build (Week 7â€“9)
1. Build 3â€“5 connected mountain levels, increasing difficulty
2. Place all enemy types (Monkey Warrior, Tengu Archer, Undead Ronin)
3. Place checkpoints, kill zones, moving platforms, hazards
4. Place NPC shopkeeper with weapon/card inventory
5. Place collectible currency throughout

### Phase 11 â€” Boss Fight (Week 9â€“10)
1. Build `PhaseComponent`
2. Create `OniLord` scene with 3 phases
3. Override `_on_phase_changed()` â€” swap movement type and attack type per phase
4. Wire boss health bar in HUD
5. Build boss arena level

### Phase 12 â€” Polish & Beta Prep (Week 10â€“12)
1. Replace all placeholder sprites with asset pack sprites
2. Full animation pass: idle, run, jump, dash, attack (all combos), hurt, death
3. SFX: jump, dash, slash, tongue, hit, enemy death, pickup, checkpoint
4. Music: loop per level, boss battle music
5. Screen transitions (fade between levels)
6. Particle effects: slash trail, hit spark, death poof, coin sparkle
7. Final playtest pass â€” tune enemy placement, difficulty, pacing
8. Export Windows/Mac builds for beta

---

## Part 13: Key Godot Tips

**Always use `move_and_slide()`** for CharacterBody2D. It handles slopes, step-ups, and platform edges automatically.

**Use AnimationPlayer for hitbox timing.** Keyframe `AttackHitbox.monitoring = true/false` inside attack animations. This syncs hit detection frame-perfectly to what the player sees â€” never use Timer nodes for this.

**Never read hardcoded constants in the player.** All movement values come from `power_up_manager.active_stats`. This is what makes power-ups work without touching player code.

**Use Groups for collision detection:**
```gdscript
add_to_group("player")
add_to_group("player_attack")  # on AttackHitbox
add_to_group("enemy")
add_to_group("enemy_attack")   # on enemy Hitbox
```
Then check `is_in_group()` in `area_entered` callbacks â€” cleaner than `instanceof` checks.

**Use signals for everything cross-system.** HUD never holds a reference to Player. PlayerData emits signals; HUD listens. This is what keeps the codebase from becoming a web of dependencies.

**Use `@export` for all enemy stats.** Health, damage, speed, drop amounts â€” all set in the editor per scene. One `EnemyBase` script serves every enemy type.

**`await animation_finished`** in `die()` is the cleanest way to let a death animation play before `queue_free()`. No timers, no flags.

**Resources are your data layer.** Weapons, power-ups, dialogue, player stats â€” all `.tres` files. New content = new resource file, not new code.

---

## Part 14: Scalability Quick Reference

How to add new things without touching existing systems:

| What | How |
|---|---|
| New power-up | Create `PowerUp.tres` â†’ set modifiers and/or `grants_ability` â†’ done |
| New stat to modify | Add `@export var` to `PlayerStats` â†’ immediately moddable |
| New combo | Add entry to `ComboMatcher.COMBOS` â†’ add animation â†’ done (e.g. `move_down + attack` = ground slam) |
| New ability (double jump, wall cling) | Add `grants_ability` string to a PowerUp â†’ check `has_ability()` in relevant state |
| New enemy type | Duplicate enemy scene â†’ change component `@export` values in editor â†’ done |
| Unique enemy behavior | Create subclass script extending `EnemyBase` â†’ override `_physics_process` |
| New boss | EnemyBase + `PhaseComponent` â†’ override `_on_phase_changed()` only |
| New NPC | Create `DialogueData.tres` â†’ assign to NPCBase scene â†’ done |
| New shop inventory | Set `shop_inventory` array on existing `DialogueData.tres` â†’ done |
| New level / biome | Duplicate level scene template â†’ swap TileSet, parallax textures, enemy placements |
| New weapon | Create `WeaponData.tres` + projectile scene â†’ appears in shop inventory automatically |

| New UI panel style | Replace panel sprite texture in Ninja Adventure source â†’ re-export |
| New shop item | Add `price` field to `WeaponData` or `PowerUp` resource â†’ add to NPC's `shop_inventory` array |

---

*Architecture v2.0 â€” Unified. Matches GDD v0.3 MVP scope.*

