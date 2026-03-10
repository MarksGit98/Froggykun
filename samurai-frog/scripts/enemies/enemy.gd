extends EnemyBase
class_name Enemy

const AnimationConstants = preload("res://scripts/constants/animation_constants.gd")

const ANIMATION_STATE_MOVE: StringName = AnimationConstants.ENEMY_MOVE
const ANIMATION_STATE_ATTACK: StringName = AnimationConstants.ENEMY_ATTACK
const ANIMATION_STATE_DEATH: StringName = AnimationConstants.ENEMY_DEATH
const ANIMATION_STATE_TAKE_HIT: StringName = AnimationConstants.ENEMY_TAKE_HIT_STATE

const ANIMATION_CLIP_ATTACK: StringName = AnimationConstants.ENEMY_ATTACK
const ANIMATION_CLIP_DEATH: StringName = AnimationConstants.ENEMY_DEATH
const ANIMATION_CLIP_TAKE_HIT: StringName = AnimationConstants.ENEMY_TAKE_HIT_CLIP

@export_group("Enemy AI")
@export var patrol_starts_left: bool = true
@export var patrol_speed_scale: float = 0.45
@export var patrol_wall_probe_distance: float = 4.0
@export var patrol_ledge_probe_forward_distance: float = 8.0
@export var patrol_ledge_probe_depth: float = 22.0
@export var patrol_ledge_probe_raise: float = 4.0
@export var combat_stop_distance: float = 2.0
@export var combat_ledge_probe_forward_distance: float = 8.0
@export var combat_ledge_probe_depth: float = 200.0
@export var combat_wall_jump_enabled: bool = false
@export var combat_wall_jump_probe_distance: float = 6.0
@export var combat_wall_jump_max_wall_height: float = 40.0
@export var combat_wall_jump_velocity: float = 300.0
@export var combat_wall_jump_cooldown_seconds: float = 0.35
@export var debug_enemy_logs: bool = true

@export_group("Audio")
@export var audio_profile_id: StringName = StringName()

@export_group("Hit Reaction")
@export var take_hit_knockback_speed: float = 180.0
@export var take_hit_knockback_lift: float = 55.0
@export var take_hit_reaction_seconds: float = 0.22
@export var take_hit_hurt_box_disable_seconds: float = 0.16

@onready var enemy_hit_box: CollisionShape2D = get_node_or_null("EnemyHitBox")
@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var animation_player: AnimationPlayer = get_node_or_null("AnimationPlayer")
@onready var animation_tree: AnimationTree = get_node_or_null("AnimationTree")
@onready var hurt_box: Area2D = get_node_or_null("HurtBox")
@onready var hurt_box_shape: CollisionShape2D = get_node_or_null("HurtBox/HurtBoxShape")
@onready var attack_area: Area2D = get_node_or_null("Attack")
@onready var attack_hit_box_left: CollisionShape2D = get_node_or_null("Attack/AttackHitBoxLeft")
@onready var attack_hit_box_right: CollisionShape2D = get_node_or_null("Attack/AttackHitBoxRight")
@onready var attack_hit_box_above: CollisionShape2D = get_node_or_null("Attack/AttackHitBoxAbove")
@onready var enemy_state_machine: EnemyStateMachine = get_node_or_null("EnemyStateMachine")

var _animation_state: AnimationNodeStateMachinePlayback
var _death_animation_locked: bool = false
var _attack_request_timer: float = 0.0
var _take_hit_request_timer: float = 0.0
var _patrol_direction: float = -1.0
var _take_hit_reaction_timer: float = 0.0
var _hurt_box_reenable_timer: float = 0.0
var _pending_take_hit_knockback_direction: float = 0.0
var _pending_take_hit_knockback_scale: float = 1.0
var _last_damage_source: Variant = null
var _queued_attack_targets: Dictionary = {}
var _combat_wall_jump_cooldown_timer: float = 0.0

const REQUEST_PULSE_SECONDS: float = 0.12
const DEFAULT_BODY_HALF_WIDTH: float = 8.0
const DEFAULT_BODY_HALF_HEIGHT: float = 16.0

func _ready() -> void:
	super._ready()
	if _should_wait_for_death_animation():
		queue_free_on_death = false
	_patrol_direction = -1.0 if patrol_starts_left else 1.0
	_connect_enemy_signals()
	_connect_animation_signals()
	_connect_attack_area_signals()
	_setup_animation_tree()
	set_attack_hitboxes_enabled(false)
	_set_hurt_box_enabled(true)
	_update_facing(_patrol_direction)
	_update_animation_parameters()
	debug_enemy_log("Enemy ready")

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_update_animation_request_timers(delta)
	_update_hit_reaction_timer(delta)
	_update_hurt_box_reenable_timer(delta)
	_update_combat_wall_jump_timer(delta)
	_update_animation_conditions()
	_update_animation_parameters()
	_queue_current_attack_overlaps()

