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
@export_category("Health & Damage")
@export var hurtbox: Area2D
@export var max_health: int = 6
@export var starting_lives: int = 4
@export var invulnerability_duration: float = 1.6
@export var hurt_recoil_time: float = 0.32
@export var knockback_horizontal: float = 80.0
@export var knockback_vertical: float = -110.0

@export_category("Normal Movement (Game Boy Tuned)")
@export var move_speed: float = 75.0
@export var jump_velocity: float = -178.0 # ~37.7px max jump height
@export var normal_gravity: float = 420.0
@export var max_fall_speed: float = 135.0
@export var ground_accel: float = 380.0
@export var ground_decel: float = 320.0
@export var air_decel: float = 97.5
@export var coyote_time: float = 0.12

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

@export_category("Collision, Animation & Level")
@export var standing_collider: CollisionShape2D
@export var crouch_collider: CollisionShape2D
@export var float_collider: CollisionShape2D
@export var anim_sprite: AnimatedSprite2D
@export var terrain_layer: TileMapLayer
@export var starting_camera_room: ReferenceRect

@export_category("Fall Bounce & Impact Star")
@export var tumble_fall_distance: float = 48.0
@export var star_fall_distance: float = 12.0
@export var bounce_velocity: float = -95.0
@export var star_particle_texture: Texture2D

@onready var cam: Camera2D = $Camera2D

# -----------------------------------------------------------------------------
# INTERNAL STATE
# -----------------------------------------------------------------------------
var start_pos: Vector2
var facing_right: bool = true
var coyote_time_counter: float = 0.0
var fall_start_y: float = 0.0

var current_health: int = 6
var lives: int = 4
var score: int = 0

var is_hurt: bool = false
var is_invulnerable: bool = false
var hurt_timer: float = 0.0
var invulnerable_timer: float = 0.0
var blink_interval: float = 0.06
var blink_timer: float = 0.0

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

var is_entering_door: bool = false
var waiting_for_up_release: bool = false

var swallow_spit_timer: float = 0.0
var wall_squish_timer: float = 0.0
var platform_crouch_delay: float = 0.0
var platform_drop_timer: float = 0.0
var blink_wait_time: float = 3.5

var inhaling_enemies: Array[Node2D] = []
var active_particles: Array[Sprite2D] = []

# Persistent screen fader
var _fade_layer: CanvasLayer = null
var _fade_mat: ShaderMaterial = null


# -----------------------------------------------------------------------------
# SETUP & RESET
# -----------------------------------------------------------------------------
func _ready() -> void:
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
	elif terrain_layer:
		_setup_terrain_camera_limits()

	# Broadcast initial stats to HUD
	call_deferred("_emit_initial_stats")


func _emit_initial_stats() -> void:
	health_changed.emit(current_health, max_health)
	lives_changed.emit(lives)
	score_changed.emit(score)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			get_tree().call_group("resettable", "reset_state")


func reset_state() -> void:
	global_position = start_pos
	if starting_camera_room:
		set_camera_room(starting_camera_room)
	velocity = Vector2.ZERO
	fall_start_y = start_pos.y

	if not facing_right:
		_flip()

	current_health = max_health
	is_hurt = false
	is_invulnerable = false
	hurt_timer = 0.0
	invulnerable_timer = 0.0
	if anim_sprite:
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

	wall_squish_timer = 0.0
	swallow_spit_timer = 0.0
	platform_crouch_delay = 0.0
	platform_drop_timer = 0.0

	_clear_inhale_state()

	if cam:
		cam.reset_smoothing()
	anim_sprite.play("idle")


# -----------------------------------------------------------------------------
# MAIN PHYSICS LOOP
# -----------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	_cleanup_invalid_enemies()
	_update_action_timers(delta)
	_update_hurt_and_invulnerability(delta)

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
	_handle_jump_and_float_actions(busy_action, overlapping_door != null)
	_update_colliders(busy_action)
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


func _handle_jump_and_float_actions(busy_action: bool, near_door: bool) -> void:
	is_flapping = false
	var busy_inhaling: bool = is_inhaling or is_inhale_recovering or busy_action

	if not is_floating and not is_exhaling and not has_bounced:
		if Input.is_action_pressed("float_up") and not is_mouthful and not busy_inhaling and not near_door:
			is_floating = true
			is_flapping = true
			is_tumbling = false
			velocity.y = float_up_velocity
			anim_sprite.play("float_startup")
		elif not busy_inhaling and Input.is_action_just_pressed("jump") and coyote_time_counter > 0.0:
			velocity.y = jump_velocity
			coyote_time_counter = 0.0
	elif is_floating:
		if Input.is_action_pressed("float_up") or Input.is_action_pressed("jump"):
			velocity.y = float_up_velocity
			is_flapping = true
		if Input.is_action_just_pressed("action"):
			_exhale_air_puff()

	# Variable jump height cut
	if not is_floating and Input.is_action_just_released("jump") and velocity.y < -40.0:
		velocity.y *= 0.5


