extends State

class_name WalledState

@export var grounded_state : State
@export var jumping_state : State
@export var falling_state : State

func on_enter():
	_set_animation_condition("jump_initiated", false)
	_set_animation_condition("landed", false)
	character.velocity.y = 0.0

func state_process(_delta):
	var has_floor_contact := character.is_on_floor()
	if character.has_method("has_stable_floor_contact"):
		has_floor_contact = character.call("has_stable_floor_contact")
	if has_floor_contact:
		next_state = grounded_state
		return
	if character.has_method("try_buffered_wall_jump") and character.call("try_buffered_wall_jump"):
		next_state = jumping_state
		return

	var should_stay_walled := false
	if character.has_method("has_stable_wall_contact"):
		should_stay_walled = character.call("has_stable_wall_contact")
	elif character.has_method("can_attach_to_wall"):
		should_stay_walled = character.call("can_attach_to_wall")
	if not should_stay_walled:
		next_state = falling_state
		return

func state_input(event : InputEvent):
	if not event.is_action_pressed("jump"):
		return
	if character.has_method("buffer_wall_jump_input"):
		character.call("buffer_wall_jump_input")
	if not character.has_method("request_wall_jump"):
		return
	if not character.call("request_wall_jump"):
		return

	next_state = jumping_state
