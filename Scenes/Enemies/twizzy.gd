extends Enemy
class_name Twizzy

enum Behavior {
	FLY, # Straight horizontal flight
	HOP  # Ground rhythmic hopping
}

const TILE_SIZE: float = 16.0

@export_category("Enemy Type")
@export var is_flying: bool = true

@export_category("Twizzy Behavior")
@export var behavior: Behavior = Behavior.FLY
@export var patrol_tiles: float = 0.0
@export var start_facing_left: bool = true

@export_category("Fly Tuning")
@export var fly_speed: float = 36.0
@export var fly_wave_frequency: float = 6.0
@export var fly_wave_amplitude: float = 12.0

@export_category("Hop Tuning")
@export var hop_height: float = -60.0
@export var hop_delay: float = 0.55
@export var gravity: float = 100.0
@export var max_fall_speed: float = 135.0

var fly_start_x: float = 0.0
var hop_timer: float = 0.0
var fly_wave_phase: float = 0.0


func _enemy_ready() -> void:
	inhale_score = 200
	defeat_score = 400
	
	move_dir = -1.0 if start_facing_left else 1.0
	fly_start_x = global_position.x
	hop_timer = hop_delay
	
	_apply_mode()
	update_sprite_direction()


func set_behavior(new_behavior: int, new_patrol_tiles: float = 0.0) -> void:
	behavior = new_behavior as Behavior
	patrol_tiles = new_patrol_tiles
	fly_start_x = global_position.x
	_apply_mode()


func _apply_mode() -> void:
	if behavior == Behavior.FLY:
		is_flying = true
		motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
		anim_sprite.play("twizzy_flap")
	else:
		is_flying = false
		motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
		anim_sprite.play("twizzy_idle")


func _physics_process(delta: float) -> void:
	if state == State.BEING_INHALED:
		process_inhale(delta)
		return

	match behavior:
		Behavior.FLY:
			_process_fly(delta)
		Behavior.HOP:
			_process_hop(delta)

	move_and_slide()
	update_sprite_direction()


# --- BEHAVIOR 1: STRAIGHT HORIZONTAL FLIGHT ---
func _process_fly(delta: float) -> void:
	fly_wave_phase += fly_wave_frequency * delta
	velocity.x = move_dir * fly_speed
	velocity.y = -cos(fly_wave_phase) * fly_wave_amplitude

	var max_patrol_px: float = patrol_tiles * TILE_SIZE
	if max_patrol_px > 0.0:
		if absf(global_position.x - fly_start_x) >= max_patrol_px:
			_turn_around()

	for i in get_slide_collision_count():
		var norm := get_slide_collision(i).get_normal()
		if absf(norm.x) > 0.6 and signf(norm.x) != signf(move_dir):
			_turn_around()


# --- BEHAVIOR 2: GROUND HOPPING ---
func _process_hop(delta: float) -> void:
	# 1. Strictly in-place (no horizontal drift)
	velocity.x = 0.0

	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)

		# 2. Animation state during the hop
		if anim_sprite and anim_sprite.sprite_frames:
			if velocity.y < 0.0:
				# Flap on the way up (1.6x speed completes exactly 2 flaps before apex)
				anim_sprite.speed_scale = 1.6
				anim_sprite.play("twizzy_flap")
			else:
				# Fall animation on the way down
				anim_sprite.speed_scale = 1.0
				anim_sprite.play("twizzy_fall")
	else:
		velocity.y = 0.0
		hop_timer -= delta

		if hop_timer <= 0.0:
			hop_timer = hop_delay
			velocity.y = hop_height
		else:
			anim_sprite.speed_scale = 1.0
			anim_sprite.play("twizzy_idle")


func _turn_around() -> void:
	move_dir *= -1.0
	fly_start_x = global_position.x
	update_sprite_direction()
