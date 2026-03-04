extends State

@export var grounded_state : State
@export var jumping_state : State
@export var walled_state : State
@export var attacking_state : State

func on_enter():
	_set_animation_condition("landed", false)

func state_process(_delta):
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

	var has_wall_contact := false
	if character.has_method("has_stable_wall_contact"):
		has_wall_contact = character.call("has_stable_wall_contact")
	elif character.has_method("can_attach_to_wall"):
		has_wall_contact = character.call("can_attach_to_wall")
	if has_wall_contact:
		if character.has_method("try_buffered_wall_jump") and character.call("try_buffered_wall_jump"):
			next_state = jumping_state
		else:
			next_state = walled_state
		return

	_set_animation_condition("landed", false)

func state_input(event : InputEvent):
	if event.is_action_pressed("attack"):
		if character.has_method("request_air_attack") and character.call("request_air_attack", StringName("Falling")):
			next_state = attacking_state
		return
	if not event.is_action_pressed("jump"):
		return
	if not character.has_method("request_ground_jump"):
		return
	if not character.call("request_ground_jump", character.jump_velocity):
		if character.has_method("buffer_wall_jump_input"):
			character.call("buffer_wall_jump_input")
		return

	_set_animation_condition("landed", false)
	next_state = jumping_state