func take_damage(amount: float, source: Variant = null) -> void:
	if is_dead() or amount <= 0.0:
		return
	_last_damage_source = source
	debug_enemy_log("take_damage amount=%.1f source_type=%s" % [amount, type_string(typeof(source))])
	super.take_damage(amount, source)

func receive_strike_knockback(strike_direction: Vector2, knockback_scale: float = 1.0) -> void:
	_pending_take_hit_knockback_direction = _resolve_strike_knockback_direction(strike_direction)
	_pending_take_hit_knockback_scale = maxf(knockback_scale, 0.0)
	debug_enemy_log("receive_strike_knockback dir=(%.2f, %.2f) resolved=%.0f scale=%.2f" % [strike_direction.x, strike_direction.y, _pending_take_hit_knockback_direction, _pending_take_hit_knockback_scale])

func apply_defend_counter_knockback(defender: Node2D, knockback_scale: float = 2.0) -> void:
	if _death_animation_locked:
		return
	var strike_direction := Vector2(_get_facing_sign(), 0.0)
	if defender != null:
		var delta: Vector2 = global_position - defender.global_position
		if absf(delta.x) > 0.01:
			strike_direction = Vector2(signf(delta.x), 0.0)
	receive_strike_knockback(strike_direction, knockback_scale)
	_apply_take_hit_knockback()
	if animation_tree != null:
		_take_hit_request_timer = REQUEST_PULSE_SECONDS
		_play_animation_state(ANIMATION_STATE_TAKE_HIT)
	debug_enemy_log("apply_defend_counter_knockback scale=%.2f dir=(%.2f, %.2f)" % [maxf(knockback_scale, 0.0), strike_direction.x, strike_direction.y])

func get_debug_animation_state() -> String:
	if _death_animation_locked and animation_player != null:
		var death_clip: StringName = animation_player.current_animation
		if death_clip != StringName():
			return String(death_clip)
	if _animation_state != null and _animation_state.has_method("get_current_node"):
		var current_node: StringName = _animation_state.get_current_node()
		if current_node != StringName():
			return String(current_node)
	if animation_player != null:
		var current_clip: StringName = animation_player.current_animation
		if current_clip != StringName():
			return String(current_clip)
	return "None"

func _play_profile_audio_cue(event_suffix: StringName) -> void:
	if audio_profile_id == StringName():
		return
	var audio_manager: Node = get_node_or_null("/root/AudioManager")
	if audio_manager == null or not audio_manager.has_method("play_sfx"):
		return
	var cue_id := StringName("%s_%s" % [String(audio_profile_id), String(event_suffix)])
	audio_manager.call("play_sfx", cue_id, self)

func debug_enemy_log(message: String) -> void:
	if not debug_enemy_logs:
		return
	var state_name: String = "None"
	if enemy_state_machine != null and enemy_state_machine.current_state != null:
		state_name = enemy_state_machine.current_state.name
	var animation_name: String = get_debug_animation_state()
	var target_text: String = "None"
	var target_node: Node2D = get_target()
	if _is_target_valid(target_node):
		target_text = "%s@(%.1f, %.1f)" % [target_node.name, target_node.global_position.x, target_node.global_position.y]
	print("[EnemyDebug] node=%s state=%s anim=%s hp=%.1f/%.1f dead=%s floor=%s wall=%s vel=(%.2f, %.2f) patrol=%.0f atk_req=%.3f hit_req=%.3f hit_react=%.3f knock=%.0f target=%s :: %s" % [
		name,
		state_name,
		animation_name,
		current_health,
		_max_health,
		str(is_dead()),
		str(is_on_floor()),
		str(is_on_wall()),
		velocity.x,
		velocity.y,
		_patrol_direction,
		_attack_request_timer,
		_take_hit_request_timer,
		_take_hit_reaction_timer,
		_pending_take_hit_knockback_direction,
		target_text,
		message,
	])

func _process_ai(delta: float) -> void:
	if _take_hit_reaction_timer > 0.0:
		_process_take_hit_reaction(delta)
		return
	if enemy_state_machine != null:
		enemy_state_machine.physics_update(delta)
		return
	super._process_ai(delta)

