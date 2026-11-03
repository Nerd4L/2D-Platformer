extends Enemy
class_name BrontoBurt

enum Behavior {
	WAVE,    # Sinusoidal wave flight
	DIVE,    # Hovers, then swoops down when Kirby approaches
	BOUNCE,   # Diagonal 45-degree bounce off ceiling/floors
	VERTICAL  # Up-and-down patrol
}

const TILE_SIZE: float = 16.0

@export_category("Enemy Type")
@export var is_flying: bool = true # Tells the spawner never to snap him to the floor!

@export_category("Bronto Burt Behavior")
@export var behavior: Behavior = Behavior.WAVE
@export var patrol_tiles: float = 0.0 # 0 = infinite, >0 = turns after X tiles
@export var start_facing_left: bool = true
@export var start_moving_down: bool = true

@export_category("Flight Speeds")
@export var flight_speed_x: float = 38.0
@export var flight_speed_y: float = 24.0
@export var dive_speed: float = 64.0

@export_category("Wave Tuning")
@export var wave_frequency: float = 4.5
@export var wave_amplitude: float = 16.0

@export_category("Dive / Ambush Tuning")
@export var dive_detection_tiles: float = 6.0
@export var telegraph_duration: float = 0.22

var wave_phase: float = 0.0
var time_alive: float = 0.0
var fly_start_x: float = 0.0
var bounce_dir_y: float = 1.0

var move_dir_y: float = 1.0
var fly_start_y: float = 0.0

enum DiveState { HOVER, TELEGRAPH, DIVING, RECOVER }
var dive_state: DiveState = DiveState.HOVER
var dive_target_pos: Vector2 = Vector2.ZERO
var dive_timer: float = 0.0


func _enemy_ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	
	inhale_score = 200
	defeat_score = 400
	
	move_dir = -1.0 if start_facing_left else 1.0
	move_dir_y = 1.0 if start_moving_down else -1.0
	fly_start_x = global_position.x
	fly_start_y = global_position.y
	bounce_dir_y = 1.0
	
	update_sprite_direction()
	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation("bronto_fly"):
		anim_sprite.play("bronto_fly")


func set_behavior(new_behavior: int, new_patrol_tiles: float = 0.0) -> void:
	behavior = new_behavior as Behavior
	patrol_tiles = new_patrol_tiles
	fly_start_x = global_position.x
	fly_start_y = global_position.y
	dive_state = DiveState.HOVER


func _physics_process(delta: float) -> void:
	if state == State.BEING_INHALED:
		process_inhale(delta)
		return

	time_alive += delta

	match behavior:
		Behavior.WAVE:
			_process_wave(delta)
		Behavior.DIVE:
			_process_dive(delta)
		Behavior.BOUNCE:
			_process_bounce(delta)
		Behavior.VERTICAL:
			_process_vertical(delta)

	move_and_slide()
	update_sprite_direction()


# --- BEHAVIOR 1: WAVE FLIGHT ---
func _process_wave(delta: float) -> void:
	wave_phase += wave_frequency * delta
	velocity.x = move_dir * flight_speed_x
	velocity.y = -cos(wave_phase) * wave_amplitude
	
	var max_patrol_px: float = patrol_tiles * TILE_SIZE
	if max_patrol_px > 0.0:
		var dist_traveled: float = absf(global_position.x - fly_start_x)
		if dist_traveled >= max_patrol_px:
			_turn_around()

	for i in get_slide_collision_count():
		var norm := get_slide_collision(i).get_normal()

		# 1. Hit from above (pillar top / floor) -> reset wave to climb upward
		if norm.y < -0.5:
			wave_phase = -PI * 0.5 # sin(-PI/2) = -1.0 (maximum upward flight)
			velocity.y = -wave_amplitude

		# 2. Hit from below (ceiling / overhang) -> reset wave to dive downward
		elif norm.y > 0.5:
			wave_phase = PI * 0.5 # sin(PI/2) = 1.0 (maximum downward flight)
			velocity.y = wave_amplitude

		# 3. Hit wall head-on -> turn around horizontally
		elif absf(norm.x) > 0.6 and signf(norm.x) != signf(move_dir):
			_turn_around()


