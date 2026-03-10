extends RefCounted
class_name CharacterStepUtility

static func try_step_up(body: CharacterBody2D, horizontal_velocity: float, step_height: float, step_probe_distance: float) -> bool:
	var step_offset: int = _find_step_offset(body, horizontal_velocity, step_height, step_probe_distance)
	if step_offset <= 0:
		return false
	body.global_position.y -= float(step_offset)
	return true

static func can_step_up(body: CharacterBody2D, horizontal_velocity: float, step_height: float, step_probe_distance: float) -> bool:
	return _find_step_offset(body, horizontal_velocity, step_height, step_probe_distance) > 0

static func try_snap_up_to_ledge(
		body: CharacterBody2D,
		body_shape: CollisionShape2D,
		horizontal_velocity: float,
		snap_height: float,
		forward_distance: float,
		floor_probe_distance: float,
		collision_mask: int
	) -> bool:
	var snap_offset: Vector2 = _find_ledge_snap_offset(
		body,
		body_shape,
		horizontal_velocity,
		snap_height,
		forward_distance,
		floor_probe_distance,
		collision_mask
	)
	if snap_offset == Vector2.ZERO:
		return false
	body.global_position += snap_offset
	return true

static func _find_step_offset(body: CharacterBody2D, horizontal_velocity: float, step_height: float, step_probe_distance: float) -> int:
	if body == null:
		return 0
	if step_height <= 0.0 or step_probe_distance <= 0.0:
		return 0
	if not body.is_on_floor():
		return 0
	if body.velocity.y < 0.0:
		return 0
	if absf(horizontal_velocity) < 0.01:
		return 0

	var move_direction: float = signf(horizontal_velocity)
	if is_zero_approx(move_direction):
		return 0

	var forward_motion: Vector2 = Vector2(move_direction * step_probe_distance, 0.0)
	if not body.test_move(body.global_transform, forward_motion):
		return 0

	var max_step_offset: int = int(round(step_height))
	for offset_value in range(1, max_step_offset + 1):
		var step_offset: int = int(offset_value)
		var raise_motion: Vector2 = Vector2(0.0, -float(step_offset))
		if body.test_move(body.global_transform, raise_motion):
			continue

		var raised_transform: Transform2D = body.global_transform.translated(raise_motion)
		if body.test_move(raised_transform, forward_motion):
			continue

		return step_offset

	return 0

static func _find_ledge_snap_offset(
		body: CharacterBody2D,
		body_shape: CollisionShape2D,
		horizontal_velocity: float,
		snap_height: float,
		forward_distance: float,
		floor_probe_distance: float,
		collision_mask: int
	) -> Vector2:
	if body == null or body_shape == null or body_shape.shape == null:
		return Vector2.ZERO
	if snap_height <= 0.0 or forward_distance <= 0.0 or floor_probe_distance <= 0.0:
		return Vector2.ZERO
	if body.is_on_floor():
		return Vector2.ZERO
	if body.velocity.y < 0.0:
		return Vector2.ZERO
	if absf(horizontal_velocity) < 0.01:
		return Vector2.ZERO

	var move_direction: float = signf(horizontal_velocity)
	if is_zero_approx(move_direction):
		return Vector2.ZERO

	var forward_motion: Vector2 = Vector2(move_direction * forward_distance, 0.0)
	if not body.test_move(body.global_transform, forward_motion):
		return Vector2.ZERO

	var max_snap_offset: int = int(round(snap_height))
	for offset_value in range(1, max_snap_offset + 1):
		var raise_motion: Vector2 = Vector2(0.0, -float(offset_value))
		if body.test_move(body.global_transform, raise_motion):
			continue

		var raised_transform: Transform2D = body.global_transform.translated(raise_motion)
		if body.test_move(raised_transform, forward_motion):
			continue

		var landing_transform: Transform2D = raised_transform.translated(forward_motion)
		if not _has_floor_support_at(body, body_shape, landing_transform, floor_probe_distance, collision_mask):
			continue

		return raise_motion + forward_motion

	return Vector2.ZERO

static func _has_floor_support_at(
		body: CharacterBody2D,
		body_shape: CollisionShape2D,
		body_transform: Transform2D,
		floor_probe_distance: float,
		collision_mask: int
	) -> bool:
	var origin: Vector2 = _get_floor_probe_origin(body_shape, body_transform)
	var target: Vector2 = origin + Vector2.DOWN * floor_probe_distance
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(origin, target)
	var exclusions: Array[RID] = [body.get_rid()]
	query.exclude = exclusions
	query.collision_mask = collision_mask
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var result: Dictionary = body.get_world_2d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return false
	var hit_normal: Vector2 = result.get("normal", Vector2.ZERO)
	return hit_normal.dot(Vector2.UP) >= 0.5

static func _get_floor_probe_origin(body_shape: CollisionShape2D, body_transform: Transform2D) -> Vector2:
	var shape_origin: Vector2 = body_transform * body_shape.position
	var shape: Shape2D = body_shape.shape
	if shape is RectangleShape2D:
		var rectangle: RectangleShape2D = shape as RectangleShape2D
		return shape_origin + Vector2(0.0, rectangle.size.y * 0.5)
	if shape is CapsuleShape2D:
		var capsule: CapsuleShape2D = shape as CapsuleShape2D
		return shape_origin + Vector2(0.0, maxf(capsule.height * 0.5, capsule.radius))
	if shape is CircleShape2D:
		var circle: CircleShape2D = shape as CircleShape2D
		return shape_origin + Vector2(0.0, circle.radius)
	return shape_origin
