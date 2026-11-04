extends Enemy
class_name Cappy

const TILE_SIZE: float = 16.0

@export_category("Cappy Settings")
@export var cap_scene: PackedScene # Slot for cappy_cap.tscn
@export var capped_patrol_tiles: float = 1.5 # Shorter patrol when capped
@export var capless_patrol_tiles: float = 3.5 # Longer panic patrol
@export var start_facing_left: bool = true

@export_category("Physics Tuning")
@export var gravity: float = 420.0
@export var max_fall_speed: float = 135.0

# Capped: bounces faster (shorter delay), moves slower
@export var capped_move_speed: float = 12.0
@export var capped_hop_impulse: float = -40.0
@export var capped_hop_delay: float = 0.08

# Capless: bounces slightly higher, moves much faster
@export var capless_move_speed: float = 12.0
@export var capless_hop_impulse: float = -40.0
@export var capless_hop_delay: float = 0.16

var has_cap: bool = true
var is_recoiling: bool = false
var walk_start_x: float = 0.0
var hop_timer: float = 0.0
var capped_look_timer: float = 0.0
const CAPPED_LOOK_INTERVAL: float = 0.35 # Flips sprite every few frames


func _enemy_ready() -> void:
	has_cap = true
	is_recoiling = false
	inhale_score = 200
	defeat_score = 400
	move_dir = -1.0 if start_facing_left else 1.0
	walk_start_x = global_position.x
	hop_timer = capped_hop_delay
	capped_look_timer = CAPPED_LOOK_INTERVAL

	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation("cappy_capped"):
		anim_sprite.play("cappy_capped")


func start_inhale(kirby: Node2D) -> void:
	if not has_cap:
		# Without cap (and not recoiling): can be inhaled normally
		super.start_inhale(kirby)
		return

	# --- 1. Pop off the cap into Kirby's vortex ---
	has_cap = false
	_spawn_inhaled_cap(kirby)

	# --- 2. Immune to inhale while bouncing backward ---
	remove_from_group("inhaleable")
	is_recoiling = true

	# Small bounce backward away from Kirby
	var away_dir: float = 1.0 if global_position.x > kirby.global_position.x else -1.0
	move_dir = away_dir
	velocity.x = away_dir * 45.0
	velocity.y = -95.0

	# Transform animation into 2-frame capless scurry
	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation("cappy_capless"):
		anim_sprite.play("cappy_capless")
		anim_sprite.flip_h = (move_dir > 0.0)


func _spawn_inhaled_cap(kirby: Node2D) -> void:
	if not cap_scene:
		return
		
	var cap := cap_scene.instantiate() as CappyCap
	cap.global_position = global_position + Vector2(0.0, -6.0)
	get_parent().add_child(cap)

	# Transfer cap into Kirby's mouth stream
	kirby.inhaling_enemies.erase(self)
	kirby.inhaling_enemies.append(cap)
	cap.start_inhale(kirby)


func _physics_process(delta: float) -> void:
	if state == State.BEING_INHALED:
		process_inhale(delta)
		return

	# Gravity
	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)

	# Handle the pop-off recoil bounce
	if is_recoiling:
		move_and_slide()
		if is_on_floor() and velocity.y >= 0.0:
			is_recoiling = false
			add_to_group("inhaleable") # Now vulnerable to being inhaled
			
			# Face and move TOWARDS Kirby upon landing:
			var kirby := get_tree().get_first_node_in_group("player") as Node2D
			if is_instance_valid(kirby):
				move_dir = 1.0 if (kirby.global_position.x > global_position.x) else -1.0

			walk_start_x = global_position.x
			hop_timer = capless_hop_delay
			
			if anim_sprite:
				anim_sprite.flip_h = (move_dir > 0.0)
		return

	# Capped sprite flipping: flips back and forth every couple frames while walking
	if has_cap and anim_sprite:
		capped_look_timer -= delta
		if capped_look_timer <= 0.0:
			capped_look_timer = CAPPED_LOOK_INTERVAL
			anim_sprite.flip_h = not anim_sprite.flip_h

	# Bouncing Patrol
	_process_bouncing_patrol(delta)
	move_and_slide()


func _process_bouncing_patrol(delta: float) -> void:
	var active_speed: float = capless_move_speed if not has_cap else capped_move_speed
	var active_impulse: float = capless_hop_impulse if not has_cap else capped_hop_impulse
	var active_delay: float = capless_hop_delay if not has_cap else capped_hop_delay
	var active_patrol_px: float = (capless_patrol_tiles if not has_cap else capped_patrol_tiles) * TILE_SIZE

	if is_on_floor():
		velocity.x = 0.0
		hop_timer -= delta
		if hop_timer <= 0.0:
			hop_timer = active_delay
			velocity.y = active_impulse
			velocity.x = move_dir * active_speed
	else:
		velocity.x = move_dir * active_speed

	# Patrol distance check
	if active_patrol_px > 0.0 and is_on_floor():
		if absf(global_position.x - walk_start_x) >= active_patrol_px:
			_turn_around()

	if is_on_wall():
		_turn_around()


func _turn_around() -> void:
	move_dir *= -1.0
	walk_start_x = global_position.x
	
	# Capless flips direction ONLY when turning
	if not has_cap and anim_sprite:
		anim_sprite.flip_h = (move_dir > 0.0)
