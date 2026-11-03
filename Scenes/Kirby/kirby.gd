class_name Kirby
extends CharacterBody2D

# -----------------------------------------------------------------------------
# SIGNALS TO HUD
# -----------------------------------------------------------------------------
signal health_changed(current: int, max_val: int)
signal lives_changed(current_lives: int)
signal score_changed(current_score: int)

# -----------------------------------------------------------------------------
# EXPORT CATEGORIES
# -----------------------------------------------------------------------------
@export_category("Debug Spawn")
@export var use_debug_spawn: bool = false
@export var debug_spawn_marker: Marker2D
@export var debug_camera_room: ReferenceRect

@export_category("Input buffering")
# 0.12 == ~7 frames of input memory
@export var jump_buffer_time: float = 0.12   
@export var action_buffer_time: float = 0.12

@export_category("Health & Damage")
@export var hurtbox: Area2D
@export var max_health: int = 6
@export var starting_lives: int = 4
@export var invulnerability_duration: float = 3
@export var hurt_recoil_time: float = 0.32
@export var knockback_horizontal: float = 80.0
@export var knockback_vertical: float = -110.0

@export_category("Normal Movement")
@export var move_speed: float = 75.0
@export var jump_velocity: float = -178.0 # ~37.7px max jump height
@export var normal_gravity: float = 420.0
@export var max_fall_speed: float = 135.0
@export var ground_accel: float = 380.0
@export var ground_decel: float = 320.0
@export var air_decel: float = 97.5
@export var coyote_time: float = 0.12
@export var platform_drop_crouch_time: float = 0.08
@export var platform_drop_ignore_time: float = 0.18

@export_category("Float Settings")
@export var float_air_speed: float = 40.0
@export var float_up_velocity: float = -68.0
@export var float_gravity: float = 180.0
@export var float_max_fall_speed: float = 42.0

@export_category("Inhale Settings")
@export var inhale_particle_texture: Texture2D
@export var inhale_pivot: Node2D
@export var inhale_area: Area2D
@export var inhale_range: float = 40.0
@export var inhale_min_range: float = 16.0
@export var inhale_funnel_half_height: float = 16.0
@export var inhale_spawn_jitter: float = 4.5
@export var inhale_min_speed: float = 100.0
@export var inhale_max_speed: float = 160.0
@export var inhale_mouth_x: float = 2.0
@export_range(1.0, 2.0) var inhale_vortex_curve: float = 1.15

@export_category("Mouthful & Projectiles")
@export var is_mouthful: bool = false
@export var projectile_scene: PackedScene
@export var projectile_spawn_offset: Vector2 = Vector2(10.0, 0.0)

@export_category("Collision, Animation & Level")
@export var standing_collider: CollisionShape2D
@export var crouch_collider: CollisionShape2D
@export var float_collider: CollisionShape2D
@export var anim_sprite: AnimatedSprite2D
@export var terrain_layer: TileMapLayer
@export var starting_camera_room: ReferenceRect
@export var hud_height: float = 16.0

@export_category("Fall Bounce & Impact Star")
@export var tumble_fall_distance: float = 48.0
@export var star_fall_distance: float = 12.0
@export var bounce_velocity: float = -95.0
@export var star_particle_texture: Texture2D

@export_category("Death Animation")
@export var death_hop_height: float = 24.0
@export var death_hop_duration: float = 0.35
#@export var death_fall_distance: float = 110.0
#@export var death_fall_duration: float = 0.7

@onready var cam: Camera2D = $Camera2D

# -----------------------------------------------------------------------------
# INTERNAL STATE
# -----------------------------------------------------------------------------
var is_game_paused: bool = false
var start_pos: Vector2
var facing_right: bool = true
var coyote_time_counter: float = 0.0
var fall_start_y: float = 0.0
const BASE_SPRITE_OFFSET := Vector2(0.0, -5.0)

var current_health: int = 6
var lives: int = 4
var score: int = 0

var is_hurt: bool = false
var is_invulnerable: bool = false
var hurt_timer: float = 0.0
var invulnerable_timer: float = 0.0
var blink_interval: float = 0.06
var blink_timer: float = 0.0
var jump_buffer_counter: float = 0.0
var action_buffer_counter: float = 0.0

var is_crouching: bool = false
var is_floating: bool = false
var is_flapping: bool = false
var is_exhaling: bool = false
var is_inhaling: bool = false
var is_inhale_recovering: bool = false
var is_swallowing: bool = false
var is_spitting: bool = false
var is_tumbling: bool = false
var has_bounced: bool = false
var is_dying: bool = false
var is_riding_warp_star: bool = false

var is_entering_door: bool = false
var waiting_for_up_release: bool = false

var swallow_spit_timer: float = 0.0
var wall_squish_timer: float = 0.0
var platform_crouch_delay: float = 0.0
var platform_drop_timer: float = 0.0
var blink_wait_time: float = 3.5

var inhaling_enemies: Array[Node2D] = []
var active_particles: Array[Sprite2D] = []


