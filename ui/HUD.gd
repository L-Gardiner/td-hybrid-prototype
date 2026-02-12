extends Control
class_name HUD

signal start_wave_pressed

@onready var gold_label: Label = $GoldLabel
@onready var base_hp_label: Label = $BaseHpLabel
@onready var wave_label: Label = $WaveLabel
@onready var start_wave_button: Button = $StartWaveButton
@onready var sim_status_label: Label = $SimStatusLabel
@onready var next_wave_panel: Control = $NextWavePanel
@onready var next_wave_number: Label = $NextWavePanel/NextWaveVBox/NextWaveNumber
@onready var next_wave_status: Label = $NextWavePanel/NextWaveVBox/NextWaveStatus
@onready var next_wave_entries: Label = $NextWavePanel/NextWaveVBox/NextWaveEntries

func _ready() -> void:
    if start_wave_button:
        start_wave_button.pressed.connect(_on_start_wave_button_pressed)

func _on_start_wave_button_pressed() -> void:
    start_wave_pressed.emit()

func set_gold(value: int) -> void:
    if gold_label:
        gold_label.text = "Gold: %d" % value

func set_base_hp(value: int) -> void:
    if base_hp_label:
        base_hp_label.text = "Base HP: %d" % value

func set_wave_label(text: String) -> void:
    if wave_label:
        wave_label.text = text

func set_start_wave_enabled(enabled: bool) -> void:
    if start_wave_button:
        start_wave_button.disabled = not enabled

func set_sim_status(text: String) -> void:
    if sim_status_label:
        sim_status_label.text = text

func set_next_wave_preview(preview: Dictionary) -> void:
    if next_wave_panel == null:
        return
    if preview.is_empty():
        next_wave_number.text = "Wave ?/?"
        next_wave_status.text = "Unknown"
        next_wave_entries.text = ""
        return
    var total_waves: int = int(preview.get("total_wave_count", 0))
    var next_number: int = int(preview.get("next_wave_number", 0))
    if next_wave_number != null:
        next_wave_number.text = "Wave %d/%d" % [next_number, total_waves]
    var status_text: String = ""
    if bool(preview.get("in_progress", false)):
        status_text = "Wave in progress..."
    var message: String = str(preview.get("message", ""))
    if message != "":
        status_text = message
    if next_wave_status != null:
        next_wave_status.text = status_text
    var preview_type: String = str(preview.get("preview_type", "unknown"))
    var entries: Array = preview.get("entries", [])
    var lines: Array[String] = []
    if preview_type == WavePreviewHelper.PREVIEW_TYPE_COUNTS:
        for entry in entries:
            if entry is Dictionary:
                var label: String = str(entry.get("label", "Unknown"))
                var count_value: int = int(entry.get("count", 0))
                lines.append("%s ×%d" % [label, count_value])
    elif preview_type == WavePreviewHelper.PREVIEW_TYPE_WEIGHTS:
        for entry in entries:
            if entry is Dictionary:
                var weight_label: String = str(entry.get("label", "Unknown"))
                var percent_value: float = float(entry.get("percent", 0.0))
                lines.append("%s %d%%" % [weight_label, int(round(percent_value))])
    elif preview_type == WavePreviewHelper.PREVIEW_TYPE_NONE:
        lines = []
    else:
        if message == "":
            status_text = "Unknown"
            if next_wave_status != null:
                next_wave_status.text = status_text
    if next_wave_entries != null:
        next_wave_entries.text = "\n".join(lines)
