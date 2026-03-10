extends Node

const BUS_MASTER: StringName = &"Master"
const BUS_MUSIC: StringName = &"Music"
const BUS_SFX: StringName = &"SFX"
const BUS_UI: StringName = &"UI"

const MIN_VOLUME_DB: float = -80.0
const DEFAULT_MUSIC_FADE_SECONDS: float = 0.6
const SCENE_MUSIC_POLL_SECONDS: float = 0.2

const AUDIO_EXTENSIONS: PackedStringArray = [".ogg", ".wav", ".mp3"]

const SCENE_MUSIC_TRACKS: Dictionary = {
	"res://scenes/world/world.tscn": &"world_theme",
	"res://scenes/levels/introLevel.tscn": &"intro_level_theme",
}

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _music_player_a: AudioStreamPlayer
var _music_player_b: AudioStreamPlayer
var _active_music_player: AudioStreamPlayer
var _inactive_music_player: AudioStreamPlayer
var _music_tween: Tween
var _current_music_track_id: StringName = StringName()
var _current_scene_path: String = ""
var _scene_music_poll_timer: float = 0.0
var _resolved_streams: Dictionary = {}
var _cooldown_deadlines: Dictionary = {}
var _missing_audio_reports: Dictionary = {}
var _sfx_specs: Dictionary = {}
var _music_specs: Dictionary = {}

func _ready() -> void:
	_rng.randomize()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sfx_specs = _build_sfx_specs()
	_music_specs = _build_music_specs()
	_ensure_audio_buses()
	_setup_music_players()
	_sync_scene_music(true)

func _process(delta: float) -> void:
	_scene_music_poll_timer = maxf(_scene_music_poll_timer - delta, 0.0)
	if _scene_music_poll_timer > 0.0:
		return
	_scene_music_poll_timer = SCENE_MUSIC_POLL_SECONDS
	_sync_scene_music(false)

func play_music(track_id: StringName, fade_time: float = DEFAULT_MUSIC_FADE_SECONDS, restart_if_same: bool = false) -> bool:
	if track_id == StringName():
		stop_music(fade_time)
		return false

	var spec: Dictionary = _music_specs.get(track_id, {})
	if spec.is_empty():
		_report_missing_once("music_spec:%s" % String(track_id), "AudioManager missing music spec for %s" % String(track_id))
		return false

	var stream: AudioStream = _pick_stream(track_id, spec)
	if stream == null:
		return false

	if not restart_if_same and _current_music_track_id == track_id and _active_music_player != null and _active_music_player.playing and _active_music_player.stream == stream:
		return false

	_cancel_music_tween()

	var target_volume_db: float = float(spec.get("volume_db", -8.0))
	var bus_name: StringName = StringName(String(spec.get("bus", BUS_MUSIC)))
	var previous_player: AudioStreamPlayer = _active_music_player
	var next_player: AudioStreamPlayer = _inactive_music_player
	if next_player == null:
		return false

	next_player.stop()
	next_player.stream = stream
	next_player.bus = String(bus_name)
	next_player.volume_db = MIN_VOLUME_DB
	next_player.pitch_scale = 1.0
	next_player.play()

	_current_music_track_id = track_id

	if previous_player == null or not previous_player.playing or fade_time <= 0.0:
		if previous_player != null and previous_player != next_player:
			previous_player.stop()
			previous_player.volume_db = MIN_VOLUME_DB
		next_player.volume_db = target_volume_db
		_set_active_music_player(next_player)
		return true

	_music_tween = create_tween()
	_music_tween.tween_property(previous_player, "volume_db", MIN_VOLUME_DB, fade_time)
	_music_tween.parallel().tween_property(next_player, "volume_db", target_volume_db, fade_time)
	_music_tween.finished.connect(_on_music_crossfade_finished.bind(previous_player, next_player), CONNECT_ONE_SHOT)
	return true

func stop_music(fade_time: float = DEFAULT_MUSIC_FADE_SECONDS) -> void:
	_current_music_track_id = StringName()
	_cancel_music_tween()

	if _active_music_player == null or not _active_music_player.playing:
		_stop_all_music_players()
		return

	if fade_time <= 0.0:
		_stop_all_music_players()
		return

	var stopping_player: AudioStreamPlayer = _active_music_player
	_music_tween = create_tween()
	_music_tween.tween_property(stopping_player, "volume_db", MIN_VOLUME_DB, fade_time)
	_music_tween.finished.connect(_on_music_stop_finished.bind(stopping_player), CONNECT_ONE_SHOT)

