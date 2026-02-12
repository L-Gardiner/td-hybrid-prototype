extends Node
class_name GameSession

signal gold_changed(new_gold: int)
signal wave_state_changed(in_progress: bool)
signal tower_built(tower: Tower)

const DEFAULT_STARTING_GOLD: int = 10
const DEFAULT_BASE_HP: int = 10
const DEFAULT_WAVE_COUNT: int = 3
const BASIC_TOWER_DEF_PATH: String = "res://towers/defs/BasicTower.tres"
const SPLASH_TOWER_DEF_PATH: String = "res://towers/defs/SplashTower.tres"

var level: Level
var spawner: EnemySpawner
var hud: HUD
var build_popup: BuildPopup
var win_lose_overlay: WinLoseOverlay
var basic_tower_def: TowerDef
var splash_tower_def: TowerDef

var waves: Array = []
var wave_index: int = 0
var active_enemies: int = 0
var spawn_finished: bool = false
var game_over: bool = false
var gold: int = 0
var base_hp: int = 0
var selected_build_spot: BuildSpot
var last_wave_in_progress: bool = false

func setup(level_instance: Level, spawner_instance: EnemySpawner, hud_instance: HUD, build_popup_instance: BuildPopup, win_lose_overlay_instance: WinLoseOverlay) -> void:
	level = level_instance
	spawner = spawner_instance
	hud = hud_instance
	build_popup = build_popup_instance
	win_lose_overlay = win_lose_overlay_instance
	_load_tower_defs()
	gold_changed.connect(_on_gold_changed)
	_init_run_state()

func handle_build_spot_clicked(build_spot: BuildSpot) -> void:
	if game_over:
		return
	if build_spot == null or build_spot.occupied:
		return
	selected_build_spot = build_spot
	var screen_position: Vector2 = build_spot.get_global_transform_with_canvas().origin
	if build_popup:
		_configure_build_popup()
		build_popup.open_at(screen_position)

func _init_run_state() -> void:
	if level == null:
		return
	var level_def: LevelDef = level.get_level_def()
	var starting_gold: int = _get_level_starting_gold(level_def)
	_set_gold(starting_gold)
	base_hp = _get_level_base_hp(level_def)
	waves = _get_level_waves(level_def)
	if waves.is_empty():
		push_warning("GameSession: LevelDef missing waves; using defaults.")
		waves = _default_waves()
	wave_index = 0
	active_enemies = 0
	spawn_finished = false
	game_over = false
	selected_build_spot = null
	_update_hud()
	_update_start_wave_state()

func _get_level_starting_gold(level_def: LevelDef) -> int:
	if level_def == null:
		push_warning("GameSession: LevelDef not assigned; using default starting_gold.")
		return DEFAULT_STARTING_GOLD
	if level_def.starting_gold <= 0:
		push_warning("GameSession: LevelDef starting_gold invalid; using default.")
		return DEFAULT_STARTING_GOLD
	return level_def.starting_gold

func _get_level_base_hp(level_def: LevelDef) -> int:
	if level_def == null:
		push_warning("GameSession: LevelDef not assigned; using default base_hp.")
		return DEFAULT_BASE_HP
	if level_def.base_hp <= 0:
		push_warning("GameSession: LevelDef base_hp invalid; using default.")
		return DEFAULT_BASE_HP
	return level_def.base_hp


func _get_level_waves(level_def: LevelDef) -> Array:
	if level_def == null:
		var empty_waves: Array = []
		return empty_waves
	if level_def.waves is Array:
		return level_def.waves
	var fallback_waves: Array = []
	return fallback_waves

func _default_waves() -> Array:
	var default_waves: Array = []
	var wave_one: Dictionary = {
		"spawn_interval": 0.8,
		"composition": [
			{
				"type": "runner",
				"count": 4
			},
			{
				"type": "tank",
				"count": 2
			}
		]
	}
	var wave_two: Dictionary = {
		"count": 8,
		"spawn_interval": 0.75,
		"weights": {
			"runner": 0.7,
			"tank": 0.3
		}
	}
	var wave_three: Dictionary = {
		"count": 6,
		"spawn_interval": 0.7
	}
	default_waves.append(wave_one)
	default_waves.append(wave_two)
	default_waves.append(wave_three)
	return default_waves