# -----------------------------------------------------------------------------
# SETUP & RESET
# -----------------------------------------------------------------------------
func _ready() -> void:
	# Make sure the game can listen for the unpause key when paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if use_debug_spawn and debug_spawn_marker:
		global_position = debug_spawn_marker.global_position
		if debug_camera_room:
			starting_camera_room = debug_camera_room
	
	# Automatic fallback if inspector slots were unlinked
	if not inhale_pivot:
		inhale_pivot = get_node_or_null("InhalePivot")
	if not inhale_area:
		inhale_area = get_node_or_null("InhalePivot/InhaleArea")
	if not hurtbox:
		hurtbox = get_node_or_null("Hurtbox")
	if not anim_sprite:
		anim_sprite = get_node_or_null("AnimatedSprite2D")
	if not standing_collider:
		standing_collider = get_node_or_null("StandingCollider")
	if not crouch_collider:
		crouch_collider = get_node_or_null("CrouchCollider")
	if not float_collider:
		float_collider = get_node_or_null("FloatCollider")

	add_to_group("player")
	add_to_group("resettable")
	start_pos = global_position
	current_health = max_health
	lives = starting_lives
	_reset_blink_timer()

	# Connect Hurtbox (both bodies and areas)
	if hurtbox:
		hurtbox.body_entered.connect(_on_hurtbox_entered)
		hurtbox.area_entered.connect(_on_hurtbox_entered)

	if starting_camera_room:
		set_camera_room(starting_camera_room)

	# Broadcast initial stats to HUD
	call_deferred("_emit_initial_stats")


func _emit_initial_stats() -> void:
	health_changed.emit(current_health, max_health)
	lives_changed.emit(lives)
	score_changed.emit(score)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			full_reset()
		elif event.keycode == KEY_F:
			take_damage(1, self.global_position)
		elif event.keycode == KEY_E:
			_handle_death()
		elif event.keycode == KEY_P:
			toggle_pause()


func reset_state() -> void:
	is_game_paused = false
	is_dying = false
	set_world_paused(false)
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if cam:
		cam.position = Vector2.ZERO
		cam.reset_smoothing()
	
	global_position = start_pos
	if starting_camera_room:
		set_camera_room(starting_camera_room)
	velocity = Vector2.ZERO
	fall_start_y = start_pos.y

	if not facing_right:
		_flip()

	current_health = max_health
	is_dying = false
	is_hurt = false
	is_invulnerable = false
	hurt_timer = 0.0
	invulnerable_timer = 0.0

	# Re-enable Hurtbox and Standing Collider
	if hurtbox:
		hurtbox.set_deferred("monitoring", true)
	if standing_collider:
		standing_collider.set_deferred("disabled", false)
	if crouch_collider:
		crouch_collider.set_deferred("disabled", true)
	if float_collider:
		float_collider.set_deferred("disabled", true)

	if anim_sprite:
		anim_sprite.offset = BASE_SPRITE_OFFSET
		anim_sprite.visible = true
	health_changed.emit(current_health, max_health)

	is_floating = false
	is_flapping = false
	is_exhaling = false
	is_mouthful = false
	is_inhaling = false
	is_inhale_recovering = false
	is_swallowing = false
	is_spitting = false
	is_tumbling = false
	has_bounced = false
	is_crouching = false
	is_entering_door = false
	waiting_for_up_release = false
	is_riding_warp_star = false

	wall_squish_timer = 0.0
	swallow_spit_timer = 0.0
	platform_crouch_delay = 0.0
	platform_drop_timer = 0.0

	_clear_inhale_state()

	if cam:
		cam.reset_smoothing()
	anim_sprite.play("idle")

## Full run restart (used by 'R' key and Game Over screen)
func full_reset() -> void:
	lives = starting_lives
	score = 0
	lives_changed.emit(lives)
	score_changed.emit(score)
	get_tree().call_group("effects", "queue_free")
	get_tree().call_group("resettable", "reset_state")

# -----------------------------------------------------------------------------
# MAIN PHYSICS LOOP
# -----------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	# Freeze all Kirby physics and updates while paused or dying
	if is_game_paused or is_dying or is_riding_warp_star:
		return

	_cleanup_invalid_enemies()
	_update_action_timers(delta)
	_update_hurt_and_invulnerability(delta)
	_check_crush_overlap()
	
	# Input buffering
	if Input.is_action_just_pressed("jump"):
		jump_buffer_counter = jump_buffer_time
	else:
		jump_buffer_counter = maxf(jump_buffer_counter - delta, 0.0)

	if Input.is_action_just_pressed("action"):
		action_buffer_counter = action_buffer_time
	else:
		action_buffer_counter = maxf(action_buffer_counter - delta, 0.0)

	# Knockback recoil state
	if is_hurt:
		velocity.y = minf(velocity.y + normal_gravity * delta, max_fall_speed)
		move_and_slide()
		_clamp_to_level_bounds()
		_update_animations(delta)
		return

	var busy_action: bool = is_swallowing or is_spitting

	# 0. Door Entry State
	if is_entering_door:
		velocity = Vector2.ZERO
		return

	# Up button release check for doors
	if not Input.is_action_pressed("float_up"):
		waiting_for_up_release = false

	var overlapping_door: Door = _get_overlapping_door()
	if overlapping_door and Input.is_action_pressed("float_up") and not waiting_for_up_release and not busy_action and not is_inhaling:
		_enter_door(overlapping_door)
		return

	# 1. Physics & Movement Sub-systems
	_handle_gravity(delta, busy_action)
	_handle_inhale_and_mouth_actions(busy_action)
	_handle_jump_and_float_actions(overlapping_door != null)
	_update_colliders()
	_handle_horizontal_movement(delta, busy_action)
	_handle_one_way_platforms(delta)

	# 2. Collisions & Environmental Impacts
	var was_on_floor: bool = is_on_floor()
	var was_on_wall: bool = is_on_wall()
	var pre_vx: float = velocity.x
	var fallen_distance: float = global_position.y - fall_start_y

	move_and_slide()
	_clamp_to_level_bounds()

	_handle_impacts(was_on_floor, was_on_wall, pre_vx, fallen_distance)
	_update_animations(delta)