func play_sfx(cue_id: StringName, emitter: Node = null, options: Dictionary = {}) -> Node:
	var spec: Dictionary = _sfx_specs.get(cue_id, {})
	if spec.is_empty():
		_report_missing_once("sfx_spec:%s" % String(cue_id), "AudioManager missing SFX spec for %s" % String(cue_id))
		return null

	if _is_on_cooldown(cue_id, spec, emitter):
		return null

	var stream: AudioStream = _pick_stream(cue_id, spec)
	if stream == null:
		return null

	var parent_node: Node = self
	if emitter != null and emitter.is_inside_tree():
		parent_node = emitter
	elif get_tree() != null and get_tree().current_scene != null:
		parent_node = get_tree().current_scene

	var use_positional: bool = bool(spec.get("positional", false))
	var bus_name: StringName = StringName(String(options.get("bus", String(spec.get("bus", BUS_SFX)))))
	var volume_db: float = float(spec.get("volume_db", 0.0))
	volume_db += _rng.randf_range(-float(spec.get("volume_variance_db", 0.0)), float(spec.get("volume_variance_db", 0.0)))
	volume_db += float(options.get("volume_db", 0.0))

	var pitch_min: float = float(spec.get("pitch_min", 1.0))
	var pitch_max: float = float(spec.get("pitch_max", 1.0))
	var pitch_scale: float = _rng.randf_range(minf(pitch_min, pitch_max), maxf(pitch_min, pitch_max))
	pitch_scale *= float(options.get("pitch_scale", 1.0))

	if use_positional:
		var positional_player := AudioStreamPlayer2D.new()
		positional_player.name = "Sfx_%s" % String(cue_id)
		positional_player.stream = stream
		positional_player.bus = String(bus_name)
		positional_player.volume_db = volume_db
		positional_player.pitch_scale = pitch_scale
		parent_node.add_child(positional_player)
		if options.has("global_position"):
			var global_position_value: Variant = options.get("global_position")
			if global_position_value is Vector2:
				positional_player.top_level = true
				positional_player.global_position = global_position_value as Vector2
		positional_player.finished.connect(positional_player.queue_free, CONNECT_ONE_SHOT)
		positional_player.play()
		_set_cooldown_deadline(cue_id, spec, emitter)
		return positional_player

	var player := AudioStreamPlayer.new()
	player.name = "Sfx_%s" % String(cue_id)
	player.stream = stream
	player.bus = String(bus_name)
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	parent_node.add_child(player)
	player.finished.connect(player.queue_free, CONNECT_ONE_SHOT)
	player.play()
	_set_cooldown_deadline(cue_id, spec, emitter)
	return player

func set_bus_volume_db(bus_name: StringName, volume_db: float) -> void:
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		return
	AudioServer.set_bus_volume_db(bus_index, volume_db)

func _sync_scene_music(force: bool) -> void:
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return

	var scene_path: String = tree.current_scene.scene_file_path
	if scene_path.is_empty():
		return
	if not force and scene_path == _current_scene_path:
		return

	_current_scene_path = scene_path
	var mapped_track: Variant = SCENE_MUSIC_TRACKS.get(scene_path, null)
	if mapped_track is StringName:
		play_music(mapped_track as StringName)

func _setup_music_players() -> void:
	_music_player_a = AudioStreamPlayer.new()
	_music_player_a.name = "MusicPlayerA"
	_music_player_a.bus = String(BUS_MUSIC)
	_music_player_a.volume_db = MIN_VOLUME_DB
	add_child(_music_player_a)

	_music_player_b = AudioStreamPlayer.new()
	_music_player_b.name = "MusicPlayerB"
	_music_player_b.bus = String(BUS_MUSIC)
	_music_player_b.volume_db = MIN_VOLUME_DB
	add_child(_music_player_b)

	_active_music_player = _music_player_a
	_inactive_music_player = _music_player_b

func _ensure_audio_buses() -> void:
	_ensure_audio_bus(BUS_MUSIC, BUS_MASTER, -8.0)
	_ensure_audio_bus(BUS_SFX, BUS_MASTER, -1.5)
	_ensure_audio_bus(BUS_UI, BUS_MASTER, -3.0)