func enter_patrol_state() -> void:
	set_attack_hitboxes_enabled(false)
	if absf(velocity.x) <= 0.01:
		_update_facing(_patrol_direction)

func process_patrol_state(delta: float) -> void:
	var direction: float = _patrol_direction
	if _should_turn_during_patrol(direction):
		reverse_patrol_direction()
		direction = _patrol_direction
	var patrol_speed: float = _move_speed * patrol_speed_scale
	_move_in_direction(direction, patrol_speed, delta)

func should_enter_combat_state() -> bool:
	return has_target_in_vision_range()

func enter_combat_state() -> void:
	set_attack_hitboxes_enabled(false)

func enter_death_state() -> void:
	if _death_animation_locked:
		return
	debug_enemy_log("enter_death_state")
	_death_animation_locked = true
	_play_profile_audio_cue(&"death")
	_attack_request_timer = 0.0
	_take_hit_request_timer = 0.0
	_take_hit_reaction_timer = 0.0
	_hurt_box_reenable_timer = 0.0
	_pending_take_hit_knockback_direction = 0.0
	_pending_take_hit_knockback_scale = 1.0
	_last_damage_source = null
	velocity = Vector2.ZERO
	set_attack_hitboxes_enabled(false)
	_set_hurt_box_enabled(false)
	if animation_tree != null:
		animation_tree.active = true
		animation_tree.set("parameters/conditions/attack_requested", false)
		animation_tree.set("parameters/conditions/take_hit_requested", false)
		animation_tree.set("parameters/conditions/death_requested", true)
		_play_animation_state(ANIMATION_STATE_DEATH)
		return
	if animation_player != null and animation_player.has_animation(ANIMATION_CLIP_DEATH):
		animation_player.play(ANIMATION_CLIP_DEATH)
		debug_enemy_log("AnimationPlayer fallback death clip")
		return
	if not queue_free_on_death and not is_queued_for_deletion():
		queue_free()

func should_stay_in_combat_state() -> bool:
	return has_target_in_vision_range()

func process_combat_state(delta: float) -> void:
	var target: Node2D = get_target()
	if not _is_target_valid(target):
		_apply_horizontal_friction(delta)
		return

	var target_offset: Vector2 = target.global_position - global_position
	var horizontal_direction: float = signf(target_offset.x)
	if absf(target_offset.x) > 0.01:
		_update_facing(horizontal_direction)

	if is_attack_animation_active() or is_take_hit_animation_active():
		_apply_horizontal_friction(delta)
		return

	if can_attack_current_target():
		if _try_attack(_get_attack_direction(target)):
			_apply_horizontal_friction(delta)
			return
		_apply_horizontal_friction(delta)
		return

	if absf(target_offset.x) <= combat_stop_distance:
		_apply_horizontal_friction(delta)
		return

	if not _has_safe_combat_floor_ahead(horizontal_direction):
		debug_enemy_log("combat_ledge_guard stopping chase dir=%.0f depth=%.1f" % [horizontal_direction, combat_ledge_probe_depth])
		_apply_horizontal_friction(delta)
		return

	_try_combat_wall_jump(horizontal_direction)
	_move_toward_x(target.global_position.x, delta)

func process_death_state(_delta: float) -> void:
	velocity = Vector2.ZERO

func has_target_in_vision_range() -> bool:
	var target: Node2D = get_target()
	if not _is_target_valid(target):
		return false
	if _aggro_range <= 0.0:
		return true
	var distance_sq: float = (target.global_position - global_position).length_squared()
	var aggro_distance_sq: float = _aggro_range * _aggro_range
	return distance_sq <= aggro_distance_sq

func can_attack_current_target() -> bool:
	var target: Node2D = get_target()
	if not _is_target_valid(target):
		return false
	if _attack_range <= 0.0:
		return false
	var distance_sq: float = (target.global_position - global_position).length_squared()
	var attack_distance_sq: float = _attack_range * _attack_range
	return distance_sq <= attack_distance_sq

func reverse_patrol_direction() -> void:
	_patrol_direction *= -1.0
	_update_facing(_patrol_direction)

func get_patrol_direction() -> float:
	return _patrol_direction

func is_attack_animation_active() -> bool:
	if _animation_state == null:
		return false
	if not _animation_state.has_method("get_current_node"):
		return false
	var current_node: StringName = _animation_state.get_current_node()
	return current_node == ANIMATION_STATE_ATTACK

