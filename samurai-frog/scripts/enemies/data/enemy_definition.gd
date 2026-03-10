extends Resource
class_name EnemyDefinition

enum AttackType {
	NONE,
	MELEE,
	RANGED,
	CHARGE,
	AOE,
	CUSTOM,
}

@export var display_name: String = "Enemy"

@export_group("Vitals")
@export var max_health: float = 10.0
@export var contact_damage: float = 1.0

@export_group("Movement")
@export var move_speed: float = 60.0
@export var acceleration: float = 500.0
@export var friction: float = 700.0
@export var gravity: float = 980.0

@export_group("Combat")
@export var attack_type: AttackType = AttackType.MELEE
@export var aggro_range: float = 220.0
@export var attack_range: float = 24.0
@export var attack_cooldown_seconds: float = 1.0
@export var leash_range: float = 500.0

@export_group("Rewards")
@export var xp_drop: int = 1
@export var guaranteed_item_drop: PackedScene
@export var optional_item_drop: PackedScene
@export var optional_item_drop_chance: float = 0.0

@export_group("Metadata")
@export var custom_properties: Dictionary = {}


