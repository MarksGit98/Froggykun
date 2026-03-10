extends Node

var player: CharacterBody2D

func initialize(owner_player: CharacterBody2D) -> void:
	player = owner_player

func is_jump_press_event(event: InputEvent) -> bool:
	if InputMap.has_action("jump"):
		return event.is_action_pressed("jump")
	return event.is_action_pressed("ui_accept")

func queue_wall_jump_buffer() -> void:
	if player == null:
		return
	player.wall_jump_input_buffer_timer = player.wall_jump_input_buffer_seconds

func prime_input_buffers(jump_just_pressed: bool) -> void:
	if player == null:
		return
	if jump_just_pressed:
		queue_wall_jump_buffer()

func try_regular_jump(direction: float, jump_just_pressed: bool, allow_coyote_jump: bool) -> bool:
	if player == null:
		return false
	if not jump_just_pressed:
		return false

	var can_coyote_jump: bool = allow_coyote_jump and player.ground_jump_coyote_timer > 0.0 and not player._has_wall_contact_for_air_actions()
	if not player.is_on_floor() and not can_coyote_jump:
		return false

	player.velocity.y = player.jump_velocity
	player._apply_runup_jump_boost(direction)
	player.wall_jump_input_buffer_timer = 0.0
	player.ground_jump_coyote_timer = 0.0
	player._play_action("jump_start")
	return true

func try_wall_jump() -> bool:
	if player == null:
		return false
	if player.is_on_floor():
		return false

	if player.wall_jump_input_buffer_timer <= 0.0:
		return false

	if not player._has_wall_contact_for_air_actions():
		return false

	var wall_normal_x: float = player.wall_contact_normal_x
	if is_zero_approx(wall_normal_x):
		wall_normal_x = player._resolve_wall_normal_x()
	if is_zero_approx(wall_normal_x):
		var move_direction: float = player._move_axis()
		if absf(move_direction) > 0.01:
			wall_normal_x = -signf(move_direction)
	if is_zero_approx(wall_normal_x) and player.sprite != null:
		wall_normal_x = -1.0 if player.sprite.flip_h else 1.0
	if is_zero_approx(wall_normal_x):
		return false

	player.velocity.x = wall_normal_x * player.wall_jump_horizontal_speed
	player.velocity.y = player.wall_jump_velocity
	player.wall_jump_control_lock_timer = player.wall_jump_control_lock_seconds
	player.wall_jump_input_buffer_timer = 0.0
	player.ground_jump_coyote_timer = 0.0
	player.sprite.flip_h = player.velocity.x < 0.0
	player.wall_contact_normal_x = 0.0
	player.wall_attached_active = false
	player.wall_slide_active = false

	# Wall jump should interrupt any currently locked action.
	player.animation_locked = false
	player._animation_lock_timer = 0.0
	player._play_action("wall_jump")
	return true
