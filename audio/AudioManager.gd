extends Node
class_name AudioManager

@export var shot_pitch_hz: float = 880.0
@export var death_pitch_hz: float = 260.0
@export var base_hit_pitch_hz: float = 180.0
@export var spawn_pitch_hz: float = 520.0
@export var tower_place_pitch_hz: float = 640.0

@export var shot_duration_sec: float = 0.06
@export var death_duration_sec: float = 0.14
@export var base_hit_duration_sec: float = 0.12
@export var spawn_duration_sec: float = 0.08
@export var tower_place_duration_sec: float = 0.1

@export var shot_volume_db: float = -10.0
@export var death_volume_db: float = -8.0
@export var base_hit_volume_db: float = -6.0
@export var spawn_volume_db: float = -10.0
@export var tower_place_volume_db: float = -8.0

@export var shot_min_interval_sec: float = 0.05
@export var death_min_interval_sec: float = 0.08
@export var base_hit_min_interval_sec: float = 0.1
@export var spawn_min_interval_sec: float = 0.05
@export var tower_place_min_interval_sec: float = 0.08

@export var waveform_gain: float = 0.6
@export var sample_rate: int = 22050
@export var envelope_attack_sec: float = 0.005
@export var envelope_release_sec: float = 0.02

var shot_player: AudioStreamPlayer
var death_player: AudioStreamPlayer
var base_hit_player: AudioStreamPlayer
var spawn_player: AudioStreamPlayer
var tower_place_player: AudioStreamPlayer

var last_shot_ms: int = -100000
var last_death_ms: int = -100000
var last_base_hit_ms: int = -100000
var last_spawn_ms: int = -100000
var last_tower_place_ms: int = -100000


func _ready() -> void:
	add_to_group("audio_manager")

	shot_player = _make_player(shot_volume_db)
	death_player = _make_player(death_volume_db)
	base_hit_player = _make_player(base_hit_volume_db)
	spawn_player = _make_player(spawn_volume_db)
	tower_place_player = _make_player(tower_place_volume_db)

	add_child(shot_player)
	add_child(death_player)
	add_child(base_hit_player)
	add_child(spawn_player)
	add_child(tower_place_player)

	_refresh_streams()


func play_shot() -> void:
	if not _can_play(shot_min_interval_sec, last_shot_ms):
		return
	last_shot_ms = Time.get_ticks_msec()
	_restart_player(shot_player)


func play_enemy_death() -> void:
	if not _can_play(death_min_interval_sec, last_death_ms):
		return
	last_death_ms = Time.get_ticks_msec()
	_restart_player(death_player)


func play_base_hit() -> void:
	if not _can_play(base_hit_min_interval_sec, last_base_hit_ms):
		return
	last_base_hit_ms = Time.get_ticks_msec()
	_restart_player(base_hit_player)


func play_enemy_spawn() -> void:
	if not _can_play(spawn_min_interval_sec, last_spawn_ms):
		return
	last_spawn_ms = Time.get_ticks_msec()
	_restart_player(spawn_player)


func play_tower_place() -> void:
	if not _can_play(tower_place_min_interval_sec, last_tower_place_ms):
		return
	last_tower_place_ms = Time.get_ticks_msec()
	_restart_player(tower_place_player)


func _refresh_streams() -> void:
	if shot_player:
		shot_player.stream = _generate_beep(shot_pitch_hz, shot_duration_sec)
	if death_player:
		death_player.stream = _generate_beep(death_pitch_hz, death_duration_sec)
	if base_hit_player:
		base_hit_player.stream = _generate_beep(base_hit_pitch_hz, base_hit_duration_sec)
	if spawn_player:
		spawn_player.stream = _generate_beep(spawn_pitch_hz, spawn_duration_sec)
	if tower_place_player:
		tower_place_player.stream = _generate_beep(tower_place_pitch_hz, tower_place_duration_sec)


func _make_player(volume_db_value: float) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.volume_db = volume_db_value
	player.max_polyphony = 1
	return player


func _restart_player(player: AudioStreamPlayer) -> void:
	if player == null:
		return
	if player.playing:
		player.stop()
	player.play()


func _can_play(min_interval_sec: float, last_ms: int) -> bool:
	var now_ms: int = Time.get_ticks_msec()
	return now_ms - last_ms >= int(min_interval_sec * 1000.0)


func _generate_beep(frequency_hz: float, duration_sec: float) -> AudioStreamWAV:
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false

	var sample_count: int = max(int(sample_rate * duration_sec), 1)

	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)

	var attack_samples: int = max(int(sample_rate * envelope_attack_sec), 1)
	var release_samples: int = max(int(sample_rate * envelope_release_sec), 1)

	for i: int in range(sample_count):
		var t: float = float(i) / float(sample_rate)
		var sample: float = sin(TAU * frequency_hz * t)

		var envelope: float = 1.0
		if i < attack_samples:
			envelope = float(i) / float(attack_samples)
		elif i > sample_count - release_samples:
			envelope = float(sample_count - i) / float(release_samples)

		var value: int = int(
			clamp(sample * envelope * waveform_gain, -1.0, 1.0) * 32767.0
		)

		data.encode_s16(i * 2, value)

	stream.data = data
	return stream
	