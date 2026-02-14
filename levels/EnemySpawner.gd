extends Node
class_name EnemySpawner

signal enemy_spawned(enemy: Enemy)
signal wave_spawn_finished

const RUNNER_DEF_PATH: String = "res://enemies/defs/RunnerEnemy.tres"
const TANK_DEF_PATH: String = "res://enemies/defs/TankEnemy.tres"

var is_spawning: bool = false
var cancel_requested: bool = false

var enemy_scene: PackedScene
var enemy_path: Path2D
var followers_root: Node
var enemy_defs: Dictionary = {}
var rng: RandomNumberGenerator

func setup(scene: PackedScene, path: Path2D, followers: Node) -> void:
    enemy_scene = scene
    enemy_path = path
    followers_root = followers
    _load_enemy_defs()
    _init_rng()

func start_wave(wave_def: Variant) -> void:
    if is_spawning:
        return
    is_spawning = true
    cancel_requested = false
    _spawn_wave(wave_def)

func cancel_wave() -> void:
    if not is_spawning:
        return
    cancel_requested = true

func _spawn_wave(wave_def: Variant) -> void:
    var interval: float = _get_wave_interval(wave_def)
    var spawn_queue: Array[String] = _resolve_spawn_queue(wave_def)
    if spawn_queue.is_empty():
        var data: Dictionary = _resolve_wave_data(wave_def)
        var count: int = data.count
        for i in range(count):
            if cancel_requested:
                break
            _spawn_enemy("")
            if i < count - 1:
                await get_tree().create_timer(interval, false).timeout
    else:
        var total: int = spawn_queue.size()
        for i in range(total):
            if cancel_requested:
                break
            _spawn_enemy(spawn_queue[i])
            if i < total - 1:
                await get_tree().create_timer(interval, false).timeout
    is_spawning = false
    if cancel_requested:
        cancel_requested = false
        return
    wave_spawn_finished.emit()

func _resolve_wave_data(wave_def: Variant) -> Dictionary:
    var count: int = 5
    var interval: float = 0.8
    if wave_def is Dictionary:
        if wave_def.has("count"):
            count = int(wave_def["count"])
        if wave_def.has("spawn_interval"):
            interval = float(wave_def["spawn_interval"])
    elif wave_def != null:
        var count_value: Variant = wave_def.get("count")
        if count_value != null:
            count = int(count_value)
        var interval_value: Variant = wave_def.get("spawn_interval_sec")
        if interval_value != null:
            interval = float(interval_value)
    return {
        "count": count,
        "interval": interval
    }

func _get_wave_interval(wave_def: Variant) -> float:
    var interval: float = 0.8
    if wave_def is Dictionary:
        if wave_def.has("spawn_interval"):
            interval = float(wave_def["spawn_interval"])
    elif wave_def != null:
        var interval_value: Variant = wave_def.get("spawn_interval_sec")
        if interval_value != null:
            interval = float(interval_value)
    return interval

func _resolve_spawn_queue(wave_def: Variant) -> Array[String]:
    var empty_queue: Array[String] = []
    if wave_def is Dictionary:
        if wave_def.has("composition"):
            return _build_composition_queue(wave_def["composition"])
        if wave_def.has("weights"):
            return _build_weighted_queue(wave_def)
    return empty_queue

func _build_composition_queue(value: Variant) -> Array[String]:
    var queue: Array[String] = []
    if value is Array:
        for entry in value:
            if entry is Dictionary:
                if entry.has("type") and entry.has("count"):
                    var type_id: String = str(entry["type"])
                    var count_value: int = int(entry["count"])
                    if count_value > 0:
                        for i in range(count_value):
                            queue.append(type_id)
    return queue

func _build_weighted_queue(wave_def: Dictionary) -> Array[String]:
    var queue: Array[String] = []
    if not wave_def.has("count"):
        return queue
    if not wave_def.has("weights"):
        return queue
    var count: int = int(wave_def["count"])
    var weights: Dictionary = wave_def["weights"]
    for i in range(count):
        queue.append(_choose_weighted_type(weights))
    return queue

func _choose_weighted_type(weights: Dictionary) -> String:
    var total_weight: float = 0.0
    for key in weights.keys():
        total_weight += float(weights[key])
    if total_weight <= 0.0:
        return ""
    var roll: float = rng.randf_range(0.0, total_weight)
    var cumulative: float = 0.0
    for key in weights.keys():
        cumulative += float(weights[key])
        if roll <= cumulative:
            return str(key)
    return ""

func _spawn_enemy(enemy_type: String) -> void:
    if enemy_scene == null or enemy_path == null:
        push_warning("EnemySpawner: enemy_scene or enemy_path not set.")
        return
    var follow: PathFollow2D = PathFollow2D.new()
    follow.loop = false
    follow.rotates = false
    enemy_path.add_child(follow)
    var enemy: Enemy = enemy_scene.instantiate() as Enemy
    if enemy == null:
        follow.queue_free()
        return
    var enemy_def: EnemyDef = _get_enemy_def(enemy_type)
    if enemy_def != null:
        enemy.enemy_def = enemy_def
    follow.add_child(enemy)
    enemy.set_path_follow(follow)
    enemy_spawned.emit(enemy)

func _load_enemy_defs() -> void:
    enemy_defs.clear()
    var runner: EnemyDef = load(RUNNER_DEF_PATH) as EnemyDef
    if runner != null and runner.id != "":
        enemy_defs[runner.id] = runner
    var tank: EnemyDef = load(TANK_DEF_PATH) as EnemyDef
    if tank != null and tank.id != "":
        enemy_defs[tank.id] = tank

func _init_rng() -> void:
    if rng == null:
        rng = RandomNumberGenerator.new()
        rng.randomize()

func _get_enemy_def(enemy_type: String) -> EnemyDef:
    if enemy_type == "":
        return null
    if enemy_defs.has(enemy_type):
        return enemy_defs[enemy_type]
    return null