func is_take_hit_animation_active() -> bool:
	if _animation_state == null:
		return false
	if not _animation_state.has_method("get_current_node"):
		return false
	var current_node: StringName = _animation_state.get_current_node()
	return current_node == ANIMATION_STATE_TAKE_HIT

func set_attack_hitboxes_enabled(enabled: bool) -> void:
	if attack_area != null:
		attack_area.monitoring = enabled
		attack_area.monitorable = false

	if enabled:
		return

	_queued_attack_targets.clear()
	if attack_hit_box_left != null:
		attack_hit_box_left.disabled = true
	if attack_hit_box_right != null:
		attack_hit_box_right.disabled = true
	if attack_hit_box_above != null:
		attack_hit_box_above.disabled = true

func _set_hurt_box_enabled(enabled: bool) -> void:
	if hurt_box != null:
		hurt_box.monitoring = false
		hurt_box.monitorable = enabled
	if hurt_box_shape != null:
		hurt_box_shape.disabled = not enabled

func _connect_enemy_signals() -> void:
	if not attack_executed.is_connected(_on_attack_executed):
		attack_executed.connect(_on_attack_executed)
	if not damaged.is_connected(_on_damaged):
		damaged.connect(_on_damaged)
	if not died.is_connected(_on_died):
		died.connect(_on_died)

func _connect_animation_signals() -> void:
	if animation_tree != null:
		if not animation_tree.animation_started.is_connected(_on_animation_started):
			animation_tree.animation_started.connect(_on_animation_started)
		if not animation_tree.animation_finished.is_connected(_on_animation_finished):
			animation_tree.animation_finished.connect(_on_animation_finished)
		return
	if animation_player == null:
		return
	if not animation_player.animation_started.is_connected(_on_animation_started):
		animation_player.animation_started.connect(_on_animation_started)
	if not animation_player.animation_finished.is_connected(_on_animation_finished):
		animation_player.animation_finished.connect(_on_animation_finished)

func _connect_attack_area_signals() -> void:
	if attack_area == null:
		return
	if not attack_area.area_entered.is_connected(_on_attack_area_entered):
		attack_area.area_entered.connect(_on_attack_area_entered)

func _setup_animation_tree() -> void:
	if animation_tree == null:
		return

	animation_tree.active = true
	animation_tree.set("parameters/conditions/attack_requested", false)
	animation_tree.set("parameters/conditions/take_hit_requested", false)
	animation_tree.set("parameters/conditions/death_requested", false)
	var playback: Variant = animation_tree.get("parameters/playback")
	if playback is AnimationNodeStateMachinePlayback:
		_animation_state = playback as AnimationNodeStateMachinePlayback
		_animation_state.start(ANIMATION_STATE_MOVE)

func _play_animation_state(state_name: StringName) -> void:
	if _animation_state == null:
		debug_enemy_log("_play_animation_state skipped: no animation playback for %s" % String(state_name))
		return
	var previous_state: String = "None"
	if _animation_state.has_method("get_current_node"):
		var current_node: StringName = _animation_state.get_current_node()
		if current_node != StringName():
			previous_state = String(current_node)
	debug_enemy_log("_play_animation_state %s -> %s" % [previous_state, String(state_name)])
	if _animation_state.has_method("travel"):
		_animation_state.travel(state_name)
		return
	_animation_state.start(state_name)

func _update_animation_request_timers(delta: float) -> void:
	_attack_request_timer = maxf(0.0, _attack_request_timer - delta)
	_take_hit_request_timer = maxf(0.0, _take_hit_request_timer - delta)

func _update_hit_reaction_timer(delta: float) -> void:
	_take_hit_reaction_timer = maxf(0.0, _take_hit_reaction_timer - delta)

func _update_hurt_box_reenable_timer(delta: float) -> void:
	if _hurt_box_reenable_timer <= 0.0:
		return
	_hurt_box_reenable_timer = maxf(0.0, _hurt_box_reenable_timer - delta)
	if _hurt_box_reenable_timer <= 0.0 and not _death_animation_locked:
		_set_hurt_box_enabled(true)
		debug_enemy_log("hurt_box_reenabled early")

func _update_combat_wall_jump_timer(delta: float) -> void:
	_combat_wall_jump_cooldown_timer = maxf(0.0, _combat_wall_jump_cooldown_timer - delta)

func _update_animation_conditions() -> void:
	if animation_tree == null:
		return

	var can_request: bool = not _death_animation_locked
	animation_tree.set("parameters/conditions/attack_requested", can_request and _attack_request_timer > 0.0)
	animation_tree.set("parameters/conditions/take_hit_requested", can_request and _take_hit_request_timer > 0.0)
	animation_tree.set("parameters/conditions/death_requested", _death_animation_locked)

