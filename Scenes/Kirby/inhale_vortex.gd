class_name InhaleVortex
extends Node2D

signal enemy_caught(enemy: Node2D)

@export var particle_texture: Texture2D
@export var detection_area: Area2D
@export var range_max: float = 40.0
@export var range_min: float = 16.0
@export var funnel_half_height: float = 16.0
@export var spawn_jitter: float = 4.5
@export var min_speed: float = 100.0
@export var max_speed: float = 160.0
@export var mouth_x: float = 2.0
@export_range(1.0, 2.0) var vortex_curve: float = 1.15

var is_active: bool = false
var inhaling_enemies: Array[Node2D] = []
var active_particles: Array[Sprite2D] = []

func _ready() -> void:
	if detection_area:
		detection_area.monitoring = false

func start() -> void:
	is_active = true
	if detection_area:
		detection_area.monitoring = true

func stop() -> void:
	is_active = false
	if detection_area:
		detection_area.monitoring = false
	_clear_particles()

func has_airborne_targets() -> bool:
	_cleanup_invalid_enemies()
	return not inhaling_enemies.is_empty()

func reset() -> void:
	stop()
	inhaling_enemies.clear()

func _physics_process(delta: float) -> void:
	_cleanup_invalid_enemies()
	_check_area_targets()
	_update_particles(delta)

func _cleanup_invalid_enemies() -> void:
	for i in range(inhaling_enemies.size() - 1, -1, -1):
		if not is_instance_valid(inhaling_enemies[i]):
			inhaling_enemies.remove_at(i)

func _check_area_targets() -> void:
	if not is_active or not detection_area:
		return
	for body in detection_area.get_overlapping_bodies():
		if body.is_in_group("inhaleable") and body.has_method("start_inhale"):
			if not inhaling_enemies.has(body):
				inhaling_enemies.append(body)
				body.start_inhale(get_parent())

func on_target_reached_mouth(target: Node2D) -> void:
	inhaling_enemies.erase(target)
	enemy_caught.emit(target)
	if inhaling_enemies.is_empty() and not is_active:
		stop()

func _update_particles(delta: float) -> void:
	if is_active and particle_texture and active_particles.is_empty():
		_spawn_particle_cluster()

	for i in range(active_particles.size() - 1, -1, -1):
		var p := active_particles[i]
		if not is_instance_valid(p):
			active_particles.remove_at(i)
			continue
		if not is_active:
			p.queue_free()
			active_particles.remove_at(i)
			continue

		var x_rem: float = maxf(p.position.x - mouth_x, 1.0)
		var x_rat: float = clampf(x_rem / maxf(range_max - mouth_x, 1.0), 0.0, 1.0)
		var speed_x: float = lerpf(max_speed, min_speed, x_rat)
		var t_mouth: float = x_rem / maxf(speed_x, 1.0)
		var speed_y: float = (abs(p.position.y) / maxf(t_mouth, 0.01)) * vortex_curve

		p.position.x = move_toward(p.position.x, mouth_x, speed_x * delta)
		p.position.y = move_toward(p.position.y, 0.0, speed_y * delta)

		if p.position.x <= mouth_x + 0.5:
			p.queue_free()
			active_particles.remove_at(i)

func _spawn_particle_cluster() -> void:
	var chosen: Array[Vector2] = []
	for i in range(3):
		var p := Sprite2D.new()
		p.texture = particle_texture
		p.z_index = -1
		var spawn_pos := Vector2.ZERO

		for attempt in range(10):
			var mid_x: float = lerpf(range_min, range_max, 0.5)
			var start_x: float = randf_range(mid_x, range_max) if randf() < 0.7 else randf_range(range_min, mid_x)
			var lane_t: float = float(randi_range(0, 6)) / 6.0
			var base_y: float = lerpf(-funnel_half_height, funnel_half_height, lane_t)
			spawn_pos = Vector2(start_x + randf_range(-spawn_jitter, spawn_jitter), base_y + randf_range(-spawn_jitter, spawn_jitter))

			var too_close: bool = false
			for other in chosen:
				if spawn_pos.distance_to(other) < 11.0:
					too_close = true
					break
			if not too_close:
				break

		chosen.append(spawn_pos)
		p.position = spawn_pos
		add_child(p)
		active_particles.append(p)

func _clear_particles() -> void:
	for p in active_particles:
		if is_instance_valid(p):
			p.queue_free()
	active_particles.clear()
