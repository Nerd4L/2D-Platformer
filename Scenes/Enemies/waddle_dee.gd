extends CharacterBody2D
class_name WaddleDee

@export_category("Waddle Dee Movement (GB Tuned)")
@export var move_speed: float = 32.0
@export var jump_velocity: float = -135.0 # Clears a 1-tile (16px) step cleanly!
@export var gravity: float = 420.0
@export var max_fall_speed: float = 135.0
@export var start_facing_left: bool = true
@export var can_jump_obstacles: bool = true # Uncheck if you want a pure walker!
@export var sprite_faces_left_by_default: bool = true

@export_category("Nodes")
@export var anim_sprite: AnimatedSprite2D
@export var collider: CollisionShape2D

enum State { PATROL, BEING_INHALED }
var state: State = State.PATROL

var move_dir: float = -1.0
var inhale_target: Node2D = null
var inhale_start_dist: float = 40.0


func _ready() -> void:
	add_to_group("inhaleable")
	if not anim_sprite:
		anim_sprite = get_node_or_null("AnimatedSprite2D")
	if not collider:
		collider = get_node_or_null("CollisionShape2D")
		
	move_dir = -1.0 if start_facing_left else 1.0
	_update_sprite_direction()
	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation("walk"):
		anim_sprite.play("walk")


func _physics_process(delta: float) -> void:
	match state:
		State.PATROL:
			_process_patrol(delta)
		State.BEING_INHALED:
			_process_being_inhaled(delta)


func _process_patrol(delta: float) -> void:
	# 1. Gravity
	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
	
	# 2. Smart Obstacle Jump Check (Replaces Unity's 4 OverlapCircles!)
	# Checks 6px ahead: if there is a wall ahead, is the space 1 tile (16px) above it clear?
	if is_on_floor() and can_jump_obstacles:
		var look_ahead := Vector2(move_dir * 6.0, 0.0)
		if test_move(global_transform, look_ahead):
			var one_tile_up := global_transform.translated(Vector2(0.0, -16.0))
			if not test_move(one_tile_up, look_ahead):
				velocity.y = jump_velocity

	# 3. Horizontal Movement
	velocity.x = move_dir * move_speed
	move_and_slide()

	# 4. Turn around if we hit a wall we couldn't jump over
	if is_on_wall():
		move_dir *= -1.0
		_update_sprite_direction()


func _process_being_inhaled(delta: float) -> void:
	if not is_instance_valid(inhale_target):
		queue_free()
		return

	# Target Kirby's mouth (slightly in front of his center)
	var mouth_pos: Vector2 = inhale_target.global_position + Vector2(inhale_target.inhale_mouth_x if inhale_target.facing_right else -inhale_target.inhale_mouth_x, 0.0)
	var dist_x: float = absf(global_position.x - mouth_pos.x)
	var ratio: float = clampf(dist_x / maxf(inhale_start_dist, 1.0), 0.0, 1.0)

	# Accelerate from Kirby's min inhale speed to max inhale speed as it approaches his mouth!
	var pull_speed_x: float = lerpf(inhale_target.inhale_max_speed, inhale_target.inhale_min_speed, ratio)
	var time_to_mouth: float = maxf(dist_x / maxf(pull_speed_x, 1.0), 0.01)
	var pull_speed_y: float = (absf(global_position.y - mouth_pos.y) / time_to_mouth) * inhale_target.inhale_vortex_curve

	global_position.x = move_toward(global_position.x, mouth_pos.x, pull_speed_x * delta)
	global_position.y = move_toward(global_position.y, mouth_pos.y, pull_speed_y * delta)

	# Caught inside Kirby's mouth!
	if global_position.distance_to(mouth_pos) <= 5.0:
		inhale_target.on_enemy_caught_in_mouth(self)
		queue_free()


func start_inhale(kirby: Node2D) -> void:
	if state == State.BEING_INHALED:
		return
	state = State.BEING_INHALED
	inhale_target = kirby
	inhale_start_dist = maxf(absf(global_position.x - kirby.global_position.x), 8.0)
	velocity = Vector2.ZERO
	
	# Disable physics collisions immediately so he gets sucked smoothly over ledges/walls!
	if collider:
		collider.set_deferred("disabled", true)
	if anim_sprite and anim_sprite.sprite_frames:
		if anim_sprite.sprite_frames.has_animation("inhaled"):
			anim_sprite.play("inhaled")
		elif anim_sprite.sprite_frames.has_animation("jump"):
			anim_sprite.play("jump")


func _update_sprite_direction() -> void:
	if not anim_sprite:
		return
	var moving_right: bool = move_dir > 0.0
	anim_sprite.flip_h = moving_right if sprite_faces_left_by_default else not moving_right