func _update_animation_parameters() -> void:
	if animation_tree == null:
		return

	var blend_position: float = 0.0
	if absf(velocity.x) > 0.01:
		blend_position = signf(velocity.x)

	animation_tree.set("parameters/Move/blend_position", blend_position)

func _process_take_hit_reaction(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, _friction * delta)

func _on_attack_executed(_attack_type: int, _target: Node2D, _damage: float) -> void:
	if _death_animation_locked:
		return
	_attack_request_timer = REQUEST_PULSE_SECONDS

func _on_damaged(amount: float, current: float, max_health_value: float) -> void:
	debug_enemy_log("_on_damaged amount=%.1f current=%.1f/%.1f" % [amount, current, max_health_value])
	if _death_animation_locked or current <= 0.0:
		debug_enemy_log("_on_damaged ignored due to death lock or zero HP")
		return
	_play_profile_audio_cue(&"hurt")
	_pending_take_hit_knockback_direction = _resolve_damage_knockback_direction(_last_damage_source)
	_pending_take_hit_knockback_scale = _resolve_damage_knockback_scale(_last_damage_source)
	_last_damage_source = null
	_take_hit_request_timer = REQUEST_PULSE_SECONDS
	_hurt_box_reenable_timer = take_hit_hurt_box_disable_seconds
	set_attack_hitboxes_enabled(false)
	_set_hurt_box_enabled(false)
	_play_animation_state(ANIMATION_STATE_TAKE_HIT)

func _on_died(_enemy: EnemyBase) -> void:
	debug_enemy_log("_on_died emitted")
	if enemy_state_machine != null:
		var death_state: EnemyState = enemy_state_machine.get_state_by_name(ANIMATION_STATE_DEATH)
		if death_state != null:
			debug_enemy_log("Switching gameplay state to Death")
			enemy_state_machine.switch_states(death_state)
			return
	debug_enemy_log("No gameplay Death state found; entering death directly")
	enter_death_state()

func _queue_attack_target(target_node: Node) -> void:
	if target_node == null:
		return
	var target_id: int = target_node.get_instance_id()
	_queued_attack_targets[target_id] = target_node
	debug_enemy_log("Queued attack target: %s" % target_node.name)

func _apply_queued_attack_damage() -> void:
	if _queued_attack_targets.is_empty():
		debug_enemy_log("No queued attack targets to damage")
		return

	var queued_targets: Array[Variant] = _queued_attack_targets.values()
	_queued_attack_targets.clear()
	for target_value: Variant in queued_targets:
		if not (target_value is Node):
			continue
		var target_node: Node = target_value as Node
		if target_node == null or not is_instance_valid(target_node):
			continue
		if not target_node.has_method("take_damage"):
			continue
		debug_enemy_log("Applying delayed attack damage to %s" % target_node.name)
		var hit_context: Dictionary = {}
		hit_context["attacker"] = self
		hit_context["source_node"] = attack_area
		hit_context["strike_direction"] = Vector2(_get_facing_sign(), 0.0)
		target_node.call("take_damage", _contact_damage, hit_context)

func _on_attack_area_entered(area: Area2D) -> void:
	if area == null or _death_animation_locked:
		return
	if not is_attack_animation_active():
		return
	_queue_attack_target_from_area(area)

func _queue_current_attack_overlaps() -> void:
	if attack_area == null or _death_animation_locked:
		return
	if not attack_area.monitoring:
		return
	if not is_attack_animation_active():
		return

	var queued_from_hitboxes: bool = _queue_attack_targets_from_hitbox_shapes()
	if queued_from_hitboxes:
		return

	var overlapping_areas_variant: Variant = attack_area.get_overlapping_areas()
	if not (overlapping_areas_variant is Array):
		return

	var overlapping_areas: Array = overlapping_areas_variant as Array
	for overlapping_area_value: Variant in overlapping_areas:
		if not (overlapping_area_value is Area2D):
			continue
		var overlapping_area: Area2D = overlapping_area_value as Area2D
		_queue_attack_target_from_area(overlapping_area)