# -----------------------------------------------------------------------------
# INHALE & MOUTHFUL ACTIONS
# -----------------------------------------------------------------------------
func _handle_inhale_and_mouth_actions(busy_action: bool) -> void:
	if is_mouthful and not busy_action and not has_bounced:
		if Input.is_action_just_pressed("action"):
			_spit_star()
		elif Input.is_action_just_pressed("crouch") and is_on_floor():
			_swallow_mouthful()

	var can_inhale: bool = not is_floating and not is_exhaling and not is_mouthful and not busy_action and not has_bounced

	if can_inhale:
		if Input.is_action_pressed("float_up") and inhaling_enemies.is_empty():
			is_inhaling = false
			is_inhale_recovering = false
			_clear_inhale_particles()
		elif Input.is_action_just_pressed("action") and not is_inhaling and not is_inhale_recovering and not is_crouching:
			is_inhaling = true
			is_tumbling = false
			wall_squish_timer = 0.0
			anim_sprite.play("inhale_recovery")
		elif is_inhaling and not Input.is_action_pressed("action") and inhaling_enemies.is_empty():
			# Released with no enemy -> clear particles instantly
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
	swallow_spit_timer = 0.18
	anim_sprite.play("mouthful_gulp")


func _spit_star() -> void:
	is_mouthful = false
	is_spitting = true
	swallow_spit_timer = 0.16
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
	proj.global_position = global_position + Vector2(10.0 * p_dir, 0.0)
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
	# Enemies currently trapped in Kirby's inhale vortex cannot damage him!
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

	if is_enemy:
		take_damage(1, enemy_node.global_position)


func take_damage(amount: int, source_pos: Vector2) -> void:
	if is_invulnerable or is_entering_door:
		return

	current_health = max(current_health - amount, 0)
	health_changed.emit(current_health, max_health)

	# 1. State disruption: Hit while floating or holding mouthful
	if is_floating:
		is_floating = false
		is_flapping = false
		is_exhaling = false
	if is_mouthful:
		is_mouthful = false
		_spawn_projectile(Projectile.Type.STAR)
	if is_inhaling:
		_clear_inhale_state()
		is_inhaling = false

	# 2. Knockback recoil
	is_hurt = true
	hurt_timer = hurt_recoil_time
	var knock_dir: float = -1.0 if (source_pos.x > global_position.x) else 1.0
	velocity.x = knock_dir * knockback_horizontal
	velocity.y = knockback_vertical

	# 3. Invincibility & blinking
	is_invulnerable = true
	invulnerable_timer = invulnerability_duration
	blink_timer = 0.0

	_spawn_impact_star()

	if anim_sprite and anim_sprite.sprite_frames.has_animation("hurt"):
		anim_sprite.play("hurt")

	if current_health <= 0:
		_handle_death()


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
	lives = max(lives - 1, 0)
	lives_changed.emit(lives)
	await gb_palette_fade(true)
	reset_state()
	await gb_palette_fade(false)


func add_score(points: int) -> void:
	score += points
	score_changed.emit(score)


# -----------------------------------------------------------------------------
# HORIZONTAL MOVEMENT & PLATFORMS
# -----------------------------------------------------------------------------
func _handle_horizontal_movement(delta: float, busy_action: bool) -> void:
	var move_dir: float = Input.get_axis("move_left", "move_right")
	var lock_input: bool = is_crouching or is_inhaling or busy_action
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
		if platform_crouch_delay >= 0.08:
			platform_drop_timer = 0.18
			platform_crouch_delay = 0.0
			position.y += 1.0
	else:
		platform_crouch_delay = 0.0

	var ignore_platforms: bool = (velocity.y < -1.0) or (platform_drop_timer > 0.0)
	set_collision_mask_value(2, not ignore_platforms)


func _update_colliders(busy_action: bool) -> void:
	var is_big_hitbox: bool = is_floating or is_mouthful
	var crouch_pressed: bool = Input.is_action_pressed("crouch")
	var busy_inhaling: bool = is_inhaling or is_inhale_recovering or busy_action

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
	if not is_tumbling and is_on_wall() and not was_on_wall and absf(pre_vx) > move_speed * 0.8:
		_spawn_impact_star()
		wall_squish_timer = 0.12
		anim_sprite.position.x = 2.0 if pre_vx > 0.0 else -2.0

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
	if swallow_spit_timer > 0.0:
		swallow_spit_timer -= delta
		if swallow_spit_timer <= 0.0:
			is_swallowing = false
			is_spitting = false

	if platform_drop_timer > 0.0:
		platform_drop_timer -= delta