func _ensure_audio_bus(bus_name: StringName, send_bus_name: StringName, default_volume_db: float) -> void:
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		AudioServer.add_bus(AudioServer.bus_count)
		bus_index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus_index, bus_name)
	AudioServer.set_bus_send(bus_index, send_bus_name)
	AudioServer.set_bus_volume_db(bus_index, default_volume_db)

func _set_active_music_player(active_player: AudioStreamPlayer) -> void:
	_active_music_player = active_player
	_inactive_music_player = _music_player_a if active_player == _music_player_b else _music_player_b

func _cancel_music_tween() -> void:
	if _music_tween != null and is_instance_valid(_music_tween):
		_music_tween.kill()
	_music_tween = null

func _on_music_crossfade_finished(previous_player: AudioStreamPlayer, next_player: AudioStreamPlayer) -> void:
	if previous_player != null:
		previous_player.stop()
		previous_player.volume_db = MIN_VOLUME_DB
	_set_active_music_player(next_player)
	_music_tween = null

func _on_music_stop_finished(stopping_player: AudioStreamPlayer) -> void:
	if stopping_player != null:
		stopping_player.stop()
		stopping_player.volume_db = MIN_VOLUME_DB
	_music_tween = null

func _stop_all_music_players() -> void:
	for player in [_music_player_a, _music_player_b]:
		if player == null:
			continue
		player.stop()
		player.volume_db = MIN_VOLUME_DB

func _is_on_cooldown(cue_id: StringName, spec: Dictionary, emitter: Node) -> bool:
	var cooldown_seconds: float = float(spec.get("cooldown_seconds", 0.0))
	if cooldown_seconds <= 0.0:
		return false
	var cooldown_key: String = _build_cooldown_key(cue_id, emitter)
	var deadline: float = float(_cooldown_deadlines.get(cooldown_key, 0.0))
	return Time.get_ticks_msec() * 0.001 < deadline

func _set_cooldown_deadline(cue_id: StringName, spec: Dictionary, emitter: Node) -> void:
	var cooldown_seconds: float = float(spec.get("cooldown_seconds", 0.0))
	if cooldown_seconds <= 0.0:
		return
	var cooldown_key: String = _build_cooldown_key(cue_id, emitter)
	_cooldown_deadlines[cooldown_key] = Time.get_ticks_msec() * 0.001 + cooldown_seconds

func _build_cooldown_key(cue_id: StringName, emitter: Node) -> String:
	if emitter == null:
		return String(cue_id)
	return "%s:%d" % [String(cue_id), emitter.get_instance_id()]

func _pick_stream(audio_id: StringName, spec: Dictionary) -> AudioStream:
	var available_streams: Array = _load_discovered_streams(spec)
	if available_streams.is_empty():
		_report_missing_once("audio_stream:%s" % String(audio_id), "AudioManager found no audio files for %s in %s" % [String(audio_id), String(spec.get("folder", ""))])
		return null
	var stream_index: int = _rng.randi_range(0, available_streams.size() - 1)
	var stream_value: Variant = available_streams[stream_index]
	if stream_value is AudioStream:
		return stream_value as AudioStream
	return null

func _load_discovered_streams(spec: Dictionary) -> Array:
	var folder: String = String(spec.get("folder", ""))
	var prefix: String = String(spec.get("prefix", ""))
	var cache_key: String = "%s|%s" % [folder, prefix]
	var cached_streams: Variant = _resolved_streams.get(cache_key, null)
	if cached_streams is Array:
		return cached_streams

	var discovered_paths: Array[String] = []
	var directory: DirAccess = DirAccess.open(folder)
	if directory == null:
		_resolved_streams[cache_key] = []
		return []

	directory.list_dir_begin()
	while true:
		var file_name: String = directory.get_next()
		if file_name.is_empty():
			break
		if directory.current_is_dir():
			continue
		if file_name.ends_with(".import"):
			continue
		var lower_name: String = file_name.to_lower()
		var is_audio_file: bool = false
		for extension in AUDIO_EXTENSIONS:
			if lower_name.ends_with(extension):
				is_audio_file = true
				break
		if not is_audio_file:
			continue
		if not lower_name.begins_with(prefix.to_lower()):
			continue
		discovered_paths.append("%s/%s" % [folder, file_name])
	directory.list_dir_end()

	discovered_paths.sort()
	var discovered_streams: Array = []
	for audio_path in discovered_paths:
		var stream_resource: Resource = load(audio_path)
		if stream_resource is AudioStream:
			discovered_streams.append(stream_resource)

	_resolved_streams[cache_key] = discovered_streams
	return discovered_streams

