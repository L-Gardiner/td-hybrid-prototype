extends Node
class_name GameSessionHarness

@export var level_scene: PackedScene
@export var hud_scene: PackedScene
@export var build_popup_scene: PackedScene
@export var win_lose_overlay_scene: PackedScene

@onready var level_root: Node = $LevelRoot
@onready var ui_layer: CanvasLayer = $UI

var level: Level
var spawner: EnemySpawner
var hud: HUD
var build_popup: BuildPopup
var win_lose_overlay: WinLoseOverlay
var session: GameSession

func _ready() -> void:
	_ensure_audio_manager()
	_spawn_level()
	_spawn_ui()
	_setup_session()

func _ensure_audio_manager() -> void:
	var audio_manager: AudioManager = get_tree().get_first_node_in_group("audio_manager") as AudioManager
	if audio_manager == null:
		var new_audio_manager: AudioManager = AudioManager.new()
		add_child(new_audio_manager)

func _spawn_level() -> void:
	if level_scene == null:
		push_warning("GameSessionHarness: level_scene not set.")
		return
	var level_instance: Level = level_scene.instantiate() as Level
	if level_instance == null:
		push_warning("GameSessionHarness: level_scene instantiation failed.")
		return
	level = level_instance
	level_root.add_child(level_instance)
	spawner = level_instance.get_spawner()
	_connect_build_spots(level_instance)

func _spawn_ui() -> void:
	if hud_scene != null:
		var hud_instance: HUD = hud_scene.instantiate() as HUD
		if hud_instance != null:
			hud = hud_instance
			ui_layer.add_child(hud_instance)
	if build_popup_scene != null:
		var build_popup_instance: BuildPopup = build_popup_scene.instantiate() as BuildPopup
		if build_popup_instance != null:
			build_popup = build_popup_instance
			build_popup.visible = false
			ui_layer.add_child(build_popup_instance)
	if win_lose_overlay_scene != null:
		var overlay_instance: WinLoseOverlay = win_lose_overlay_scene.instantiate() as WinLoseOverlay
		if overlay_instance != null:
			win_lose_overlay = overlay_instance
			win_lose_overlay.visible = false
			ui_layer.add_child(overlay_instance)

func _setup_session() -> void:
	if level == null:
		return
	session = GameSession.new()
	add_child(session)
	session.setup(level, spawner, hud, build_popup, win_lose_overlay)
	_connect_ui_signals()
	_connect_spawner_signals()

func _connect_ui_signals() -> void:
	if hud != null:
		hud.start_wave_pressed.connect(session._on_start_wave_pressed)
	if build_popup != null:
		build_popup.tower_selected.connect(session._on_build_popup_tower_selected)
		build_popup.request_close.connect(session._on_build_popup_close_requested)
	if win_lose_overlay != null:
		win_lose_overlay.restart_pressed.connect(_on_restart_pressed)

func _connect_spawner_signals() -> void:
	if spawner != null:
		spawner.enemy_spawned.connect(session._on_enemy_spawned)
		spawner.wave_spawn_finished.connect(session._on_wave_spawn_finished)

func _connect_build_spots(level_instance: Level) -> void:
	var spots: Array[BuildSpot] = level_instance.get_build_spots()
	for spot: BuildSpot in spots:
		spot.clicked.connect(_on_build_spot_clicked)

func _on_build_spot_clicked(build_spot: BuildSpot) -> void:
	if session == null:
		return
	session.handle_build_spot_clicked(build_spot)

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()
