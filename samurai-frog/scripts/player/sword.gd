extends Area2D

const AnimationConstants = preload("res://scripts/constants/animation_constants.gd")

signal strike_landed(target: Node, strike_direction: Vector2, applied_damage: float)
signal strike_queued(target: Node, attack_token: StringName, strike_direction: Vector2, queued_damage: float)

@export var damage: float = 3.0
@export var combo_finisher_damage: float = 4.0
@export var strike_knockback_scale: float = 1.0

var _active_attack_token: StringName = StringName()
var _hit_target_ids_by_token: Dictionary = {}
var _queued_strikes_by_token: Dictionary = {}

func _process(_delta: float) -> void:
	_refresh_attack_token_state()

func _on_area_entered(area: Area2D) -> void:
	if area == null or area.name != "HurtBox":
		return

	_refresh_attack_token_state()
	if _active_attack_token == StringName() or not _has_active_hitbox():
		return

	var target_node: Node = area.get_parent()
	if target_node == null or not target_node.has_method("take_damage"):
		return

	var attack_token: StringName = _active_attack_token
	var hit_target_ids: Dictionary = _get_or_create_hit_target_ids(attack_token)
	var target_id: int = target_node.get_instance_id()
	if hit_target_ids.has(target_id):
		return
	hit_target_ids[target_id] = true

	var applied_damage: float = _resolve_damage_amount()
	var strike_direction: Vector2 = _resolve_strike_direction(target_node)
	var hit_context: Dictionary = _build_hit_context(strike_direction)
	var queued_strike: Dictionary = {}
	queued_strike["target"] = target_node
	queued_strike["damage"] = applied_damage
	queued_strike["strike_direction"] = strike_direction
	queued_strike["hit_context"] = hit_context
	_queue_strike(attack_token, queued_strike)
	strike_queued.emit(target_node, attack_token, strike_direction, applied_damage)

func apply_queued_strikes_for_animation(animation_name: StringName) -> void:
	if animation_name == StringName():
		return

	var queued_value: Variant = _queued_strikes_by_token.get(animation_name, null)
	_queued_strikes_by_token.erase(animation_name)
	_hit_target_ids_by_token.erase(animation_name)
	if not (queued_value is Array):
		return

	var queued_strikes: Array = queued_value as Array
	for queued_value_item: Variant in queued_strikes:
		if not (queued_value_item is Dictionary):
			continue
		var strike_data: Dictionary = queued_value_item as Dictionary
		var target_value: Variant = strike_data.get("target", null)
		if not (target_value is Node):
			continue
		var target_node: Node = target_value as Node
		if target_node == null or not is_instance_valid(target_node):
			continue
		if not target_node.has_method("take_damage"):
			continue
		var damage_value: Variant = strike_data.get("damage", damage)
		var applied_damage: float = damage
		if typeof(damage_value) == TYPE_FLOAT or typeof(damage_value) == TYPE_INT:
			applied_damage = float(damage_value)
		var strike_direction_value: Variant = strike_data.get("strike_direction", Vector2.RIGHT)
		var strike_direction: Vector2 = Vector2.RIGHT
		if strike_direction_value is Vector2:
			strike_direction = strike_direction_value as Vector2
		var hit_context_value: Variant = strike_data.get("hit_context", {})
		var hit_context: Dictionary = {}
		if hit_context_value is Dictionary:
			hit_context = hit_context_value as Dictionary
		var knockback_scale: float = get_strike_knockback_scale()
		if hit_context.has("knockback_scale"):
			var context_knockback_scale: Variant = hit_context["knockback_scale"]
			if typeof(context_knockback_scale) == TYPE_FLOAT or typeof(context_knockback_scale) == TYPE_INT:
				knockback_scale = maxf(float(context_knockback_scale), 0.0)
		if target_node.has_method("receive_strike_knockback"):
			target_node.call("receive_strike_knockback", strike_direction, knockback_scale)
		strike_landed.emit(target_node, strike_direction, applied_damage)
		target_node.call("take_damage", applied_damage, hit_context)

