extends Node
class_name Main

@export var level_scene: PackedScene
@export var level_def: LevelDef

@onready var level_root: Node = $LevelRoot
@onready var hud: HUD = $UI/HUD
@onready var build_popup: BuildPopup = $UI/BuildPopup
@onready var upgrade_popup: UpgradePopup = $UI/UpgradePopup
@onready var win_lose_overlay: WinLoseOverlay = $UI/WinLoseOverlay
@onready var sim_controller: SimController = $SimController

var level: Level
var spawner: EnemySpawner
var session: GameSession
var selected_tower: Tower

const DELETE_REFUND_RATIO: float = 0.5

func _ready() -> void:
	_ensure_session()
	_connect_ui()
	_spawn_level()
	_configure_ui_pause_mode()
	_connect_sim_controller()
	set_process_unhandled_input(true)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_on_restart_pressed()

func _spawn_level() -> void:
	if level_scene == null:
		push_warning("Main: level_scene not set.")
		return
	var level_instance: Level = level_scene.instantiate() as Level
	if level_instance == null:
		push_warning("Main: level_scene instantiation failed.")
		return
	level = level_instance
	if level_def != null:
		level.level_def = level_def
	level_root.add_child(level_instance)
	_connect_level(level_instance)
	_setup_session()

func _connect_ui() -> void:
	if hud != null and session != null:
		hud.start_wave_pressed.connect(session._on_start_wave_pressed)
	if build_popup != null and session != null:
		build_popup.tower_selected.connect(session._on_build_popup_tower_selected)
		build_popup.request_close.connect(session._on_build_popup_close_requested)
	if upgrade_popup != null:
		upgrade_popup.upgrade_selected.connect(_on_upgrade_selected)
		upgrade_popup.delete_selected.connect(_on_delete_selected)
		upgrade_popup.request_close.connect(_on_upgrade_popup_close_requested)
	if win_lose_overlay:
		win_lose_overlay.restart_pressed.connect(_on_restart_pressed)

func _configure_ui_pause_mode() -> void:
	if hud != null:
		hud.process_mode = Node.PROCESS_MODE_ALWAYS
	if build_popup != null:
		build_popup.process_mode = Node.PROCESS_MODE_ALWAYS
	if upgrade_popup != null:
		upgrade_popup.process_mode = Node.PROCESS_MODE_ALWAYS
	if win_lose_overlay != null:
		win_lose_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	if sim_controller != null:
		sim_controller.process_mode = Node.PROCESS_MODE_ALWAYS

func _connect_sim_controller() -> void:
	if sim_controller == null:
		return
	if hud != null:
		sim_controller.state_changed.connect(hud.set_sim_status)
		hud.set_sim_status(sim_controller.get_status_text())
	if session != null:
		session.wave_state_changed.connect(_on_wave_state_changed)
		session.gold_changed.connect(_on_gold_changed)
		session.tower_built.connect(_on_tower_built)

func _connect_level(level_instance: Level) -> void:
	var spots: Array[BuildSpot] = level_instance.get_build_spots()
	for spot: BuildSpot in spots:
		spot.clicked.connect(_on_build_spot_clicked)
	spawner = level_instance.get_spawner()
	if spawner != null and session != null:
		spawner.enemy_spawned.connect(session._on_enemy_spawned)
		spawner.wave_spawn_finished.connect(session._on_wave_spawn_finished)

func _on_build_spot_clicked(build_spot: BuildSpot) -> void:
	if session == null:
		return
	_clear_selected_tower()
	session.handle_build_spot_clicked(build_spot)

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()

func _ensure_session() -> void:
	if session != null:
		return
	session = GameSession.new()
	add_child(session)

func _setup_session() -> void:
	if session == null:
		return
	if level == null:
		return
	session.setup(level, spawner, hud, build_popup, win_lose_overlay)

func _on_tower_built(tower: Tower) -> void:
	if tower == null:
		return
	tower.clicked.connect(_on_tower_clicked)

