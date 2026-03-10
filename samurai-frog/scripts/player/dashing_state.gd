extends State

class_name DashingState

const AnimationConstants = preload("res://scripts/constants/animation_constants.gd")

@export var grounded_state: State
@export var jumping_state: State
@export var falling_state: State
@export var walled_state: State
@export var attacking_state: State

var _dash_animation_finished: bool = false

func on_enter() -> void:
	_set_animation_condition("jump_initiated", false)
	_set_animation_condition("landed", false)
	_dash_animation_finished = false
	if character.has_method("clear_attack_animation_request"):
		character.call("clear_attack_animation_request")
	if character.has_method("clear_air_attack_animation_request"):
		character.call("clear_air_attack_animation_request")
	if character.has_method("clear_wall_jump_animation_request"):
		character.call("clear_wall_jump_animation_request")
	if character.has_method("consume_finished_animation"):
		while character.call("consume_finished_animation", AnimationConstants.PLAYER_DASH):
			pass
	if playback != null:
		playback.travel(AnimationConstants.PLAYER_DASH)

	var dash_active := false
	if character.has_method("is_dash_active"):
		dash_active = character.call("is_dash_active")
	if not dash_active and character.has_method("request_dash"):
		dash_active = character.call("request_dash")
	if not dash_active:
		_route_after_dash()

func state_process(_delta: float) -> void:
	if not _dash_animation_finished:
		if character.has_method("consume_finished_animation") and character.call("consume_finished_animation", AnimationConstants.PLAYER_DASH):
			_dash_animation_finished = true
		else:
			return

	if character.has_method("is_dash_active") and character.call("is_dash_active"):
		return
	_route_after_dash()

func state_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		if character.has_method("buffer_dash_jump_input"):
			character.call("buffer_dash_jump_input")
		return
	if event.is_action_pressed("attack"):
		if character.has_method("buffer_dash_attack_input"):
			character.call("buffer_dash_attack_input")

func _route_after_dash() -> void:
	var on_floor_now := character.is_on_floor()
	var has_floor_contact := on_floor_now
	if character.has_method("has_stable_floor_contact"):
		has_floor_contact = character.call("has_stable_floor_contact")

	var can_attach_to_wall := false
	if character.has_method("can_attach_to_wall"):
		can_attach_to_wall = character.call("can_attach_to_wall")

	if character.has_method("consume_buffered_dash_jump_input") and character.call("consume_buffered_dash_jump_input"):
		if character.has_method("request_ground_jump") and character.call("request_ground_jump", character.jump_velocity):
			next_state = jumping_state
			return
		if character.has_method("buffer_wall_jump_input"):
			character.call("buffer_wall_jump_input")
		if can_attach_to_wall and character.has_method("request_wall_jump") and character.call("request_wall_jump"):
			next_state = jumping_state
			return

	if character.has_method("consume_buffered_dash_attack_input") and character.call("consume_buffered_dash_attack_input"):
		var attack_started := false
		if has_floor_contact and character.has_method("request_ground_attack"):
			attack_started = character.call("request_ground_attack")
		elif character.has_method("request_air_attack"):
			var source_state_name: StringName = AnimationConstants.PLAYER_STATE_FALLING
			if character.velocity.y <= 0.0:
				source_state_name = AnimationConstants.PLAYER_STATE_JUMPING
			attack_started = character.call("request_air_attack", source_state_name)
		if attack_started:
			next_state = attacking_state
			return

	if has_floor_contact:
		next_state = grounded_state
		return
	if can_attach_to_wall:
		next_state = walled_state
		return
	next_state = falling_state


