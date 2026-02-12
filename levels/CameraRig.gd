extends Node2D
class_name CameraRig

@export var min_zoom: float = 0.6
@export var max_zoom: float = 2.0
@export var zoom_step: float = 0.1
@export var pan_speed: float = 1.0
@export var enable_controls: bool = false

@onready var camera: Camera2D = $Camera2D

var dragging: bool = false

func _unhandled_input(event: InputEvent) -> void:
	if not enable_controls:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			dragging = event.pressed
			return
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_apply_zoom(-zoom_step)
			return
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_apply_zoom(zoom_step)
			return
	if event is InputEventMagnifyGesture:
		var delta := 0.0
		if event.factor > 1.0:
			delta = (event.factor - 1.0) * zoom_step
		elif event.factor < 1.0:
			delta = -(1.0 - event.factor) * zoom_step
		if delta != 0.0:
			_apply_zoom(delta)
		return
	if event is InputEventPanGesture:
		var scale := 1.0
		if camera:
			scale = camera.zoom.x
		position -= event.delta * scale * pan_speed
		return
	if event is InputEventMouseMotion and dragging:
		var scale := 1.0
		if camera:
			scale = camera.zoom.x
		position -= event.relative * scale * pan_speed

func _apply_zoom(delta: float) -> void:
	if camera == null:
		return
	var target := camera.zoom.x + delta
	target = clamp(target, min_zoom, max_zoom)
	camera.zoom = Vector2(target, target)
