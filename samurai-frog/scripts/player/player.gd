extends CharacterBody2D

@export var speed : float = 200.0
@export var jump_velocity : float = -450.0
@export_range(0.0, 0.3, 0.01) var coyote_time_seconds : float = 0.12
@export_range(0.0, 16.0, 1.0) var step_height : float = 8.0
@export_range(0.0, 8.0, 0.5) var step_probe_distance : float = 2.0
@export_range(0.0, 10.0, 1.0) var state_contact_grace_frames : float = 4.0
@export_range(0.0, 64.0, 1.0) var wall_min_floor_clearance : float = 25.0
@export_range(0.0, 128.0, 1.0) var wall_min_height : float = 36.0
@export_range(0.0, 16.0, 1.0) var wall_attach_snap_distance : float = 8.0
@export_range(0.0, 0.2, 0.01) var wall_contact_grace_seconds : float = 0.10
@export_range(0.0, 1.0, 0.05) var wall_slide_gravity_scale : float = 0.4
@export_range(0.0, 0.3, 0.01) var wall_jump_input_buffer_seconds : float = 0.20
@export_range(0.0, 0.3, 0.01) var wall_jump_control_lock_seconds : float = 0.12
@export_range(0.0, 16.0, 1.0) var grounded_attack_floor_probe_distance : float = 6.0
@export_range(0.0, 1.0, 0.01) var attack_chain_window_seconds : float = 0.5
@export_range(0.0, 0.5, 0.01) var attack_input_buffer_seconds : float = 0.5
@export_range(0.0, 3.0, 0.01) var attack_combo_cooldown_seconds : float = 1.0
@export_range(0.0, 3.0, 0.01) var air_attack_cooldown_seconds : float = 1.0
@export var debug_attack_logs : bool = true
@export var wall_jump_velocity : float = -350.0
@export var wall_jump_horizontal_speed : float = 220.0
@export var wall_jump_boost_horizontal_speed : float = 280.0
@export_range(0.0, 1024.0, 1.0) var fall_death_y : float = 420.0

@onready var collision_shape : CollisionShape2D = $CollisionShape2D
@onready var sprite : Sprite2D = $Sprite2D
@onready var animation_tree : AnimationTree = $AnimationTree
@onready var state_machine : PlayerStateMachine = $PlayerStateMachine
@onready var attacking_state : State = $PlayerStateMachine/Attacking
@onready var walled_state : State = $PlayerStateMachine/Walled
@onready var death_state : State = $PlayerStateMachine/Dead

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var direction : Vector2 = Vector2.ZERO
var ground_jump_coyote_timer : float = 0.0
var wall_jump_input_buffer_timer : float = 0.0
var wall_jump_control_lock_timer : float = 0.0
var wall_contact_grace_timer : float = 0.0
var floor_state_contact_timer : float = 0.0
var wall_state_contact_timer : float = 0.0
var attack_chain_timer : float = 0.0
var attack_input_buffer_timer : float = 0.0
var attack_combo_cooldown_timer : float = 0.0
var air_attack_cooldown_timer : float = 0.0
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

func _ready():
	animation_tree.active = true
	if not animation_tree.animation_started.is_connected(_on_animation_tree_animation_started):
		animation_tree.animation_started.connect(_on_animation_tree_animation_started)
	if not animation_tree.animation_finished.is_connected(_on_animation_tree_animation_finished):
		animation_tree.animation_finished.connect(_on_animation_tree_animation_finished)

func _physics_process(delta):
	_update_wall_jump_timers(delta)
	_update_attack_timers(delta)

	# Add the gravity.
	if not is_on_floor():
		var gravity_scale: float = wall_slide_gravity_scale if _is_walled_state_active() and velocity.y >= 0.0 else 1.0
		velocity.y += gravity * gravity_scale * delta

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	direction = Input.get_vector("move_left", "move_right", "jump", "move_down")
	
	# Control whether to move or not to move
	if wall_jump_control_lock_timer > 0.0:
		pass
	elif direction.x != 0 && state_machine.check_if_can_move():
		velocity.x = direction.x * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)

	_try_snap_to_nearby_wall()
	_try_step_up()
	move_and_slide()
	_update_wall_contact_state(delta)
	_update_state_contact_timers(delta)
	_update_ground_jump_coyote_timer(delta)
	_trigger_fall_death_if_needed()
	update_animation_parameters()
	update_facing_direction()