# -----------------------------------------------------------------------------
# GRAVITY & VERTICAL LOGIC
# -----------------------------------------------------------------------------
func _handle_gravity(delta: float, busy_action: bool) -> void:
	if is_on_floor():
		coyote_time_counter = coyote_time
		if not is_tumbling:
			fall_start_y = global_position.y
		return

	if is_floating:
		velocity.y = minf(velocity.y + float_gravity * delta, float_max_fall_speed)
		fall_start_y = global_position.y
		is_tumbling = false
	else:
		velocity.y = minf(velocity.y + normal_gravity * delta, max_fall_speed)
		if not has_bounced:
			if velocity.y <= 0.0 or is_inhaling or is_inhale_recovering or busy_action:
				fall_start_y = global_position.y
				is_tumbling = false
			elif (global_position.y - fall_start_y) >= tumble_fall_distance and not is_mouthful:
				is_tumbling = true

	if coyote_time_counter > 0.0:
		coyote_time_counter -= delta


func _handle_jump_and_float_actions(near_door: bool) -> void:
	is_flapping = false
	var busy_inhaling: bool = is_inhaling or is_inhale_recovering or is_swallowing

	if not is_floating and not is_exhaling and not has_bounced:
		if Input.is_action_pressed("float_up") and not is_mouthful and not busy_inhaling and not near_door:
			is_floating = true
			is_flapping = true
			is_tumbling = false
			wall_squish_timer = 0.0
			velocity.y = float_up_velocity
			anim_sprite.play("float_startup")
		elif not busy_inhaling and jump_buffer_counter > 0.0 and (is_on_floor() or coyote_time_counter > 0.0):
			velocity.y = jump_velocity
			jump_buffer_counter = 0.0
			coyote_time_counter = 0.0
	elif is_floating:
		if Input.is_action_pressed("float_up") or Input.is_action_pressed("jump"):
			velocity.y = float_up_velocity
			is_flapping = true
		if action_buffer_counter > 0.0:
			action_buffer_counter = 0.0
			_exhale_air_puff()

	# Variable jump height cut
	if not is_floating and Input.is_action_just_released("jump") and velocity.y < -40.0:
		velocity.y *= 0.5


# -----------------------------------------------------------------------------
# INHALE & MOUTHFUL ACTIONS
# -----------------------------------------------------------------------------
func _handle_inhale_and_mouth_actions(busy_action: bool) -> void:
	if is_mouthful and not busy_action and not has_bounced:
		if action_buffer_counter > 0.0:
			action_buffer_counter = 0.0
			_spit_star()
			return
		elif (Input.is_action_just_pressed("crouch") or Input.is_action_pressed("crouch")) and is_on_floor():
			_swallow_mouthful()
			return

	var can_inhale: bool = not is_floating and not is_exhaling and not is_mouthful and not busy_action and not has_bounced and not is_inhale_recovering

	if can_inhale:
		if Input.is_action_pressed("float_up") and inhaling_enemies.is_empty():
			is_inhaling = false
			is_inhale_recovering = false
			_clear_inhale_particles()
		elif (action_buffer_counter > 0.0 or Input.is_action_pressed("action")) and not is_inhaling and not is_crouching:
			action_buffer_counter = 0.0
			is_inhaling = true
			is_inhale_recovering = false
			is_tumbling = false
			wall_squish_timer = 0.0
			anim_sprite.play("inhale_recovery")
		elif is_inhaling and not Input.is_action_pressed("action") and inhaling_enemies.is_empty():
			is_inhaling = false
			is_inhale_recovering = true
			_clear_inhale_particles()
			anim_sprite.play("inhale_recovery")
	elif is_mouthful or is_floating or is_exhaling or busy_action:
		is_inhaling = false
		_clear_inhale_particles()

	_check_inhale_targets()
	_update_inhale_particles(get_physics_process_delta_time())


func _check_inhale_targets() -> void:
	if not inhale_area:
		return
	inhale_area.monitoring = is_inhaling
	if not is_inhaling:
		return

	for body in inhale_area.get_overlapping_bodies():
		if body.is_in_group("inhaleable") and body.has_method("start_inhale"):
			if not inhaling_enemies.has(body):
				inhaling_enemies.append(body)
				body.start_inhale(self)


func on_enemy_caught_in_mouth(enemy: Node2D) -> void:
	inhaling_enemies.erase(enemy)

	# 1. Ask the enemy for its specific inhale point value
	if is_instance_valid(enemy):
		var pts: int = enemy.inhale_score	
		add_score(pts)

	# 2. Enter mouthful immediately
	if inhaling_enemies.is_empty():
		is_inhaling = false
		is_inhale_recovering = false
		is_mouthful = true
		_clear_inhale_particles()
		anim_sprite.play("mouthful_idle")


func _clear_inhale_particles() -> void:
	for p in active_particles:
		if is_instance_valid(p):
			p.queue_free()
	active_particles.clear()


func _swallow_mouthful() -> void:
	is_mouthful = false
	is_swallowing = true
	anim_sprite.play("mouthful_gulp")


func _spit_star() -> void:
	is_mouthful = false
	is_spitting = true
	anim_sprite.play("mouthful_spit")
	_spawn_projectile(Projectile.Type.STAR)


func _exhale_air_puff() -> void:
	is_floating = false
	is_flapping = false
	is_exhaling = true
	anim_sprite.play("float_recovery")
	_spawn_projectile(Projectile.Type.AIR_PUFF)


