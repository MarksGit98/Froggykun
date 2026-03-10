extends CharacterBody2D

const AnimationConstants = preload("res://scripts/constants/animation_constants.gd")

@export var speed : float = 240.0
@export var jump_velocity : float = -450.0
@export var ground_acceleration : float = 1800.0
@export var ground_turn_acceleration : float = 2600.0
@export var ground_friction : float = 2400.0
@export var air_acceleration : float = 900.0
@export var air_turn_acceleration : float = 1300.0
@export var air_friction : float = 250.0
@export var coyote_time_seconds : float = 0.12
@export var step_height : float = 8.0
@export var step_probe_distance : float = 2.0
@export var jump_ledge_snap_height : float = 6.0
@export var jump_ledge_snap_forward_distance : float = 2.0
@export var jump_ledge_snap_floor_probe_distance : float = 8.0
@export var state_contact_grace_frames : float = 4.0
@export var wall_min_floor_clearance : float = 25.0
@export var wall_min_height : float = 42.0
@export var wall_attach_snap_distance : float = 5.0
@export var wall_contact_grace_seconds : float = 0.08
@export var wall_slide_gravity_scale : float = 0.28
@export var wall_attach_hysteresis_seconds : float = 0.05
@export var wall_detach_hysteresis_seconds : float = 0.12
@export var wall_state_hit_box_offset : Vector2 = Vector2(6.0, -25.0)
@export var wall_state_hit_box_size : Vector2 = Vector2(9.0, 27.0)
@export var wall_state_hurt_box_offset : Vector2 = Vector2(6.0, -25.0)
@export var wall_state_hurt_box_size : Vector2 = Vector2(9.0, 27.0)
@export var wall_sprite_contact_offset_x : float = 10.0
@export var wall_sprite_contact_left_extra_x : float = 1.0
@export var ground_jump_ascent_gravity_scale : float = 0.85
@export var ground_jump_descent_gravity_scale : float = 1.25
@export var jump_transition_fall_gravity_boost_scale : float = 1.35
@export var jump_transition_downward_velocity_boost : float = 60.0
@export var fall_acceleration_multiplier : float = 1.1
@export var fall_acceleration_ramp_speed : float = 400.0
@export var max_fall_speed : float = 800.0
@export var wall_jump_input_buffer_seconds : float = 0.16
@export var wall_jump_control_lock_seconds : float = 0.18
@export var wall_jump_reattach_cooldown_seconds : float = 0.08
@export var wall_jump_queue_release_seconds : float = 0.02
@export var dash_distance : float = 120.0
@export var dash_duration_seconds : float = 0.18
@export var dash_speed_scale : float = 0.9
@export var dash_exit_speed_retention : float = 0.35
@export var dash_cooldown_seconds : float = 2.0
@export_flags_2d_physics var dash_terrain_collision_mask : int = 1
@export var dash_min_travel_distance : float = 8.0
@export var dash_invulnerability_frames : int = 5
@export var grounded_attack_floor_probe_distance : float = 6.0
@export var grounded_attack_ledge_grace_seconds : float = 0.08
@export var attack_chain_window_seconds : float = 0.5 
@export var attack_input_buffer_seconds : float = 0.2
@export var attack_combo_cooldown_seconds : float = 1.0
@export var air_attack_cooldown_seconds : float = 1.0
@export var debug_attack_logs : bool = true
@export var wall_jump_velocity : float = -380.0
@export var wall_jump_horizontal_speed : float = 220.0
@export var wall_jump_boost_horizontal_speed : float = 300.0
@export var wall_jump_toward_wall_vertical_scale : float = 0.7
@export var fall_death_y : float = 420.0
@export var max_health : float = 10.0
@export var damage_invulnerability_seconds : float = 0.35
@export var damage_knockback_speed : float = 250.0
@export var damage_knockback_lift : float = 50.0
@export var sword_damage : float = 3.0
@export var combo_finisher_sword_damage : float = 4.0
@export var defend_cooldown_seconds : float = 2.0
@export var defend_block_knockback_scale : float = 0.6
@export var defend_counter_knockback_multiplier : float = 2.0

@onready var collision_shape : CollisionShape2D = get_node_or_null("PlayerHitBox") as CollisionShape2D
@onready var hurt_box_shape : CollisionShape2D = get_node_or_null("HurtBox/HurtBoxShape") as CollisionShape2D
@onready var sprite : Sprite2D = $Sprite2D
@onready var animation_player : AnimationPlayer = $AnimationPlayer
@onready var animation_tree : AnimationTree = $AnimationTree
@onready var state_machine : PlayerStateMachine = $PlayerStateMachine
@onready var attacking_state : State = $PlayerStateMachine/Attacking
@onready var dashing_state : State = $PlayerStateMachine/Dashing
@onready var walled_state : State = $PlayerStateMachine/Walled
@onready var death_state : State = $PlayerStateMachine/Dead
@onready var defend_state : State = $PlayerStateMachine/Defend
@onready var sword_area : Area2D = get_node_or_null("Sword") as Area2D

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var direction : Vector2 = Vector2.ZERO
var ground_jump_coyote_timer : float = 0.0
var wall_jump_input_buffer_timer : float = 0.0
var wall_jump_control_lock_timer : float = 0.0
var wall_jump_reattach_cooldown_timer : float = 0.0
var wall_contact_grace_timer : float = 0.0
var floor_state_contact_timer : float = 0.0
var wall_state_contact_timer : float = 0.0
var attack_chain_timer : float = 0.0
var attack_input_buffer_timer : float = 0.0
var attack_combo_cooldown_timer : float = 0.0
var air_attack_cooldown_timer : float = 0.0
var grounded_attack_ledge_grace_timer : float = 0.0
var current_health : float = 0.0
var damage_invulnerability_timer : float = 0.0
var dash_invulnerability_timer : float = 0.0
var defend_cooldown_timer : float = 0.0
var _defend_cast_active : bool = false
var _defend_successful : bool = false
var _defend_player_hit_flag : bool = false
var _defend_source_state_name : StringName = StringName()
var _defend_counter_attacker : Node2D = null
var current_attack_stage : int = 0
var queued_attack_stage : int = 0
var _attack_animation_requested : bool = false
var _air_attack_animation_requested : bool = false
var _air_attack_active : bool = false
var _air_attack_return_jump_requested : bool = false
var _air_attack_source_state_name : StringName = StringName()
var _started_animations : Array[StringName] = []
var _finished_animations : Array[StringName] = []
var _last_wall_normal : Vector2 = Vector2.ZERO
var _wall_jump_animation_requested : bool = false
var _dash_active : bool = false
var _dash_direction : float = 0.0
var _dash_speed : float = 0.0
var _dash_remaining_distance : float = 0.0
var _dash_cooldown_timer : float = 0.0
var _dash_jump_queued : bool = false
var _dash_attack_queued : bool = false
var _ground_jump_curve_active : bool = false
var _sprite_base_position : Vector2 = Vector2.ZERO

func _ready() -> void:
	current_health = max_health
	if not is_in_group(&"player"):
		add_to_group(&"player")
	if sprite != null:
		_sprite_base_position = sprite.position
	animation_tree.active = true
	if not animation_tree.animation_started.is_connected(_on_animation_tree_animation_started):
		animation_tree.animation_started.connect(_on_animation_tree_animation_started)
	if not animation_tree.animation_finished.is_connected(_on_animation_tree_animation_finished):
		animation_tree.animation_finished.connect(_on_animation_tree_animation_finished)
	if sword_area != null and sword_area.has_signal("strike_landed"):
		var landed_callable := Callable(self, "_on_sword_strike_landed")
		if not sword_area.is_connected("strike_landed", landed_callable):
			sword_area.connect("strike_landed", landed_callable)

func _play_audio_cue(cue_id: StringName) -> void:
	var audio_manager: Node = get_node_or_null("/root/AudioManager")
	if audio_manager == null or not audio_manager.has_method("play_sfx"):
		return
	audio_manager.call("play_sfx", cue_id, self)

func _on_sword_strike_landed(_target: Node, _strike_direction: Vector2, _applied_damage: float) -> void:
	_play_audio_cue(&"player_hit_confirm")

