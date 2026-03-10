extends State

const AnimationConstants = preload("res://scripts/constants/animation_constants.gd")

@export var grounded_state : State
@export var jumping_state : State
@export var walled_state : State
@export var attacking_state : State
@export var dashing_state : State
@export var defend_state : State

var _wall_attach_contact_timer : float = 0.0

func on_enter():
	_set_animation_condition("landed", false)
	_wall_attach_contact_timer = 0.0

func state_process(delta):
	var has_floor_contact := character.is_on_floor()
	if character.has_method("has_stable_floor_contact"):
		has_floor_contact = character.call("has_stable_floor_contact")
	if has_floor_contact:
		_set_animation_condition("landed", true)
		next_state = grounded_state
		return

	if character.has_method("is_wall_jump_control_locked") and character.call("is_wall_jump_control_locked"):
		_set_animation_condition("landed", false)
		return

	var can_reattach_to_wall := true
	if character.has_method("is_wall_jump_reattach_cooldown_active"):
		can_reattach_to_wall = not character.call("is_wall_jump_reattach_cooldown_active")
	if can_reattach_to_wall:
		if character.has_method("try_snap_to_nearby_wall_from_fall") and character.call("try_snap_to_nearby_wall_from_fall"):
			var can_attach_to_wall := true
			if character.has_method("can_attach_to_wall"):
				can_attach_to_wall = character.call("can_attach_to_wall")
			if can_attach_to_wall:
				if character.has_method("debug_attack_log"):
					character.call("debug_attack_log", "Falling.state_process snapped to wall threshold -> Walled")
				next_state = walled_state
				return

		var has_wall_contact := _has_stable_wall_contact()
		if has_wall_contact:
			_wall_attach_contact_timer += delta
			var attach_hysteresis_seconds := 0.0
			if character.has_method("get_wall_attach_hysteresis_seconds"):
				attach_hysteresis_seconds = character.call("get_wall_attach_hysteresis_seconds")
			if _wall_attach_contact_timer >= attach_hysteresis_seconds:
				if character.has_method("debug_attack_log"):
					character.call("debug_attack_log", "Falling.state_process wall attach hysteresis met -> Walled")
				next_state = walled_state
				return
		else:
			_wall_attach_contact_timer = 0.0
	else:
		_wall_attach_contact_timer = 0.0

	_set_animation_condition("landed", false)

func _has_stable_wall_contact() -> bool:
	if character.has_method("has_stable_wall_contact"):
		return character.call("has_stable_wall_contact")
	if character.has_method("can_attach_to_wall"):
		return character.call("can_attach_to_wall")
	if character.has_method("has_wall_attach_contact"):
		return character.call("has_wall_attach_contact")
	return false

func state_input(event : InputEvent):
	if event.is_action_pressed("defend"):
		if defend_state != null and character.has_method("request_defend") and character.call("request_defend", AnimationConstants.PLAYER_STATE_FALLING):
			next_state = defend_state
		return
	if event.is_action_pressed("dash"):
		if character.has_method("request_dash") and character.call("request_dash"):
			next_state = dashing_state
		return
	if event.is_action_pressed("attack"):
		if character.has_method("request_air_attack") and character.call("request_air_attack", AnimationConstants.PLAYER_STATE_FALLING):
			next_state = attacking_state
		return
	if event.is_action_pressed("jump"):
		if not character.has_method("request_ground_jump"):
			return
		if not character.call("request_ground_jump", character.jump_velocity):
			if character.has_method("buffer_wall_jump_input"):
				character.call("buffer_wall_jump_input")
			if character.has_method("debug_attack_log"):
				character.call("debug_attack_log", "Falling.state_input jump pressed without ground jump -> wall jump buffered")
			return

		_set_animation_condition("landed", false)
		next_state = jumping_state