# -----------------------------------------------------------------------------
# DOORS & SCREEN FADE
# -----------------------------------------------------------------------------
func _get_overlapping_door() -> Door:
	for node in get_tree().get_nodes_in_group("doors"):
		var door := node as Door
		if door and door.overlaps_body(self):
			var door_col := door.get_node_or_null("CollisionShape2D") as Node2D
			var door_y: float = door_col.global_position.y if door_col else door.global_position.y
			var dy: float = global_position.y - door_y
			if dy <= 2.0 and dy >= -12.0:
				return door
	return null


func _enter_door(door: Door) -> void:
	if not door.target_position_node:
		return

	is_entering_door = true
	velocity = Vector2.ZERO
	anim_sprite.position = Vector2.ZERO

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

	await gb_palette_fade(true)

	for node in get_tree().get_nodes_in_group("resettable"):
		if node is Projectile:
			node.queue_free()

	global_position = door.target_position_node.global_position
	fall_start_y = global_position.y
	if door.target_camera_room:
		set_camera_room(door.target_camera_room)
	anim_sprite.play("idle")

	await get_tree().create_timer(0.06).timeout
	await gb_palette_fade(false)

	waiting_for_up_release = true
	is_entering_door = false


func gb_palette_fade(to_white: bool) -> void:
	if not _fade_layer or not is_instance_valid(_fade_layer):
		_fade_layer = CanvasLayer.new()
		_fade_layer.layer = 100
		var rect := ColorRect.new()
		rect.position = Vector2.ZERO
		rect.size = Vector2(160.0, 128.0) # Game Boy screen minus 16px HUD
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var shader := Shader.new()
		shader.code = """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform int fade_step : hint_range(0, 3) = 0;

void fragment() {
	vec4 col = texture(screen_tex, SCREEN_UV);
	float lum = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	int shade = int(round(lum * 3.0));
	shade = min(shade + fade_step, 3);
	float out_lum = float(shade) / 3.0;
	COLOR = vec4(vec3(out_lum), 1.0);
}
"""
		_fade_mat = ShaderMaterial.new()
		_fade_mat.shader = shader
		rect.material = _fade_mat
		_fade_layer.add_child(rect)
		get_tree().root.add_child(_fade_layer)

	_fade_layer.visible = true
	var steps: Array = [1, 2, 3] if to_white else [2, 1, 0]
	for s in steps:
		_fade_mat.set_shader_parameter("fade_step", s)
		await get_tree().create_timer(0.055).timeout

	if not to_white:
		_fade_layer.visible = false


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
	cam.limit_bottom = int(rect.end.y) + 16
	cam.reset_smoothing()


func _setup_terrain_camera_limits() -> void:
	cam.limit_enabled = true
	var used_rect: Rect2i = terrain_layer.get_used_rect()
	var tile_size: Vector2i = terrain_layer.tile_set.tile_size
	var top_left: Vector2 = terrain_layer.to_global(Vector2(used_rect.position * tile_size))
	var bottom_right: Vector2 = terrain_layer.to_global(Vector2(used_rect.end * tile_size))
	cam.limit_left = int(top_left.x)
	cam.limit_top = int(top_left.y)
	cam.limit_right = int(bottom_right.x)
	cam.limit_bottom = int(bottom_right.y) + 16


func _clamp_to_level_bounds() -> void:
	if not cam or not cam.limit_enabled:
		return
	var half_width: float = 12.0 if (is_floating or is_mouthful) else 8.0
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

	if wall_squish_timer <= 0.0:
		anim_sprite.position.x = 0.0
	anim_sprite.position.y = 0.0

	# Hurt animation takes top priority
	if is_hurt:
		if anim_sprite.sprite_frames.has_animation("hurt"):
			anim_sprite.play("hurt")
		return

	if has_bounced:
		_reset_blink_timer()
		anim_sprite.play("fall")
		return

	if is_swallowing or is_spitting:
		return

	if is_exhaling:
		if anim_sprite.animation == "float_recovery" and anim_sprite.is_playing():
			return
		is_exhaling = false

	if is_floating:
		if anim_sprite.animation == "float_startup" and anim_sprite.is_playing():
			return
		anim_sprite.play("float_flap" if is_flapping else "float")
		if anim_sprite.frame == 0:
			anim_sprite.position.y = 1.0
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
				anim_sprite.position.y = 1.0
			elif anim_sprite.frame == 0:
				anim_sprite.position.x = 1.0
		else:
			anim_sprite.play("mouthful_idle")
		return

	if wall_squish_timer > 0.0:
		wall_squish_timer -= delta
		anim_sprite.play("squish")
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
