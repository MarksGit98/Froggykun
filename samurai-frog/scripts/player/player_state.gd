extends Node

class_name State

@export var can_move : bool = true

var character : CharacterBody2D
var playback : AnimationNodeStateMachinePlayback
var next_state : State

func state_process(delta):
	pass

func state_input(event : InputEvent):
	pass

func on_enter():
	pass

func on_exit():
	pass

func _get_animation_tree() -> AnimationTree:
	return character.get_node_or_null("AnimationTree") as AnimationTree

func _set_animation_condition(condition_name: String, value: bool) -> void:
	var tree := _get_animation_tree()
	if tree != null:
		tree.set("parameters/conditions/%s" % condition_name, value)

func _get_current_animation_node() -> StringName:
	if playback == null or not playback.has_method("get_current_node"):
		return StringName()
	return playback.get_current_node()

func _clear_condition_after_leaving(condition_name: String, active_nodes: Array[StringName]) -> void:
	var current_node := _get_current_animation_node()
	if current_node == StringName():
		return
	if not active_nodes.has(current_node):
		_set_animation_condition(condition_name, false)
