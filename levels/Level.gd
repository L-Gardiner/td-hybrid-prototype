extends Node2D
class_name Level

@export var level_def: LevelDef
@export var enemy_scene: PackedScene
@export var tower_scene: PackedScene

@onready var build_spots_root: Node = $World/BuildSpots
@onready var enemy_path: Path2D = $World/EnemyPath
@onready var spawner: EnemySpawner = $EnemySpawner
@onready var base_marker: BaseMarker = $World/Base

func _ready() -> void:
	_ensure_path_curve()
	if spawner:
		spawner.setup(enemy_scene, enemy_path, null)

func _ensure_path_curve() -> void:
	if enemy_path == null:
		return
	if enemy_path.curve == null:
		enemy_path.curve = Curve2D.new()
	if enemy_path.curve.point_count < 2:
		enemy_path.curve.clear_points()
		enemy_path.curve.add_point(Vector2(240, 360))
		enemy_path.curve.add_point(Vector2(1040, 360))
		push_warning("Level: EnemyPath curve was empty. Using fallback path. Draw Path2D points in the editor for your layout.")

func get_build_spots() -> Array[BuildSpot]:
	var spots: Array[BuildSpot] = []
	if build_spots_root:
		for child in build_spots_root.get_children():
			if child is BuildSpot:
				spots.append(child)
	return spots

func get_spawner() -> EnemySpawner:
	return spawner

func get_base_marker() -> BaseMarker:
	return base_marker

func get_enemy_path() -> Path2D:
	return enemy_path

func get_level_def() -> Resource:
	return level_def
