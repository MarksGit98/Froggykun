extends Label

@export var state_machine : PlayerStateMachine

func _process(_delta: float) -> void:
	if state_machine == null:
		return

	var hp_text: String = _get_hp_text()
	var defend_text: String = _get_defend_text()
	var wall_text: String = _get_wall_text()
	text = "State: " + state_machine.get_current_state() + "\nAnimation: " + state_machine.get_current_animation_state() + "\nHP: " + hp_text + "\nDefend: " + defend_text + "\nWall: " + wall_text

func _get_hp_text() -> String:
	if state_machine == null or state_machine.character == null:
		return "?"
	var character: CharacterBody2D = state_machine.character
	var health_value: Variant = character.get("current_health")
	var max_health_value: Variant = character.get("max_health")
	if (typeof(health_value) != TYPE_FLOAT and typeof(health_value) != TYPE_INT) or (typeof(max_health_value) != TYPE_FLOAT and typeof(max_health_value) != TYPE_INT):
		return "?"
	return "%d/%d" % [int(round(float(health_value))), int(round(float(max_health_value)))]

func _get_defend_text() -> String:
	if state_machine == null or state_machine.character == null:
		return "?"
	var character: CharacterBody2D = state_machine.character
	if not character.has_method("get_defend_debug_text"):
		return "n/a"
	var defend_value: Variant = character.call("get_defend_debug_text")
	if typeof(defend_value) == TYPE_STRING:
		return String(defend_value)
	return "?"

func _get_wall_text() -> String:
	if state_machine == null or state_machine.character == null:
		return "?"
	var character: CharacterBody2D = state_machine.character
	if not character.has_method("get_wall_debug_text"):
		return "n/a"
	var wall_value: Variant = character.call("get_wall_debug_text")
	if typeof(wall_value) == TYPE_STRING:
		return String(wall_value)
	return "?"
