@tool
extends CharacterBody2D
class_name EnemyBase

signal health_changed(current: float, max_health: float)
signal damaged(amount: float, current: float, max_health: float)
signal died(enemy: EnemyBase)
signal xp_dropped(amount: int)
signal item_dropped(item_instance: Node)
signal attack_requested(attack_type: int, target: Node2D, direction: Vector2, damage: float)
signal attack_executed(attack_type: int, target: Node2D, damage: float)
signal target_changed(new_target: Node2D)

@export var definition: EnemyDefinition

@export_group("Fallback Stats")
@export var fallback_max_health: float = 10.0
@export var fallback_contact_damage: float = 1.0
@export var fallback_move_speed: float = 60.0
@export var fallback_acceleration: float = 500.0
@export var fallback_friction: float = 700.0
@export var fallback_gravity: float = 980.0
@export var fallback_attack_type: EnemyDefinition.AttackType = EnemyDefinition.AttackType.MELEE
@export var fallback_aggro_range: float = 220.0
@export var fallback_attack_range: float = 24.0
@export var fallback_attack_cooldown_seconds: float = 1.0
@export var fallback_leash_range: float = 500.0
@export var fallback_xp_drop: int = 1
@export var fallback_guaranteed_item_drop: PackedScene
@export var fallback_optional_item_drop: PackedScene
@export var fallback_optional_item_drop_chance: float = 0.0

@export_group("AI")
@export var target_group: StringName = &"player"
@export var target_refresh_interval_seconds: float = 0.35
@export var auto_face_target: bool = true
@export var queue_free_on_death: bool = true

@export_group("Traversal")
@export var step_height: float = 8.0
@export var step_probe_distance: float = 2.0


@onready var animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var sprite_2d: Sprite2D = get_node_or_null("Sprite2D")

var current_health: float = 0.0

var _current_target: Node2D
var _target_refresh_timer: float = 0.0
var _attack_cooldown_timer: float = 0.0
var _spawn_position: Vector2
var _dead: bool = false

var _max_health: float = 1.0
var _contact_damage: float = 0.0
var _move_speed: float = 0.0
var _acceleration: float = 0.0
var _friction: float = 0.0
var _gravity: float = 0.0
var _attack_type: EnemyDefinition.AttackType = EnemyDefinition.AttackType.NONE
var _aggro_range: float = 0.0
var _attack_range: float = 0.0
var _attack_cooldown_seconds: float = 0.1
var _leash_range: float = 0.0
var _xp_drop: int = 0
var _guaranteed_item_drop: PackedScene
var _optional_item_drop: PackedScene
var _optional_item_drop_chance: float = 0.0

func _ready() -> void:
	_apply_stats_from_definition()
	current_health = _max_health
	_spawn_position = global_position

	if not Engine.is_editor_hint():
		add_to_group("enemy")

	health_changed.emit(current_health, _max_health)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or _dead:
		return

	_update_target(delta)
	_update_cooldowns(delta)
	_apply_gravity(delta)
	_process_ai(delta)
	_try_step_up()
	move_and_slide()

func _try_step_up() -> void:
	CharacterStepUtility.try_step_up(self, velocity.x, step_height, step_probe_distance)

func is_dead() -> bool:
	return _dead

func get_target() -> Node2D:
	return _current_target

func set_target(target: Node2D) -> void:
	_set_target(target)

func take_damage(amount: float, source: Variant = null) -> void:
	if _dead or amount <= 0.0:
		return

	var previous_health: float = current_health
	current_health = maxf(0.0, current_health - amount)
	if has_method("debug_enemy_log"):
		call("debug_enemy_log", "EnemyBase.take_damage %.1f -> %.1f (amount=%.1f)" % [previous_health, current_health, amount])
	damaged.emit(amount, current_health, _max_health)
	health_changed.emit(current_health, _max_health)

	if current_health <= 0.0:
		_die(source)