func request_ground_jump(jump_speed: float) -> bool:
	if not is_on_floor() and ground_jump_coyote_timer <= 0.0:
		return false

	velocity.y = jump_speed
	ground_jump_coyote_timer = 0.0
	floor_state_contact_timer = 0.0
	_air_attack_return_jump_requested = false
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
			return &"attack_1"
		2:
			return &"attack_2"
		3:
			return &"attack_3"
		_:
			return StringName()

func get_queued_attack_animation() -> StringName:
	match queued_attack_stage:
		1:
			return &"attack_1"
		2:
			return &"attack_2"
		3:
			return &"attack_3"
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

func consume_started_animation(animation_name: StringName) -> bool:
	return _consume_animation_event(_started_animations, animation_name)

func consume_finished_animation(animation_name: StringName) -> bool:
	return _consume_animation_event(_finished_animations, animation_name)

func buffer_wall_jump_input() -> void:
	wall_jump_input_buffer_timer = wall_jump_input_buffer_seconds

func try_buffered_wall_jump() -> bool:
	if wall_jump_input_buffer_timer <= 0.0:
		return false
	return request_wall_jump()

func request_wall_jump() -> bool:
	if is_on_floor():
		return false
	if not has_wall_attach_contact() and not has_wall_contact_grace():
		return false
	if not has_wall_attach_floor_clearance():
		return false

	var wall_normal := _resolve_wall_normal()
	if is_zero_approx(wall_normal.x):
		return false

	var launch_direction := signf(wall_normal.x)
	var input_direction := signf(Input.get_axis("move_left", "move_right"))
	var horizontal_speed := wall_jump_horizontal_speed
	if is_zero_approx(input_direction):
		input_direction = launch_direction
	elif signf(input_direction) != launch_direction:
		return false
	else:
		horizontal_speed = wall_jump_boost_horizontal_speed

	velocity.x = input_direction * horizontal_speed
	velocity.y = wall_jump_velocity
	ground_jump_coyote_timer = 0.0
	wall_jump_input_buffer_timer = 0.0
	wall_jump_control_lock_timer = wall_jump_control_lock_seconds
	floor_state_contact_timer = 0.0
	wall_state_contact_timer = 0.0
	_wall_jump_animation_requested = true

	if sprite != null:
		sprite.flip_h = input_direction < 0.0
	return true

func is_wall_jump_animation_requested() -> bool:
	return _wall_jump_animation_requested

func clear_wall_jump_animation_request() -> void:
	_wall_jump_animation_requested = false

func is_wall_jump_control_locked() -> bool:
	return wall_jump_control_lock_timer > 0.0

func has_wall_contact_grace() -> bool:
	return wall_contact_grace_timer > 0.0

func has_stable_floor_contact() -> bool:
	return is_on_floor() or floor_state_contact_timer > 0.0

func has_stable_wall_contact() -> bool:
	return can_attach_to_wall() or wall_state_contact_timer > 0.0

func has_wall_attach_contact() -> bool:
	if is_on_floor():
		return false
	if is_on_wall():
		return true
	if is_zero_approx(_last_wall_normal.x):
		return false

	var max_probe_offset := maxi(int(round(wall_attach_snap_distance)), 1)
	var wall_probe_direction := -signf(_last_wall_normal.x)
	for probe_offset in range(1, max_probe_offset + 1):
		var probe_motion := Vector2(wall_probe_direction * float(probe_offset), 0.0)
		if test_move(global_transform, probe_motion):
			return true

	return false

func can_attach_to_wall() -> bool:
	if is_on_floor():
		return false
	if not has_wall_attach_contact():
		return false
	if not has_wall_attach_height():
		return false
	return has_wall_attach_floor_clearance()

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

func _update_ground_jump_coyote_timer(delta: float) -> void:
	if is_on_floor():
		ground_jump_coyote_timer = coyote_time_seconds
		return

	ground_jump_coyote_timer = maxf(ground_jump_coyote_timer - delta, 0.0)

func _update_attack_timers(delta: float) -> void:
	attack_chain_timer = maxf(attack_chain_timer - delta, 0.0)
	attack_input_buffer_timer = maxf(attack_input_buffer_timer - delta, 0.0)
	attack_combo_cooldown_timer = maxf(attack_combo_cooldown_timer - delta, 0.0)
	air_attack_cooldown_timer = maxf(air_attack_cooldown_timer - delta, 0.0)

	if attack_chain_timer <= 0.0 and not _is_attacking_state_active():
		current_attack_stage = 0
		queued_attack_stage = 0

