extends Enemy
class_name WaddleDee

enum Behavior {
	PATROL,     # standard walk + obstacle hopping
	SLIDE,      # flat sliding/skating speed
	SLOW_WALK   # slow patrol
}

@export_category("Waddle Dee Behavior")
@export var behavior: Behavior = Behavior.PATROL:
	set(val):
		behavior = val
		if is_node_ready():
			apply_behavior_settings()

const TILE_SIZE: float = 16.0
@export var patrol_tiles: float = 0.0 # 0 = infinite, >0 = turn after X pixels
@export var start_facing_left: bool = true
@export var turns_at_ledges: bool = false
@export var turn_ease_time: float = 0.5

@export_category("Physics Tuning")
@export var move_speed: float = 32.0
@export var normal_walk_speed: float = 32.0
@export var slide_speed: float = 52.0
@export var slow_walk_speed: float = 14.0
@export var jump_velocity: float = -135.0
@export var gravity: float = 420.0
@export var max_fall_speed: float = 135.0

var can_jump_obstacles: bool = true

# Strict distance & turnaround tracking
var walk_start_x: float = 0.0
var is_turning: bool = false
var decel_rate: float = 0.0


func _enemy_ready() -> void:
	move_dir = -1.0 if start_facing_left else 1.0
	walk_start_x = global_position.x
	is_turning = false
	update_sprite_direction()
	apply_behavior_settings()


func set_behavior(new_behavior: int, new_patrol_tiles: float = 0.0) -> void:
	behavior = new_behavior as Behavior
	patrol_tiles = new_patrol_tiles
	walk_start_x = global_position.x
	is_turning = false
	apply_behavior_settings()


func apply_behavior_settings() -> void:
	if not anim_sprite:
		anim_sprite = get_node_or_null("AnimatedSprite2D")

	match behavior:
		Behavior.PATROL:
			move_speed = normal_walk_speed
			can_jump_obstacles = true
			anim_sprite.speed_scale = 1
			anim_sprite.play("waddle_dee_walk")

		Behavior.SLIDE:
			move_speed = slide_speed
			can_jump_obstacles = false
			anim_sprite.speed_scale = 1.0
			anim_sprite.play("waddle_dee_slide")

		Behavior.SLOW_WALK:
			move_speed = slow_walk_speed
			can_jump_obstacles = true
			anim_sprite.speed_scale = 0.5
			anim_sprite.play("waddle_dee_walk")


func _physics_process(delta: float) -> void:
	if state == State.BEING_INHALED:
		process_inhale(delta)
		return

	_process_movement(delta)


func _process_movement(delta: float) -> void:
	# 1. Gravity
	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)

	# 2. Check if we should start braking for our patrol limit
	var dist_from_start: float = absf(global_position.x - walk_start_x)
	var max_patrol_px: float = patrol_tiles * TILE_SIZE
	
	if max_patrol_px > 0.0 and is_on_floor() and not is_turning:
		# Braking distance: d = 0.5 * v * t (capped at half the total patrol so he never brakes immediately)
		var stop_dist: float = minf(0.5 * move_speed * turn_ease_time, max_patrol_px * 0.5)
		var brake_threshold: float = max_patrol_px - stop_dist
		
		if dist_from_start >= brake_threshold:
			_start_deceleration(stop_dist)

	# 3. Turn Ease Execution (Decelerating)
	if is_turning:
		velocity.x = move_toward(velocity.x, 0.0, decel_rate * delta)
		move_and_slide()

		var current_dist: float = absf(global_position.x - walk_start_x)
		
		# Stop & flip when speed hits 0 OR when physical distance reaches patrol_distance
		if is_zero_approx(velocity.x) or (max_patrol_px > 0.0 and current_dist >= max_patrol_px):
			if max_patrol_px > 0.0:
				global_position.x = walk_start_x + (move_dir * max_patrol_px)
				
			is_turning = false
			move_dir *= -1.0
			walk_start_x = global_position.x
			update_sprite_direction()
			apply_behavior_settings()
		return

	# 4. Smart Obstacle Jump Check
	if is_on_floor() and can_jump_obstacles:
		var look_ahead := Vector2(move_dir * 6.0, 0.0)
		if test_move(global_transform, look_ahead):
			var one_tile_up := global_transform.translated(Vector2(0.0, -16.0))
			if not test_move(one_tile_up, look_ahead):
				velocity.y = jump_velocity
				anim_sprite.play("waddle_dee_slide")

	# 5. Landing reset
	if is_on_floor() and velocity.y >= 0.0:
		if anim_sprite and anim_sprite.animation == "waddle_dee_slide":
			apply_behavior_settings()

	# 6. Optional Ledge Turnaround
	if turns_at_ledges and is_on_floor():
		var down_ahead := Vector2(move_dir * 8.0, 10.0)
		if not test_move(global_transform, down_ahead):
			_immediate_turnaround()

	# 7. Normal Constant Walk
	velocity.x = move_dir * move_speed
	move_and_slide()

	# 8. Wall Hit
	if is_on_wall():
		_immediate_turnaround()


func _start_deceleration(stopping_distance: float) -> void:
	is_turning = true
	var safe_dist: float = maxf(stopping_distance, 1.0)
	decel_rate = (move_speed * move_speed) / (2.0 * safe_dist)
	
	if behavior == Behavior.SLIDE:
		anim_sprite.play("waddle_dee_slide_turn")


func _immediate_turnaround() -> void:
	is_turning = false
	move_dir *= -1.0
	walk_start_x = global_position.x
	update_sprite_direction()