func _spawn_projectile(proj_type: Projectile.Type) -> void:
	if not projectile_scene:
		return
	var proj := projectile_scene.instantiate() as Projectile
	var p_dir: float = 1.0 if facing_right else -1.0
	proj.global_position = global_position + Vector2(projectile_spawn_offset.x * p_dir, projectile_spawn_offset.y)
	get_parent().add_child(proj)
	proj.setup(proj_type, p_dir)


func _update_inhale_particles(delta: float) -> void:
	if not inhale_pivot:
		return

	if is_inhaling and inhale_particle_texture and active_particles.is_empty():
		_spawn_inhale_particle_cluster()

	for i in range(active_particles.size() - 1, -1, -1):
		var p: Sprite2D = active_particles[i]
		if not is_instance_valid(p):
			active_particles.remove_at(i)
			continue
		if not is_inhaling:
			p.queue_free()
			active_particles.remove_at(i)
			continue

		var x_rem: float = maxf(p.position.x - inhale_mouth_x, 1.0)
		var x_rat: float = clampf(x_rem / maxf(inhale_range - inhale_mouth_x, 1.0), 0.0, 1.0)
		var speed_x: float = lerpf(inhale_max_speed, inhale_min_speed, x_rat)
		var t_mouth: float = x_rem / maxf(speed_x, 1.0)
		var speed_y: float = (absf(p.position.y) / maxf(t_mouth, 0.01)) * inhale_vortex_curve

		p.position.x = move_toward(p.position.x, inhale_mouth_x, speed_x * delta)
		p.position.y = move_toward(p.position.y, 0.0, speed_y * delta)

		if p.position.x <= inhale_mouth_x + 0.5:
			p.queue_free()
			active_particles.remove_at(i)


func _spawn_inhale_particle_cluster() -> void:
	var chosen_positions: Array[Vector2] = []
	for i in range(3):
		var p := Sprite2D.new()
		p.texture = inhale_particle_texture
		p.z_index = -1
		var spawn_pos := Vector2.ZERO

		for attempt in range(10):
			var mid_x: float = lerpf(inhale_min_range, inhale_range, 0.5)
			var start_x: float = randf_range(mid_x, inhale_range) if randf() < 0.70 else randf_range(inhale_min_range, mid_x)
			var lane_t: float = float(randi_range(0, 6)) / 6.0
			var base_y: float = lerpf(-inhale_funnel_half_height, inhale_funnel_half_height, lane_t)

			start_x += randf_range(-inhale_spawn_jitter, inhale_spawn_jitter)
			var start_y: float = base_y + randf_range(-inhale_spawn_jitter, inhale_spawn_jitter)
			spawn_pos = Vector2(start_x, start_y)

			var too_close: bool = false
			for other in chosen_positions:
				if spawn_pos.distance_to(other) < 11.0:
					too_close = true
					break
			if not too_close:
				break

		chosen_positions.append(spawn_pos)
		p.position = spawn_pos
		inhale_pivot.add_child(p)
		active_particles.append(p)


func _clear_inhale_state() -> void:
	inhaling_enemies.clear()
	_clear_inhale_particles()


func _cleanup_invalid_enemies() -> void:
	for i in range(inhaling_enemies.size() - 1, -1, -1):
		if not is_instance_valid(inhaling_enemies[i]):
			inhaling_enemies.remove_at(i)


# -----------------------------------------------------------------------------
# COMBAT, DAMAGE & KNOCKBACK
# -----------------------------------------------------------------------------
func _on_hurtbox_entered(collider: Node2D) -> void:
	# Enemies trapped in inhale vortex cannot damage him
	if inhaling_enemies.has(collider):
		return

	# Support collision with the enemy body or an enemy Area2D hitbox
	var enemy_node: Node2D = collider
	if not (enemy_node is CharacterBody2D) and collider.get_parent() is CharacterBody2D:
		enemy_node = collider.get_parent()

	var is_enemy: bool = (
		enemy_node.get_collision_layer_value(4)
		or enemy_node.is_in_group("enemies")
		or enemy_node.is_in_group("inhaleable")
		or collider.is_in_group("enemies")
	)
	
	# Future-proof hazards: Spikes, environmental traps, or enemy projectiles
	var is_hazard: bool = (
		collider.is_in_group("hazards")
		or collider.is_in_group("spikes")
		or collider.is_in_group("enemy_projectiles")
		or enemy_node.is_in_group("hazards")
		or enemy_node.is_in_group("spikes")
	)
	
	if not is_enemy and not is_hazard:
		return

	# 1. INVINCIBILITY (i-frames or Super Star candy)
	if is_invulnerable and not is_hazard:
		_damage_enemy(enemy_node)
		return

	# 2. TUMBLE ATTACK:
	# While tumbling downward (before the bounce), Kirby crushes enemies without taking damage!
	var is_tumbling_attack: bool = is_tumbling and not has_bounced
	if is_tumbling_attack and is_enemy and not is_hazard:
		_crush_enemy(enemy_node)
		return # Kirby crushes the enemy and takes NO damage!

	# 3. NORMAL DAMAGE (includes the ensuing bounce, walking into enemies, or hitting hazards/spikes)
	take_damage(1, enemy_node.global_position)

func _crush_enemy(enemy_node: Node2D) -> void:
	_damage_enemy(enemy_node)
	velocity.y = 0.0
	fall_start_y = global_position.y
	is_tumbling = false