# --- BEHAVIOR 2: AMBUSH DIVE ---
func _process_dive(delta: float) -> void:
	var kirby := get_tree().get_first_node_in_group("player") as Node2D

	match dive_state:
		DiveState.HOVER:
			# Gentle vertical bob while waiting
			velocity.x = 0.0
			velocity.y = sin(time_alive * 5.0) * 10.0

			if is_instance_valid(kirby):
				var dx: float = kirby.global_position.x - global_position.x
				var dy: float = kirby.global_position.y - global_position.y
				var in_front: bool = (signf(dx) == move_dir)
				var dist_tiles: float = absf(dx) / TILE_SIZE

				# Trigger dive when Kirby is in front and within range
				if in_front and dist_tiles <= dive_detection_tiles and dy > -16.0:
					dive_target_pos = kirby.global_position
					dive_state = DiveState.TELEGRAPH
					dive_timer = telegraph_duration

		DiveState.TELEGRAPH:
			# Rapid shiver pause
			velocity = Vector2(0.0, sin(time_alive * 30.0) * 4.0)
			dive_timer -= delta
			if dive_timer <= 0.0:
				dive_state = DiveState.DIVING

		DiveState.DIVING:
			# Swoop diagonally down toward Kirby's spot
			var swoop_dir: Vector2 = (dive_target_pos - global_position).normalized()
			velocity = swoop_dir * dive_speed

			if global_position.y >= dive_target_pos.y or is_on_wall():
				dive_state = DiveState.RECOVER

		DiveState.RECOVER:
			# Level out and fly forward
			velocity.x = move_dir * flight_speed_x
			velocity.y = move_toward(velocity.y, -flight_speed_x * 0.4, 80.0 * delta)

			if is_on_wall():
				var wall_norm: Vector2 = get_wall_normal()
				if signf(wall_norm.x) != signf(move_dir):
					_turn_around()


# --- BEHAVIOR 3: DIAGONAL BOUNCE ---
func _process_bounce(_delta: float) -> void:
	velocity.x = move_dir * flight_speed_x
	velocity.y = bounce_dir_y * flight_speed_y

	# Inspect slide collisions directly (works on hills, steps, floors, and ceilings!)
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var norm := col.get_normal()

		# Hit a floor (normal pointing UP) -> bounce upward
		if norm.y < -0.6 and bounce_dir_y > 0.0:
			bounce_dir_y = -1.0
		# Hit a ceiling (normal pointing DOWN) -> bounce downward
		elif norm.y > 0.6 and bounce_dir_y < 0.0:
			bounce_dir_y = 1.0

		# Hit a wall / hill step (normal pointing LEFT or RIGHT) -> bounce horizontally
		if absf(norm.x) > 0.6 and signf(norm.x) != signf(move_dir):
			move_dir = signf(norm.x)
			fly_start_x = global_position.x

# --- BEHAVIOR 4: VERTICAL PATROL ---
func _process_vertical(_delta: float) -> void:
	velocity.x = 0.0
	velocity.y = move_dir_y * flight_speed_y

	# Distance patrol limit (along Y axis)
	var max_patrol_px: float = patrol_tiles * TILE_SIZE
	if max_patrol_px > 0.0:
		var dist_traveled: float = absf(global_position.y - fly_start_y)
		if dist_traveled >= max_patrol_px:
			_turn_around_vertical()

	# Ceiling / floor collision rebound
	for i in get_slide_collision_count():
		var norm := get_slide_collision(i).get_normal()
		if absf(norm.y) > 0.6 and signf(norm.y) != signf(move_dir_y):
			_turn_around_vertical()

func _turn_around() -> void:
	move_dir *= -1.0
	fly_start_x = global_position.x
	update_sprite_direction()

func _turn_around_vertical() -> void:
	move_dir_y *= -1.0
	fly_start_y = global_position.y
