extends CharacterBody2D
class_name Player

signal request_build_menu(build_spot: BuildSpot)
signal build_spot_out_of_range(build_spot: BuildSpot)
@export var move_speed: float = 180.0
@export var body_radius: float = 10.0
@export var body_color: Color = Color(0.9, 0.95, 1.0, 1.0)
@export var proximity_radius: float = 30.0

@onready var proximity_area: Area2D = $ProximityArea
@onready var proximity_shape: CollisionShape2D = $ProximityArea/CollisionShape2D

var session: GameSession
var nearby_spots: Array[BuildSpot] = []

func _ready() -> void:
	_ensure_input_actions()
	add_to_group("player")
	_sync_proximity_shape()
	if proximity_area:
		proximity_area.monitoring = true
		proximity_area.collision_layer = 0
		proximity_area.collision_mask = 1
		proximity_area.area_entered.connect(_on_proximity_area_entered)
		proximity_area.area_exited.connect(_on_proximity_area_exited)
	queue_redraw()

func _physics_process(delta: float) -> void:
	var input_vector := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	if input_vector.length_squared() > 1.0:
		input_vector = input_vector.normalized()
	velocity = input_vector * move_speed
	move_and_slide()

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("open_build_menu"):
		var spot: BuildSpot = _get_nearest_build_spot(true)
		request_build_menu.emit(spot)

func _get_nearest_build_spot(include_occupied: bool) -> BuildSpot:
	var best: BuildSpot = null
	var best_distance: float = INF
	for spot: BuildSpot in nearby_spots:
		if spot == null:
			continue
		if not include_occupied and spot.occupied:
			continue
		var distance: float = global_position.distance_squared_to(spot.global_position)
		if distance < best_distance:
			best_distance = distance
			best = spot
	return best

func _on_proximity_area_entered(area: Area2D) -> void:
	var spot: BuildSpot = area as BuildSpot
	if spot == null:
		return
	if not nearby_spots.has(spot):
		nearby_spots.append(spot)
		spot.set_in_range(true)

func _on_proximity_area_exited(area: Area2D) -> void:
	var spot: BuildSpot = area as BuildSpot
	if spot == null:
		return
	nearby_spots.erase(spot)
	spot.set_in_range(false)
	build_spot_out_of_range.emit(spot)

func _sync_proximity_shape() -> void:
	if proximity_shape == null:
		return
	var circle: CircleShape2D = proximity_shape.shape as CircleShape2D
	if circle == null:
		circle = CircleShape2D.new()
		proximity_shape.shape = circle
	circle.radius = max(proximity_radius, 4.0)

func _draw() -> void:
	draw_circle(Vector2.ZERO, body_radius, body_color)

func _ensure_input_actions() -> void:
	_ensure_action("move_up", [KEY_W, KEY_UP])
	_ensure_action("move_down", [KEY_S, KEY_DOWN])
	_ensure_action("move_left", [KEY_A, KEY_LEFT])
	_ensure_action("move_right", [KEY_D, KEY_RIGHT])
	_ensure_action("build_basic", [KEY_1])
	_ensure_action("build_splash", [KEY_2])
	_ensure_action("build_delete", [KEY_3])
	_ensure_action("open_build_menu", [KEY_B])

func _ensure_action(action_name: String, keycodes: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for code in keycodes:
		var event := InputEventKey.new()
		event.keycode = int(code)
		InputMap.action_add_event(action_name, event)
