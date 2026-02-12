extends Resource
class_name TowerDef

@export var id: String = ""
@export var display_name: String = ""
@export var cost: int = 0
@export var damage: float = 0.0
@export var range: float = 0.0
@export var shots_per_second: float = 0.0
@export var cooldown_sec: float = 0.0
@export var projectile_speed: float = 0.0
@export var splash_radius: float = 0.0
@export var splash_multiplier: float = 0.0
@export var targeting_policy: int = 0
@export var upgrade_option_a: TowerDef
@export var upgrade_option_b: TowerDef
@export var upgrade_cost_a: int = 0
@export var upgrade_cost_b: int = 0