func heal(amount: float) -> void:
	if _dead or amount <= 0.0:
		return
	current_health = minf(_max_health, current_health + amount)
	health_changed.emit(current_health, _max_health)

func _process_ai(delta: float) -> void:
	if not _is_target_valid(_current_target):
		_apply_horizontal_friction(delta)
		return

	var target_position := _current_target.global_position
	var to_target := target_position - global_position
	var distance_sq := to_target.length_squared()

	if _leash_range > 0.0:
		var leash_distance_sq := _leash_range * _leash_range
		if (global_position - _spawn_position).length_squared() > leash_distance_sq:
			_move_toward_x(_spawn_position.x, delta)
			return

	if _aggro_range > 0.0:
		var aggro_distance_sq := _aggro_range * _aggro_range
		if distance_sq > aggro_distance_sq:
			_apply_horizontal_friction(delta)
			return

	if _can_attack_target(distance_sq):
		var attack_direction := Vector2.RIGHT
		if distance_sq > 0.001:
			attack_direction = to_target.normalized()
		if _try_attack(attack_direction):
			_apply_horizontal_friction(delta)
			return

	_move_toward_x(target_position.x, delta)

func _can_attack_target(distance_sq: float) -> bool:
	if _attack_range <= 0.0:
		return false
	var attack_distance_sq := _attack_range * _attack_range
	return distance_sq <= attack_distance_sq

func _try_attack(attack_direction: Vector2) -> bool:
	if _attack_cooldown_timer > 0.0:
		return false
	if not _is_target_valid(_current_target):
		return false
	if _attack_type == EnemyDefinition.AttackType.NONE:
		return false

	var attacked := false
	match _attack_type:
		EnemyDefinition.AttackType.MELEE:
			attacked = _perform_melee_attack(_current_target)
		EnemyDefinition.AttackType.RANGED, EnemyDefinition.AttackType.CHARGE, EnemyDefinition.AttackType.AOE:
			attacked = _request_attack(_current_target, attack_direction)
		EnemyDefinition.AttackType.CUSTOM:
			attacked = _perform_custom_attack(_current_target, attack_direction)
		_:
			attacked = false

	if not attacked:
		return false

	_attack_cooldown_timer = _attack_cooldown_seconds
	attack_executed.emit(int(_attack_type), _current_target, _contact_damage)
	return true

func _perform_melee_attack(target: Node2D) -> bool:
	return _deal_damage_to_target(target, _contact_damage)

func _perform_custom_attack(target: Node2D, direction: Vector2) -> bool:
	# Intended to be overridden by inherited enemy classes.
	return _request_attack(target, direction)

func _request_attack(target: Node2D, direction: Vector2) -> bool:
	attack_requested.emit(int(_attack_type), target, direction, _contact_damage)
	return true

func _deal_damage_to_target(target: Node, damage_amount: float) -> bool:
	if target == null or damage_amount <= 0.0:
		return false
	if target.has_method("take_damage"):
		target.call("take_damage", damage_amount)
		return true
	if target.has_method("apply_damage"):
		target.call("apply_damage", damage_amount)
		return true
	return false

func _move_toward_x(target_x: float, delta: float) -> void:
	var dx := target_x - global_position.x
	var direction := 0.0
	if absf(dx) > 1.0:
		direction = signf(dx)

	velocity.x = move_toward(velocity.x, direction * _move_speed, _acceleration * delta)
	_update_facing(direction)

func _apply_horizontal_friction(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, _friction * delta)

func _update_facing(direction: float) -> void:
	if not auto_face_target:
		return
	if absf(direction) > 0.01:
		var facing_left := direction < 0.0
		if animated_sprite != null:
			animated_sprite.flip_h = facing_left
		if sprite_2d != null:
			sprite_2d.flip_h = facing_left

func _apply_gravity(delta: float) -> void:
	if _gravity <= 0.0:
		return
	if not is_on_floor():
		velocity.y += _gravity * delta

