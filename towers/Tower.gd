extends Node2D
class_name Tower

signal clicked(tower: Tower)

const TARGETING_FIRST: int = 0
const TARGETING_LAST: int = 1
const TARGETING_STRONG: int = 2

@export var tower_def: TowerDef
@export var range: float = 120.0
@export var damage: float = 2.0
@export var splash_radius: float = 0.0
@export var splash_multiplier: float = 0.0
@export var splash_debug_enabled: bool = false
@export var splash_debug_radius_multiplier: float = 2.5
@export var splash_vfx_color: Color = Color(0.6, 0.9, 1.0, 0.7)
@export var splash_vfx_duration: float = 0.25
@export var shots_per_second: float = 1.0
@export var cooldown_sec: float = 1.0
@export var projectile_speed: float = 520.0
@export var targeting_policy: int = TARGETING_FIRST
@export var radius: float = 10.0
@export var color: Color = Color.SKY_BLUE
@export var shot_color: Color = Color(1.0, 0.95, 0.6, 0.95)
@export var muzzle_flash_radius: float = 7.0
@export var tracer_width: float = 2.5
@export var tracer_hit_radius: float = 4.0
@export var shot_flash_duration: float = 0.10
@export var range_color: Color = Color(0.3, 0.6, 1.0, 0.25)
@export var range_outline_color: Color = Color(0.3, 0.6, 1.0, 0.6)
@export var range_indicator_duration: float = 1.0
@export var selected_outline_color: Color = Color(1.0, 0.95, 0.4, 0.85)
@export var selected_outline_width: float = 2.0
@export var selected_outline_scale: float = 1.5

@onready var range_area: Area2D = $RangeArea
@onready var range_shape: CollisionShape2D = $RangeArea/CollisionShape2D
@onready var select_area: Area2D = $SelectArea
@onready var attack_timer: Timer = $AttackTimer

var enemies_in_range: Array[Enemy] = []
var current_target: Enemy
var range_indicator_until_ms: int = 0
var shot_flash_until_ms: int = 0
var is_selected: bool = false
var build_spot: BuildSpot