func _update_hud() -> void:
	if hud == null:
		return
	hud.set_gold(gold)
	hud.set_base_hp(base_hp)
	var total: int = waves.size()
	var display_wave: int = wave_index
	if total > 0 and _is_wave_in_progress():
		display_wave = min(wave_index + 1, total)
	hud.set_wave_label("Wave %d/%d" % [display_wave, total])
	_update_wave_preview()

func _update_wave_preview() -> void:
	if hud == null:
		return
	var preview: Dictionary = WavePreviewHelper.build_preview(waves, wave_index, _is_wave_in_progress())
	hud.set_next_wave_preview(preview)

func _update_start_wave_state() -> void:
	if hud == null:
		return
	var can_start: bool = true
	if game_over:
		can_start = false
	elif wave_index >= waves.size():
		can_start = false
	elif _is_wave_in_progress():
		can_start = false
	hud.set_start_wave_enabled(can_start)
	_emit_wave_state_if_changed()

func _is_wave_in_progress() -> bool:
	return (spawner != null and spawner.is_spawning) or active_enemies > 0

func _on_start_wave_pressed() -> void:
	if game_over:
		return
	if wave_index >= waves.size():
		return
	if level == null:
		return
	if spawner == null:
		push_warning("Main: EnemySpawner not found.")
		return
	if _is_wave_in_progress():
		return
	spawn_finished = false
	spawner.start_wave(waves[wave_index])
	_update_hud()
	_update_start_wave_state()

func _on_build_popup_tower_selected(tower_id: String) -> void:
	if game_over:
		return
	if selected_build_spot == null or selected_build_spot.occupied:
		return
	var tower_def: TowerDef = _get_tower_def(tower_id)
	if tower_def == null:
		return
	if gold < tower_def.cost:
		return
	if level == null:
		return
	var tower_scene: PackedScene = level.tower_scene
	if tower_scene == null:
		push_warning("Main: tower_scene not set.")
		return
	var tower: Tower = tower_scene.instantiate() as Tower
	if tower == null:
		return
	tower.tower_def = tower_def
	level.add_child(tower)
	tower.global_position = selected_build_spot.global_position
	tower.build_spot = selected_build_spot
	selected_build_spot.occupied = true
	_set_gold(gold - tower_def.cost)
	var audio_manager: AudioManager = get_tree().get_first_node_in_group("audio_manager") as AudioManager
	if audio_manager != null:
		audio_manager.play_tower_place()
	_update_hud()
	_update_start_wave_state()
	if build_popup:
		build_popup.close()
	selected_build_spot = null
	tower_built.emit(tower)

func _refresh_build_popup() -> void:
	if build_popup and build_popup.visible and selected_build_spot != null:
		_configure_build_popup()

func _on_build_popup_close_requested() -> void:
	if build_popup:
		build_popup.close()
	selected_build_spot = null

func _on_enemy_spawned(enemy: Enemy) -> void:
	if enemy == null:
		return
	active_enemies += 1
	var audio_manager: AudioManager = get_tree().get_first_node_in_group("audio_manager") as AudioManager
	if audio_manager != null:
		audio_manager.play_enemy_spawn()
	enemy.died.connect(_on_enemy_died)
	enemy.escaped.connect(_on_enemy_escaped)
	_update_start_wave_state()

func _on_enemy_died(reward_gold: int) -> void:
	_set_gold(gold + reward_gold)
	active_enemies = max(active_enemies - 1, 0)
	_update_hud()
	_refresh_build_popup()
	_check_wave_completion()
	_update_start_wave_state()

