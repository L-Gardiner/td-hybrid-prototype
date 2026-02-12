extends Area2D
class_name BuildSpot

signal clicked(build_spot: BuildSpot)

var occupied: bool = false
var hovered: bool = false

@export var radius: float = 18.0
@export var base_color: Color = Color(0.2, 0.8, 0.2, 0.6)
@export var hover_color: Color = Color(0.95, 0.85, 0.2, 0.85)
@export var occupied_color: Color = Color(0.5, 0.5, 0.5, 0.6)

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
	draw_circle(Vector2.ZERO, radius, color)

func _on_mouse_entered() -> void:
	hovered = true
	queue_redraw()

func _on_mouse_exited() -> void:
	hovered = false
	queue_redraw()