func _physics_process(delta):
	_update_wall_jump_timers(delta)
	_update_dash_timers(delta)
	_update_attack_timers(delta)
	_update_damage_timers(delta)

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	direction = Input.get_vector("move_left", "move_right", "jump", "move_down")

	if _is_walled_state_active():
		prepare_wall_state_collision()

	if _dash_active:
		_update_dash_motion(delta)
	else:
		# Add the gravity.
		if not is_on_floor():
			var gravity_scale: float = wall_slide_gravity_scale if _is_walled_state_active() and velocity.y >= 0.0 else 1.0
			var fall_acceleration_scale := _get_fall_acceleration_scale()
			velocity.y += gravity * gravity_scale * fall_acceleration_scale * delta
			if max_fall_speed > 0.0:
				velocity.y = minf(velocity.y, max_fall_speed)

		# Control whether to move or not to move
		if wall_jump_control_lock_timer > 0.0:
			pass
		else:
			_update_horizontal_velocity(delta)

	_try_snap_to_nearby_wall()
	_try_step_up()
	move_and_slide()
	_update_wall_contact_state(delta)
	_update_state_contact_timers(delta)
	_update_grounded_attack_ledge_grace(delta)
	_update_ground_jump_coyote_timer(delta)
	_trigger_fall_death_if_needed()
	update_animation_parameters()
	update_facing_direction()
	_update_wall_sprite_contact_offset()

func request_ground_jump(jump_speed: float) -> bool:
	if not is_on_floor() and ground_jump_coyote_timer <= 0.0:
		return false

	velocity.y = jump_speed
	ground_jump_coyote_timer = 0.0
	floor_state_contact_timer = 0.0
	_ground_jump_curve_active = true
	_air_attack_return_jump_requested = false
	_play_audio_cue(&"player_jump")
	return true

func request_dash() -> bool:
	if _dash_active:
		debug_attack_log("request_dash rejected: already active")
		return false
	if _dash_cooldown_timer > 0.0:
		debug_attack_log("request_dash rejected: cooldown %.3f" % _dash_cooldown_timer)
		return false

	var dash_direction := _resolve_dash_direction()
	if is_zero_approx(dash_direction):
		debug_attack_log("request_dash rejected: no dash direction")
		return false

	var clamped_dash_distance := _resolve_dash_travel_distance(dash_direction, dash_distance)
	if clamped_dash_distance < dash_min_travel_distance:
		debug_attack_log("request_dash rejected: terrain blocks dash (distance=%.2f min=%.2f)" % [clamped_dash_distance, dash_min_travel_distance])
		return false

	var dash_duration := maxf(dash_duration_seconds, 0.01)
	var effective_dash_scale := clampf(dash_speed_scale, 0.1, 1.0)
	_dash_active = true
	_dash_direction = dash_direction
	_dash_speed = (dash_distance * effective_dash_scale) / dash_duration
	_dash_remaining_distance = clamped_dash_distance * effective_dash_scale
	_dash_jump_queued = false
	_dash_attack_queued = false
	_ground_jump_curve_active = false
	_start_dash_invulnerability()

	if sprite != null:
		sprite.flip_h = _dash_direction < 0.0
	debug_attack_log("request_dash accepted dir=%.0f speed=%.2f distance=%.2f (requested=%.2f)" % [
		_dash_direction,
		_dash_speed,
		_dash_remaining_distance,
		dash_distance,
	])
	_play_audio_cue(&"player_dash")
	return true

func stop_action_motion() -> void:
	_dash_active = false
	_dash_direction = 0.0
	_dash_speed = 0.0
	_dash_remaining_distance = 0.0
	_dash_jump_queued = false
	_dash_attack_queued = false
	dash_invulnerability_timer = 0.0
	velocity = Vector2.ZERO

func is_dash_active() -> bool:
	return _dash_active

func is_dash_invulnerable() -> bool:
	return dash_invulnerability_timer > 0.0

func buffer_dash_jump_input() -> void:
	_dash_jump_queued = true
	debug_attack_log("dash_jump_buffered")

func buffer_dash_attack_input() -> void:
	_dash_attack_queued = true
	debug_attack_log("dash_attack_buffered")

func consume_buffered_dash_jump_input() -> bool:
	if not _dash_jump_queued:
		return false
	_dash_jump_queued = false
	debug_attack_log("consume_dash_jump_buffer -> true")
	return true

func consume_buffered_dash_attack_input() -> bool:
	if not _dash_attack_queued:
		return false
	_dash_attack_queued = false
	debug_attack_log("consume_dash_attack_buffer -> true")
	return true

func request_ground_attack() -> bool:
	debug_attack_log("request_ground_attack called")
	if not is_on_floor():
		debug_attack_log("request_ground_attack rejected: not on floor")
		return false
	if attack_combo_cooldown_timer > 0.0 and current_attack_stage == 0:
		debug_attack_log("request_ground_attack rejected: combo cooldown active")
		return false

	if _is_attacking_state_active():
		if current_attack_stage <= 0 or current_attack_stage >= 3:
			debug_attack_log("request_ground_attack rejected: invalid current attack stage while attacking")
			return false
		queued_attack_stage = maxi(queued_attack_stage, current_attack_stage + 1)
		attack_input_buffer_timer = attack_input_buffer_seconds
		debug_attack_log("request_ground_attack queued next stage -> %d" % queued_attack_stage)
		return true

	var next_attack_stage := 1
	if current_attack_stage > 0 and current_attack_stage < 3 and attack_chain_timer > 0.0:
		next_attack_stage = mini(current_attack_stage + 1, 3)

	current_attack_stage = next_attack_stage
	queued_attack_stage = 0
	attack_input_buffer_timer = 0.0
	attack_chain_timer = attack_chain_window_seconds
	_attack_animation_requested = true
	_air_attack_active = false
	_air_attack_animation_requested = false
	_air_attack_return_jump_requested = false
	_air_attack_source_state_name = StringName()
	debug_attack_log("request_ground_attack started stage %d" % current_attack_stage)
	return true

func has_queued_ground_attack() -> bool:
	return queued_attack_stage == current_attack_stage + 1

func consume_queued_ground_attack() -> bool:
	if not has_queued_ground_attack():
		debug_attack_log("consume_queued_ground_attack -> false")
		return false

	current_attack_stage = queued_attack_stage
	queued_attack_stage = 0
	attack_input_buffer_timer = 0.0
	attack_chain_timer = attack_chain_window_seconds
	_attack_animation_requested = true
	debug_attack_log("consume_queued_ground_attack -> true, current stage %d" % current_attack_stage)
	return true

func request_air_attack(source_state_name: StringName) -> bool:
	if is_on_floor():
		return false
	if air_attack_cooldown_timer > 0.0:
		return false
	if _is_walled_state_active():
		return false
	if _is_attacking_state_active() and _air_attack_active:
		return false

	_air_attack_active = true
	_air_attack_source_state_name = source_state_name
	_air_attack_animation_requested = true
	_attack_animation_requested = false
	attack_input_buffer_timer = 0.0
	queued_attack_stage = 0
	air_attack_cooldown_timer = air_attack_cooldown_seconds
	return true

func get_current_attack_animation() -> StringName:
	match current_attack_stage:
		1:
			return AnimationConstants.PLAYER_ATTACK_1
		2:
			return AnimationConstants.PLAYER_ATTACK_2
		3:
			return AnimationConstants.PLAYER_ATTACK_3
		_:
			return StringName()

func get_sword_damage() -> float:
	if _air_attack_active:
		return combo_finisher_sword_damage
	if get_current_attack_animation() == AnimationConstants.PLAYER_ATTACK_3:
		return combo_finisher_sword_damage
	return sword_damage

func get_sword_knockback_scale() -> float:
	if sword_area != null and sword_area.has_method("get_strike_knockback_scale"):
		var knockback_value: Variant = sword_area.call("get_strike_knockback_scale")
		if typeof(knockback_value) == TYPE_FLOAT or typeof(knockback_value) == TYPE_INT:
			return maxf(float(knockback_value), 0.0)
	return 1.0

