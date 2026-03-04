extends State

class_name GroundedState

@export var jumping_state : State
@export var falling_state: State
@export var attacking_state : State

func state_process(_delta):
	var has_floor_contact := character.is_on_floor()
	if character.has_method("has_stable_floor_contact"):
		has_floor_contact = character.call("has_stable_floor_contact")
	if !has_floor_contact and character.velocity.y > 0.0:
		next_state = falling_state
		return
	
	_clear_condition_after_leaving("landed", _landed_animation_nodes())

func state_input(event : InputEvent):
	if event.is_action_pressed("attack"):
		if character.has_method("request_ground_attack") and character.call("request_ground_attack"):
			_set_animation_condition("landed", false)
			next_state = attacking_state
		return
	if(event.is_action_pressed("jump")):
		jump()

func on_enter():
	_set_animation_condition("jump_initiated", false)
	_set_animation_condition("landed", true)
	_clear_condition_after_leaving("landed", _landed_animation_nodes())
		
func jump():
	if not character.has_method("request_ground_jump"):
		return
	if not character.call("request_ground_jump", character.jump_velocity):
		return

	_set_animation_condition("landed", false)
	next_state = jumping_state

func _landed_animation_nodes() -> Array[StringName]:
	return [
		&"fall",
		&"wall_contact",
		&"wall_slide",
		&"jump_start",
		&"jump",
		&"jump_transition",
		&"wall_jump",
		&"attack_1",
		&"attack_2",
		&"attack_3",
		&"air_attack",
	]
