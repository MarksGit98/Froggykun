extends Resource
class_name BossMove

@export var move_id: StringName = &"basic_attack"
@export var attack_type: EnemyDefinition.AttackType = EnemyDefinition.AttackType.CUSTOM
@export var cooldown_seconds: float = 0.0
@export var weight: float = 1.0
@export var animation_name: StringName = &""
@export var metadata: Dictionary = {}