func _queue_attack_targets_from_hitbox_shapes() -> bool:
	var hitboxes: Array[CollisionShape2D] = _get_active_attack_hitboxes()
	if hitboxes.is_empty():
		return false

	var queued_any: bool = false
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	for hitbox: CollisionShape2D in hitboxes:
		var shape_query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
		shape_query.shape = hitbox.shape
		shape_query.transform = hitbox.global_transform
		shape_query.collision_mask = attack_area.collision_mask
		shape_query.collide_with_areas = true
		shape_query.collide_with_bodies = false
		var exclusions: Array[RID] = [get_rid()]
		shape_query.exclude = exclusions
		var results: Array[Dictionary] = space_state.intersect_shape(shape_query, 16)
		for result: Dictionary in results:
			var collider_value: Variant = result.get("collider", null)
			if collider_value is Area2D:
				var target_area: Area2D = collider_value as Area2D
				_queue_attack_target_from_area(target_area)
				queued_any = true
	return queued_any

func _get_active_attack_hitboxes() -> Array[CollisionShape2D]:
	var hitboxes: Array[CollisionShape2D] = []
	if attack_hit_box_left != null and not attack_hit_box_left.disabled and attack_hit_box_left.shape != null:
		hitboxes.append(attack_hit_box_left)
	if attack_hit_box_right != null and not attack_hit_box_right.disabled and attack_hit_box_right.shape != null:
		hitboxes.append(attack_hit_box_right)
	if attack_hit_box_above != null and not attack_hit_box_above.disabled and attack_hit_box_above.shape != null:
		hitboxes.append(attack_hit_box_above)
	return hitboxes

func _queue_attack_target_from_area(area: Area2D) -> void:
	if area == null:
		return
	var target_node: Node = area.get_parent()
	if target_node != null and target_node.has_method("take_damage"):
		_queue_attack_target(target_node)

func _on_animation_started(animation_name: StringName) -> void:
	debug_enemy_log("animation_started: %s" % String(animation_name))
	if animation_name == ANIMATION_CLIP_ATTACK:
		_play_profile_audio_cue(&"attack")
		_queued_attack_targets.clear()
		set_attack_hitboxes_enabled(true)
		return
	if animation_name == ANIMATION_CLIP_TAKE_HIT:
		_apply_take_hit_knockback()
	set_attack_hitboxes_enabled(false)

func _on_animation_finished(animation_name: StringName) -> void:
	debug_enemy_log("animation_finished: %s" % String(animation_name))
	if animation_name == ANIMATION_CLIP_ATTACK:
		_queue_current_attack_overlaps()
		_apply_queued_attack_damage()
		set_attack_hitboxes_enabled(false)
		return
	if animation_name == ANIMATION_CLIP_TAKE_HIT:
		_take_hit_reaction_timer = 0.0
		_hurt_box_reenable_timer = 0.0
		if not _death_animation_locked:
			_set_hurt_box_enabled(true)
		_play_animation_state(ANIMATION_STATE_MOVE)
		return
	if animation_name == ANIMATION_CLIP_DEATH and not is_queued_for_deletion():
		debug_enemy_log("Death animation finished; queue_free")
		queue_free()

func _should_wait_for_death_animation() -> bool:
	if animation_tree != null:
		return true
	if animation_player != null and animation_player.has_animation(ANIMATION_CLIP_DEATH):
		return true
	return false

func _perform_melee_attack(target: Node2D) -> bool:
	if _death_animation_locked or target == null:
		return false
	return _request_attack(target, _get_attack_direction(target))

func _get_attack_direction(target: Node2D) -> Vector2:
	if target == null:
		return Vector2(_get_facing_sign(), 0.0)
	var attack_direction: Vector2 = target.global_position - global_position
	if attack_direction.length_squared() <= 0.001:
		return Vector2(_get_facing_sign(), 0.0)
	return attack_direction.normalized()

func _apply_take_hit_knockback() -> void:
	if is_zero_approx(_pending_take_hit_knockback_direction):
		_pending_take_hit_knockback_direction = -_get_facing_sign()
	var resolved_scale: float = maxf(_pending_take_hit_knockback_scale, 0.0)
	if not is_zero_approx(_pending_take_hit_knockback_direction):
		velocity.x = _pending_take_hit_knockback_direction * take_hit_knockback_speed * resolved_scale
		_update_facing(_pending_take_hit_knockback_direction)
	if is_on_floor() and take_hit_knockback_lift > 0.0:
		velocity.y = -take_hit_knockback_lift * resolved_scale
	_take_hit_reaction_timer = take_hit_reaction_seconds
	debug_enemy_log("_apply_take_hit_knockback vx=%.2f vy=%.2f scale=%.2f" % [velocity.x, velocity.y, resolved_scale])
	_pending_take_hit_knockback_direction = 0.0
	_pending_take_hit_knockback_scale = 1.0