func _check_crush_overlap() -> void:
	if not hurtbox:
		return

	var is_tumbling_downward: bool = is_tumbling and not has_bounced
	if not is_invulnerable and not is_tumbling_downward:
		return

	for body in hurtbox.get_overlapping_bodies():
		if inhaling_enemies.has(body):
			continue
		var is_enemy: bool = body.get_collision_layer_value(4) or body.is_in_group("enemies") or body.is_in_group("inhaleable")
		var is_hazard: bool = body.is_in_group("hazards") or body.is_in_group("spikes") or body.is_in_group("enemy_projectiles")

		if is_enemy and not is_hazard:
			if is_tumbling_downward:
				_crush_enemy(body)
			elif is_invulnerable:
				_damage_enemy(body)

func _damage_enemy(enemy: Node2D) -> void:
	if not is_instance_valid(enemy):
		return
	if enemy.has_method("take_damage"):
		enemy.take_damage(1)
	elif enemy.has_method("die"):
		enemy.die()
	else:
		HitFX.spawn(self, "star_burst", enemy.global_position)
		enemy.queue_free()


func take_damage(amount: int, source_pos: Vector2) -> void:
	if is_dying or is_invulnerable or is_entering_door:
		return

	current_health = max(current_health - amount, 0)
	health_changed.emit(current_health, max_health)

	if current_health <= 0:
		_handle_death()
		return

	# 1. HORIZONTAL DIRECTION:
	var h_dir: float = 0.0
	if absf(velocity.x) > 5.0:
		# Knock opposite to his current movement direction
		h_dir = -signf(velocity.x)
	else:
		# Standing still: knock away from the enemy
		if source_pos != Vector2.INF and absf(source_pos.x - global_position.x) > 1.0:
			h_dir = -1.0 if (source_pos.x > global_position.x) else 1.0
		else:
			h_dir = -1.0 if facing_right else 1.0

	# 2. VERTICAL DIRECTION:
	# Mostly launched upwards (-1.0), unless Kirby clearly hit them from below while rising
	var v_dir: float = -1.0
	if velocity.y < -15.0 and source_pos != Vector2.INF and global_position.y > (source_pos.y + 4.0):
		v_dir = 1.0 # Spiked downwards!

	# 3. EXACT 45-DEGREE ANGLE (|velocity.x| == |velocity.y|)
	var knock_speed: float = knockback_horizontal # Uses your export (80.0)
	velocity.x = h_dir * knock_speed
	velocity.y = v_dir * knock_speed

	# Lock movement briefly during recoil & start i-frames
	is_hurt = true
	hurt_timer = hurt_recoil_time
	is_invulnerable = true
	invulnerable_timer = invulnerability_duration
	blink_timer = 0.0


func _update_hurt_and_invulnerability(delta: float) -> void:
	# Hurt recoil recovery
	if is_hurt:
		hurt_timer -= delta
		if hurt_timer <= 0.0 or (is_on_floor() and velocity.y >= 0.0):
			is_hurt = false

	# Invincibility frame timer and sprite blinking
	if is_invulnerable:
		invulnerable_timer -= delta
		blink_timer += delta
		if blink_timer >= blink_interval:
			blink_timer = 0.0
			anim_sprite.visible = not anim_sprite.visible

		if invulnerable_timer <= 0.0:
			is_invulnerable = false
			anim_sprite.visible = true


