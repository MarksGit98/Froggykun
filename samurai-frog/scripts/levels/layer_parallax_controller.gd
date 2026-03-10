extends Node2D

@export_group("Layer Paths")
@export_node_path("Node2D") var background_path: NodePath = ^"TileMap/Background"
@export_node_path("Node2D") var middleground_path: NodePath = ^"TileMap/Middleground"
@export_node_path("Node2D") var foreground_path: NodePath

@export_group("Parallax Strength")
@export var background_strength: Vector2 = Vector2(0.10, 0.02)
@export var middleground_strength: Vector2 = Vector2(0.28, 0.06)
@export var foreground_strength: Vector2 = Vector2(0.46, 0.10)

@export_group("Camera")
@export var auto_find_active_camera: bool = true
@export_node_path("Camera2D") var camera_path: NodePath

var _camera: Camera2D
var _camera_origin: Vector2 = Vector2.ZERO
var _layers: Array[Node2D] = []
var _layer_origins: Array[Vector2] = []
var _layer_strengths: Array[Vector2] = []

func _ready() -> void:
	_cache_layers()
	_rebind_camera()
	_apply_parallax()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return

	var active_camera := _resolve_camera()
	if active_camera == null:
		return

	if active_camera != _camera:
		_camera = active_camera
		_camera_origin = _camera.global_position
		_capture_current_layer_origins()
		return

	_apply_parallax()

func _cache_layers() -> void:
	_layers.clear()
	_layer_origins.clear()
	_layer_strengths.clear()

	_add_layer(background_path, background_strength, "Background")
	_add_layer(middleground_path, middleground_strength, "Middleground")
	_add_layer(foreground_path, foreground_strength, "Foreground")

func _add_layer(path: NodePath, strength: Vector2, label: String) -> void:
	if path.is_empty():
		return

	var layer := get_node_or_null(path) as Node2D
	if layer == null:
		push_warning("LayerParallaxController: %s path '%s' is invalid." % [label, path])
		return

	_layers.append(layer)
	_layer_origins.append(layer.position)
	_layer_strengths.append(strength)

func _rebind_camera() -> void:
	_camera = _resolve_camera()
	if _camera != null:
		_camera_origin = _camera.global_position

func _resolve_camera() -> Camera2D:
	if not camera_path.is_empty():
		var configured_camera := get_node_or_null(camera_path) as Camera2D
		if configured_camera != null:
			return configured_camera

	if auto_find_active_camera:
		return get_viewport().get_camera_2d()

	return null

func _capture_current_layer_origins() -> void:
	for i in range(_layers.size()):
		var layer := _layers[i]
		if is_instance_valid(layer):
			_layer_origins[i] = layer.position

func _apply_parallax() -> void:
	if _camera == null:
		return

	var camera_delta := _camera.global_position - _camera_origin
	for i in range(_layers.size()):
		var layer := _layers[i]
		if not is_instance_valid(layer):
			continue
		layer.position = _layer_origins[i] + (camera_delta * _layer_strengths[i])