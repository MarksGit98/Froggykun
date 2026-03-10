extends State

class_name DeadState

const AnimationConstants = preload("res://scripts/constants/animation_constants.gd")

const DEATH_ANIMATION: StringName = AnimationConstants.PLAYER_DEATH

var _death_animation_finished: bool = false
var _restart_queued: bool = false

func get_state_name() -> StringName:
	return &"dead"

func on_enter() -> void:
	_death_animation_finished = false
	_restart_queued = false

	if character != null:
		character.velocity = Vector2.ZERO
		if character.has_method("stop_action_motion"):
			character.call("stop_action_motion")
		if character.has_method("cancel_attack_sequence"):
			character.call("cancel_attack_sequence")

	var animation_tree: AnimationTree = null
	if character != null:
		animation_tree = character.get_node_or_null("AnimationTree") as AnimationTree
	if animation_tree != null:
		animation_tree.active = true

	if character != null and character.has_method("consume_finished_animation"):
		var cleared_finished_event: bool = true
		while cleared_finished_event:
			var consumed_value: Variant = character.call("consume_finished_animation", DEATH_ANIMATION)
			if consumed_value is bool:
				var consumed_finished: bool = bool(consumed_value)
				cleared_finished_event = consumed_finished
			else:
				cleared_finished_event = false

	if playback == null:
		_death_animation_finished = true
		return

	playback.start(DEATH_ANIMATION)

func state_process(_delta: float) -> void:
	if _restart_queued:
		return

	if character != null and character.has_method("consume_finished_animation"):
		var consumed_value: Variant = character.call("consume_finished_animation", DEATH_ANIMATION)
		if consumed_value is bool:
			var consumed_finished: bool = bool(consumed_value)
			if consumed_finished:
				_death_animation_finished = true

	if not _death_animation_finished:
		return

	_restart_queued = true
	call_deferred("_go_to_main_scene")

func on_exit() -> void:
	_death_animation_finished = false
	_restart_queued = false

func _go_to_main_scene() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return

	var main_scene_value: Variant = ProjectSettings.get_setting("application/run/main_scene")
	if typeof(main_scene_value) != TYPE_STRING:
		return

	var main_scene_path: String = String(main_scene_value)
	if main_scene_path.is_empty():
		return

	tree.change_scene_to_file(main_scene_path)


