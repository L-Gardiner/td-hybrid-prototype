extends Area2D
class_name BuildSpot

signal clicked(build_spot: BuildSpot)

var _occupied: bool = false
var occupied: bool:
	set(value):
		if _occupied == value:
			return
		_occupied = value
		queue_redraw()
	get:
		return _occupied
var hovered: bool = false
var in_range: bool = false

@export var radius: float = 18.0
@export var base_color: Color = Color(0.2, 0.8, 0.2, 0.6)
@export var hover_color: Color = Color(0.95, 0.85, 0.2, 0.85)
@export var occupied_color: Color = Color(0.5, 0.5, 0.5, 0.6)
@export var in_range_color: Color = Color(0.2, 0.6, 1.0, 0.8)

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	queue_redraw()

func _input_event(viewport: Viewport, event: InputEvent, shape_idx: int) -> void:
	if occupied:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		clicked.emit(self)

func _draw() -> void:
	var color := base_color
	if occupied:
		color = occupied_color
	elif hovered:
		color = hover_color
	elif in_range:
		color = in_range_color
	draw_circle(Vector2.ZERO, radius, color)
	if in_range:
		draw_arc(Vector2.ZERO, radius + 3.0, 0.0, TAU, 32, in_range_color, 2.0)

func _on_mouse_entered() -> void:
	hovered = true
	queue_redraw()

func _on_mouse_exited() -> void:
	hovered = false
	queue_redraw()

func set_in_range(value: bool) -> void:
	if in_range == value:
		return
	in_range = value
	queue_redraw()
