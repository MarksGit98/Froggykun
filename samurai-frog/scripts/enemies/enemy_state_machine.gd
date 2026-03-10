extends Node
class_name EnemyStateMachine

@export var enemy: Enemy
@export var current_state: EnemyState
@export var animation_tree: AnimationTree

var states: Array[EnemyState] = []

func _ready() -> void:
	if enemy == null:
		var parent_node: Node = get_parent()
		if parent_node is Enemy:
			enemy = parent_node as Enemy

	for child in get_children():
		if child is EnemyState:
			var state: EnemyState = child as EnemyState
			states.append(state)
			state.enemy = enemy
			state.state_machine = self
		else:
			push_warning("Child " + child.name + " is not an EnemyState for EnemyStateMachine")

	if current_state == null and not states.is_empty():
		current_state = states[0]

	if current_state != null:
		current_state.next_state = null
		if enemy != null and enemy.has_method("debug_enemy_log"):
			enemy.call("debug_enemy_log", "EnemyStateMachine ready -> " + current_state.name)
		current_state.on_enter()

func physics_update(delta: float) -> void:
	if current_state == null:
		return

	if current_state.next_state != null:
		switch_states(current_state.next_state)

	current_state.state_process(delta)

	if current_state.next_state != null:
		switch_states(current_state.next_state)

func switch_states(new_state: EnemyState) -> void:
	if new_state == null or new_state == current_state:
		return

	var previous_state_name: String = "None"
	if current_state != null:
		previous_state_name = current_state.name
		current_state.on_exit()
		current_state.next_state = null

	current_state = new_state
	current_state.next_state = null
	if enemy != null and enemy.has_method("debug_enemy_log"):
		enemy.call("debug_enemy_log", "EnemyStateMachine: " + previous_state_name + " -> " + current_state.name)
	current_state.on_enter()

func get_state_by_name(state_name: StringName) -> EnemyState:
	var desired_name: String = String(state_name)
	for state in states:
		if state.name == desired_name:
			return state
	return null

func get_current_state() -> String:
	return current_state.name

func get_current_animation_state() -> String:
	if enemy != null and enemy.has_method("get_debug_animation_state"):
		var animation_state: Variant = enemy.call("get_debug_animation_state")
		if animation_state is String:
			var animation_text: String = animation_state as String
			if animation_text != "":
				return animation_text
	if animation_tree == null:
		return "None"
	var playback: AnimationNodeStateMachinePlayback = animation_tree["parameters/playback"]
	if playback == null or not playback.has_method("get_current_node"):
		return "None"
	var current_node: StringName = playback.get_current_node()
	if current_node == StringName():
		return "None"
	return String(current_node)