class SplashImpact:
	extends Node2D

	var radius: float = 0.0
	var base_color: Color = Color(1.0, 1.0, 1.0, 1.0)
	var duration: float = 0.25
	var tween: Tween

	func _init(new_radius: float, new_color: Color, new_duration: float) -> void:
		radius = new_radius
		base_color = new_color
		duration = new_duration

	func _ready() -> void:
		scale = Vector2.ONE * 0.6
		modulate = Color(base_color.r, base_color.g, base_color.b, 0.6)
		tween = create_tween()
		tween.tween_property(self, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(self, "modulate", Color(base_color.r, base_color.g, base_color.b, 0.0), duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.tween_callback(queue_free)

	func _draw() -> void:
		draw_circle(Vector2.ZERO, radius, Color(base_color.r, base_color.g, base_color.b, 1.0))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(base_color.r, base_color.g, base_color.b, 1.0), 2.0)

class Projectile:
	extends Node2D

	var target: Enemy
	var speed: float = 400.0
	var damage: float = 1.0
	var splash_radius: float = 0.0
	var splash_multiplier: float = 0.0
	var shot_color: Color = Color.WHITE
	var hit_radius: float = 6.0
	var trail_length: float = 10.0
	var trail_width: float = 2.0
	var last_target_pos: Vector2 = Vector2.ZERO
	var last_dir: Vector2 = Vector2.RIGHT
	var tower: Tower

	func _init(new_target: Enemy, new_speed: float, new_damage: float, new_splash_radius: float, new_splash_multiplier: float, new_color: Color, new_tower: Tower) -> void:
		target = new_target
		speed = new_speed
		damage = new_damage
		splash_radius = new_splash_radius
		splash_multiplier = new_splash_multiplier
		shot_color = new_color
		tower = new_tower

	func _ready() -> void:
		if target != null and is_instance_valid(target):
			last_target_pos = target.global_position
		set_process(true)
		queue_redraw()

	func _process(delta: float) -> void:
		var target_pos: Vector2 = last_target_pos
		if target != null and is_instance_valid(target):
			target_pos = target.global_position
			last_target_pos = target_pos
		var to_target: Vector2 = target_pos - global_position
		var distance: float = to_target.length()
		if distance <= max(speed * delta, hit_radius):
			_impact()
			return
		if distance > 0.0:
			last_dir = to_target.normalized()
			global_position += to_target.normalized() * speed * delta
		queue_redraw()

	func _draw() -> void:
		var tail_color: Color = shot_color
		tail_color.a *= 0.6
		draw_line(Vector2.ZERO, -last_dir * trail_length, tail_color, trail_width)
		draw_circle(Vector2.ZERO, hit_radius, shot_color)

	func _impact() -> void:
		if tower != null:
			tower._on_projectile_impact(self)
		queue_free()

class ImpactVfx:
	extends Node2D

	var radius: float = 6.0
	var base_color: Color = Color.WHITE
	var duration: float = 0.12
	var alpha: float = 1.0
	var scale_value: float = 0.6
	var tween: Tween

	func _init(new_radius: float, new_color: Color, new_duration: float) -> void:
		radius = new_radius
		base_color = new_color
		duration = new_duration

	func _ready() -> void:
		scale_value = 0.7
		alpha = 0.9
		set_process(true)
		tween = create_tween()
		tween.tween_property(self, "scale_value", 1.35, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(self, "alpha", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.tween_callback(queue_free)

	func _process(delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var draw_color: Color = base_color
		draw_color.a *= alpha
		draw_arc(Vector2.ZERO, radius * scale_value, 0.0, TAU, 24, draw_color, 2.0)

func _ready() -> void:
	_apply_tower_def()
	if attack_timer:
		attack_timer.wait_time = _get_attack_cooldown_sec()
		attack_timer.timeout.connect(_on_attack_timer_timeout)
		attack_timer.start()
	_sync_range_shape()
	if range_area:
		range_area.area_entered.connect(_on_range_area_entered)
		range_area.area_exited.connect(_on_range_area_exited)
	if select_area:
		select_area.input_event.connect(_on_select_area_input)
	show_range_indicator(range_indicator_duration)
	queue_redraw()

func _process(delta: float) -> void:
	_prune_invalid_enemies()
	_update_target()
	if range_indicator_until_ms > 0 and Time.get_ticks_msec() > range_indicator_until_ms:
		range_indicator_until_ms = 0
		queue_redraw()
	if shot_flash_until_ms > 0 and Time.get_ticks_msec() > shot_flash_until_ms:
		shot_flash_until_ms = 0
		queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, color)
	if is_selected:
		draw_arc(Vector2.ZERO, radius * selected_outline_scale, 0.0, TAU, 64, selected_outline_color, selected_outline_width)
	if range_indicator_until_ms > 0:
		draw_circle(Vector2.ZERO, range, range_color)
		draw_arc(Vector2.ZERO, range, 0.0, TAU, 64, range_outline_color, 2.0)
	if shot_flash_until_ms > 0:
		draw_circle(Vector2.ZERO, muzzle_flash_radius, shot_color)

func show_range_indicator(duration_sec: float = 1.0) -> void:
	range_indicator_until_ms = Time.get_ticks_msec() + int(duration_sec * 1000.0)
	queue_redraw()

func _sync_range_shape() -> void:
	if range_shape == null:
		return
	var circle: CircleShape2D = range_shape.shape as CircleShape2D
	if circle == null:
		circle = CircleShape2D.new()
		range_shape.shape = circle
	circle.radius = range

func _on_range_area_entered(area: Area2D) -> void:
	var enemy: Enemy = _resolve_enemy_from_area(area)
	if enemy == null:
		return
	if not enemies_in_range.has(enemy):
		enemies_in_range.append(enemy)
		_update_target()

func _on_range_area_exited(area: Area2D) -> void:
	var enemy: Enemy = _resolve_enemy_from_area(area)
	if enemy == null:
		return
	enemies_in_range.erase(enemy)
	_update_target()

func _resolve_enemy_from_area(area: Area2D) -> Enemy:
	if area == null:
		return null
	var node: Node = area
	while node:
		if node is Enemy:
			return node as Enemy
		node = node.get_parent()
	return null

func _prune_invalid_enemies() -> void:
	for i in range(enemies_in_range.size() - 1, -1, -1):
		if not is_instance_valid(enemies_in_range[i]):
			enemies_in_range.remove_at(i)

func _update_target() -> void:
	var best: Enemy = choose_target(enemies_in_range, get_targeting_policy())
	if best != current_target:
		current_target = best
		queue_redraw()

func get_targeting_policy() -> int:
	if tower_def != null:
		var policy_value: Variant = tower_def.get("targeting_policy")
		if policy_value != null:
			return int(policy_value)
	return targeting_policy

func choose_target(candidates: Array, policy: int) -> Enemy:
	var best: Enemy = null
	var best_progress: float = 0.0
	var best_hp: float = 0.0
	var best_id: int = 0
	var has_best: bool = false
	for candidate in candidates:
		var enemy: Enemy = candidate as Enemy
		if enemy == null:
			continue
		if not is_instance_valid(enemy):
			continue
		var progress: float = _get_enemy_progress(enemy)
		var hp_value: float = _get_enemy_hp(enemy)
		var instance_id: int = enemy.get_instance_id()
		if not has_best:
			best = enemy
			best_progress = progress
			best_hp = hp_value
			best_id = instance_id
			has_best = true
			continue
		if policy == TARGETING_LAST:
			if progress < best_progress:
				best = enemy
				best_progress = progress
				best_hp = hp_value
				best_id = instance_id
				continue
			if progress == best_progress:
				if hp_value > best_hp:
					best = enemy
					best_hp = hp_value
					best_id = instance_id
					continue
				if hp_value == best_hp and instance_id < best_id:
					best = enemy
					best_id = instance_id
					continue
			continue
		if policy == TARGETING_STRONG:
			if hp_value > best_hp:
				best = enemy
				best_hp = hp_value
				best_progress = progress
				best_id = instance_id
				continue
			if hp_value == best_hp:
				if progress > best_progress:
					best = enemy
					best_progress = progress
					best_id = instance_id
					continue
				if progress == best_progress and instance_id < best_id:
					best = enemy
					best_id = instance_id
					continue
			continue
		if progress > best_progress:
			best = enemy
			best_progress = progress
			best_hp = hp_value
			best_id = instance_id
			continue
		if progress == best_progress:
			if hp_value > best_hp:
				best = enemy
				best_hp = hp_value
				best_id = instance_id
				continue
			if hp_value == best_hp and instance_id < best_id:
				best = enemy
				best_id = instance_id
				continue
	return best

func _get_enemy_progress(enemy: Enemy) -> float:
	var follow: PathFollow2D = _get_enemy_follow(enemy)
	if follow:
		return follow.progress_ratio
	return 0.0

func _get_enemy_hp(enemy: Enemy) -> float:
	if enemy == null:
		return 0.0
	var hp_value: Variant = enemy.get("hp")
	if hp_value != null:
		return float(hp_value)
	var max_value: Variant = enemy.get("max_hp")
	if max_value != null:
		return float(max_value)
	return 0.0

func _get_enemy_follow(enemy: Enemy) -> PathFollow2D:
	if enemy == null:
		return null
	if enemy.path_follow:
		return enemy.path_follow
	var parent: Node = enemy.get_parent()
	if parent is PathFollow2D:
		return parent
	if parent and parent.get_parent() is PathFollow2D:
		return parent.get_parent()
	return null

func _on_attack_timer_timeout() -> void:
	_update_target()
	if current_target == null:
		return
	if not is_instance_valid(current_target):
		return
	if not enemies_in_range.has(current_target):
		return
	_perform_attack(current_target)

func _perform_attack(target: Enemy) -> void:
	if target == null or not is_instance_valid(target):
		return
	_trigger_shot_flash(target)
	_play_shot_sfx()
	_spawn_projectile(target)

func _spawn_projectile(target: Enemy) -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var speed_value: float = max(projectile_speed, 1.0)
	var projectile: Projectile = Projectile.new(target, speed_value, damage, splash_radius, splash_multiplier, shot_color, self)
	parent_node.add_child(projectile)
	projectile.global_position = global_position

func _on_projectile_impact(projectile: Projectile) -> void:
	if projectile == null:
		return
	_spawn_projectile_impact_vfx(projectile.global_position, projectile.hit_radius, projectile.shot_color)
	if projectile.target != null and is_instance_valid(projectile.target):
		projectile.target.apply_damage(projectile.damage)
		_apply_splash_damage_at(projectile.target, projectile.damage)

func _spawn_projectile_impact_vfx(world_pos: Vector2, radius_value: float, color_value: Color) -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var impact_radius: float = max(radius_value * 1.8, 6.0)
	var impact: ImpactVfx = ImpactVfx.new(impact_radius, color_value, 0.12)
	parent_node.add_child(impact)
	impact.global_position = world_pos

func _apply_splash_damage_at(primary: Enemy, base_damage: float) -> void:
	if splash_radius <= 0.0 or splash_multiplier <= 0.0:
		return
	if primary == null or not is_instance_valid(primary):
		return
	var primary_pos: Vector2 = primary.global_position
	var splash_damage: float = base_damage * splash_multiplier
	var effective_radius: float = splash_radius * splash_debug_radius_multiplier
	var nodes: Array = get_tree().get_nodes_in_group("enemies")
	var hit_count: int = 0
	if splash_debug_enabled:
		print("SPLASH radius=", effective_radius, " base=", splash_radius, " nodes=", nodes.size())
	_spawn_splash_vfx(primary_pos, effective_radius)
	for node: Node in nodes:
		var enemy: Enemy = node as Enemy
		if enemy == null:
			continue
		if enemy == primary:
			continue
		if not is_instance_valid(enemy):
			continue
		var distance: float = enemy.global_position.distance_to(primary_pos)
		if splash_debug_enabled:
			print("SPLASH check enemy=", enemy.name, " dist=", distance)
		if distance <= effective_radius:
			enemy.apply_damage(splash_damage)
			hit_count += 1
	if splash_debug_enabled:
		print("SPLASH hit_count=", hit_count)

func _spawn_splash_vfx(world_pos: Vector2, radius_value: float) -> void:
	if radius_value <= 0.0:
		return
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var splash_vfx: SplashImpact = SplashImpact.new(radius_value, splash_vfx_color, splash_vfx_duration)
	parent_node.add_child(splash_vfx)
	splash_vfx.global_position = world_pos

func _trigger_shot_flash(target: Enemy) -> void:
	shot_flash_until_ms = Time.get_ticks_msec() + int(shot_flash_duration * 1000.0)
	queue_redraw()

func _play_shot_sfx() -> void:
	var audio_manager: AudioManager = get_tree().get_first_node_in_group("audio_manager") as AudioManager
	if audio_manager != null and audio_manager.has_method("play_shot"):
		print("SHOT SFX")
		audio_manager.play_shot()
	else:
		print("SHOT SFX — AudioManager not found! audio_manager=", audio_manager)

func _apply_tower_def() -> void:
	if tower_def == null:
		return
	range = _get_def_float(tower_def, "range", range)
	damage = _get_def_float(tower_def, "damage", damage)
	shots_per_second = _get_def_float(tower_def, "shots_per_second", shots_per_second)
	cooldown_sec = _get_def_float(tower_def, "cooldown_sec", cooldown_sec)
	projectile_speed = _get_def_float(tower_def, "projectile_speed", projectile_speed)
	splash_radius = _get_def_float(tower_def, "splash_radius", splash_radius)
	splash_multiplier = _get_def_float(tower_def, "splash_multiplier", splash_multiplier)
	targeting_policy = _get_def_int(tower_def, "targeting_policy", targeting_policy)
	queue_redraw()

func apply_new_def(new_def: TowerDef) -> void:
	if new_def == null:
		return
	tower_def = new_def
	_apply_tower_def()
	_sync_range_shape()
	if attack_timer:
		attack_timer.wait_time = _get_attack_cooldown_sec()
		if not attack_timer.is_stopped():
			attack_timer.start()
	queue_redraw()

func set_selected(selected: bool) -> void:
	is_selected = selected
	queue_redraw()

func _on_select_area_input(viewport: Viewport, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)

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

func _get_attack_cooldown_sec() -> float:
	if tower_def != null:
		var sps_value: Variant = tower_def.get("shots_per_second")
		if sps_value != null:
			var sps: float = float(sps_value)
			if sps > 0.0:
				return 1.0 / sps
		var cooldown_value: Variant = tower_def.get("cooldown_sec")
		if cooldown_value != null:
			return max(float(cooldown_value), 0.01)
	if shots_per_second > 0.0:
		return 1.0 / shots_per_second
	return max(cooldown_sec, 0.01)
