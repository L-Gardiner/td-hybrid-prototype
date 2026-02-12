extends Node2D
class_name Enemy

signal died(reward_gold: int)
signal escaped(leak_damage: int)

@export var enemy_def: Resource
@export var max_hp: float = 6.0
@export var speed: float = 90.0
@export var reward_gold: int = 1
@export var leak_damage: int = 1
@export var radius: float = 6.0
@export var color: Color = Color.WHITE
@export var hit_flash_color: Color = Color(1.0, 0.9, 0.4, 0.95)
@export var hit_flash_duration: float = 0.08
@export var death_flash_color: Color = Color(1.0, 0.35, 0.25, 0.95)
@export var death_flash_duration: float = 0.22
@export var death_pop_scale: float = 2.6
@export var hit_scale_peak: float = 1.15
@export var hit_scale_duration: float = 0.12
@export var death_scale_duration: float = 0.25
@export var hit_burst_count: int = 4
@export var death_burst_count: int = 10
@export var hit_burst_duration: float = 0.16
@export var death_burst_duration: float = 0.26
@export var spawn_pop_duration: float = 0.2
@export var spawn_ring_color: Color = Color(0.8, 0.95, 1.0, 0.75)
@export var spawn_ring_radius: float = 12.0
@export var health_bar_width: float = 26.0
@export var health_bar_height: float = 3.0
@export var health_bar_offset: float = 12.0
@export var health_bar_fill_color: Color = Color(0.45, 0.95, 0.55, 0.95)
@export var health_bar_bg_color: Color = Color(0.05, 0.05, 0.05, 0.2)
@export var flat_damage_reduction: int = 0

const MITIGATION_FLASH_DURATION: float = 0.08
const MITIGATION_FLASH_MULTIPLIER: float = 0.6

var hp: float = 0.0
var path_follow: PathFollow2D
var resolved: bool = false
var hit_flash_until_ms: int = 0
var death_flash_until_ms: int = 0
var mitigation_flash_until_ms: int = 0
var hit_scale: float = 1.0
var death_pop_scale_current: float = 1.0
var death_flash_alpha: float = 1.0
var hit_tween: Tween
var death_tween: Tween
var enemy_id: String = ""

@onready var health_bar: ProgressBar = $HealthBar

func _ready() -> void:
	add_to_group("enemies")
	_apply_enemy_def()
	hp = max_hp
	path_follow = get_parent() as PathFollow2D
	if path_follow == null:
		push_warning("Enemy: expected PathFollow2D parent.")
	_configure_health_bar()
	_update_health_bar()
	_play_spawn_pop()
	queue_redraw()

func _draw() -> void:
	_draw_body(color, hit_scale)
	if hit_flash_until_ms > 0:
		_draw_body(hit_flash_color, hit_scale)
	if mitigation_flash_until_ms > 0:
		var dim_color: Color = Color(color.r * MITIGATION_FLASH_MULTIPLIER, color.g * MITIGATION_FLASH_MULTIPLIER, color.b * MITIGATION_FLASH_MULTIPLIER, color.a)
		_draw_body(dim_color, hit_scale)
	if death_flash_until_ms > 0:
		var flash_color: Color = death_flash_color
		flash_color.a *= death_flash_alpha
		_draw_body(flash_color, death_pop_scale_current)

func _process(delta: float) -> void:
	_update_flash_state()
	if resolved:
		return
	if path_follow == null:
		return
	path_follow.progress += speed * delta
	if path_follow.progress_ratio >= 1.0:
		escape()

func take_damage(amount: float) -> void:
	apply_damage(amount)

func apply_damage(amount: float) -> void:
	if resolved:
		return
	var reduction: float = max(float(flat_damage_reduction), 0.0)
	var final_damage: float = max(amount - reduction, 0.0)
	if reduction > 0.0 and amount > final_damage:
		_trigger_mitigation_flash()
	if final_damage <= 0.0:
		return
	hp -= final_damage
	_update_health_bar()
	if hp <= 0.0:
		_begin_death()
		return
	_trigger_hit_flash()
	_play_hit_tween()
	_spawn_hit_burst()

func escape() -> void:
	if resolved:
		return
	resolved = true
	escaped.emit(leak_damage)
	if path_follow:
		path_follow.queue_free()
	queue_free()

func _begin_death() -> void:
	resolved = true
	died.emit(reward_gold)
	_trigger_death_flash()
	_play_death_tween()
	_spawn_death_burst()
	_play_death_sfx()
	if health_bar:
		health_bar.visible = false
	await get_tree().create_timer(death_flash_duration).timeout
	if path_follow:
		path_follow.queue_free()
	queue_free()