func _resolve_damage_knockback_direction(source: Variant) -> float:
	if source is Dictionary:
		var source_dictionary: Dictionary = source as Dictionary
		if source_dictionary.has("strike_direction"):
			var strike_direction_value: Variant = source_dictionary["strike_direction"]
			if strike_direction_value is Vector2:
				return _resolve_strike_knockback_direction(strike_direction_value as Vector2)
		if source_dictionary.has("attacker"):
			var attacker_value: Variant = source_dictionary["attacker"]
			var attacker_node: Node2D = _resolve_damage_source_node(attacker_value)
			if attacker_node != null:
				var attacker_delta: float = global_position.x - attacker_node.global_position.x
				if absf(attacker_delta) > 0.01:
					return signf(attacker_delta)
	var source_node_2d: Node2D = _resolve_damage_source_node(source)
	if source_node_2d != null:
		var horizontal_delta: float = global_position.x - source_node_2d.global_position.x
		if absf(horizontal_delta) > 0.01:
			return signf(horizontal_delta)
	return -_get_facing_sign()

func _resolve_damage_knockback_scale(source: Variant) -> float:
	if source is Dictionary:
		var source_dictionary: Dictionary = source as Dictionary
		if source_dictionary.has("knockback_scale"):
			var knockback_scale_value: Variant = source_dictionary["knockback_scale"]
			if typeof(knockback_scale_value) == TYPE_FLOAT or typeof(knockback_scale_value) == TYPE_INT:
				return maxf(float(knockback_scale_value), 0.0)
	return 1.0

func _resolve_strike_knockback_direction(strike_direction: Vector2) -> float:
	if absf(strike_direction.x) > 0.01:
		return signf(strike_direction.x)
	return -_get_facing_sign()

func _resolve_damage_source_node(source: Variant) -> Node2D:
	if source is Node2D:
		return source as Node2D
	if source is Node:
		var source_node: Node = source as Node
		var parent_node: Node = source_node.get_parent()
		if parent_node is Node2D:
			return parent_node as Node2D
	return null

func _move_in_direction(direction: float, speed: float, delta: float) -> void:
	var clamped_direction: float = signf(direction)
	if absf(clamped_direction) <= 0.01:
		_apply_horizontal_friction(delta)
		return
	velocity.x = move_toward(velocity.x, clamped_direction * speed, _acceleration * delta)
	_update_facing(clamped_direction)

func _should_turn_during_patrol(direction: float) -> bool:
	if absf(direction) <= 0.01:
		return false
	if _is_wall_ahead(direction):
		return true
	return not _has_floor_ahead(direction)

func _try_combat_wall_jump(direction: float) -> bool:
	if not combat_wall_jump_enabled:
		return false
	if _combat_wall_jump_cooldown_timer > 0.0:
		return false
	if not is_on_floor():
		return false
	if velocity.y < 0.0:
		return false
	var direction_sign: float = signf(direction)
	if absf(direction_sign) <= 0.01:
		return false
	if not _is_wall_ahead_with_probe_distance(direction_sign, combat_wall_jump_probe_distance):
		return false
	var jump_height: float = _find_jumpable_wall_height(direction_sign, combat_wall_jump_max_wall_height, combat_wall_jump_probe_distance)
	if jump_height <= 0.0:
		return false
	velocity.y = -combat_wall_jump_velocity
	_combat_wall_jump_cooldown_timer = combat_wall_jump_cooldown_seconds
	debug_enemy_log("combat_wall_jump dir=%.0f height=%.1f vy=%.2f" % [direction_sign, jump_height, velocity.y])
	return true

func _is_wall_ahead(direction: float) -> bool:
	return _is_wall_ahead_with_probe_distance(direction, patrol_wall_probe_distance)

func _is_wall_ahead_with_probe_distance(direction: float, probe_distance: float) -> bool:
	var direction_sign: float = signf(direction)
	if absf(direction_sign) <= 0.01:
		return false
	var start: Vector2 = _get_patrol_wall_probe_start(direction_sign)
	var finish: Vector2 = start + Vector2(direction_sign * maxf(1.0, probe_distance), 0.0)
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(start, finish)
	var exclusions: Array[RID] = [get_rid()]
	query.exclude = exclusions
	query.collision_mask = collision_mask
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var result: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return false
	if CharacterStepUtility.can_step_up(self, direction_sign, step_height, step_probe_distance):
		return false
	return true

