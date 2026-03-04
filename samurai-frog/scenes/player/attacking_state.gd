extends State

class_name AttackingState

@export var grounded_state : State
@export var jumping_state : State
@export var falling_state : State
@export var walled_state : State

var active_animation : StringName = StringName()

func on_enter():
	_set_animation_condition("jump_initiated", false)
	_set_animation_condition("landed", false)
	_refresh_active_animation()
	_debug_attack("enter attacking with active animation %s" % String(active_animation))

func state_process(_delta):
	if _is_air_attack():
		var has_floor_contact := character.is_on_floor()
		if character.has_method("has_stable_floor_contact"):
			has_floor_contact = character.call("has_stable_floor_contact")
		if has_floor_contact:
			_debug_attack("air attack landed -> grounded")
			character.call("finish_air_attack")
			_set_animation_condition("landed", true)
			next_state = grounded_state
			return
		if _can_attach_to_wall():
			_debug_attack("air attack attached to wall -> walled")
			character.call("finish_air_attack")
			next_state = walled_state
			return
	else:
		var has_floor_contact := character.is_on_floor()
		if character.has_method("has_stable_floor_contact"):
			has_floor_contact = character.call("has_stable_floor_contact")
		if has_floor_contact:
			var move_interrupt := Input.is_action_just_pressed("move_left") or Input.is_action_just_pressed("move_right")
			if move_interrupt or Input.is_action_just_pressed("dash"):
				_debug_attack("ground attack interrupted by move/dash -> grounded")
				character.call("cancel_attack_sequence")
				next_state = grounded_state
				return
		elif character.velocity.y > 0.0:
			_debug_attack("ground attack lost floor and is falling -> falling")
			character.call("cancel_attack_sequence")
			next_state = falling_state
			return

	_consume_request_if_started()
	if not _consume_finished_animation():
		return

	_debug_attack("finished animation %s" % String(active_animation))
	if _is_air_attack():
		_finish_air_attack()
		return

	if character.has_method("consume_queued_ground_attack") and character.call("consume_queued_ground_attack"):
		_debug_attack("queued grounded attack consumed, staying in attacking")
		_refresh_active_animation()
		return

	_debug_attack("no queued grounded attack, returning to grounded")
	character.call("finish_attack_sequence")
	next_state = grounded_state

func state_input(event : InputEvent):
	if event.is_action_pressed("jump") and not _is_air_attack():
		_debug_attack("jump pressed during grounded attack")
		if character.call("request_ground_jump", character.jump_velocity):
			_debug_attack("jump accepted, interrupting attack -> jumping")
			character.call("cancel_attack_sequence")
			next_state = jumping_state
			return

	if not event.is_action_pressed("attack"):
		return
	if _is_air_attack():
		_debug_attack("attack pressed during air attack, ignored")
		return

	_debug_attack("attack pressed during grounded attack")
	character.call("request_ground_attack")

func _refresh_active_animation() -> void:
	if _is_air_attack():
		active_animation = &"air_attack"
	else:
		active_animation = character.call("get_current_attack_animation")

func _consume_request_if_started() -> void:
	if not character.has_method("consume_started_animation"):
		return
	if not character.call("consume_started_animation", active_animation):
		return

	if _is_air_attack():
		if character.has_method("is_air_attack_animation_requested") and character.call("is_air_attack_animation_requested"):
			character.call("clear_air_attack_animation_request")
		return

	if character.has_method("is_attack_animation_requested") and character.call("is_attack_animation_requested"):
		_debug_attack("active grounded attack animation started: %s" % String(active_animation))
		character.call("clear_attack_animation_request")

func _consume_finished_animation() -> bool:
	if not character.has_method("consume_finished_animation"):
		return false
	return character.call("consume_finished_animation", active_animation)

func _finish_air_attack() -> void:
	var source_state_name := String(character.call("get_air_attack_source_state_name"))
	var landed := character.is_on_floor()
	if character.has_method("has_stable_floor_contact"):
		landed = character.call("has_stable_floor_contact")
	character.call("finish_air_attack")

	if landed:
		_set_animation_condition("landed", true)
		next_state = grounded_state
		return

	if source_state_name == "Jumping":
		character.call("prepare_air_attack_return_to_jump")
		next_state = jumping_state
		return

	next_state = falling_state

func _is_air_attack() -> bool:
	return character.has_method("is_air_attack_active") and character.call("is_air_attack_active")

func _can_attach_to_wall() -> bool:
	if character.has_method("has_stable_wall_contact"):
		return character.call("has_stable_wall_contact")
	if character.has_method("can_attach_to_wall"):
		return character.call("can_attach_to_wall")
	return false

func _debug_attack(message: String) -> void:
	if character != null and character.has_method("debug_attack_log"):
		character.call("debug_attack_log", "AttackingState: %s" % message)