func get_queued_attack_animation() -> StringName:
	match queued_attack_stage:
		1:
			return AnimationConstants.PLAYER_ATTACK_1
		2:
			return AnimationConstants.PLAYER_ATTACK_2
		3:
			return AnimationConstants.PLAYER_ATTACK_3
		_:
			return StringName()

func get_requested_attack_animation() -> StringName:
	if _attack_animation_requested:
		return get_current_attack_animation()
	return StringName()

func finish_attack_sequence() -> void:
	debug_attack_log("finish_attack_sequence called")
	_attack_animation_requested = false
	_air_attack_active = false
	_air_attack_animation_requested = false
	if current_attack_stage >= 3:
		current_attack_stage = 0
		queued_attack_stage = 0
		attack_input_buffer_timer = 0.0
		attack_chain_timer = 0.0
		attack_combo_cooldown_timer = attack_combo_cooldown_seconds
	else:
		attack_chain_timer = attack_chain_window_seconds

func cancel_attack_sequence() -> void:
	debug_attack_log("cancel_attack_sequence called")
	_clear_queued_sword_damage()
	current_attack_stage = 0
	queued_attack_stage = 0
	attack_input_buffer_timer = 0.0
	attack_chain_timer = 0.0
	attack_combo_cooldown_timer = 0.0
	_attack_animation_requested = false
	_air_attack_active = false
	_air_attack_animation_requested = false

func finish_air_attack() -> void:
	_air_attack_active = false
	_air_attack_animation_requested = false
	_air_attack_source_state_name = StringName()

func prepare_air_attack_return_to_jump() -> void:
	_air_attack_return_jump_requested = true

func is_air_attack_return_jump_requested() -> bool:
	return _air_attack_return_jump_requested

func clear_air_attack_return_jump_request() -> void:
	_air_attack_return_jump_requested = false

func is_attack_animation_requested() -> bool:
	return _attack_animation_requested

func clear_attack_animation_request() -> void:
	_attack_animation_requested = false

func is_air_attack_animation_requested() -> bool:
	return _air_attack_animation_requested

func clear_air_attack_animation_request() -> void:
	_air_attack_animation_requested = false

func is_air_attack_active() -> bool:
	return _air_attack_active

func get_air_attack_source_state_name() -> StringName:
	return _air_attack_source_state_name

func request_defend(source_state_name: StringName) -> bool:
	if death_state != null and state_machine != null and state_machine.current_state == death_state:
		return false
	if defend_cooldown_timer > 0.0:
		debug_attack_log("request_defend rejected cooldown=%.2f" % defend_cooldown_timer)
		return false
	if _defend_cast_active:
		debug_attack_log("request_defend rejected cast already active")
		return false
	if source_state_name == AnimationConstants.PLAYER_STATE_ATTACKING:
		cancel_attack_sequence()
	_defend_cast_active = true
	_defend_successful = false
	_defend_player_hit_flag = false
	_defend_source_state_name = source_state_name
	_defend_counter_attacker = null
	if not _start_queue_defense_animation():
		_defend_cast_active = false
		_defend_source_state_name = StringName()
		_defend_counter_attacker = null
		debug_attack_log("request_defend failed to start queue_defense")
		return false
	debug_attack_log("request_defend started source=%s" % String(source_state_name))
	_play_audio_cue(&"player_defend_queue")
	return true

func get_defend_source_state_name() -> StringName:
	return _defend_source_state_name

func get_defend_debug_text() -> String:
	return "cast=%s success=%s player_hit=%s cooldown=%.2f source=%s" % [
		str(_defend_cast_active),
		str(_defend_successful),
		str(_defend_player_hit_flag),
		defend_cooldown_timer,
		String(_defend_source_state_name),
	]

func get_wall_debug_text() -> String:
	var touch_left: bool = false
	var touch_right: bool = false
	var snap_left: float = -1.0
	var snap_right: float = -1.0
	if collision_shape != null and collision_shape.shape != null:
		touch_left = test_move(global_transform, Vector2(-1.0, 0.0))
		touch_right = test_move(global_transform, Vector2(1.0, 0.0))
		snap_left = _resolve_wall_contact_snap_distance(-1.0, maxf(wall_attach_snap_distance, 1.0))
		snap_right = _resolve_wall_contact_snap_distance(1.0, maxf(wall_attach_snap_distance, 1.0))
	return "wall=%s attach=%s can=%s stable=%s nx=%.0f last=%.0f L(t=%s s=%.2f) R(t=%s s=%.2f)" % [
		str(is_on_wall()),
		str(has_wall_attach_contact()),
		str(can_attach_to_wall()),
		str(has_stable_wall_contact()),
		_resolve_wall_normal().x,
		_last_wall_normal.x,
		str(touch_left),
		snap_left,
		str(touch_right),
		snap_right,
	]

func start_defend_cooldown() -> void:
	if defend_cooldown_seconds <= 0.0:
		defend_cooldown_timer = 0.0
		return
	defend_cooldown_timer = defend_cooldown_seconds
	debug_attack_log("defend_cooldown_started %.2f" % defend_cooldown_timer)


func get_animation_length(animation_name: StringName) -> float:
	if animation_player == null:
		return 0.0
	if not animation_player.has_animation(animation_name):
		return 0.0
	var animation_resource: Animation = animation_player.get_animation(animation_name)
	if animation_resource == null:
		return 0.0
	return animation_resource.length

func clear_defend_state() -> void:
	debug_attack_log("clear_defend_state called")
	_defend_cast_active = false
	_defend_successful = false
	_defend_player_hit_flag = false
	_defend_source_state_name = StringName()
	_defend_counter_attacker = null

func consume_defend_player_hit_flag() -> bool:
	if not _defend_player_hit_flag:
		return false
	_defend_player_hit_flag = false
	return true

func apply_defend_counter_knockback() -> void:
	if not _defend_successful:
		return
	if _defend_counter_attacker == null or not is_instance_valid(_defend_counter_attacker):
		debug_attack_log("defend_counter skipped: attacker missing")
		_defend_counter_attacker = null
		return
	var attacker_node: Node2D = _defend_counter_attacker
	var counter_scale: float = get_sword_knockback_scale() * maxf(defend_counter_knockback_multiplier, 0.0)
	var strike_direction: Vector2 = _resolve_counter_knockback_direction(attacker_node)
	if attacker_node.has_method("apply_defend_counter_knockback"):
		attacker_node.call("apply_defend_counter_knockback", self, counter_scale)
	elif attacker_node.has_method("receive_strike_knockback"):
		attacker_node.call("receive_strike_knockback", strike_direction, counter_scale)
	debug_attack_log("defend_counter applied scale=%.2f attacker=%s dir=(%.2f, %.2f)" % [counter_scale, attacker_node.name, strike_direction.x, strike_direction.y])
	_defend_counter_attacker = null

func _resolve_counter_knockback_direction(attacker_node: Node2D) -> Vector2:
	var delta: Vector2 = attacker_node.global_position - global_position
	if absf(delta.x) > 0.01:
		return Vector2(signf(delta.x), 0.0)
	if sprite != null:
		return Vector2(-1.0, 0.0) if sprite.flip_h else Vector2(1.0, 0.0)
	return Vector2.RIGHT

func _try_consume_defend_hit(source: Variant) -> bool:
	if not _defend_cast_active:
		return false
	var attacker_node: Node = _resolve_defend_attacker(source)
	if attacker_node == null or not attacker_node.is_in_group(&"enemy"):
		return false
	_defend_cast_active = false
	_defend_successful = true
	_defend_player_hit_flag = true
	if animation_tree != null:
		animation_tree.set("parameters/conditions/player_hit", true)
	if attacker_node is Node2D:
		_defend_counter_attacker = attacker_node as Node2D
	else:
		_defend_counter_attacker = null
	_apply_damage_knockback_scaled(source, defend_block_knockback_scale)
	debug_attack_log("defend_success source=%s knockback_scale=%.2f attacker=%s" % [String(_defend_source_state_name), defend_block_knockback_scale, attacker_node.name])
	_play_audio_cue(&"player_defend_block")
	return true

