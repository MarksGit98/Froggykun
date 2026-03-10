extends EnemyState
class_name EnemyCombatState

@export var patrol_state_name: StringName = &"Patrol"

func on_enter() -> void:
	if enemy != null:
		enemy.enter_combat_state()

func state_process(delta: float) -> void:
	if enemy == null:
		return
	if not enemy.should_stay_in_combat_state():
		if state_machine != null:
			next_state = state_machine.get_state_by_name(patrol_state_name)
		return
	enemy.process_combat_state(delta)
