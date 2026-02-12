extends Control
class_name BuildPopup

signal tower_selected(tower_id: String)
signal request_close

@onready var container: Control = $VBoxContainer
@onready var basic_button: Button = $VBoxContainer/BasicButton
@onready var splash_button: Button = $VBoxContainer/SplashButton

func _ready() -> void:
	set_process_unhandled_input(true)
	if basic_button:
		basic_button.pressed.connect(_on_basic_button_pressed)
	if splash_button:
		splash_button.pressed.connect(_on_splash_button_pressed)

func open_at(screen_position: Vector2) -> void:
	global_position = screen_position
	visible = true

func close() -> void:
	visible = false

func configure_towers(basic_cost: int, can_afford_basic: bool, splash_cost: int, can_afford_splash: bool) -> void:
	_configure_button(basic_button, "Build Basic Tower", basic_cost, can_afford_basic)
	_configure_button(splash_button, "Build Splash Tower", splash_cost, can_afford_splash)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		request_close.emit()
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			request_close.emit()
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			var rect: Rect2 = get_global_rect()
			if container:
				rect = container.get_global_rect()
			if not rect.has_point(event.position):
				request_close.emit()

func _on_basic_button_pressed() -> void:
	tower_selected.emit("basic")
	request_close.emit()

func _on_splash_button_pressed() -> void:
	tower_selected.emit("splash")
	request_close.emit()

func _configure_button(button: Button, label: String, cost: int, can_afford: bool) -> void:
	if button == null:
		return
	button.text = "%s (cost %d)" % [label, cost]
	button.disabled = not can_afford
