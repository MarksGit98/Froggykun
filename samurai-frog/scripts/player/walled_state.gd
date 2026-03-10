extends State

class_name WalledState

const AnimationConstants = preload("res://scripts/constants/animation_constants.gd")

@export var grounded_state : State
@export var jumping_state : State
@export var falling_state : State
@export var dashing_state : State

var _wall_detach_timer : float = 0.0
var _wall_contact_finished : bool = false
var _wall_contact_elapsed : float = 0.0

func on_enter():
	_set_animation_condition("jump_initiated", false)
	_set_animation_condition("landed", false)
	character.velocity.x = 0.0
	character.velocity.y = 0.0
	_wall_detach_timer = 0.0
	_wall_contact_finished = false
	_wall_contact_elapsed = 0.0
	if character.has_method("debug_attack_log"):
		character.call("debug_attack_log", "Walled.on_enter reset wall_contact gate")
	if character.has_method("clear_wall_jump_animation_request"):
		character.call("clear_wall_jump_animation_request")
	if character.has_method("prepare_wall_state_collision"):
		character.call("prepare_wall_state_collision")
	if character.has_method("try_snap_to_last_wall_contact"):
		character.call("try_snap_to_last_wall_contact")
	if character.has_method("consume_finished_animation"):
		while character.call("consume_finished_animation", AnimationConstants.PLAYER_WALL_CONTACT):
			pass

func state_process(delta):
	var has_floor_contact := character.is_on_floor()
	if character.has_method("has_stable_floor_contact"):
		has_floor_contact = character.call("has_stable_floor_contact")
	if has_floor_contact:
		next_state = grounded_state
		return

	if character.has_method("prepare_wall_state_collision"):
		character.call("prepare_wall_state_collision")

	var snapped_to_wall: bool = false
	if character.velocity.y >= 0.0 and character.has_method("try_snap_to_last_wall_contact"):
		var snapped_value: Variant = character.call("try_snap_to_last_wall_contact")
		if snapped_value is bool:
			snapped_to_wall = bool(snapped_value)

	var has_stable_wall_contact: bool = _has_stable_wall_contact() or snapped_to_wall
	if has_stable_wall_contact and character.has_method("refresh_wall_contact_cache"):
		character.call("refresh_wall_contact_cache")
	if has_stable_wall_contact:
		_wall_contact_elapsed += delta
	else:
		_wall_contact_elapsed = 0.0

	if not _wall_contact_finished:
		if character.has_method("consume_finished_animation") and character.call("consume_finished_animation", AnimationConstants.PLAYER_WALL_CONTACT):
			_wall_contact_finished = true
			if character.has_method("debug_attack_log"):
				character.call("debug_attack_log", "Walled.state_process wall_contact finished -> wall jump gate open")
	var wall_jump_release_seconds := 0.0
	if character.has_method("get_wall_jump_queue_release_seconds"):
		wall_jump_release_seconds = character.call("get_wall_jump_queue_release_seconds")
	var wall_jump_gate_open := _wall_contact_finished or _wall_contact_elapsed >= wall_jump_release_seconds
	var has_buffered_wall_jump := false
	if character.has_method("has_buffered_wall_jump_input"):
		has_buffered_wall_jump = character.call("has_buffered_wall_jump_input")
	if has_stable_wall_contact and wall_jump_gate_open and has_buffered_wall_jump and character.has_method("try_buffered_wall_jump") and character.call("try_buffered_wall_jump"):
		if character.has_method("debug_attack_log"):
			character.call("debug_attack_log", "Walled.state_process buffered wall jump executed")
		next_state = jumping_state
		return

	var should_stay_walled := has_stable_wall_contact
	if not should_stay_walled:
		var detach_hysteresis_seconds: float = 0.0
		if character.has_method("get_wall_detach_hysteresis_seconds"):
			var detach_value: Variant = character.call("get_wall_detach_hysteresis_seconds")
			if detach_value is float or detach_value is int:
				detach_hysteresis_seconds = float(detach_value)
		_wall_detach_timer += delta
		if _wall_detach_timer >= detach_hysteresis_seconds:
			if character.has_method("debug_attack_log"):
				character.call("debug_attack_log", "Walled.state_process detach hysteresis elapsed -> Falling")
			next_state = falling_state
			return
	else:
		_wall_detach_timer = 0.0

func _has_stable_wall_contact() -> bool:
	if character.has_method("should_remain_walled"):
		return character.call("should_remain_walled")
	if character.has_method("has_stable_wall_contact"):
		return character.call("has_stable_wall_contact")
	if character.has_method("can_attach_to_wall"):
		return character.call("can_attach_to_wall")
	if character.has_method("has_wall_attach_contact"):
		return character.call("has_wall_attach_contact")
	return false

func state_input(event : InputEvent):
	if event.is_action_pressed("dash"):
		if character.has_method("request_dash") and character.call("request_dash"):
			next_state = dashing_state
		return
	if event.is_action_pressed("jump"):
		if character.has_method("buffer_wall_jump_input"):
			character.call("buffer_wall_jump_input")
		if character.has_method("debug_attack_log"):
			character.call("debug_attack_log", "Walled.state_input jump pressed -> wall jump buffered")
