extends Control
class_name WinLoseOverlay

signal restart_pressed

@onready var message_label: Label = $MessageLabel
@onready var restart_button: Button = $RestartButton

func _ready() -> void:
	if restart_button:
		restart_button.pressed.connect(_on_restart_button_pressed)

func show_message(text: String) -> void:
	visible = true
	if message_label:
		message_label.text = text

func _on_restart_button_pressed() -> void:
	restart_pressed.emit()