func _on_tower_clicked(tower: Tower) -> void:
	if tower == null:
		return
	if selected_tower != null and selected_tower != tower:
		selected_tower.set_selected(false)
	selected_tower = tower
	selected_tower.set_selected(true)
	if build_popup:
		build_popup.close()
	_show_upgrade_popup(tower)

func _show_upgrade_popup(tower: Tower) -> void:
	if upgrade_popup == null or tower == null:
		return
	var tower_def: TowerDef = tower.tower_def
	var option_a: TowerDef = null
	var option_b: TowerDef = null
	var cost_a: int = 0
	var cost_b: int = 0
	var label_a: String = "No Upgrade"
	var label_b: String = "No Upgrade"
	if tower_def != null:
		option_a = tower_def.upgrade_option_a
		option_b = tower_def.upgrade_option_b
		cost_a = tower_def.upgrade_cost_a
		cost_b = tower_def.upgrade_cost_b
		if option_a != null:
			label_a = _get_tower_display_name(option_a, "Upgrade A")
		if option_b != null:
			label_b = _get_tower_display_name(option_b, "Upgrade B")
	var gold: int = session.get_gold() if session != null else 0
	var can_afford_a: bool = option_a != null and gold >= cost_a
	var can_afford_b: bool = option_b != null and gold >= cost_b
	var upgrades_enabled: bool = session != null and not session.is_wave_in_progress()
	var refund: int = _get_delete_refund(tower_def)
	upgrade_popup.configure(label_a, cost_a, option_a != null, can_afford_a, label_b, cost_b, option_b != null, can_afford_b, upgrades_enabled, upgrades_enabled, refund)
	upgrade_popup.open_at(tower.get_global_transform_with_canvas().origin)

func _on_upgrade_selected(option_index: int) -> void:
	if selected_tower == null:
		return
	if session == null:
		return
	if session.is_wave_in_progress():
		return
	var tower_def: TowerDef = selected_tower.tower_def
	if tower_def == null:
		return
	var new_def: TowerDef = tower_def.upgrade_option_a if option_index == 0 else tower_def.upgrade_option_b
	var cost: int = tower_def.upgrade_cost_a if option_index == 0 else tower_def.upgrade_cost_b
	if new_def == null:
		return
	if not session.try_spend_gold(cost):
		return
	selected_tower.apply_new_def(new_def)
	_close_upgrade_popup()

func _on_delete_selected() -> void:
	if selected_tower == null:
		return
	if session == null:
		return
	if session.is_wave_in_progress():
		return
	var tower_def: TowerDef = selected_tower.tower_def
	var refund: int = _get_delete_refund(tower_def)
	if refund > 0:
		session.add_gold(refund)
	if selected_tower.build_spot != null:
		selected_tower.build_spot.occupied = false
	selected_tower.queue_free()
	_close_upgrade_popup()

func _on_upgrade_popup_close_requested() -> void:
	_close_upgrade_popup()

func _close_upgrade_popup() -> void:
	if upgrade_popup:
		upgrade_popup.close()
	_clear_selected_tower()

func _clear_selected_tower() -> void:
	if selected_tower != null:
		selected_tower.set_selected(false)
	selected_tower = null

func _on_wave_state_changed(in_progress: bool) -> void:
	if upgrade_popup != null and upgrade_popup.visible and selected_tower != null:
		_show_upgrade_popup(selected_tower)

func _on_gold_changed(new_gold: int) -> void:
	if upgrade_popup != null and upgrade_popup.visible and selected_tower != null:
		_show_upgrade_popup(selected_tower)

func _get_delete_refund(def: TowerDef) -> int:
	if def == null:
		return 0
	return int(round(float(def.cost) * DELETE_REFUND_RATIO))

func _get_tower_display_name(def: TowerDef, fallback: String) -> String:
	if def == null:
		return fallback
	if def.display_name != "":
		return def.display_name
	return fallback
