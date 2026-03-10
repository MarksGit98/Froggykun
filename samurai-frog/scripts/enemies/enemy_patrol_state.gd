extends EnemyState
class_name EnemyPatrolState

@export var combat_state_name: StringName = &"Combat"

func on_enter() -> void:
	if enemy != null:
		enemy.enter_patrol_state()

func state_process(delta: float) -> void:
	if enemy == null:
		return
	if enemy.should_enter_combat_state():
		if state_machine != null:
			next_state = state_machine.get_state_by_name(combat_state_name)
		return
	enemy.process_patrol_state(delta)
