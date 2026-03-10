extends State

class_name GroundedState

const AnimationConstants = preload("res://scripts/constants/animation_constants.gd")

@export var jumping_state : State
@export var falling_state: State
@export var attacking_state : State
@export var dashing_state : State
@export var defend_state : State

func state_process(_delta):
	var has_floor_contact := character.is_on_floor()
	if character.has_method("has_stable_floor_contact"):
		has_floor_contact = character.call("has_stable_floor_contact")
	if !has_floor_contact and character.velocity.y > 0.0:
		next_state = falling_state
		return

	if playback != null and _get_current_animation_node() != AnimationConstants.PLAYER_MOVE:
		playback.start(AnimationConstants.PLAYER_MOVE)
		
	_clear_condition_after_leaving("landed", _landed_animation_nodes())

func state_input(event : InputEvent):
	if event.is_action_pressed("defend"):
		if defend_state != null and character.has_method("request_defend") and character.call("request_defend", AnimationConstants.PLAYER_STATE_GROUNDED):
			next_state = defend_state
		return
	if event.is_action_pressed("dash"):
		if character.has_method("request_dash") and character.call("request_dash"):
			next_state = dashing_state
		return
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
	if playback != null:
		playback.start(AnimationConstants.PLAYER_MOVE)
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
		AnimationConstants.PLAYER_FALL,
		AnimationConstants.PLAYER_WALL_CONTACT,
		AnimationConstants.PLAYER_WALL_SLIDE,
		AnimationConstants.PLAYER_JUMP_START,
		AnimationConstants.PLAYER_JUMP,
		AnimationConstants.PLAYER_JUMP_TRANSITION,
		AnimationConstants.PLAYER_WALL_JUMP,
		AnimationConstants.PLAYER_ATTACK_1,
		AnimationConstants.PLAYER_ATTACK_2,
		AnimationConstants.PLAYER_ATTACK_3,
		AnimationConstants.PLAYER_AIR_ATTACK,
	]



