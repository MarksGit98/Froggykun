extends State

class_name JumpingState

@export var grounded_state: State
@export var falling_state: State
@export var walled_state: State
@export var attacking_state: State

func on_enter():
	if character.has_method("is_air_attack_return_jump_requested") and character.call("is_air_attack_return_jump_requested"):
		_set_animation_condition("jump_initiated", false)
		return
	if character.has_method("is_wall_jump_animation_requested") and character.call("is_wall_jump_animation_requested"):
		_set_animation_condition("jump_initiated", false)
		return

	_set_animation_condition("jump_initiated", true)

func state_process(_delta):
	if character.has_method("is_wall_jump_animation_requested") and character.call("is_wall_jump_animation_requested"):
		var current_animation := _get_current_animation_node()
		if current_animation == &"wall_jump" or current_animation == &"jump":
			character.call("clear_wall_jump_animation_request")
	if character.has_method("is_air_attack_return_jump_requested") and character.call("is_air_attack_return_jump_requested"):
		if _get_current_animation_node() == &"jump":
			character.call("clear_air_attack_return_jump_request")

	var has_floor_contact := character.is_on_floor()
	if character.has_method("has_stable_floor_contact"):
		has_floor_contact = character.call("has_stable_floor_contact")
	if has_floor_contact:
		next_state = grounded_state
		return

	if character.has_method("is_wall_jump_control_locked") and character.call("is_wall_jump_control_locked"):
		return

	var has_wall_contact := false
	if character.has_method("has_stable_wall_contact"):
		has_wall_contact = character.call("has_stable_wall_contact")
	elif character.has_method("can_attach_to_wall"):
		has_wall_contact = character.call("can_attach_to_wall")
	if has_wall_contact:
		if character.has_method("try_buffered_wall_jump") and character.call("try_buffered_wall_jump"):
			next_state = self
		else:
			next_state = walled_state
		return

	if character.velocity.y > 0.0:
		next_state = falling_state
		return
		
func state_input(event : InputEvent):
	if event.is_action_pressed("attack"):
		if character.has_method("request_air_attack") and character.call("request_air_attack", StringName("Jumping")):
			next_state = attacking_state
		return
	if(event.is_action_pressed("jump")):
		if character.has_method("buffer_wall_jump_input"):
			character.call("buffer_wall_jump_input")

func on_exit():
	_set_animation_condition("jump_initiated", false)