func _handle_death() -> void:
	is_dying = true
	velocity = Vector2.ZERO

	# 1. Freeze the whole world instantly (enemies, animations, projectiles all stop)
	set_world_paused(true)

	# Kirby freezes in his hurt pose
	if anim_sprite:
		anim_sprite.pause()

	# 2. Disable collisions so Kirby can drop through the floor
	standing_collider.set_deferred("disabled", true)
	crouch_collider.set_deferred("disabled", true)
	if float_collider:
		float_collider.set_deferred("disabled", true)
	if hurtbox:
		hurtbox.set_deferred("monitoring", false)

	# 3. Freeze 
	await get_tree().create_timer(0.75, true).timeout
	
	# 3B. Death fireworks
	_spawn_death_fireworks()
	
	# 3A. Pop up, then drop down off-screen while spinning
	anim_sprite.play("death")

	# Lock camera in place so it stops tracking Kirby while he dies
	var saved_cam_pos: Vector2 = cam.global_position if cam else Vector2.ZERO
	
	# Dynamically calculates half the screen height, regardless of resolution or aspect ratio
	var viewport_half_height: float = get_viewport_rect().size.y * 0.5
	var exit_margin: float = 24.0
	var screen_bottom: float = (cam.get_screen_center_position().y + viewport_half_height + exit_margin) if cam else (global_position.y + get_viewport_rect().size.y + exit_margin)
	
	# Hop up (pinning camera in place)
	var hop_pos := global_position + Vector2(0.0, -death_hop_height)
	var hop_tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	hop_tween.tween_property(self, "global_position", hop_pos, death_hop_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	while hop_tween.is_running():
		await get_tree().process_frame
		if cam:
			cam.global_position = saved_cam_pos

	# Fall down until completely past the dynamic screen bottom
	var death_fall_speed: float = 40.0
	while global_position.y < screen_bottom:
		await get_tree().process_frame
		var dt: float = get_process_delta_time()
		death_fall_speed = minf(death_fall_speed + 540.0 * dt, 320.0)
		global_position.y += death_fall_speed * dt
		if cam:
			cam.global_position = saved_cam_pos

	# 4. Fade to white
	await ScreenFader.fade(true)

	# 5. DURING THE FADE: Decrement and update the HUD lives counter
	lives = max(lives - 1, 0)
	lives_changed.emit(lives)

	# 6. Clean up room while screen is white
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and enemy != self:
			enemy.queue_free()
	for enemy in get_tree().get_nodes_in_group("inhaleable"):
		if is_instance_valid(enemy) and enemy != self and not (enemy is TileMapLayer):
			enemy.queue_free()

	get_tree().call_group("projectiles", "queue_free")
	get_tree().call_group("effects", "queue_free")

	# 7. Unpause and reset level state
	set_world_paused(false)
	get_tree().call_group("resettable", "reset_state")

	await get_tree().create_timer(0.08, true).timeout

	# 8. Fade back in
	await ScreenFader.fade(false)
	is_dying = false


func add_score(points: int) -> void:
	score += points
	score_changed.emit(score)


# -----------------------------------------------------------------------------
# HORIZONTAL MOVEMENT & PLATFORMS
# -----------------------------------------------------------------------------
func _handle_horizontal_movement(delta: float, busy_action: bool) -> void:
	var move_dir: float = Input.get_axis("move_left", "move_right")
	var lock_input: bool = is_crouching or is_inhaling or is_inhale_recovering or is_swallowing
	var effective_dir: float = 0.0 if lock_input else move_dir
	var current_max_speed: float = float_air_speed if is_floating else move_speed
	var target_speed: float = effective_dir * current_max_speed

	if effective_dir != 0.0:
		var is_turning: bool = (signf(effective_dir) != signf(velocity.x)) and absf(velocity.x) > 10.0
		var accel_rate: float = (ground_decel * 1.35) if is_turning else ground_accel
		velocity.x = move_toward(velocity.x, target_speed, accel_rate * delta)
	else:
		var decel_rate: float = ground_decel if is_on_floor() else air_decel
		velocity.x = move_toward(velocity.x, 0.0, decel_rate * delta)

	if not is_inhaling and not busy_action:
		if move_dir > 0.0 and not facing_right:
			_flip()
		elif move_dir < 0.0 and facing_right:
			_flip()


func _handle_one_way_platforms(delta: float) -> void:
	if is_crouching and is_on_floor():
		platform_crouch_delay += delta
		if platform_crouch_delay >= platform_drop_crouch_time:
			platform_drop_timer = platform_drop_ignore_time
			platform_crouch_delay = 0.0
			position.y += 1.0
	else:
		platform_crouch_delay = 0.0

	var ignore_platforms: bool = (velocity.y < -1.0) or (platform_drop_timer > 0.0)
	set_collision_mask_value(2, not ignore_platforms)


func _update_colliders() -> void:
	var is_big_hitbox: bool = is_floating or is_mouthful
	var crouch_pressed: bool = Input.is_action_pressed("crouch")
	var busy_inhaling: bool = is_inhaling or is_inhale_recovering or is_swallowing

	is_crouching = crouch_pressed and is_on_floor() and not is_big_hitbox and not busy_inhaling

	if is_big_hitbox:
		standing_collider.disabled = true
		crouch_collider.disabled = true
		if float_collider: float_collider.disabled = false
	elif is_crouching:
		standing_collider.disabled = true
		crouch_collider.disabled = false
		if float_collider: float_collider.disabled = true
	else:
		standing_collider.disabled = false
		crouch_collider.disabled = true
		if float_collider: float_collider.disabled = true


func _handle_impacts(was_on_floor: bool, was_on_wall: bool, pre_vx: float, fallen_px: float) -> void:
	var can_wall_squish: bool = not is_floating and not is_mouthful and not is_exhaling and not is_tumbling
	if can_wall_squish and is_on_wall() and not was_on_wall and absf(pre_vx) > move_speed * 0.8:
		_spawn_impact_star()
		wall_squish_timer = 0.12
		anim_sprite.offset.x = BASE_SPRITE_OFFSET.x + (2.0 if pre_vx > 0.0 else -2.0)

	if is_on_floor() and not was_on_floor:
		if not has_bounced and (fallen_px >= star_fall_distance or is_tumbling):
			_spawn_impact_star()

		if is_tumbling:
			if not has_bounced:
				velocity.y = bounce_velocity
				has_bounced = true
			else:
				is_tumbling = false
				has_bounced = false
	elif is_on_floor() and velocity.y >= 0.0:
		is_tumbling = false
		has_bounced = false


func _spawn_impact_star(spawn_pos: Vector2 = Vector2.INF) -> void:
	if not star_particle_texture:
		return
	var pos: Vector2 = (global_position + Vector2(0.0, 4.0)) if spawn_pos == Vector2.INF else spawn_pos
	var star := Sprite2D.new()
	star.add_to_group("effects")
	star.texture = star_particle_texture
	star.z_index = 10
	star.global_position = pos
	get_parent().add_child(star)

	var target_pos: Vector2 = pos + Vector2.from_angle(randf_range(0.0, TAU)) * 22.0
	var tween := create_tween()
	tween.tween_property(star, "global_position", target_pos, 0.15)
	tween.tween_interval(0.15)
	tween.tween_callback(star.queue_free)


func _update_action_timers(delta: float) -> void:
	_update_hurt_and_invulnerability(delta)
	
	if wall_squish_timer > 0.0:
		wall_squish_timer -= delta
		if wall_squish_timer <= 0.0:
			wall_squish_timer = 0.0
			anim_sprite.offset.x = BASE_SPRITE_OFFSET.x

	if platform_drop_timer > 0.0:
		platform_drop_timer -= delta


# -----------------------------------------------------------------------------
# DOORS & SCREEN FADE
# -----------------------------------------------------------------------------
func _get_overlapping_door() -> Door:
	for node in get_tree().get_nodes_in_group("doors"):
		var door := node as Door
		if door and door.overlaps_body(self):
			var door_col := door.get_node_or_null("CollisionShape2D") as CollisionShape2D
			if door_col and door_col.shape:
				var door_half_h: float = door_col.shape.get_rect().size.y * 0.5
				var dy: float = global_position.y - door_col.global_position.y
				if dy >= -door_half_h and dy <= door_half_h + 4.0:
					return door
			else:
				return door
	return null


func _enter_door(door: Door) -> void:
	if not door.target_position_node:
		return

	is_entering_door = true
	velocity = Vector2.ZERO
	anim_sprite.offset = BASE_SPRITE_OFFSET

	standing_collider.disabled = false
	crouch_collider.disabled = true
	if float_collider: float_collider.disabled = true

	if is_floating:
		_exhale_air_puff()
		await get_tree().create_timer(0.12).timeout
		is_exhaling = false

	is_floating = false
	is_flapping = false
	is_tumbling = false
	has_bounced = false
	is_crouching = false

	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation("enter_door"):
		anim_sprite.sprite_frames.set_animation_loop("enter_door", false)
		anim_sprite.play("enter_door")
		await anim_sprite.animation_finished

	await ScreenFader.fade(true)

	# 1. Clean up stray projectiles & effects
	get_tree().call_group("projectiles", "queue_free")
	get_tree().call_group("effects", "queue_free")

	# 2. Reset all enemy spawners so defeated enemies can respawn
	get_tree().call_group("resettable", "reset_state")

	# 3. Move Kirby and update room
	global_position = door.target_position_node.global_position
	fall_start_y = global_position.y
	if door.target_camera_room:
		set_camera_room(door.target_camera_room)
	anim_sprite.play("idle")

	await get_tree().create_timer(0.06).timeout
	await ScreenFader.fade(false)

	waiting_for_up_release = true
	is_entering_door = false

# -----------------------------------------------------------------------------
# WARPSTAR RIDING + ANIMATION
# -----------------------------------------------------------------------------
func mount_warp_star(star: Node2D, faces_right: bool = true) -> void:
	is_riding_warp_star = true
	velocity = Vector2.ZERO

	# Cancel any float or mouthful and particles
	is_floating = false
	is_mouthful = false
	_clear_inhale_particles()

	# Snap Kirby directly onto the star
	global_position = star.global_position
	if anim_sprite:
		anim_sprite.flip_h = not faces_right

	# Disable colliders while riding
	standing_collider.set_deferred("disabled", true)
	crouch_collider.set_deferred("disabled", true)
	float_collider.set_deferred("disabled", true)
	hurtbox.set_deferred("monitoring", false)

	anim_sprite.play("warp_star_ride")

func dismount_warp_star() -> void:
	is_riding_warp_star = false
	velocity = Vector2.ZERO

	# Re-enable colliders
	standing_collider.set_deferred("disabled", false)
	hurtbox.set_deferred("monitoring", true)

	anim_sprite.play("idle")

# -----------------------------------------------------------------------------
# CAMERA BOUNDARIES
# -----------------------------------------------------------------------------
func set_camera_room(room: ReferenceRect) -> void:
	if not room or not cam:
		return
	cam.limit_enabled = true
	var rect: Rect2 = room.get_global_rect()
	cam.limit_left = int(rect.position.x)
	cam.limit_top = int(rect.position.y)
	cam.limit_right = int(rect.end.x)
	cam.limit_bottom = int(rect.end.y + hud_height)
	cam.reset_smoothing()

func _clamp_to_level_bounds() -> void:
	if not cam or not cam.limit_enabled:
		return
	var half_width: float = _get_current_half_width()
	var min_x: float = cam.limit_left + half_width
	var max_x: float = cam.limit_right - half_width

	if global_position.x < min_x:
		global_position.x = min_x
		velocity.x = 0.0
	elif global_position.x > max_x:
		global_position.x = max_x
		velocity.x = 0.0

	if global_position.y < cam.limit_top:
		global_position.y = cam.limit_top
		if velocity.y < 0.0:
			velocity.y = 0.0


## Smoothly unlocks the camera towards the right without jumping or snapping
func smooth_expand_camera_room(room: ReferenceRect, duration: float = 1.4) -> void:
	if not room or not cam:
		return
	var rect: Rect2 = room.get_global_rect()
	cam.limit_top = min(cam.limit_top, int(rect.position.y))
	cam.limit_bottom = max(cam.limit_bottom, int(rect.end.y + hud_height))

	# Smoothly glide the right boundary over time so the camera pans like butter!
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(cam, "limit_right", int(rect.end.x), duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# -----------------------------------------------------------------------------
# VISUALS & ANIMATIONS
# -----------------------------------------------------------------------------
func _flip() -> void:
	facing_right = not facing_right
	anim_sprite.flip_h = not facing_right
	if inhale_pivot:
		inhale_pivot.scale.x = 1.0 if facing_right else -1.0


func _reset_blink_timer() -> void:
	blink_wait_time = randf_range(2.5, 5.5)


func _update_animations(delta: float) -> void:
	if not anim_sprite or not anim_sprite.sprite_frames:
		return

	anim_sprite.offset.y = BASE_SPRITE_OFFSET.y
	
	if wall_squish_timer > 0.0 and not is_floating and not is_mouthful:
		anim_sprite.play("squish")
		return

	if has_bounced:
		_reset_blink_timer()
		anim_sprite.play("fall")
		return

	if is_swallowing:
		if anim_sprite.animation == "mouthful_gulp" and anim_sprite.is_playing():
			return
		is_swallowing = false

	if is_spitting:
		if anim_sprite.animation == "mouthful_spit" and anim_sprite.is_playing():
			return
		is_spitting = false

	if is_exhaling:
		if anim_sprite.animation == "float_recovery" and anim_sprite.is_playing():
			return
		is_exhaling = false

	if is_floating:
		if anim_sprite.animation == "float_startup" and anim_sprite.is_playing():
			return
		anim_sprite.play("float_flap" if is_flapping else "float")
		if anim_sprite.frame == 0:
			anim_sprite.offset.y = BASE_SPRITE_OFFSET.y + 1.0
		return

	if is_inhale_recovering:
		if (anim_sprite.animation == "inhale_recovery" or anim_sprite.animation == "inflate_recovery") and anim_sprite.is_playing():
			return
		is_inhale_recovering = false

	if is_inhaling:
		if anim_sprite.animation == "inhale_recovery" and anim_sprite.is_playing():
			return
		anim_sprite.play("inhale")
		return

	if is_mouthful:
		if absf(velocity.x) > 5.0:
			anim_sprite.play("mouthful_walk")
			if anim_sprite.frame == 1:
				anim_sprite.offset.y = BASE_SPRITE_OFFSET.y + 1.0
			elif anim_sprite.frame == 0:
				anim_sprite.offset.x = BASE_SPRITE_OFFSET.x + 1.0
		else:
			anim_sprite.play("mouthful_idle")
		return

	if not is_on_floor():
		_reset_blink_timer()
		anim_sprite.play("fall" if is_tumbling else "jump")
	elif is_crouching:
		_reset_blink_timer()
		anim_sprite.play("crouch")
	elif absf(velocity.x) > 5.0:
		_reset_blink_timer()
		anim_sprite.play("walk")
	else:
		if anim_sprite.animation == "blink" and anim_sprite.is_playing():
			return
		anim_sprite.play("idle")
		blink_wait_time -= delta
		if blink_wait_time <= 0.0:
			anim_sprite.play("blink")
			_reset_blink_timer()

# -----------------------------------------------------------------------------
# DEATH FIREWORKS (Authentic Game Boy Effect)
# -----------------------------------------------------------------------------
func _spawn_death_fireworks() -> void:
	# 1. Spawn 8-directional big stars
	var effects_frames: SpriteFrames = null
	if ResourceLoader.exists("res://Animations/effects.tres"):
		effects_frames = load("res://Animations/effects.tres") as SpriteFrames

	for i in range(8):
		var angle: float = float(i) * (TAU / 8.0)
		_spawn_single_firework_star(Vector2.from_angle(angle), effects_frames)

	# 2. Spawn 5 trailing small stars during his jump and fall
	_spawn_death_trail_stars()


func _spawn_single_firework_star(dir_vec: Vector2, frames: SpriteFrames) -> void:
	var star := AnimatedSprite2D.new()
	if frames and frames.has_animation("rotating_star"):
		star.sprite_frames = frames
		star.play("rotating_star")

	star.z_index = 10
	star.global_position = global_position
	star.add_to_group("effects")
	get_parent().add_child(star)

	var target_pos: Vector2 = global_position + dir_vec * 50.0
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(star, "global_position", target_pos, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Big star briefly turns into a small star at the end before vanishing
	tween.tween_callback(func():
		if is_instance_valid(star):
			var end_pos: Vector2 = star.global_position
			star.queue_free()
			_spawn_brief_small_star(end_pos, 0.15)
	)


func _spawn_brief_small_star(pos: Vector2, lifetime: float) -> void:
	if not star_particle_texture:
		return
	var small_star := Sprite2D.new()
	small_star.texture = star_particle_texture
	small_star.z_index = 10
	small_star.global_position = pos
	small_star.add_to_group("effects")
	get_parent().add_child(small_star)

	var t := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.tween_interval(lifetime)
	t.tween_callback(small_star.queue_free)


func _spawn_death_trail_stars() -> void:
	for i in range(5):
		if not is_dying:
			break
		if star_particle_texture:
			var s := Sprite2D.new()
			s.texture = star_particle_texture
			s.z_index = 10
			s.global_position = global_position + Vector2(randf_range(-4, 4), randf_range(-4, 4))
			s.add_to_group("effects")
			get_parent().add_child(s)

			var drift_pos := s.global_position + Vector2.from_angle(randf_range(0.0, TAU)) * randf_range(10.0, 18.0)
			var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			tw.tween_property(s, "global_position", drift_pos, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_callback(s.queue_free)

		await get_tree().create_timer(0.18, true).timeout


# -----------------------------------------------------------------------------
# Dynamic numbers
# -----------------------------------------------------------------------------
func _get_current_half_width() -> float:
	var active_col: CollisionShape2D = float_collider if (is_floating or is_mouthful) else (crouch_collider if is_crouching else standing_collider)
	if active_col and active_col.shape:
		return active_col.shape.get_rect().size.x * 0.5
	return 8.0 # Fallback


# -----------------------------------------------------------------------------
# Pausing and fullscreen
# -----------------------------------------------------------------------------
## Unified world pause controller (shared by the Pause button and the Death sequence)
func set_world_paused(should_pause: bool) -> void:
	get_tree().paused = should_pause
	if should_pause:
		if anim_sprite:
			anim_sprite.pause()
	else:
		if anim_sprite and not is_dying:
			anim_sprite.play()

## Player pause toggle (P)
func toggle_pause() -> void:
	if is_dying:
		return
	is_game_paused = not is_game_paused
	set_world_paused(is_game_paused)

func toggle_fullscreen() -> void:
	var current_mode := DisplayServer.window_get_mode(DisplayServer.MAIN_WINDOW_ID)
	
	if current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN or current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED, DisplayServer.MAIN_WINDOW_ID)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN, DisplayServer.MAIN_WINDOW_ID)