func _update_wall_jump_timers(delta: float) -> void:
	wall_jump_input_buffer_timer = maxf(wall_jump_input_buffer_timer - delta, 0.0)
	wall_jump_control_lock_timer = maxf(wall_jump_control_lock_timer - delta, 0.0)

func _update_wall_contact_state(delta: float) -> void:
	if not is_on_floor() and is_on_wall():
		wall_contact_grace_timer = wall_contact_grace_seconds
		var wall_normal := get_wall_normal()
		if not is_zero_approx(wall_normal.x):
			_last_wall_normal = wall_normal
		return

	wall_contact_grace_timer = maxf(wall_contact_grace_timer - delta, 0.0)
	if wall_contact_grace_timer <= 0.0:
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

	if can_attach_to_wall():
		wall_state_contact_timer = state_contact_grace_seconds
	else:
		wall_state_contact_timer = maxf(wall_state_contact_timer - delta, 0.0)

func _on_animation_tree_animation_started(animation_name: StringName) -> void:
	_started_animations.append(animation_name)
	debug_attack_log("animation_started: %s" % String(animation_name))

func _on_animation_tree_animation_finished(animation_name: StringName) -> void:
	_finished_animations.append(animation_name)
	debug_attack_log("animation_finished: %s" % String(animation_name))

func _consume_animation_event(events: Array[StringName], animation_name: StringName) -> bool:
	var index := events.find(animation_name)
	if index == -1:
		return false
	events.remove_at(index)
	return true

func _trigger_fall_death_if_needed() -> void:
	if death_state == null:
		return
	if state_machine.current_state == death_state:
		return
	if global_position.y <= fall_death_y:
		return

	state_machine.switch_states(death_state)

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

func _state_contact_grace_seconds() -> float:
	if state_contact_grace_frames <= 0.0:
		return 0.0

	var physics_ticks := float(ProjectSettings.get_setting("physics/common/physics_ticks_per_second"))
	if physics_ticks <= 0.0:
		physics_ticks = 60.0
	return state_contact_grace_frames / physics_ticks

func _try_step_up() -> void:
	if step_height <= 0.0:
		return
	if not is_on_floor():
		return
	if velocity.y < 0.0:
		return
	if absf(velocity.x) < 0.01:
		return

	var move_direction: float = signf(velocity.x)
	if is_zero_approx(move_direction):
		return

	var forward_motion := Vector2(move_direction * step_probe_distance, 0.0)
	if not test_move(global_transform, forward_motion):
		return

	var max_step_offset: int = int(round(step_height))
	for step_offset in range(1, max_step_offset + 1):
		var raise_motion := Vector2(0.0, -float(step_offset))
		if test_move(global_transform, raise_motion):
			continue

		var raised_transform := global_transform.translated(raise_motion)
		if test_move(raised_transform, forward_motion):
			continue

		global_position.y -= float(step_offset)
		return

func _try_snap_to_nearby_wall() -> void:
	if wall_attach_snap_distance <= 0.0:
		return
	if wall_jump_control_lock_timer > 0.0:
		return
	if is_on_floor() or is_on_wall():
		return

	var attach_direction := signf(direction.x)
	if is_zero_approx(attach_direction):
		attach_direction = signf(velocity.x)
	if is_zero_approx(attach_direction):
		return

	var max_snap_offset: int = int(round(wall_attach_snap_distance))
	for snap_offset in range(1, max_snap_offset + 1):
		var snap_motion := Vector2(attach_direction * float(snap_offset), 0.0)
		if not test_move(global_transform, snap_motion):
			continue

		global_position.x += snap_motion.x
		return
	
func update_animation_parameters():
	animation_tree.set("parameters/Move/blend_position", direction.x)

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

func debug_attack_log(message: String) -> void:
	if not debug_attack_logs:
		return

	var state_name := "None"
	if state_machine != null and state_machine.current_state != null:
		state_name = state_machine.current_state.name

	var animation_name := "None"
	if state_machine != null and state_machine.has_method("get_current_animation_state"):
		animation_name = state_machine.get_current_animation_state()

	print("[AttackDebug] state=%s anim=%s floor=%s vel=(%.2f, %.2f) stage=%d queued=%d attack_req=%s air_attack=%s :: %s" % [
		state_name,
		animation_name,
		str(is_on_floor()),
		velocity.x,
		velocity.y,
		current_attack_stage,
		queued_attack_stage,
		str(_attack_animation_requested),
		str(_air_attack_active),
		message,
	])