func _find_jumpable_wall_height(direction: float, max_wall_height: float, probe_distance: float) -> float:
	var direction_sign: float = signf(direction)
	if absf(direction_sign) <= 0.01:
		return 0.0
	if max_wall_height <= 0.0 or probe_distance <= 0.0:
		return 0.0
	var forward_motion: Vector2 = Vector2(direction_sign * maxf(1.0, probe_distance), 0.0)
	if not test_move(global_transform, forward_motion):
		return 0.0
	var max_height_steps: int = int(round(max_wall_height))
	for height_step_value in range(1, max_height_steps + 1):
		var height_step: int = int(height_step_value)
		var raise_motion: Vector2 = Vector2(0.0, -float(height_step))
		if test_move(global_transform, raise_motion):
			continue
		var raised_transform: Transform2D = global_transform.translated(raise_motion)
		if test_move(raised_transform, forward_motion):
			continue
		return float(height_step)
	return 0.0

func _get_patrol_wall_probe_start(direction: float) -> Vector2:
	var direction_sign: float = signf(direction)
	var body_center: Vector2 = Vector2.ZERO
	if enemy_hit_box != null:
		body_center = enemy_hit_box.position
	var half_width: float = _get_body_half_width()
	return global_position + body_center + Vector2(direction_sign * half_width, 0.0)

func _has_floor_ahead(direction: float) -> bool:
	return _has_floor_ahead_with_probe(direction, patrol_ledge_probe_forward_distance, patrol_ledge_probe_depth)

func _has_safe_combat_floor_ahead(direction: float) -> bool:
	return _has_floor_ahead_with_probe(direction, combat_ledge_probe_forward_distance, combat_ledge_probe_depth)

func _has_floor_ahead_with_probe(direction: float, forward_distance: float, probe_depth: float) -> bool:
	if enemy_hit_box == null:
		return true
	var direction_sign: float = signf(direction)
	if absf(direction_sign) <= 0.01:
		return true
	if probe_depth <= 0.0:
		return true

	var clamped_forward_distance: float = maxf(forward_distance, 0.0)
	var front_offset_x: float = enemy_hit_box.position.x + direction_sign * (_get_body_half_width() + clamped_forward_distance)
	var feet_offset_y: float = enemy_hit_box.position.y + _get_body_half_height()
	var start: Vector2 = global_position + Vector2(front_offset_x, feet_offset_y - patrol_ledge_probe_raise)
	var finish: Vector2 = start + Vector2(0.0, probe_depth)
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(start, finish)
	var exclusions: Array[RID] = [get_rid()]
	query.exclude = exclusions
	query.collision_mask = collision_mask
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var result: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	return not result.is_empty()

func _get_body_half_width() -> float:
	if enemy_hit_box == null or enemy_hit_box.shape == null:
		return DEFAULT_BODY_HALF_WIDTH
	var shape: Shape2D = enemy_hit_box.shape
	if shape is RectangleShape2D:
		var rectangle: RectangleShape2D = shape as RectangleShape2D
		return rectangle.size.x * 0.5
	if shape is CapsuleShape2D:
		var capsule: CapsuleShape2D = shape as CapsuleShape2D
		return capsule.radius
	if shape is CircleShape2D:
		var circle: CircleShape2D = shape as CircleShape2D
		return circle.radius
	return DEFAULT_BODY_HALF_WIDTH

func _get_body_half_height() -> float:
	if enemy_hit_box == null or enemy_hit_box.shape == null:
		return DEFAULT_BODY_HALF_HEIGHT
	var shape: Shape2D = enemy_hit_box.shape
	if shape is RectangleShape2D:
		var rectangle: RectangleShape2D = shape as RectangleShape2D
		return rectangle.size.y * 0.5
	if shape is CapsuleShape2D:
		var capsule: CapsuleShape2D = shape as CapsuleShape2D
		return maxf(capsule.height * 0.5, capsule.radius)
	if shape is CircleShape2D:
		var circle: CircleShape2D = shape as CircleShape2D
		return circle.radius
	return DEFAULT_BODY_HALF_HEIGHT

func _update_facing(direction: float) -> void:
	super._update_facing(direction)
	if attack_area != null and absf(direction) > 0.01:
		var attack_scale: Vector2 = attack_area.scale
		attack_scale.x = -1.0 if direction < 0.0 else 1.0
		attack_area.scale = attack_scale

func _get_facing_sign() -> float:
	if sprite != null:
		return -1.0 if sprite.flip_h else 1.0
	if animated_sprite != null:
		return -1.0 if animated_sprite.flip_h else 1.0
	if absf(_patrol_direction) > 0.01:
		return signf(_patrol_direction)
	return 1.0
