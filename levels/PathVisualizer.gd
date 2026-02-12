extends Node2D
class_name PathVisualizer

@export var path_node: Path2D
@export var line_color: Color = Color(0.2, 0.9, 1.0, 0.7)
@export var line_width: float = 3.0

@onready var line: Line2D = $Line2D

func _ready() -> void:
	_update_line()

func _process(delta: float) -> void:
	_update_line()

func _update_line() -> void:
	if line == null:
		return
	var path := path_node
	if path == null and get_parent() is Path2D:
		path = get_parent() as Path2D
	if path == null:
		line.clear_points()
		return
	var curve := path.curve
	if curve == null or curve.point_count < 2:
		line.clear_points()
		return
	line.default_color = line_color
	line.width = line_width
	line.clear_points()
	for i in range(curve.point_count):
		line.add_point(curve.get_point_position(i))