func _on_enemy_escaped(leak_damage: int) -> void:
	base_hp -= leak_damage
	active_enemies = max(active_enemies - 1, 0)
	_update_hud()
	if level:
		var base_marker: BaseMarker = level.get_base_marker()
		if base_marker:
			base_marker.trigger_flash()
	if base_hp <= 0:
		_show_lose()
		return
	_check_wave_completion()
	_update_start_wave_state()

func _on_wave_spawn_finished() -> void:
	spawn_finished = true
	_check_wave_completion()
	_update_start_wave_state()

func _check_wave_completion() -> void:
	if game_over:
		return
	if not spawn_finished:
		return
	if active_enemies > 0:
		return
	wave_index += 1
	_update_hud()
	if wave_index >= waves.size():
		_show_win()
		return
	_update_start_wave_state()

func _show_win() -> void:
	game_over = true
	_update_start_wave_state()
	if build_popup:
		build_popup.close()
	if win_lose_overlay:
		win_lose_overlay.show_message("WIN")
	else:
		print("WIN")

func _show_lose() -> void:
	game_over = true
	_update_start_wave_state()
	if build_popup:
		build_popup.close()
	if win_lose_overlay:
		win_lose_overlay.show_message("LOSE")
	else:
		print("LOSE")

func _configure_build_popup() -> void:
	if build_popup == null:
		return
	var basic_cost: int = _get_tower_cost(basic_tower_def)
	var splash_cost: int = _get_tower_cost(splash_tower_def)
	var can_afford_basic: bool = basic_tower_def != null and gold >= basic_cost
	var can_afford_splash: bool = splash_tower_def != null and gold >= splash_cost
	build_popup.configure_towers(basic_cost, can_afford_basic, splash_cost, can_afford_splash)

func _get_tower_cost(def: TowerDef) -> int:
	if def == null:
		return 0
	return def.cost

func _get_tower_def(tower_id: String) -> TowerDef:
	if tower_id == "basic":
		return basic_tower_def
	if tower_id == "splash":
		return splash_tower_def
	return null

func _set_gold(new_gold: int) -> void:
	gold = new_gold
	gold_changed.emit(gold)

func _on_gold_changed(new_gold: int) -> void:
	if hud != null:
		hud.set_gold(new_gold)
	if new_gold == gold:
		_refresh_build_popup()

func get_gold() -> int:
	return gold

func is_wave_in_progress() -> bool:
	return _is_wave_in_progress()

func try_spend_gold(amount: int) -> bool:
	if amount <= 0:
		return true
	if gold < amount:
		return false
	_set_gold(gold - amount)
	return true

func add_gold(amount: int) -> void:
	if amount <= 0:
		return
	_set_gold(gold + amount)

func _emit_wave_state_if_changed() -> void:
	var in_progress: bool = _is_wave_in_progress()
	if in_progress == last_wave_in_progress:
		return
	last_wave_in_progress = in_progress
	wave_state_changed.emit(in_progress)

func _load_tower_defs() -> void:
	basic_tower_def = _load_tower_def(BASIC_TOWER_DEF_PATH, _make_basic_fallback())
	splash_tower_def = _load_tower_def(SPLASH_TOWER_DEF_PATH, _make_splash_fallback())

func _load_tower_def(path: String, fallback: TowerDef) -> TowerDef:
	var res: Resource = load(path)
	if res != null and res is TowerDef:
		return res as TowerDef
	return fallback

func _make_basic_fallback() -> TowerDef:
	var def: TowerDef = TowerDef.new()
	def.id = "basic"
	def.display_name = "Basic"
	def.cost = 3
	def.damage = 2.0
	def.range = 120.0
	def.shots_per_second = 1.0
	def.cooldown_sec = 1.0
	def.splash_radius = 0.0
	def.splash_multiplier = 0.0
	return def

func _make_splash_fallback() -> TowerDef:
	var def: TowerDef = TowerDef.new()
	def.id = "splash"
	def.display_name = "Splash"
	def.cost = 5
	def.damage = 1.6
	def.range = 110.0
	def.shots_per_second = 0.9
	def.cooldown_sec = 1.2
	def.splash_radius = 48.0
	def.splash_multiplier = 0.6
	return def
