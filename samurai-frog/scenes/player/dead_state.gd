extends State

class_name DeadState

var _restart_queued: bool = false

func get_state_name() -> StringName:
	return &"dead"

func on_enter() -> void:
	if _restart_queued:
		return

	_restart_queued = true
	call_deferred("_reload_current_scene")

func on_exit() -> void:
	_restart_queued = false

func _reload_current_scene() -> void:
	var tree := get_tree()
	if tree == null:
		return
	tree.reload_current_scene()
