extends Node
class_name EnemyState

@export var can_move: bool = true

var enemy: Enemy
var state_machine: EnemyStateMachine
var next_state: EnemyState

func state_process(_delta: float) -> void:
	pass

func on_enter() -> void:
	pass

func on_exit() -> void:
	pass