func _draw_body(body_color: Color, scale_value: float) -> void:
	var render_radius: float = radius * scale_value
	if enemy_id == "runner":
		_draw_runner(render_radius, body_color)
		return
	if enemy_id == "tank":
		_draw_tank(render_radius, body_color)
		return
	draw_circle(Vector2.ZERO, render_radius, body_color)

func _draw_runner(render_radius: float, body_color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	points.append(Vector2(0.0, -render_radius))
	points.append(Vector2(render_radius * 0.9, render_radius))
	points.append(Vector2(-render_radius * 0.9, render_radius))
	draw_colored_polygon(points, body_color)

func _draw_tank(render_radius: float, body_color: Color) -> void:
	var r: float = render_radius * 1.1
	var points: PackedVector2Array = PackedVector2Array()
	points.append(Vector2(0.0, -r))
	points.append(Vector2(r, -r * 0.35))
	points.append(Vector2(r, r * 0.35))
	points.append(Vector2(0.0, r))
	points.append(Vector2(-r, r * 0.35))
	points.append(Vector2(-r, -r * 0.35))
	draw_colored_polygon(points, body_color)

class BurstVfx:
	extends Node2D

	var points: PackedVector2Array = PackedVector2Array()
	var radii: Array[float] = []
	var base_color: Color = Color.WHITE
	var duration: float = 0.2
	var alpha: float = 1.0
	var scale_value: float = 1.0
	var tween: Tween

	func _init(point_count: int, base_radius: float, spread: float, new_color: Color, new_duration: float) -> void:
		base_color = new_color
		duration = new_duration
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.randomize()
		for i in range(point_count):
			var angle: float = rng.randf_range(0.0, TAU)
			var dist: float = rng.randf_range(spread * 0.35, spread)
			points.append(Vector2(cos(angle), sin(angle)) * dist)
			radii.append(rng.randf_range(base_radius * 0.5, base_radius))

	func _ready() -> void:
		scale_value = 0.6
		alpha = 0.9
		set_process(true)
		tween = create_tween()
		tween.tween_property(self, "scale_value", 1.15, duration * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(self, "alpha", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.tween_callback(queue_free)

	func _process(delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var draw_color: Color = base_color
		draw_color.a *= alpha
		for i in range(points.size()):
			draw_circle(points[i] * scale_value, radii[i] * scale_value, draw_color)

class SpawnRingVfx:
	extends Node2D

	var ring_radius: float = 10.0
	var base_color: Color = Color.WHITE
	var duration: float = 0.2
	var alpha: float = 1.0
	var scale_value: float = 0.6
	var tween: Tween

	func _init(new_radius: float, new_color: Color, new_duration: float) -> void:
		ring_radius = new_radius
		base_color = new_color
		duration = new_duration

	func _ready() -> void:
		scale_value = 0.7
		alpha = 0.9
		set_process(true)
		tween = create_tween()
		tween.tween_property(self, "scale_value", 1.25, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(self, "alpha", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.tween_callback(queue_free)

	func _process(delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var draw_color: Color = base_color
		draw_color.a *= alpha
		draw_arc(Vector2.ZERO, ring_radius * scale_value, 0.0, TAU, 32, draw_color, 2.0)

func _spawn_hit_burst() -> void:
	if hit_burst_count <= 0:
		return
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var burst_radius: float = max(radius * 0.28, 2.0)
	var spread: float = max(radius * 0.9, 6.0)
	var burst: BurstVfx = BurstVfx.new(hit_burst_count, burst_radius, spread, hit_flash_color, hit_burst_duration)
	parent_node.add_child(burst)
	burst.global_position = global_position

func _spawn_death_burst() -> void:
	if death_burst_count <= 0:
		return
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var burst_radius: float = max(radius * 0.35, 2.5)
	var spread: float = max(radius * 1.3, 8.0)
	var burst: BurstVfx = BurstVfx.new(death_burst_count, burst_radius, spread, death_flash_color, death_burst_duration)
	parent_node.add_child(burst)
	burst.global_position = global_position

func _play_spawn_pop() -> void:
	if spawn_pop_duration <= 0.0:
		return
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var ring_radius: float = max(spawn_ring_radius, radius * 1.4)
	var ring: SpawnRingVfx = SpawnRingVfx.new(ring_radius, spawn_ring_color, spawn_pop_duration)
	parent_node.add_child(ring)
	ring.global_position = global_position

func _trigger_hit_flash() -> void:
	hit_flash_until_ms = Time.get_ticks_msec() + int(hit_flash_duration * 1000.0)
	queue_redraw()

func _trigger_mitigation_flash() -> void:
	mitigation_flash_until_ms = Time.get_ticks_msec() + int(MITIGATION_FLASH_DURATION * 1000.0)
	queue_redraw()

func _trigger_death_flash() -> void:
	death_flash_until_ms = Time.get_ticks_msec() + int(death_flash_duration * 1000.0)
	queue_redraw()

func _play_hit_tween() -> void:
	if hit_tween and hit_tween.is_running():
		hit_tween.kill()
	hit_scale = 1.0
	hit_tween = create_tween()
	hit_tween.tween_property(self, "hit_scale", hit_scale_peak, hit_scale_duration * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	hit_tween.tween_property(self, "hit_scale", 1.0, hit_scale_duration * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _play_death_tween() -> void:
	if death_tween and death_tween.is_running():
		death_tween.kill()
	death_pop_scale_current = 1.0
	death_flash_alpha = 1.0
	death_tween = create_tween()
	death_tween.tween_property(self, "death_pop_scale_current", death_pop_scale, death_scale_duration * 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	death_tween.tween_property(self, "death_flash_alpha", 0.0, death_scale_duration * 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _play_death_sfx() -> void:
	var audio_manager: AudioManager = get_tree().get_first_node_in_group("audio_manager") as AudioManager
	if audio_manager != null and audio_manager.has_method("play_enemy_death"):
		print("DEATH SFX")
		audio_manager.play_enemy_death()
	else:
		print("DEATH SFX — AudioManager not found! audio_manager=", audio_manager)

func _update_flash_state() -> void:
	var now_ms: int = Time.get_ticks_msec()
	if hit_flash_until_ms > 0 and now_ms > hit_flash_until_ms:
		hit_flash_until_ms = 0
		queue_redraw()
	if mitigation_flash_until_ms > 0 and now_ms > mitigation_flash_until_ms:
		mitigation_flash_until_ms = 0
		queue_redraw()
	if death_flash_until_ms > 0 and now_ms > death_flash_until_ms:
		death_flash_until_ms = 0
		queue_redraw()

func set_path_follow(follow: PathFollow2D) -> void:
	path_follow = follow

func _apply_enemy_def() -> void:
	if enemy_def == null:
		return
	enemy_id = _get_def_string(enemy_def, "id", enemy_id)
	max_hp = _get_def_float(enemy_def, "max_hp", max_hp)
	speed = _get_def_float(enemy_def, "speed", speed)
	reward_gold = _get_def_int(enemy_def, "reward_gold", reward_gold)
	leak_damage = _get_def_int(enemy_def, "leak_damage", leak_damage)
	color = _get_def_color(enemy_def, "color", color)
	flat_damage_reduction = _get_def_int(enemy_def, "flat_damage_reduction", flat_damage_reduction)
	queue_redraw()

func _get_def_string(def: Resource, property_name: String, fallback: String) -> String:
	var value: Variant = def.get(property_name)
	if value == null:
		return fallback
	if value is String:
		return value
	return fallback

func _get_def_float(def: Resource, property_name: String, fallback: float) -> float:
	var value: Variant = def.get(property_name)
	if value == null:
		return fallback
	return float(value)

func _get_def_int(def: Resource, property_name: String, fallback: int) -> int:
	var value: Variant = def.get(property_name)
	if value == null:
		return fallback
	return int(value)

func _get_def_color(def: Resource, property_name: String, fallback: Color) -> Color:
	var value: Variant = def.get(property_name)
	if value == null:
		return fallback
	if value is Color:
		return value
	return fallback

func _update_health_bar() -> void:
	if health_bar == null:
		return
	health_bar.min_value = 0
	health_bar.max_value = max_hp
	health_bar.value = clamp(hp, 0.0, max_hp)

func _configure_health_bar() -> void:
	if health_bar == null:
		return
	var bar_width: float = max(health_bar_width, 6.0)
	var bar_height: float = max(health_bar_height, 2.0)
	health_bar.show_percentage = false
	health_bar.size = Vector2(bar_width, bar_height)
	health_bar.position = Vector2(-bar_width * 0.5, -(radius + health_bar_offset))
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = health_bar_bg_color
	bg.border_width_left = 0
	bg.border_width_top = 0
	bg.border_width_right = 0
	bg.border_width_bottom = 0
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = health_bar_fill_color
	fill.border_width_left = 0
	fill.border_width_top = 0
	fill.border_width_right = 0
	fill.border_width_bottom = 0
	health_bar.add_theme_stylebox_override("background", bg)
	health_bar.add_theme_stylebox_override("fill", fill)