func _start_queue_defense_animation() -> bool:
	if animation_tree == null:
		return false
	while consume_started_animation(AnimationConstants.PLAYER_DEFEND_QUEUE):
		pass
	while consume_finished_animation(AnimationConstants.PLAYER_DEFEND_QUEUE):
		pass
	while consume_started_animation(AnimationConstants.PLAYER_DEFEND_SUCCESS):
		pass
	while consume_finished_animation(AnimationConstants.PLAYER_DEFEND_SUCCESS):
		pass
	var playback_value: Variant = animation_tree.get("parameters/playback")
	if playback_value is AnimationNodeStateMachinePlayback:
		var animation_playback: AnimationNodeStateMachinePlayback = playback_value as AnimationNodeStateMachinePlayback
		animation_tree.active = true
		animation_playback.start(AnimationConstants.PLAYER_DEFEND_QUEUE)
		return true
	return false


func _is_valid_defend_source(source: Variant) -> bool:
	var attacker_node: Node = _resolve_defend_attacker(source)
	if attacker_node != null and attacker_node.is_in_group(&"enemy"):
		return true
	return false

func _resolve_defend_attacker(source: Variant) -> Node:
	if source is Dictionary:
		var source_dictionary: Dictionary = source as Dictionary
		if source_dictionary.has("attacker"):
			var attacker_value: Variant = source_dictionary["attacker"]
			if attacker_value is Node:
				return attacker_value as Node
		if source_dictionary.has("source_node"):
			var source_node_value: Variant = source_dictionary["source_node"]
			if source_node_value is Node:
				var source_node: Node = source_node_value as Node
				var parent_node: Node = source_node.get_parent()
				if parent_node != null:
					return parent_node
	if source is Node:
		return source as Node
	return null

func consume_started_animation(animation_name: StringName) -> bool:
	return _consume_animation_event(_started_animations, animation_name)

func consume_finished_animation(animation_name: StringName) -> bool:
	return _consume_animation_event(_finished_animations, animation_name)

func buffer_wall_jump_input() -> void:
	var previous_timer := wall_jump_input_buffer_timer
	wall_jump_input_buffer_timer = wall_jump_input_buffer_seconds
	debug_attack_log("wall_jump_buffered timer %.3f -> %.3f" % [previous_timer, wall_jump_input_buffer_timer])

func try_buffered_wall_jump() -> bool:
	if wall_jump_input_buffer_timer <= 0.0:
		debug_attack_log("try_buffered_wall_jump skipped: buffer empty")
		return false
	debug_attack_log("try_buffered_wall_jump attempting execution")
	var executed := request_wall_jump()
	debug_attack_log("try_buffered_wall_jump result=%s" % str(executed))
	return executed

func has_buffered_wall_jump_input() -> bool:
	return wall_jump_input_buffer_timer > 0.0

func request_wall_jump() -> bool:
	if is_on_floor():
		debug_attack_log("request_wall_jump rejected: on_floor")
		return false

	var attach_contact := has_wall_attach_contact()
	var contact_grace := has_wall_contact_grace()
	if not attach_contact and not contact_grace:
		debug_attack_log("request_wall_jump rejected: no_contact (attach=%s grace=%s)" % [str(attach_contact), str(contact_grace)])
		return false

	var floor_clearance := has_wall_attach_floor_clearance()
	if not floor_clearance:
		debug_attack_log("request_wall_jump rejected: floor_clearance=false")
		return false

	var wall_normal := _resolve_wall_normal()
	if is_zero_approx(wall_normal.x):
		debug_attack_log("request_wall_jump rejected: wall_normal.x=0")
		return false

	var launch_direction := signf(wall_normal.x)
	var input_direction := signf(Input.get_axis("move_left", "move_right"))
	var horizontal_speed := wall_jump_horizontal_speed
	var vertical_speed := wall_jump_velocity
	if not is_zero_approx(input_direction) and input_direction == launch_direction:
		horizontal_speed = wall_jump_boost_horizontal_speed
	elif not is_zero_approx(input_direction):
		vertical_speed *= wall_jump_toward_wall_vertical_scale

	velocity.x = launch_direction * horizontal_speed
	velocity.y = vertical_speed
	ground_jump_coyote_timer = 0.0
	wall_jump_input_buffer_timer = 0.0
	wall_jump_control_lock_timer = wall_jump_control_lock_seconds
	wall_jump_reattach_cooldown_timer = wall_jump_control_lock_seconds + wall_jump_reattach_cooldown_seconds
	floor_state_contact_timer = 0.0
	wall_state_contact_timer = 0.0
	_ground_jump_curve_active = false
	_wall_jump_animation_requested = true

	if sprite != null:
		sprite.flip_h = launch_direction < 0.0
	debug_attack_log("request_wall_jump executed launch=%.0f input=%.0f vx=%.2f vy=%.2f" % [
		launch_direction,
		input_direction,
		velocity.x,
		velocity.y,
	])
	return true

func is_wall_jump_animation_requested() -> bool:
	return _wall_jump_animation_requested

func clear_wall_jump_animation_request() -> void:
	if _wall_jump_animation_requested:
		debug_attack_log("clear_wall_jump_animation_request")
	_wall_jump_animation_requested = false

func is_wall_jump_control_locked() -> bool:
	return wall_jump_control_lock_timer > 0.0

func is_wall_jump_reattach_cooldown_active() -> bool:
	return wall_jump_reattach_cooldown_timer > 0.0

func has_wall_contact_grace() -> bool:
	return wall_contact_grace_timer > 0.0

func get_wall_jump_queue_release_seconds() -> float:
	return wall_jump_queue_release_seconds

func get_wall_attach_hysteresis_seconds() -> float:
	return wall_attach_hysteresis_seconds

func get_wall_detach_hysteresis_seconds() -> float:
	return wall_detach_hysteresis_seconds

func has_stable_floor_contact() -> bool:
	return is_on_floor() or floor_state_contact_timer > 0.0
	
func has_grounded_attack_floor_contact() -> bool:
	return has_stable_floor_contact() or grounded_attack_ledge_grace_timer > 0.0


func has_stable_wall_contact() -> bool:
	var wall_contact_active: bool = should_remain_walled() if _is_walled_state_active() else can_attach_to_wall()
	return wall_contact_active or has_wall_contact_grace() or wall_state_contact_timer > 0.0

func can_enter_walled_state() -> bool:
	if is_on_floor():
		return false
	return has_wall_attach_contact() and has_wall_attach_height() and has_wall_attach_floor_clearance()

func should_remain_walled() -> bool:
	if is_on_floor():
		return false
	var wall_normal: Vector2 = _get_contact_wall_normal()
	if is_zero_approx(wall_normal.x):
		return false
	var wall_direction_sign: float = -signf(wall_normal.x)
	return _has_wall_contact_in_direction(wall_direction_sign, maxf(wall_attach_snap_distance, 1.0))

func refresh_wall_contact_cache() -> void:
	var wall_normal: Vector2 = _get_contact_wall_normal()
	if is_zero_approx(wall_normal.x):
		return
	_last_wall_normal = wall_normal
	wall_contact_grace_timer = maxf(wall_contact_grace_timer, wall_contact_grace_seconds)
	wall_state_contact_timer = maxf(wall_state_contact_timer, _state_contact_grace_seconds())

func prepare_wall_state_collision() -> void:
	_apply_wall_state_collision_profile()

func has_wall_attach_contact() -> bool:
	if is_on_floor():
		return false
	if is_on_wall():
		return true
	var wall_normal: Vector2 = _get_contact_wall_normal()
	if is_zero_approx(wall_normal.x):
		return false

	var max_probe_offset := maxi(int(round(wall_attach_snap_distance)), 1)
	var wall_probe_direction: float = -signf(wall_normal.x)
	for probe_offset in range(1, max_probe_offset + 1):
		var probe_motion := Vector2(wall_probe_direction * float(probe_offset), 0.0)
		if test_move(global_transform, probe_motion):
			return true

	return false

func can_attach_to_wall() -> bool:
	return can_enter_walled_state()

func has_wall_attach_height() -> bool:
	if wall_min_height <= 0.0:
		return true

	var wall_normal := _resolve_wall_normal()
	if is_zero_approx(wall_normal.x):
		return false

	var probe_distance := maxf(wall_attach_snap_distance, 1.0)
	var raised_transform := global_transform.translated(Vector2(0.0, -wall_min_height))
	var wall_probe_motion := Vector2(-signf(wall_normal.x) * probe_distance, 0.0)
	return test_move(raised_transform, wall_probe_motion)