func clear_all_queued_strikes() -> void:
	_active_attack_token = StringName()
	_hit_target_ids_by_token.clear()
	_queued_strikes_by_token.clear()

func _refresh_attack_token_state() -> void:
	var attack_token: StringName = _get_attack_token()
	if attack_token == StringName():
		_active_attack_token = StringName()
		return

	if attack_token != _active_attack_token:
		_active_attack_token = attack_token
		_hit_target_ids_by_token.erase(attack_token)
		_queued_strikes_by_token.erase(attack_token)

func _has_active_hitbox() -> bool:
	for child: Node in get_children():
		if child is CollisionShape2D:
			var shape: CollisionShape2D = child as CollisionShape2D
			if not shape.disabled:
				return true
	return false

func _get_attack_token() -> StringName:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return StringName()
	if parent_node.has_method("is_air_attack_active"):
		var air_attack_active: Variant = parent_node.call("is_air_attack_active")
		if typeof(air_attack_active) == TYPE_BOOL and bool(air_attack_active):
			return AnimationConstants.PLAYER_AIR_ATTACK
	if parent_node.has_method("get_current_attack_animation"):
		var attack_animation: Variant = parent_node.call("get_current_attack_animation")
		if attack_animation is StringName:
			return attack_animation as StringName
	return StringName()

func get_strike_knockback_scale() -> float:
	return maxf(strike_knockback_scale, 0.0)

func _resolve_damage_amount() -> float:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return damage
	if not parent_node.has_method("get_sword_damage"):
		return damage

	var resolved_damage: Variant = parent_node.call("get_sword_damage")
	if typeof(resolved_damage) == TYPE_FLOAT or typeof(resolved_damage) == TYPE_INT:
		return float(resolved_damage)
	return damage

func _resolve_strike_direction(target_node: Node) -> Vector2:
	var parent_node: Node = get_parent()
	if parent_node is Node2D and target_node is Node2D:
		var attacker: Node2D = parent_node as Node2D
		var target: Node2D = target_node as Node2D
		var delta: Vector2 = target.global_position - attacker.global_position
		if absf(delta.x) > 0.01:
			return Vector2(signf(delta.x), 0.0)

	var facing_sign: float = _resolve_parent_facing_sign(parent_node)
	return Vector2(facing_sign, 0.0)

func _resolve_parent_facing_sign(parent_node: Node) -> float:
	if parent_node == null:
		return 1.0
	var sprite_node: Node = parent_node.get_node_or_null("Sprite2D")
	if sprite_node is Sprite2D:
		var sprite: Sprite2D = sprite_node as Sprite2D
		return -1.0 if sprite.flip_h else 1.0
	return 1.0

func _build_hit_context(strike_direction: Vector2) -> Dictionary:
	var hit_context: Dictionary = {}
	hit_context["source_node"] = self
	hit_context["attacker"] = get_parent()
	hit_context["strike_direction"] = strike_direction
	hit_context["attack_token"] = _active_attack_token
	hit_context["knockback_scale"] = get_strike_knockback_scale()
	return hit_context

func _get_or_create_hit_target_ids(attack_token: StringName) -> Dictionary:
	var existing_value: Variant = _hit_target_ids_by_token.get(attack_token, null)
	if existing_value is Dictionary:
		return existing_value as Dictionary
	var hit_target_ids: Dictionary = {}
	_hit_target_ids_by_token[attack_token] = hit_target_ids
	return hit_target_ids

func _queue_strike(attack_token: StringName, queued_strike: Dictionary) -> void:
	var existing_value: Variant = _queued_strikes_by_token.get(attack_token, null)
	var queued_strikes: Array = []
	if existing_value is Array:
		queued_strikes = existing_value as Array
	queued_strikes.append(queued_strike)
	_queued_strikes_by_token[attack_token] = queued_strikes
