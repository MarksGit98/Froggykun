extends State

class_name DefendState

const AnimationConstants = preload("res://scripts/constants/animation_constants.gd")

const QUEUE_DEFEND_ANIMATION: StringName = AnimationConstants.PLAYER_DEFEND_QUEUE
const DEFEND_ANIMATION: StringName = AnimationConstants.PLAYER_DEFEND_SUCCESS
const QUEUE_DEFEND_FALLBACK_SECONDS: float = 0.6
const DEFEND_FALLBACK_SECONDS: float = 0.25

@export var grounded_state: State
@export var falling_state: State
@export var attacking_state: State

var _queue_defense_finished: bool = false
var _defend_animation_started: bool = false
var _queue_defense_timer: float = 0.0
var _defend_animation_timer: float = 0.0

func on_enter() -> void:
	_queue_defense_finished = false
	_defend_animation_started = false
	_queue_defense_timer = _resolve_animation_length(QUEUE_DEFEND_ANIMATION, QUEUE_DEFEND_FALLBACK_SECONDS)
	_defend_animation_timer = 0.0
	can_move = _resolve_source_can_move()
	_debug_defend("on_enter source=%s queue_timer=%.3f can_move=%s" % [_resolve_source_state_name(), _queue_defense_timer, str(can_move)])

func state_process(delta: float) -> void:
	if not _queue_defense_finished:
		if _consume_animation_started(DEFEND_ANIMATION):
			_queue_defense_finished = true
			_defend_animation_started = true
			_defend_animation_timer = _resolve_animation_length(DEFEND_ANIMATION, DEFEND_FALLBACK_SECONDS)
			_debug_defend("defend animation started via animation-tree player_hit transition timer=%.3f" % _defend_animation_timer)
			return

		_queue_defense_timer = maxf(_queue_defense_timer - delta, 0.0)
		var queue_finished_by_signal: bool = _consume_animation_finished(QUEUE_DEFEND_ANIMATION)
		if queue_finished_by_signal or _queue_defense_timer <= 0.0:
			_queue_defense_finished = true
			_debug_defend("queue_defense complete signal=%s timer=%.3f" % [str(queue_finished_by_signal), _queue_defense_timer])
			_start_defend_cooldown_if_available()
			_route_after_queue_defense_finished()
		return

	if not _defend_animation_started:
		# Guard in case defend starts right after queue finished branch.
		if _consume_animation_started(DEFEND_ANIMATION):
			_defend_animation_started = true
			_defend_animation_timer = _resolve_animation_length(DEFEND_ANIMATION, DEFEND_FALLBACK_SECONDS)
			_debug_defend("defend animation started after queue branch timer=%.3f" % _defend_animation_timer)
			return
		_debug_defend("state_process no defend animation active -> route after queue")
		_route_after_queue_defense_finished()
		return

	_defend_animation_timer = maxf(_defend_animation_timer - delta, 0.0)
	var defend_finished_by_signal: bool = _consume_animation_finished(DEFEND_ANIMATION)
	if defend_finished_by_signal or _defend_animation_timer <= 0.0:
		_debug_defend("defend animation complete signal=%s timer=%.3f" % [str(defend_finished_by_signal), _defend_animation_timer])
		_apply_defend_counter_knockback_if_available()
		_route_after_successful_defend()

func on_exit() -> void:
	_debug_defend("on_exit queue_finished=%s defend_started=%s next=%s" % [str(_queue_defense_finished), str(_defend_animation_started), _get_next_state_name()])
	_queue_defense_finished = false
	_defend_animation_started = false
	_queue_defense_timer = 0.0
	_defend_animation_timer = 0.0
	if character != null and character.has_method("clear_defend_state"):
		character.call("clear_defend_state")

func _consume_animation_started(animation_name: StringName) -> bool:
	if character == null or not character.has_method("consume_started_animation"):
		return false
	var started_value: Variant = character.call("consume_started_animation", animation_name)
	if started_value is bool:
		return bool(started_value)
	return false

func _consume_animation_finished(animation_name: StringName) -> bool:
	if character == null or not character.has_method("consume_finished_animation"):
		return false
	var finished_value: Variant = character.call("consume_finished_animation", animation_name)
	if finished_value is bool:
		return bool(finished_value)
	return false

func _apply_defend_counter_knockback_if_available() -> void:
	if character != null and character.has_method("apply_defend_counter_knockback"):
		character.call("apply_defend_counter_knockback")

func _start_defend_cooldown_if_available() -> void:
	if character != null and character.has_method("start_defend_cooldown"):
		character.call("start_defend_cooldown")

func _resolve_animation_length(animation_name: StringName, fallback_seconds: float) -> float:
	if character != null and character.has_method("get_animation_length"):
		var length_value: Variant = character.call("get_animation_length", animation_name)
		if length_value is float:
			var resolved_length: float = float(length_value)
			if resolved_length > 0.0:
				return resolved_length
		if length_value is int:
			var resolved_length_int: float = float(length_value)
			if resolved_length_int > 0.0:
				return resolved_length_int
	return fallback_seconds

func _route_after_queue_defense_finished() -> void:
	var source_state_name: StringName = _resolve_source_state_name()
	if _has_floor_contact() and grounded_state != null:
		_debug_defend("route_after_queue -> Grounded source=%s" % String(source_state_name))
		next_state = grounded_state
		return
	if playback != null:
		playback.start(AnimationConstants.PLAYER_FALL)
	if falling_state != null:
		_debug_defend("route_after_queue -> Falling source=%s" % String(source_state_name))
		next_state = falling_state

func _route_after_successful_defend() -> void:
	if _has_floor_contact() and grounded_state != null:
		_debug_defend("route_after_success -> Grounded")
		next_state = grounded_state
		return
	if playback != null:
		playback.start(AnimationConstants.PLAYER_FALL)
	if falling_state != null:
		_debug_defend("route_after_success -> Falling")
		next_state = falling_state

func _has_floor_contact() -> bool:
	if character == null:
		return false
	var has_floor_contact: bool = character.is_on_floor()
	if character.has_method("has_stable_floor_contact"):
		var floor_value: Variant = character.call("has_stable_floor_contact")
		if floor_value is bool:
			has_floor_contact = bool(floor_value)
	return has_floor_contact

func _resolve_source_state_name() -> StringName:
	if character != null and character.has_method("get_defend_source_state_name"):
		var source_value: Variant = character.call("get_defend_source_state_name")
		if source_value is StringName:
			return source_value as StringName
		if typeof(source_value) == TYPE_STRING:
			return StringName(String(source_value))
	return StringName()

func _resolve_source_can_move() -> bool:
	var source_state_name: StringName = _resolve_source_state_name()
	if source_state_name == AnimationConstants.PLAYER_STATE_ATTACKING and attacking_state != null:
		return attacking_state.can_move
	if source_state_name == AnimationConstants.PLAYER_STATE_GROUNDED and grounded_state != null:
		return grounded_state.can_move
	if source_state_name == AnimationConstants.PLAYER_STATE_FALLING and falling_state != null:
		return falling_state.can_move
	return true

func _get_next_state_name() -> String:
	if next_state == null:
		return "None"
	return next_state.name

func _debug_defend(message: String) -> void:
	if character != null and character.has_method("debug_attack_log"):
		character.call("debug_attack_log", "DefendState: %s" % message)