func _update_dash_motion(delta: float) -> void:
	if not _dash_active:
		return

	velocity.x = _dash_direction * _dash_speed
	velocity.y = 0.0
	_dash_remaining_distance = maxf(_dash_remaining_distance - _dash_speed * delta, 0.0)
	if _dash_remaining_distance > 0.0:
		return

	_dash_active = false
	velocity.x = _dash_direction * minf(absf(velocity.x) * dash_exit_speed_retention, speed)
	debug_attack_log("dash_finished")

func _resolve_dash_direction() -> float:
	var input_direction := signf(Input.get_axis("move_left", "move_right"))
	if not is_zero_approx(input_direction):
		return input_direction
	if absf(velocity.x) > 0.01:
		return signf(velocity.x)
	if sprite != null:
		return -1.0 if sprite.flip_h else 1.0
	return 1.0

func _resolve_dash_travel_distance(dash_direction: float, requested_distance: float) -> float:
	var travel_distance := maxf(requested_distance, 0.0)
	if travel_distance <= 0.0:
		return 0.0
	if collision_shape == null or collision_shape.shape == null:
		return travel_distance

	var safe_distance := _cast_dash_safe_distance(dash_direction, travel_distance, 0.0)
	if is_on_floor() and safe_distance < dash_min_travel_distance:
		# Retry slightly above ground to avoid floor-contact false positives when grounded.
		safe_distance = maxf(safe_distance, _cast_dash_safe_distance(dash_direction, travel_distance, -2.0))
	return safe_distance

func _cast_dash_safe_distance(dash_direction: float, travel_distance: float, y_offset: float) -> float:
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = collision_shape.shape
	query.transform = collision_shape.global_transform.translated(Vector2(0.0, y_offset))
	query.motion = Vector2(dash_direction * travel_distance, 0.0)
	query.collision_mask = dash_terrain_collision_mask
	query.exclude = [get_rid()]
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var cast_result := get_world_2d().direct_space_state.cast_motion(query)
	if cast_result.size() <= 0:
		return travel_distance

	var safe_fraction := clampf(float(cast_result[0]), 0.0, 1.0)
	if safe_fraction >= 1.0:
		return travel_distance

	# Keep a tiny gap from the hit surface to avoid overlap jitter.
	var safe_distance := travel_distance * safe_fraction - 0.01
	return maxf(safe_distance, 0.0)

func _update_ground_jump_coyote_timer(delta: float) -> void:
	if is_on_floor():
		ground_jump_coyote_timer = coyote_time_seconds
		_ground_jump_curve_active = false
		return

	ground_jump_coyote_timer = maxf(ground_jump_coyote_timer - delta, 0.0)

func _update_dash_timers(delta: float) -> void:
	_dash_cooldown_timer = maxf(_dash_cooldown_timer - delta, 0.0)

func _update_attack_timers(delta: float) -> void:
	attack_chain_timer = maxf(attack_chain_timer - delta, 0.0)
	attack_input_buffer_timer = maxf(attack_input_buffer_timer - delta, 0.0)
	attack_combo_cooldown_timer = maxf(attack_combo_cooldown_timer - delta, 0.0)
	air_attack_cooldown_timer = maxf(air_attack_cooldown_timer - delta, 0.0)

	if attack_chain_timer <= 0.0 and not _is_attacking_state_active():
		current_attack_stage = 0
		queued_attack_stage = 0

func _update_wall_jump_timers(delta: float) -> void:
	var previous_buffer := wall_jump_input_buffer_timer
	var previous_lock := wall_jump_control_lock_timer
	var previous_reattach := wall_jump_reattach_cooldown_timer
	wall_jump_input_buffer_timer = maxf(wall_jump_input_buffer_timer - delta, 0.0)
	wall_jump_control_lock_timer = maxf(wall_jump_control_lock_timer - delta, 0.0)
	wall_jump_reattach_cooldown_timer = maxf(wall_jump_reattach_cooldown_timer - delta, 0.0)
	if previous_buffer > 0.0 and wall_jump_input_buffer_timer <= 0.0:
		debug_attack_log("wall_jump_buffer expired")
	if previous_lock > 0.0 and wall_jump_control_lock_timer <= 0.0:
		debug_attack_log("wall_jump_control_lock expired")
	if previous_reattach > 0.0 and wall_jump_reattach_cooldown_timer <= 0.0:
		debug_attack_log("wall_jump_reattach_cooldown expired")

func _update_wall_contact_state(delta: float) -> void:
	if not is_on_floor() and is_on_wall():
		wall_contact_grace_timer = wall_contact_grace_seconds
		var wall_normal := get_wall_normal()
		if not is_zero_approx(wall_normal.x):
			_last_wall_normal = wall_normal
		return

	wall_contact_grace_timer = maxf(wall_contact_grace_timer - delta, 0.0)
	if wall_contact_grace_timer <= 0.0 and not _is_walled_state_active() and wall_state_contact_timer <= 0.0:
		_last_wall_normal = Vector2.ZERO

func _update_state_contact_timers(delta: float) -> void:
	var state_contact_grace_seconds := _state_contact_grace_seconds()
	if state_contact_grace_seconds <= 0.0:
		floor_state_contact_timer = 0.0
		wall_state_contact_timer = 0.0
		return

	if is_on_floor() or (velocity.y >= 0.0 and has_floor_support()):
		floor_state_contact_timer = state_contact_grace_seconds
	else:
		floor_state_contact_timer = maxf(floor_state_contact_timer - delta, 0.0)

	var wall_contact_active: bool = should_remain_walled() if _is_walled_state_active() else can_enter_walled_state()
	if wall_contact_active:
		wall_state_contact_timer = state_contact_grace_seconds
	else:
		wall_state_contact_timer = maxf(wall_state_contact_timer - delta, 0.0)


func _update_damage_timers(delta: float) -> void:
	damage_invulnerability_timer = maxf(damage_invulnerability_timer - delta, 0.0)
	_update_dash_invulnerability_timer(delta)
	defend_cooldown_timer = maxf(defend_cooldown_timer - delta, 0.0)

func _update_grounded_attack_ledge_grace(delta: float) -> void:
	if grounded_attack_ledge_grace_seconds <= 0.0:
		grounded_attack_ledge_grace_timer = 0.0
		return

	if is_on_floor() or floor_state_contact_timer > 0.0:
		grounded_attack_ledge_grace_timer = grounded_attack_ledge_grace_seconds
		return

	grounded_attack_ledge_grace_timer = maxf(grounded_attack_ledge_grace_timer - delta, 0.0)

func _on_animation_tree_animation_started(animation_name: StringName) -> void:
	_started_animations.append(animation_name)
	if animation_name == AnimationConstants.PLAYER_JUMP_TRANSITION and velocity.y > 0.0 and jump_transition_downward_velocity_boost > 0.0:
		velocity.y += jump_transition_downward_velocity_boost
		debug_attack_log("jump_transition velocity boost applied: +%.2f" % jump_transition_downward_velocity_boost)
	# Treat wall-jump request as a one-shot trigger once the animation starts.
	if animation_name == AnimationConstants.PLAYER_WALL_JUMP:
		_wall_jump_animation_requested = false
	if animation_name == AnimationConstants.PLAYER_ATTACK_1 or animation_name == AnimationConstants.PLAYER_ATTACK_2 or animation_name == AnimationConstants.PLAYER_ATTACK_3 or animation_name == AnimationConstants.PLAYER_AIR_ATTACK:
		_play_audio_cue(&"player_swing")
	debug_attack_log("animation_started: %s" % String(animation_name))

func _on_animation_tree_animation_finished(animation_name: StringName) -> void:
	_finished_animations.append(animation_name)
	_apply_queued_sword_damage(animation_name)
	if animation_name == AnimationConstants.PLAYER_DASH:
		_dash_cooldown_timer = dash_cooldown_seconds
		debug_attack_log("dash_cooldown_started %.3f" % _dash_cooldown_timer)
	debug_attack_log("animation_finished: %s" % String(animation_name))

