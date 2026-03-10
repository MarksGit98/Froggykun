extends Node
class_name PlayerStateMachine

const AnimationConstants = preload("res://scripts/constants/animation_constants.gd")

@export var character: CharacterBody2D
@export var animation_tree: AnimationTree
@export var current_state: State

var states : Array[State]

func _ready():
	for child in get_children():
		if(child is State):
			states.append(child)
			
			# Set the states up with what they need to function
			child.character = character
			child.playback = animation_tree["parameters/playback"]
			
		else:
			push_warning("Child " + child.name + " is not a State for CharacterStateMachine")

	_sync_animation_conditions()

func _physics_process(delta):
	if(current_state.next_state != null):
		switch_states(current_state.next_state)
		
	current_state.state_process(delta)

	if(current_state.next_state != null):
		switch_states(current_state.next_state)

	_sync_animation_conditions()

func check_if_can_move():
	return current_state.can_move


func switch_states(new_state : State):
	var previous_state_name := "None"
	if current_state != null:
		previous_state_name = current_state.name

	if(current_state != null):
		current_state.on_exit()
		current_state.next_state = null
	
	current_state = new_state
	
	current_state.on_enter()
	if animation_tree != null and current_state.name == String(AnimationConstants.PLAYER_STATE_GROUNDED):
		var playback: AnimationNodeStateMachinePlayback = animation_tree["parameters/playback"]
		if playback != null:
			playback.start(AnimationConstants.PLAYER_MOVE)
	_sync_animation_conditions()
	if character != null and character.has_method("debug_attack_log"):
		character.call("debug_attack_log", "StateMachine: %s -> %s" % [previous_state_name, current_state.name])

func _input(event : InputEvent):
	current_state.state_input(event)

func get_current_state() -> String:
	return current_state.name

func get_current_animation_state() -> String:
	if animation_tree == null:
		return "None"
	var playback: AnimationNodeStateMachinePlayback = animation_tree["parameters/playback"]
	if playback == null or not playback.has_method("get_current_node"):
		return "None"
	var current_node: StringName = playback.get_current_node()
	if current_node == StringName():
		return "None"
	return String(current_node)

func get_animation_condition(condition_name: String) -> bool:
	if animation_tree == null:
		return false
	var value = animation_tree.get("parameters/conditions/%s" % condition_name)
	if typeof(value) != TYPE_BOOL:
		return false
	return value

func _sync_animation_conditions() -> void:
	if animation_tree == null or current_state == null:
		return

	animation_tree.set("parameters/conditions/is_falling", current_state.name == String(AnimationConstants.PLAYER_STATE_FALLING))
	animation_tree.set("parameters/conditions/is_walled", current_state.name == String(AnimationConstants.PLAYER_STATE_WALLED))
	animation_tree.set("parameters/conditions/is_dashing", current_state.name == String(AnimationConstants.PLAYER_STATE_DASHING))
	var wall_jump_requested := false
	if character != null and character.has_method("is_wall_jump_animation_requested"):
		wall_jump_requested = character.call("is_wall_jump_animation_requested")
	animation_tree.set("parameters/conditions/wall_jump_requested", wall_jump_requested)
	var requested_attack_animation := StringName()
	if character != null and character.has_method("get_requested_attack_animation"):
		requested_attack_animation = character.call("get_requested_attack_animation")
	animation_tree.set("parameters/conditions/attack_1_requested", requested_attack_animation == AnimationConstants.PLAYER_ATTACK_1)
	animation_tree.set("parameters/conditions/attack_2_requested", requested_attack_animation == AnimationConstants.PLAYER_ATTACK_2)
	animation_tree.set("parameters/conditions/attack_3_requested", requested_attack_animation == AnimationConstants.PLAYER_ATTACK_3)
	var air_attack_requested := false
	if character != null and character.has_method("is_air_attack_animation_requested"):
		air_attack_requested = character.call("is_air_attack_animation_requested")
	animation_tree.set("parameters/conditions/air_attack_requested", air_attack_requested)
	var air_attack_return_jump_requested := false
	if character != null and character.has_method("is_air_attack_return_jump_requested"):
		air_attack_return_jump_requested = character.call("is_air_attack_return_jump_requested")
	animation_tree.set("parameters/conditions/air_attack_return_jump_requested", air_attack_return_jump_requested)
	var player_hit := false
	if character != null and character.has_method("consume_defend_player_hit_flag"):
		player_hit = character.call("consume_defend_player_hit_flag")
	animation_tree.set("parameters/conditions/player_hit", player_hit)