func _update_cooldowns(delta: float) -> void:
	if _attack_cooldown_timer > 0.0:
		_attack_cooldown_timer = maxf(0.0, _attack_cooldown_timer - delta)

func _update_target(delta: float) -> void:
	if target_refresh_interval_seconds > 0.0:
		_target_refresh_timer -= delta
		if _target_refresh_timer > 0.0 and _is_target_valid(_current_target):
			return
		_target_refresh_timer = target_refresh_interval_seconds

	var best_target: Node2D
	var best_dist_sq := INF
	for candidate in get_tree().get_nodes_in_group(String(target_group)):
		if not (candidate is Node2D):
			continue
		var candidate_node := candidate as Node2D
		if not _is_target_valid(candidate_node):
			continue
		var dist_sq := (candidate_node.global_position - global_position).length_squared()
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best_target = candidate_node

	_set_target(best_target)

func _set_target(target: Node2D) -> void:
	if target == _current_target:
		return
	_current_target = target
	target_changed.emit(_current_target)

func _is_target_valid(target: Node2D) -> bool:
	return target != null and is_instance_valid(target) and target.is_inside_tree()

func _die(source: Variant = null) -> void:
	if _dead:
		return
	_dead = true
	current_health = 0.0
	if has_method("debug_enemy_log"):
		call("debug_enemy_log", "EnemyBase._die called")
	health_changed.emit(current_health, _max_health)
	velocity = Vector2.ZERO

	if _xp_drop > 0:
		xp_dropped.emit(_xp_drop)

	if _guaranteed_item_drop != null:
		_spawn_item_drop(_guaranteed_item_drop)
	if _optional_item_drop != null and randf() <= _optional_item_drop_chance:
		_spawn_item_drop(_optional_item_drop)

	_on_death(source)
	died.emit(self)

	if queue_free_on_death:
		queue_free()

func _on_death(_source: Variant) -> void:
	# Intended to be overridden by inherited enemy classes.
	pass

func _spawn_item_drop(item_scene: PackedScene) -> void:
	var item_instance := item_scene.instantiate()
	if item_instance == null:
		return

	var parent_node := get_parent()
	if get_tree() != null and get_tree().current_scene != null:
		parent_node = get_tree().current_scene
	if parent_node == null:
		return

	parent_node.add_child(item_instance)
	if item_instance is Node2D:
		(item_instance as Node2D).global_position = global_position

	item_dropped.emit(item_instance)

func _apply_stats_from_definition() -> void:
	if definition == null:
		_max_health = fallback_max_health
		_contact_damage = fallback_contact_damage
		_move_speed = fallback_move_speed
		_acceleration = fallback_acceleration
		_friction = fallback_friction
		_gravity = fallback_gravity
		_attack_type = fallback_attack_type
		_aggro_range = fallback_aggro_range
		_attack_range = fallback_attack_range
		_attack_cooldown_seconds = fallback_attack_cooldown_seconds
		_leash_range = fallback_leash_range
		_xp_drop = fallback_xp_drop
		_guaranteed_item_drop = fallback_guaranteed_item_drop
		_optional_item_drop = fallback_optional_item_drop
		_optional_item_drop_chance = fallback_optional_item_drop_chance
		return

	_max_health = definition.max_health
	_contact_damage = definition.contact_damage
	_move_speed = definition.move_speed
	_acceleration = definition.acceleration
	_friction = definition.friction
	_gravity = definition.gravity
	_attack_type = definition.attack_type
	_aggro_range = definition.aggro_range
	_attack_range = definition.attack_range
	_attack_cooldown_seconds = definition.attack_cooldown_seconds
	_leash_range = definition.leash_range
	_xp_drop = definition.xp_drop
	_guaranteed_item_drop = definition.guaranteed_item_drop
	_optional_item_drop = definition.optional_item_drop
	_optional_item_drop_chance = definition.optional_item_drop_chance




