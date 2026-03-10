extends Enemy
class_name GoblinEnemy

func _ready() -> void:
	audio_profile_id = &"goblin"
	combat_wall_jump_enabled = true
	super._ready()
