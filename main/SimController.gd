extends Node
class_name SimController

signal paused_changed(paused: bool)
signal speed_changed(multiplier: float)
signal state_changed(text: String)

const SPEED_NORMAL: float = 1.0
const SPEED_FAST: float = 2.0

var is_paused: bool = false
var speed_multiplier: float = SPEED_NORMAL

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_unhandled_input(true)
	_apply_state()
	_emit_state_changed()

func _unhandled_input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null:
		return
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_P:
		toggle_pause()
	elif key_event.keycode == KEY_T:
		toggle_speed()

func toggle_pause() -> void:
	set_paused(not is_paused)

func toggle_speed() -> void:
	if speed_multiplier == SPEED_FAST:
		set_speed_multiplier(SPEED_NORMAL)
	else:
		set_speed_multiplier(SPEED_FAST)

func set_paused(value: bool) -> void:
	if is_paused == value:
		return
	is_paused = value
	_apply_state()
	paused_changed.emit(is_paused)
	_emit_state_changed()

func set_speed_multiplier(value: float) -> void:
	var clamped_value: float = value
	if clamped_value <= 0.0:
		clamped_value = SPEED_NORMAL
	if speed_multiplier == clamped_value:
		return
	speed_multiplier = clamped_value
	_apply_state()
	speed_changed.emit(speed_multiplier)
	_emit_state_changed()

func get_status_text() -> String:
	if is_paused:
		return "PAUSED"
	if speed_multiplier >= SPEED_FAST:
		return "2x"
	return "1x"

func _apply_state() -> void:
	get_tree().paused = is_paused
	Engine.time_scale = speed_multiplier

func _emit_state_changed() -> void:
	state_changed.emit(get_status_text())
