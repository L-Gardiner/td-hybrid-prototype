extends Control
class_name UpgradePopup

signal upgrade_selected(option_index: int)
signal delete_selected
signal request_close

@onready var container: Control = $VBoxContainer
@onready var option_a_button: Button = $VBoxContainer/OptionAButton
@onready var option_b_button: Button = $VBoxContainer/OptionBButton
@onready var delete_button: Button = $VBoxContainer/DeleteButton

func _ready() -> void:
	set_process_unhandled_input(true)
	if option_a_button:
		option_a_button.pressed.connect(_on_option_a_pressed)
	if option_b_button:
		option_b_button.pressed.connect(_on_option_b_pressed)
	if delete_button:
		delete_button.pressed.connect(_on_delete_pressed)

func open_at(screen_position: Vector2) -> void:
	global_position = screen_position
	visible = true

func close() -> void:
	visible = false

func configure(option_a_label: String, option_a_cost: int, option_a_available: bool, can_afford_a: bool, option_b_label: String, option_b_cost: int, option_b_available: bool, can_afford_b: bool, upgrades_enabled: bool, allow_delete: bool, delete_refund: int) -> void:
	_configure_button(option_a_button, option_a_label, option_a_cost, option_a_available and can_afford_a and upgrades_enabled)
	_configure_button(option_b_button, option_b_label, option_b_cost, option_b_available and can_afford_b and upgrades_enabled)
	if delete_button:
		delete_button.text = "Delete Tower (+%d)" % delete_refund
		delete_button.disabled = not allow_delete

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

func _on_option_a_pressed() -> void:
	upgrade_selected.emit(0)

func _on_option_b_pressed() -> void:
	upgrade_selected.emit(1)

func _on_delete_pressed() -> void:
	delete_selected.emit()

func _configure_button(button: Button, label: String, cost: int, enabled: bool) -> void:
	if button == null:
		return
	button.text = "%s (%d)" % [label, cost]
	button.disabled = not enabled