func _consume_animation_event(events: Array[StringName], animation_name: StringName) -> bool:
	var index := events.find(animation_name)
	if index == -1:
		return false
	events.remove_at(index)
	if animation_name == AnimationConstants.PLAYER_WALL_CONTACT or animation_name == AnimationConstants.PLAYER_WALL_JUMP or animation_name == AnimationConstants.PLAYER_WALL_SLIDE:
		debug_attack_log("consume_animation_event: %s" % String(animation_name))
	return true

func _apply_queued_sword_damage(animation_name: StringName) -> void:
	if not _is_sword_damage_animation(animation_name):
		return
	if sword_area == null:
		return
	if sword_area.has_method("apply_queued_strikes_for_animation"):
		sword_area.call("apply_queued_strikes_for_animation", animation_name)

func _clear_queued_sword_damage() -> void:
	if sword_area == null:
		return
	if sword_area.has_method("clear_all_queued_strikes"):
		sword_area.call("clear_all_queued_strikes")

func _is_sword_damage_animation(animation_name: StringName) -> bool:
	return animation_name == AnimationConstants.PLAYER_ATTACK_1 or animation_name == AnimationConstants.PLAYER_ATTACK_2 or animation_name == AnimationConstants.PLAYER_ATTACK_3 or animation_name == AnimationConstants.PLAYER_AIR_ATTACK

func take_damage(amount: float, source: Variant = null) -> void:
	if amount <= 0.0:
		return
	if _should_ignore_damage_during_dash(source):
		debug_attack_log("take_damage ignored by dash_i_frames source_type=%s" % type_string(typeof(source)))
		return
	if _try_consume_defend_hit(source):
		return
	if damage_invulnerability_timer > 0.0:
		return
	if death_state != null and state_machine != null and state_machine.current_state == death_state:
		return

	current_health = maxf(0.0, current_health - amount)
	damage_invulnerability_timer = damage_invulnerability_seconds
	if current_health > 0.0:
		_play_audio_cue(&"player_hurt")
	_apply_damage_knockback(source)
	if current_health <= 0.0:
		_trigger_death_state()

func _apply_damage_knockback(source: Variant) -> void:
	_apply_damage_knockback_scaled(source, 1.0)

func _apply_damage_knockback_scaled(source: Variant, knockback_scale: float) -> void:
	var clamped_knockback_scale: float = maxf(knockback_scale, 0.0)
	var knockback_direction: float = _resolve_damage_knockback_direction(source)
	if not is_zero_approx(knockback_direction):
		velocity.x = knockback_direction * damage_knockback_speed * clamped_knockback_scale
	if damage_knockback_lift > 0.0:
		velocity.y = -damage_knockback_lift * clamped_knockback_scale

func _resolve_damage_knockback_direction(source: Variant) -> float:
	if source is Dictionary:
		var source_dictionary: Dictionary = source as Dictionary
		if source_dictionary.has("strike_direction"):
			var strike_direction_value: Variant = source_dictionary["strike_direction"]
			if strike_direction_value is Vector2:
				var strike_direction: Vector2 = strike_direction_value as Vector2
				if absf(strike_direction.x) > 0.01:
					return signf(strike_direction.x)
		if source_dictionary.has("attacker"):
			var attacker_value: Variant = source_dictionary["attacker"]
			var attacker_node: Node2D = _resolve_damage_source_node(attacker_value)
			if attacker_node != null:
				var attacker_delta: float = global_position.x - attacker_node.global_position.x
				if absf(attacker_delta) > 0.01:
					return signf(attacker_delta)
	var source_node: Node2D = _resolve_damage_source_node(source)
	if source_node != null:
		var horizontal_delta: float = global_position.x - source_node.global_position.x
		if absf(horizontal_delta) > 0.01:
			return signf(horizontal_delta)
	if sprite != null:
		return 1.0 if sprite.flip_h else -1.0
	return -1.0

func _resolve_damage_source_node(source: Variant) -> Node2D:
	if source is Node2D:
		return source as Node2D
	if source is Node:
		var source_node: Node = source as Node
		var parent_node: Node = source_node.get_parent()
		if parent_node is Node2D:
			return parent_node as Node2D
	return null

func _trigger_fall_death_if_needed() -> void:
	if death_state == null:
		return
	if state_machine.current_state == death_state:
		return
	if global_position.y <= fall_death_y:
		return

	_trigger_death_state()

func _trigger_death_state() -> void:
	_clear_queued_sword_damage()
	clear_defend_state()
	dash_invulnerability_timer = 0.0
	if death_state == null or state_machine == null:
		return
	if state_machine.current_state == death_state:
		return
	current_health = 0.0
	damage_invulnerability_timer = 0.0
	_play_audio_cue(&"player_death")
	state_machine.switch_states(death_state)

func _get_fall_acceleration_scale() -> float:
	if _is_walled_state_active():
		return 1.0

	var fall_scale := 1.0
	if velocity.y > 0.0:
		var ramp_denominator := maxf(fall_acceleration_ramp_speed, 1.0)
		var ramp_ratio := clampf(velocity.y / ramp_denominator, 0.0, 1.0)
		fall_scale = lerpf(1.0, fall_acceleration_multiplier, ramp_ratio)

	if _ground_jump_curve_active:
		if velocity.y < 0.0:
			fall_scale *= ground_jump_ascent_gravity_scale
		elif velocity.y > 0.0:
			fall_scale *= ground_jump_descent_gravity_scale

	if velocity.y > 0.0 and state_machine != null and state_machine.has_method("get_current_animation_state"):
		if state_machine.get_current_animation_state() == String(AnimationConstants.PLAYER_JUMP_TRANSITION):
			fall_scale *= jump_transition_fall_gravity_boost_scale

	return fall_scale

func _is_walled_state_active() -> bool:
	return state_machine != null and walled_state != null and state_machine.current_state == walled_state

func _is_attacking_state_active() -> bool:
	return state_machine != null and attacking_state != null and state_machine.current_state == attacking_state

func has_wall_attach_floor_clearance() -> bool:
	if wall_min_floor_clearance <= 0.0:
		return true

	var from := _floor_probe_origin()
	var to := from + Vector2.DOWN * wall_min_floor_clearance
	var query := PhysicsRayQueryParameters2D.create(from, to, collision_mask, [get_rid()])
	var result := get_world_2d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return true

	var hit_normal: Vector2 = result.get("normal", Vector2.ZERO)
	if hit_normal.dot(Vector2.UP) < 0.5:
		return true

	var hit_position: Vector2 = result.get("position", to)
	return from.distance_to(hit_position) >= wall_min_floor_clearance - 0.01

func has_floor_support(max_distance: float = 0.0) -> bool:
	var probe_distance := max_distance
	if probe_distance <= 0.0:
		probe_distance = grounded_attack_floor_probe_distance
	if probe_distance <= 0.0:
		return false

	var from := _floor_probe_origin()
	var to := from + Vector2.DOWN * probe_distance
	var query := PhysicsRayQueryParameters2D.create(from, to, collision_mask, [get_rid()])
	var result := get_world_2d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return false

	var hit_normal: Vector2 = result.get("normal", Vector2.ZERO)
	return hit_normal.dot(Vector2.UP) >= 0.5

func _floor_probe_origin() -> Vector2:
	if collision_shape != null and collision_shape.shape is RectangleShape2D:
		var shape := collision_shape.shape as RectangleShape2D
		return collision_shape.global_position + Vector2(0.0, shape.size.y * 0.5)
	return global_position

func _resolve_wall_normal() -> Vector2:
	if is_on_wall():
		var wall_normal := get_wall_normal()
		if not is_zero_approx(wall_normal.x):
			return wall_normal

	if not is_zero_approx(_last_wall_normal.x):
		return _last_wall_normal

	if absf(direction.x) > 0.01:
		return Vector2(-signf(direction.x), 0.0)

	if sprite != null:
		return Vector2(1.0, 0.0) if sprite.flip_h else Vector2(-1.0, 0.0)

	return Vector2.ZERO

func _get_contact_wall_normal() -> Vector2:
	if is_on_wall():
		var wall_normal: Vector2 = get_wall_normal()
		if not is_zero_approx(wall_normal.x):
			return wall_normal
	if not is_zero_approx(_last_wall_normal.x):
		return _last_wall_normal
	return Vector2.ZERO

