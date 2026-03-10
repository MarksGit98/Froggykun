@tool
extends EnemyBase
class_name BossBase

signal phase_changed(phase_index: int, health_ratio: float, move_set_id: StringName)
signal boss_move_selected(move_id: StringName, phase_index: int)

@export var phase_health_thresholds: PackedFloat32Array = PackedFloat32Array([0.66, 0.33])
@export var phase_move_sets: Array[BossMoveSet] = []
@export var allow_repeating_moves: bool = false

var current_phase: int = 0
var _last_selected_move_id: StringName = &""

func _ready() -> void:
	super._ready()
	_normalize_phase_thresholds()
	_update_phase(true)

func take_damage(amount: float, source: Variant = null) -> void:
	if is_dead():
		return

	super.take_damage(amount, source)
	if not is_dead():
		_update_phase(false)

func request_next_boss_move() -> BossMove:
	var move_set: BossMoveSet = _get_current_move_set()
	if move_set == null or move_set.moves.is_empty():
		return null

	var candidates: Array[BossMove] = []
	for move in move_set.moves:
		if move == null:
			continue
		if not allow_repeating_moves and move_set.moves.size() > 1 and _last_selected_move_id != &"" and move.move_id == _last_selected_move_id:
			continue
		candidates.append(move)

	if candidates.is_empty():
		for move in move_set.moves:
			if move != null:
				candidates.append(move)

	if candidates.is_empty():
		return null

	var total_weight: float = 0.0
	for move in candidates:
		total_weight += maxf(0.01, move.weight)

	var pick: float = randf() * total_weight
	for move in candidates:
		pick -= maxf(0.01, move.weight)
		if pick <= 0.0:
			_last_selected_move_id = move.move_id
			boss_move_selected.emit(move.move_id, current_phase)
			return move

	var fallback: BossMove = candidates[candidates.size() - 1]
	_last_selected_move_id = fallback.move_id
	boss_move_selected.emit(fallback.move_id, current_phase)
	return fallback

func _get_current_move_set() -> BossMoveSet:
	if phase_move_sets.is_empty():
		return null
	var index: int = mini(current_phase, phase_move_sets.size() - 1)
	return phase_move_sets[index]

func _update_phase(force_emit: bool) -> void:
	if is_dead() or _max_health <= 0.0:
		return

	var health_ratio: float = clampf(current_health / _max_health, 0.0, 1.0)
	var new_phase: int = 0
	for threshold in phase_health_thresholds:
		if health_ratio <= threshold:
			new_phase += 1

	if not force_emit and new_phase == current_phase:
		return

	current_phase = new_phase
	var move_set_id: StringName = &""
	var move_set: BossMoveSet = _get_current_move_set()
	if move_set != null:
		move_set_id = move_set.set_id
	phase_changed.emit(current_phase, health_ratio, move_set_id)

func _normalize_phase_thresholds() -> void:
	var normalized: Array[float] = []
	for threshold in phase_health_thresholds:
		normalized.append(clampf(float(threshold), 0.0, 1.0))

	normalized.sort()
	normalized.reverse()
	phase_health_thresholds = PackedFloat32Array(normalized)
