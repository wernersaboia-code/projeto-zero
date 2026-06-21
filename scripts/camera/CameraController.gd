extends Camera2D
class_name CameraController

const PAN_SPEED: float = 600.0
const ZOOM_MIN: float = 0.05
const ZOOM_MAX: float = 2.0
const ZOOM_STEP: float = 0.1
const EDGE_MARGIN: float = 20.0
const SMOOTHING: float = 8.0

var _target_zoom: float = 0.12
var _target_position: Vector2
var _is_dragging: bool = false
var _drag_start: Vector2
var _drag_start_pos: Vector2

var _last_emit_pos: Vector2 = Vector2(INF, INF)
var _last_emit_zoom: float = -1.0
const _MOVE_THRESHOLD: float = 0.5
const _ZOOM_THRESHOLD: float = 0.001


func _ready() -> void:
	_target_position = position
	zoom = Vector2(_target_zoom, _target_zoom)


func _process(delta: float) -> void:
	_handle_keyboard_pan(delta)
	_handle_edge_pan(delta)
	_smooth_move(delta)
	_emit_camera_update()


func _handle_keyboard_pan(delta: float) -> void:
	var input_dir = Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_dir.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_dir.x += 1

	if input_dir != Vector2.ZERO:
		var speed = PAN_SPEED / _target_zoom
		_target_position += input_dir.normalized() * speed * delta


func _handle_edge_pan(delta: float) -> void:
	var viewport = get_viewport()
	if not viewport:
		return
	var mouse_pos = viewport.get_mouse_position()
	var viewport_size = viewport.get_visible_rect().size
	var edge_dir = Vector2.ZERO

	if mouse_pos.x < EDGE_MARGIN:
		edge_dir.x -= 1
	elif mouse_pos.x > viewport_size.x - EDGE_MARGIN:
		edge_dir.x += 1
	if mouse_pos.y < EDGE_MARGIN:
		edge_dir.y -= 1
	elif mouse_pos.y > viewport_size.y - EDGE_MARGIN:
		edge_dir.y += 1

	if edge_dir != Vector2.ZERO:
		var distance = min(
			min(mouse_pos.x, viewport_size.x - mouse_pos.x),
			min(mouse_pos.y, viewport_size.y - mouse_pos.y)
		)
		var factor = clamp(1.0 - (distance / EDGE_MARGIN), 0.0, 1.0)
		var speed = PAN_SPEED / _target_zoom * factor
		_target_position += edge_dir.normalized() * speed * delta


func _smooth_move(delta: float) -> void:
	position = position.lerp(_target_position, SMOOTHING * delta)
	var current_zoom = zoom.x
	var new_zoom = lerp(current_zoom, _target_zoom, SMOOTHING * delta)
	zoom = Vector2(new_zoom, new_zoom)


func _emit_camera_update() -> void:
	if position.distance_squared_to(_last_emit_pos) < _MOVE_THRESHOLD * _MOVE_THRESHOLD \
			and abs(zoom.x - _last_emit_zoom) < _ZOOM_THRESHOLD:
		return
	_last_emit_pos = position
	_last_emit_zoom = zoom.x
	EventBus.camera_moved.emit(position, zoom.x)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_zoom = min(_target_zoom + ZOOM_STEP, ZOOM_MAX)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_zoom = max(_target_zoom - ZOOM_STEP, ZOOM_MIN)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				_is_dragging = true
				_drag_start = get_viewport().get_mouse_position()
				_drag_start_pos = _target_position
			else:
				_is_dragging = false

	if event is InputEventMouseMotion and _is_dragging:
		var mouse_delta = get_viewport().get_mouse_position() - _drag_start
		_target_position = _drag_start_pos - mouse_delta / _target_zoom


func center_on_world(world_pos: Vector2) -> void:
	_target_position = world_pos