func _has_wall_contact_in_direction(direction_sign: float, max_distance: float) -> bool:
	if absf(direction_sign) <= 0.01 or max_distance <= 0.0:
		return false
	var max_probe_offset: int = maxi(int(round(max_distance)), 1)
	for probe_offset in range(1, max_probe_offset + 1):
		var probe_motion: Vector2 = Vector2(direction_sign * float(probe_offset), 0.0)
		if test_move(global_transform, probe_motion):
			return true
	return false

func _apply_wall_state_collision_profile() -> void:
	var wall_normal: Vector2 = _get_contact_wall_normal()
	if is_zero_approx(wall_normal.x):
		return
	var wall_side_sign: float = -signf(wall_normal.x)
	_apply_rectangle_collision_profile(collision_shape, wall_state_hit_box_offset, wall_state_hit_box_size, wall_side_sign)
	_apply_rectangle_collision_profile(hurt_box_shape, wall_state_hurt_box_offset, wall_state_hurt_box_size, wall_side_sign)

func _apply_rectangle_collision_profile(target_shape: CollisionShape2D, local_offset: Vector2, size: Vector2, mirror_sign: float) -> void:
	if target_shape == null:
		return
	target_shape.position = Vector2(absf(local_offset.x) * mirror_sign, local_offset.y)
	if target_shape.shape is RectangleShape2D:
		var rectangle_shape: RectangleShape2D = target_shape.shape as RectangleShape2D
		rectangle_shape.size = size

func _state_contact_grace_seconds() -> float:
	if state_contact_grace_frames <= 0.0:
		return 0.0

	var physics_ticks: float = _get_physics_ticks_per_second()
	if physics_ticks <= 0.0:
		physics_ticks = 60.0
	return state_contact_grace_frames / physics_ticks

func _start_dash_invulnerability() -> void:
	var dash_iframe_seconds: float = _dash_invulnerability_seconds()
	if dash_iframe_seconds <= 0.0:
		dash_invulnerability_timer = 0.0
		return
	dash_invulnerability_timer = dash_iframe_seconds
	debug_attack_log("dash_i_frames_started %.3f" % dash_invulnerability_timer)

func _update_dash_invulnerability_timer(delta: float) -> void:
	var previous_timer: float = dash_invulnerability_timer
	dash_invulnerability_timer = maxf(dash_invulnerability_timer - delta, 0.0)
	if previous_timer > 0.0 and dash_invulnerability_timer <= 0.0:
		debug_attack_log("dash_i_frames_expired")

func _should_ignore_damage_during_dash(source: Variant) -> bool:
	if not is_dash_invulnerable():
		return false
	return _is_dash_invulnerability_source(source)

func _is_dash_invulnerability_source(source: Variant) -> bool:
	if source is Dictionary:
		var source_dictionary: Dictionary = source as Dictionary
		if source_dictionary.has("attacker"):
			var attacker_value: Variant = source_dictionary["attacker"]
			if attacker_value is Node:
				var attacker_node: Node = attacker_value as Node
				if attacker_node.is_in_group(&"enemy"):
					return true
		if source_dictionary.has("source_node"):
			var source_node_value: Variant = source_dictionary["source_node"]
			if source_node_value is Node:
				var source_node: Node = source_node_value as Node
				if source_node.is_in_group(&"enemy"):
					return true
				var source_parent: Node = source_node.get_parent()
				if source_parent != null and source_parent.is_in_group(&"enemy"):
					return true
		return true
	if source is Node:
		var source_node_direct: Node = source as Node
		if source_node_direct.is_in_group(&"player"):
			return false
		var source_parent_direct: Node = source_node_direct.get_parent()
		if source_parent_direct != null and source_parent_direct.is_in_group(&"player"):
			return false
		return true
	return true

func _dash_invulnerability_seconds() -> float:
	if dash_invulnerability_frames <= 0:
		return 0.0
	var physics_ticks: float = _get_physics_ticks_per_second()
	if physics_ticks <= 0.0:
		physics_ticks = 60.0
	return float(dash_invulnerability_frames) / physics_ticks

func _get_physics_ticks_per_second() -> float:
	var physics_ticks_value: Variant = ProjectSettings.get_setting("physics/common/physics_ticks_per_second")
	if typeof(physics_ticks_value) == TYPE_FLOAT or typeof(physics_ticks_value) == TYPE_INT:
		return float(physics_ticks_value)
	return 60.0

func try_snap_to_grounded_ledge_from_jump() -> bool:
	if collision_shape == null:
		return false
	if is_on_floor():
		return false
	if velocity.y < 0.0:
		return false
	if jump_ledge_snap_height <= 0.0 or jump_ledge_snap_forward_distance <= 0.0 or jump_ledge_snap_floor_probe_distance <= 0.0:
		return false

	var horizontal_motion: float = velocity.x
	if absf(horizontal_motion) <= 0.01 and absf(direction.x) > 0.01:
		horizontal_motion = direction.x * speed
	if absf(horizontal_motion) <= 0.01:
		var wall_normal: Vector2 = _resolve_wall_normal()
		if absf(wall_normal.x) > 0.01:
			horizontal_motion = -wall_normal.x
	if absf(horizontal_motion) <= 0.01:
		return false

	var snapped: bool = CharacterStepUtility.try_snap_up_to_ledge(
		self,
		collision_shape,
		horizontal_motion,
		jump_ledge_snap_height,
		jump_ledge_snap_forward_distance,
		jump_ledge_snap_floor_probe_distance,
		collision_mask
	)
	if not snapped:
		return false

	velocity.y = 0.0
	ground_jump_coyote_timer = coyote_time_seconds
	floor_state_contact_timer = _state_contact_grace_seconds()
	wall_contact_grace_timer = 0.0
	wall_state_contact_timer = 0.0
	_last_wall_normal = Vector2.ZERO
	debug_attack_log("try_snap_to_grounded_ledge_from_jump -> true")
	return true

func _try_step_up() -> void:
	if _dash_active:
		return
	CharacterStepUtility.try_step_up(self, velocity.x, step_height, step_probe_distance)

func _update_horizontal_velocity(delta: float) -> void:
	if not state_machine.check_if_can_move():
		_apply_horizontal_friction(delta)
		return

	var input_x := direction.x
	if absf(input_x) <= 0.01:
		_apply_horizontal_friction(delta)
		return

	var target_speed := input_x * speed
	var acceleration := _get_horizontal_acceleration(input_x)
	velocity.x = move_toward(velocity.x, target_speed, acceleration * delta)

func _apply_horizontal_friction(delta: float) -> void:
	var friction := ground_friction if is_on_floor() else air_friction
	velocity.x = move_toward(velocity.x, 0.0, friction * delta)

func _get_horizontal_acceleration(input_x: float) -> float:
	var turning := absf(velocity.x) > 0.01 and signf(input_x) != signf(velocity.x)
	if is_on_floor():
		return ground_turn_acceleration if turning else ground_acceleration
	return air_turn_acceleration if turning else air_acceleration

func try_snap_to_nearby_wall_from_fall() -> bool:
	if wall_attach_snap_distance <= 0.0:
		return false
	if _dash_active:
		return false
	if wall_jump_control_lock_timer > 0.0:
		return false
	if wall_jump_reattach_cooldown_timer > 0.0:
		return false
	if is_on_floor() or is_on_wall():
		return false

	var preferred_direction: float = signf(direction.x)
	if is_zero_approx(preferred_direction):
		preferred_direction = signf(velocity.x)

	var probe_directions: Array[float] = []
	if not is_zero_approx(preferred_direction):
		probe_directions.append(preferred_direction)
	probe_directions.append(-1.0)
	probe_directions.append(1.0)

	var max_snap_offset: int = int(round(wall_attach_snap_distance))
	var checked_left := false
	var checked_right := false
	for probe_direction in probe_directions:
		if is_zero_approx(probe_direction):
			continue
		var direction_sign: float = signf(probe_direction)
		if direction_sign < 0.0:
			if checked_left:
				continue
			checked_left = true
		elif direction_sign > 0.0:
			if checked_right:
				continue
			checked_right = true
		else:
			continue

		for snap_offset in range(1, max_snap_offset + 1):
			var snap_motion: Vector2 = Vector2(direction_sign * float(snap_offset), 0.0)
			if not test_move(global_transform, snap_motion):
				continue

			if not _snap_to_wall_contact(direction_sign, float(snap_offset)):
				continue
			_last_wall_normal = Vector2(-direction_sign, 0.0)
			velocity.x = 0.0
			wall_contact_grace_timer = maxf(wall_contact_grace_timer, wall_contact_grace_seconds)
			wall_state_contact_timer = maxf(wall_state_contact_timer, _state_contact_grace_seconds())
			debug_attack_log("try_snap_to_nearby_wall_from_fall snapped dir=%.0f offset=%d" % [direction_sign, snap_offset])
			return true

	return false

