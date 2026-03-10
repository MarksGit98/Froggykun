extends EnemyState
class_name EnemyDeathState

func on_enter() -> void:
	enemy.enter_death_state()

func state_process(delta: float) -> void:
	enemy.process_death_state(delta)