func _report_missing_once(report_key: String, message: String) -> void:
	if _missing_audio_reports.get(report_key, false):
		return
	_missing_audio_reports[report_key] = true
	push_warning(message)

func _build_sfx_specs() -> Dictionary:
	return {
		&"player_jump": _make_sfx_spec("res://assets/audio/sfx/player", "player_jump_", BUS_SFX, -5.0, 0.75, 0.98, 1.03, 0.0, true),
		&"player_dash": _make_sfx_spec("res://assets/audio/sfx/player", "player_dash_", BUS_SFX, -3.0, 0.5, 0.96, 1.02, 0.05, true),
		&"player_swing": _make_sfx_spec("res://assets/audio/sfx/player", "player_swing_", BUS_SFX, -4.0, 1.0, 0.94, 1.06, 0.03, true),
		&"player_hit_confirm": _make_sfx_spec("res://assets/audio/sfx/player", "player_hit_confirm_", BUS_SFX, -2.0, 0.5, 0.98, 1.02, 0.02, true),
		&"player_defend_queue": _make_sfx_spec("res://assets/audio/sfx/player", "player_defend_queue_", BUS_SFX, -4.0, 0.5, 0.99, 1.01, 0.02, true),
		&"player_defend_block": _make_sfx_spec("res://assets/audio/sfx/player", "player_defend_block_", BUS_SFX, -2.5, 0.5, 0.98, 1.02, 0.02, true),
		&"player_hurt": _make_sfx_spec("res://assets/audio/sfx/player", "player_hurt_", BUS_SFX, -3.5, 0.5, 0.98, 1.02, 0.08, true),
		&"player_death": _make_sfx_spec("res://assets/audio/sfx/player", "player_death_", BUS_SFX, -2.0, 0.0, 1.0, 1.0, 0.0, true),
		&"goblin_attack": _make_sfx_spec("res://assets/audio/sfx/enemies/goblin", "goblin_attack_", BUS_SFX, -3.0, 0.75, 0.97, 1.03, 0.04, true),
		&"goblin_hurt": _make_sfx_spec("res://assets/audio/sfx/enemies/goblin", "goblin_hurt_", BUS_SFX, -3.0, 0.5, 0.98, 1.02, 0.06, true),
		&"goblin_death": _make_sfx_spec("res://assets/audio/sfx/enemies/goblin", "goblin_death_", BUS_SFX, -1.5, 0.0, 1.0, 1.0, 0.0, true),
		&"ui_confirm": _make_sfx_spec("res://assets/audio/sfx/ui", "ui_confirm_", BUS_UI, -4.0, 0.5, 0.99, 1.01, 0.02, false),
		&"ui_back": _make_sfx_spec("res://assets/audio/sfx/ui", "ui_back_", BUS_UI, -4.0, 0.5, 0.99, 1.01, 0.02, false),
		&"ui_pause": _make_sfx_spec("res://assets/audio/sfx/ui", "ui_pause_", BUS_UI, -4.0, 0.5, 0.99, 1.01, 0.02, false),
	}

func _build_music_specs() -> Dictionary:
	return {
		&"world_theme": _make_music_spec("res://assets/audio/music", "world_theme_", BUS_MUSIC, -10.0),
		&"intro_level_theme": _make_music_spec("res://assets/audio/music", "intro_level_theme_", BUS_MUSIC, -10.5),
		&"dungreed_level_theme": _make_music_spec("res://assets/audio/music", "dungreed_level_theme_", BUS_MUSIC, -9.0),
	}

func _make_sfx_spec(folder: String, prefix: String, bus_name: StringName, volume_db: float, volume_variance_db: float, pitch_min: float, pitch_max: float, cooldown_seconds: float, positional: bool) -> Dictionary:
	return {
		"folder": folder,
		"prefix": prefix,
		"bus": bus_name,
		"volume_db": volume_db,
		"volume_variance_db": volume_variance_db,
		"pitch_min": pitch_min,
		"pitch_max": pitch_max,
		"cooldown_seconds": cooldown_seconds,
		"positional": positional,
	}

func _make_music_spec(folder: String, prefix: String, bus_name: StringName, volume_db: float) -> Dictionary:
	return {
		"folder": folder,
		"prefix": prefix,
		"bus": bus_name,
		"volume_db": volume_db,
	}