func try_snap_to_last_wall_contact() -> bool:
	if wall_attach_snap_distance <= 0.0:
		return false
	if _dash_active:
		return false
	if wall_jump_control_lock_timer > 0.0:
		return false
	if wall_jump_reattach_cooldown_timer > 0.0:
		return false
	if is_on_floor() or is_on_wall():
		return false
	if is_zero_approx(_last_wall_normal.x):
		return false

	var direction_sign: float = -signf(_last_wall_normal.x)
	var max_snap_offset: int = int(round(wall_attach_snap_distance))
	for snap_offset in range(1, max_snap_offset + 1):
		var snap_motion: Vector2 = Vector2(direction_sign * float(snap_offset), 0.0)
		if not test_move(global_transform, snap_motion):
			continue

		if not _snap_to_wall_contact(direction_sign, float(snap_offset)):
			continue
		velocity.x = 0.0
		wall_contact_grace_timer = maxf(wall_contact_grace_timer, wall_contact_grace_seconds)
		wall_state_contact_timer = maxf(wall_state_contact_timer, _state_contact_grace_seconds())
		debug_attack_log("try_snap_to_last_wall_contact snapped dir=%.0f offset=%d" % [direction_sign, snap_offset])
		return true

	return false

func _try_snap_to_nearby_wall() -> void:
	if wall_attach_snap_distance <= 0.0:
		return
	if _dash_active:
		return
	if wall_jump_control_lock_timer > 0.0:
		return
	if wall_jump_reattach_cooldown_timer > 0.0:
		return
	if is_on_floor() or is_on_wall():
		return

	var attach_direction: float = signf(direction.x)
	if is_zero_approx(attach_direction):
		attach_direction = signf(velocity.x)
	if is_zero_approx(attach_direction):
		return

	var max_snap_offset: int = int(round(wall_attach_snap_distance))
	for snap_offset in range(1, max_snap_offset + 1):
		var snap_motion: Vector2 = Vector2(attach_direction * float(snap_offset), 0.0)
		if not test_move(global_transform, snap_motion):
			continue

		_snap_to_wall_contact(attach_direction, float(snap_offset))
		return

func _snap_to_wall_contact(direction_sign: float, max_distance: float) -> bool:
	var snap_distance: float = _resolve_wall_contact_snap_distance(direction_sign, max_distance)
	if snap_distance < 0.0:
		return false
	if snap_distance > 0.0:
		global_position.x += direction_sign * snap_distance
	return true

func _resolve_wall_contact_snap_distance(direction_sign: float, max_distance: float) -> float:
	if collision_shape == null or collision_shape.shape == null:
		return _resolve_wall_contact_snap_distance_fallback(direction_sign, max_distance)
	if absf(direction_sign) <= 0.01 or max_distance <= 0.0:
		return -1.0

	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = collision_shape.shape
	query.transform = collision_shape.global_transform
	query.motion = Vector2(direction_sign * max_distance, 0.0)
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var cast_result: Array = get_world_2d().direct_space_state.cast_motion(query)
	if cast_result.size() <= 0:
		return _resolve_wall_contact_snap_distance_fallback(direction_sign, max_distance)

	var safe_fraction: float = clampf(float(cast_result[0]), 0.0, 1.0)
	if safe_fraction >= 1.0:
		return -1.0

	var snap_distance: float = max_distance * safe_fraction - 0.01
	return maxf(snap_distance, 0.0)

func _resolve_wall_contact_snap_distance_fallback(direction_sign: float, max_distance: float) -> float:
	if absf(direction_sign) <= 0.01 or max_distance <= 0.0:
		return -1.0

	var max_snap_offset: int = int(round(max_distance))
	for snap_offset in range(1, max_snap_offset + 1):
		var snap_motion: Vector2 = Vector2(direction_sign * float(snap_offset), 0.0)
		if test_move(global_transform, snap_motion):
			return maxf(float(snap_offset) - 0.01, 0.0)
	return -1.0

func update_animation_parameters():
	var blend_position := 0.0
	if is_on_floor():
		var max_speed := maxf(speed, 0.001)
		blend_position = clampf(velocity.x / max_speed, -1.0, 1.0)
	else:
		blend_position = clampf(direction.x, -1.0, 1.0)

	if absf(blend_position) < 0.02:
		blend_position = 0.0

	animation_tree.set("parameters/Move/blend_position", blend_position)

func update_facing_direction():
	if _is_walled_state_active():
		var wall_normal := _resolve_wall_normal()
		if not is_zero_approx(wall_normal.x):
			sprite.flip_h = wall_normal.x < 0.0
			return

	if direction.x > 0:
		sprite.flip_h = false
	elif direction.x < 0:
		sprite.flip_h = true

func _update_wall_sprite_contact_offset() -> void:
	if sprite == null:
		return

	var target_position: Vector2 = _sprite_base_position
	if _is_walled_state_active():
		var wall_normal: Vector2 = _resolve_wall_normal()
		if not is_zero_approx(wall_normal.x):
			var wall_side_sign: float = -signf(wall_normal.x)
			var contact_offset: float = absf(wall_sprite_contact_offset_x)
			if wall_side_sign < 0.0:
				contact_offset += maxf(wall_sprite_contact_left_extra_x, 0.0)
			target_position.x = _sprite_base_position.x + wall_side_sign * contact_offset

	sprite.position = target_position

func debug_attack_log(message: String) -> void:
	if not debug_attack_logs:
		return

	var state_name := "None"
	if state_machine != null and state_machine.current_state != null:
		state_name = state_machine.current_state.name

	var animation_name := "None"
	if state_machine != null and state_machine.has_method("get_current_animation_state"):
		animation_name = state_machine.get_current_animation_state()

	var input_x := Input.get_axis("move_left", "move_right")
	var wall_normal := _resolve_wall_normal()
	var attach_contact := has_wall_attach_contact()
	var can_attach := can_attach_to_wall()
	var stable_wall := has_stable_wall_contact()

	print("[AttackDebug] state=%s anim=%s floor=%s wall=%s vel=(%.2f, %.2f) input_x=%.2f wall_nx=%.2f last_nx=%.2f stage=%d queued=%d attack_req=%s air_attack=%s wall_req=%s dash=%s ddir=%.0f drem=%.2f dcd=%.3f djq=%s daq=%s wbuf=%.3f wlock=%.3f wcd=%.3f wgate=%.3f wgrace=%.3f wstate=%.3f fstate=%.3f attach=%s can_attach=%s stable_wall=%s :: %s" % [
		state_name,
		animation_name,
		str(is_on_floor()),
		str(is_on_wall()),
		velocity.x,
		velocity.y,
		input_x,
		wall_normal.x,
		_last_wall_normal.x,
		current_attack_stage,
		queued_attack_stage,
		str(_attack_animation_requested),
		str(_air_attack_active),
		str(_wall_jump_animation_requested),
		str(_dash_active),
		_dash_direction,
		_dash_remaining_distance,
		_dash_cooldown_timer,
		str(_dash_jump_queued),
		str(_dash_attack_queued),
		wall_jump_input_buffer_timer,
		wall_jump_control_lock_timer,
		wall_jump_reattach_cooldown_timer,
		wall_jump_queue_release_seconds,
		wall_contact_grace_timer,
		wall_state_contact_timer,
		floor_state_contact_timer,
		str(attach_contact),
		str(can_attach),
		str(stable_wall),
		message,
	])
