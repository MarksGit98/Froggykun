extends Label

@export var state_machine : EnemyStateMachine

func _process(_delta: float) -> void:
	if state_machine == null:
		return

	var hp_text: String = _get_hp_text()
	text = "State: " + state_machine.get_current_state() + "\nAnimation: " + state_machine.get_current_animation_state() + "\nHP: " + hp_text

func _get_hp_text() -> String:
	if state_machine == null or state_machine.enemy == null:
		return "?"
	var enemy: Enemy = state_machine.enemy
	var health_value: Variant = enemy.get("current_health")
	var max_health_value: Variant = enemy.get("_max_health")
	if (typeof(health_value) != TYPE_FLOAT and typeof(health_value) != TYPE_INT) or (typeof(max_health_value) != TYPE_FLOAT and typeof(max_health_value) != TYPE_INT):
		return "?"
	return "%d/%d" % [int(round(float(health_value))), int(round(float(max_health_value)))]
