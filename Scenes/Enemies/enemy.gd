extends CharacterBody2D
class_name Enemy

@export_category("Enemy Stats")
@export var max_health: int = 1
@export var score_value: int = 200
@export var sprite_faces_left_by_default: bool = true

@export_category("Nodes")
@export var anim_sprite: AnimatedSprite2D
@export var collider: CollisionShape2D

var current_health: int = 1

# State 0 = NORMAL (patrol, slide, etc.), State 1 = BEING_INHALED
enum State { NORMAL, BEING_INHALED }
var state: State = State.NORMAL

var move_dir: float = -1.0
var inhale_target: Node2D = null
var inhale_start_dist: float = 40.0


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("inhaleable")
	current_health = max_health
	
	if not anim_sprite:
		anim_sprite = get_node_or_null("AnimatedSprite2D")
	if not collider:
		collider = get_node_or_null("CollisionShape2D")
	
	_enemy_ready()


## Virtual hook for subclasses to initialize
func _enemy_ready() -> void:
	pass


func take_damage(amount: int = 1) -> void:
	current_health -= amount
	if current_health <= 0:
		die()


func die() -> void:
	HitFX.spawn(self, "star_burst", global_position)
	
	var kirby := get_tree().get_first_node_in_group("player")
	if kirby and kirby.has_method("add_score"):
		kirby.add_score(score_value)
		
	queue_free()


func process_inhale(delta: float) -> void:
	if not is_instance_valid(inhale_target):
		queue_free()
		return

	var mouth_offset_x: float = inhale_target.inhale_mouth_x if inhale_target.facing_right else -inhale_target.inhale_mouth_x
	var mouth_pos: Vector2 = inhale_target.global_position + Vector2(mouth_offset_x, 0.0)
	var dist_x: float = absf(global_position.x - mouth_pos.x)
	var ratio: float = clampf(dist_x / maxf(inhale_start_dist, 1.0), 0.0, 1.0)

	var pull_speed_x: float = lerpf(inhale_target.inhale_max_speed, inhale_target.inhale_min_speed, ratio)
	var time_to_mouth: float = maxf(dist_x / maxf(pull_speed_x, 1.0), 0.01)
	var pull_speed_y: float = (absf(global_position.y - mouth_pos.y) / time_to_mouth) * inhale_target.inhale_vortex_curve

	global_position.x = move_toward(global_position.x, mouth_pos.x, pull_speed_x * delta)
	global_position.y = move_toward(global_position.y, mouth_pos.y, pull_speed_y * delta)

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
	
	if collider:
		collider.set_deferred("disabled", true)
	if anim_sprite and anim_sprite.sprite_frames:
		if anim_sprite.sprite_frames.has_animation("inhaled"):
			anim_sprite.play("inhaled")
		elif anim_sprite.sprite_frames.has_animation("jump"):
			anim_sprite.play("jump")


func update_sprite_direction() -> void:
	if not anim_sprite:
		return
	var moving_right: bool = move_dir > 0.0
	anim_sprite.flip_h = moving_right if sprite_faces_left_by_default else not moving_right
