extends Node2D
class_name BaseMarker

@export var radius: float = 10.0
@export var color: Color = Color.ORANGE_RED
@export var flash_color: Color = Color(1.0, 0.4, 0.3, 0.95)
@export var flash_duration: float = 0.18
@export var flash_scale: float = 1.5
@export var hit_scale_peak: float = 1.12
@export var hit_scale_duration: float = 0.14
@export var shake_distance: float = 8.0
@export var shake_duration: float = 0.16

var flash_until_ms: int = 0
var hit_tween: Tween
var base_scale: Vector2 = Vector2.ONE
var base_position: Vector2 = Vector2.ZERO
var shake_tween: Tween

func _ready() -> void:
	base_position = position
	queue_redraw()
	set_process(true)

func _process(delta: float) -> void:
	if flash_until_ms > 0 and Time.get_ticks_msec() > flash_until_ms:
		flash_until_ms = 0
		queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, color)
	if flash_until_ms > 0:
		draw_circle(Vector2.ZERO, radius * flash_scale, flash_color)

func trigger_flash() -> void:
	flash_until_ms = Time.get_ticks_msec() + int(flash_duration * 1000.0)
	_play_hit_tween()
	_play_shake_tween()
	_play_base_hit_sfx()
	queue_redraw()

func _play_hit_tween() -> void:
	if hit_tween and hit_tween.is_running():
		hit_tween.kill()
	base_scale = Vector2.ONE
	set_scale(base_scale)
	hit_tween = create_tween()
	hit_tween.tween_property(self, "scale", Vector2.ONE * hit_scale_peak, hit_scale_duration * 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	hit_tween.tween_property(self, "scale", Vector2.ONE, hit_scale_duration * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _play_base_hit_sfx() -> void:
	var audio_manager: AudioManager = get_tree().get_first_node_in_group("audio_manager") as AudioManager
	if audio_manager != null and audio_manager.has_method("play_base_hit"):
		print("BASE HIT SFX")
		audio_manager.play_base_hit()
	else:
		print("BASE HIT SFX — AudioManager not found! audio_manager=", audio_manager)

func _play_shake_tween() -> void:
	if shake_distance <= 0.0 or shake_duration <= 0.0:
		return
	if shake_tween and shake_tween.is_running():
		shake_tween.kill()
	position = base_position
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var offset: Vector2 = Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)).normalized() * shake_distance
	shake_tween = create_tween()
	shake_tween.tween_property(self, "position", base_position + offset, shake_duration * 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	shake_tween.tween_property(self, "position", base_position, shake_duration * 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
