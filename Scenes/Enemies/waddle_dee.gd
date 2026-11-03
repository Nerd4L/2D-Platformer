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

@export var start_facing_left: bool = true
@export var turns_at_ledges: bool = false

@export_category("Physics Tuning")
@export var move_speed: float = 32.0
@export var normal_walk_speed: float = 32.0
@export var slide_speed: float = 52.0
@export var slow_walk_speed: float = 14.0
@export var jump_velocity: float = -135.0
@export var gravity: float = 420.0
@export var max_fall_speed: float = 135.0

var can_jump_obstacles: bool = true


func _enemy_ready() -> void:
	move_dir = -1.0 if start_facing_left else 1.0
	update_sprite_direction()
	apply_behavior_settings()


func set_behavior(new_behavior: int) -> void:
	behavior = new_behavior as Behavior
	apply_behavior_settings()


func apply_behavior_settings() -> void:
	# Ensure anim_sprite is found even if called early
	if not anim_sprite:
		anim_sprite = get_node_or_null("AnimatedSprite2D")

	match behavior:
		Behavior.PATROL:
			move_speed = normal_walk_speed
			can_jump_obstacles = true
			if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation("walk"):
				anim_sprite.speed_scale = 1.0
				anim_sprite.play("walk")

		Behavior.SLIDE:
			move_speed = slide_speed
			can_jump_obstacles = false # Classic GB sliding Dee glides across terrain
			if anim_sprite and anim_sprite.sprite_frames:
				if anim_sprite.sprite_frames.has_animation("slide"):
					anim_sprite.speed_scale = 1.0
					anim_sprite.play("slide")
				elif anim_sprite.sprite_frames.has_animation("walk"):
					# Fallback: rapid walk if no dedicated slide sprite exists
					anim_sprite.speed_scale = 1.6
					anim_sprite.play("walk")

		Behavior.SLOW_WALK:
			move_speed = slow_walk_speed
			can_jump_obstacles = true
			if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation("walk"):
				anim_sprite.speed_scale = 0.5
				anim_sprite.play("walk")


func _physics_process(delta: float) -> void:
	if state == State.BEING_INHALED:
		process_inhale(delta)
		return

	_process_movement(delta)


func _process_movement(delta: float) -> void:
	# 1. Gravity
	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)

	# 2. Smart Obstacle Jump Check (16px step clearance)
	if is_on_floor() and can_jump_obstacles:
		var look_ahead := Vector2(move_dir * 6.0, 0.0)
		if test_move(global_transform, look_ahead):
			var one_tile_up := global_transform.translated(Vector2(0.0, -16.0))
			if not test_move(one_tile_up, look_ahead):
				velocity.y = jump_velocity
				if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation("jump"):
					anim_sprite.play("jump")

	# 3. Floor landing reset
	if is_on_floor() and velocity.y >= 0.0:
		if anim_sprite and anim_sprite.animation == "jump":
			apply_behavior_settings()

	# 4. Optional Ledge Turnaround
	if turns_at_ledges and is_on_floor():
		var down_ahead := Vector2(move_dir * 8.0, 10.0)
		if not test_move(global_transform, down_ahead):
			_turn_around()

	# 5. Move with the active move_speed
	velocity.x = move_dir * move_speed
	move_and_slide()

	# 6. Turn around on walls
	if is_on_wall():
		_turn_around()


func _turn_around() -> void:
	move_dir *= -1.0
	update_sprite_direction()
