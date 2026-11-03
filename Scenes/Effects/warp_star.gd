class_name WarpStar
extends Area2D

@export_category("Destination")
@export var target_camera_room: ReferenceRect  # Room1_Forest
@export var target_marker: Marker2D           # Place on the forest ledge where he crashes!
@export var target_scene: PackedScene         # (For future levels)

@export_category("Flight Tuning")
@export var flight_faces_right: bool = true

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D

var is_activated: bool = false

func _ready() -> void:
	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation("warp_star"):
		anim_sprite.play("warp_star")
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if is_activated:
		return
	if body.is_in_group("player") and body is Kirby:
		is_activated = true
		_start_launch_sequence.call_deferred(body as Kirby)


func _start_launch_sequence(kirby: Kirby) -> void:
	set_deferred("monitoring", false)

	# 1. Hide the idle star (Kirby's animation has both Kirby and the star)
	if anim_sprite:
		anim_sprite.visible = false

	# 2. Board star and ensure Kirby faces right
	kirby.mount_warp_star(self, flight_faces_right)

	# 3. 4 SMALL STARS SHOOT OUT (Screenshot 1: X-pattern)
	_spawn_4_star_burst(kirby.global_position)

	# 4. LEVITATE UP AND BACKWARDS
	var start_pos: Vector2 = kirby.global_position
	var levitate_pos: Vector2 = start_pos + Vector2(-14.0, -18.0)
	
	var lev_tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	lev_tween.tween_property(kirby, "global_position", levitate_pos, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await lev_tween.finished

	await get_tree().create_timer(0.08, true).timeout

	# 5. SMOOTHLY UNLOCK CAMERA TO FOREST (Zero snapping, camera follows him seamlessly!)
	if target_camera_room:
		kirby.expand_camera_room(target_camera_room)

	# Determine destination position on the forest ledge
	var forest_landing_pos: Vector2 = target_marker.global_position if target_marker else (start_pos + Vector2(360.0, 0.0))
	var forest_sky_pos: Vector2 = forest_landing_pos + Vector2(-15.0, -90.0)

	# 6. THE FLIGHT ACROSS THE CLOUDS:
	# Part A: Plunge down and forward off the cliff edge
	var plunge_pos: Vector2 = start_pos + Vector2(55.0, 35.0)
	
	# Start small_star trail following him across the clouds
	_start_flight_trail(kirby, 1.6)

	var flight_tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	# Plunge off cliff
	flight_tween.tween_property(kirby, "global_position", plunge_pos, 0.48).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Rocket high into the clouds across to the forest sky
	flight_tween.tween_property(kirby, "global_position", forest_sky_pos, 1.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await flight_tween.finished

	# 7. CRASH INTO THE FOREST (Screenshot 2: Small star drops with boom effect!)
	await _handle_forest_crash(kirby, forest_sky_pos, forest_landing_pos)

	# 8. FADE OUT TO NEXT STAGE
	await get_tree().create_timer(0.4, true).timeout
	await ScreenFader.fade(true)

	if target_scene:
		get_tree().change_scene_to_packed(target_scene)


func _handle_forest_crash(kirby: Kirby, sky_start: Vector2, landing_pos: Vector2) -> void:
	# Hide Kirby temporarily while the small_star drops (Screenshot 2)
	kirby.visible = false
	kirby.global_position = landing_pos

	var drop_star := AnimatedSprite2D.new()
	var effects_frames: SpriteFrames = load("res://Animations/effects.tres") as SpriteFrames
	if effects_frames and effects_frames.has_animation("small_star"):
		drop_star.sprite_frames = effects_frames
		drop_star.play("small_star")
	drop_star.z_index = 10
	drop_star.global_position = sky_start
	get_parent().add_child(drop_star)

	# Drop straight down to the ground
	var drop_tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	drop_tween.tween_property(drop_star, "global_position", landing_pos, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await drop_tween.finished
	drop_star.queue_free()

	# --- BOOM CRASH EFFECT! ---
	HitFX.spawn(self, "small_explosion", landing_pos)

	# Kirby pops out from the explosion and tumbles forward onto his feet
	kirby.visible = true
	if kirby.anim_sprite and kirby.anim_sprite.sprite_frames.has_animation("fall"):
		kirby.anim_sprite.play("fall")

	var bounce_pos: Vector2 = landing_pos + Vector2(12.0, -14.0)
	var final_ground: Vector2 = landing_pos + Vector2(20.0, 0.0)

	var tumble_tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tumble_tween.tween_property(kirby, "global_position", bounce_pos, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tumble_tween.tween_property(kirby, "global_position", final_ground, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tumble_tween.finished

	kirby.dismount_warp_star()


# 4 small stars shooting diagonally outward (Screenshot 1)
func _spawn_4_star_burst(pos: Vector2) -> void:
	var offsets: Array[Vector2] = [
		Vector2(-20.0, -18.0), # Top-Left
		Vector2(20.0, -18.0),  # Top-Right
		Vector2(-20.0, 14.0),  # Bottom-Left
		Vector2(20.0, 14.0)    # Bottom-Right
	]
	for offset in offsets:
		_spawn_drifting_small_star(pos, pos + offset, 0.35)


func _spawn_drifting_small_star(from_pos: Vector2, to_pos: Vector2, duration: float) -> void:
	var s := AnimatedSprite2D.new()
	var frames: SpriteFrames = load("res://Animations/effects.tres") as SpriteFrames
	if frames and frames.has_animation("small_star"):
		s.sprite_frames = frames
		s.play("small_star")
	s.z_index = 10
	s.global_position = from_pos
	s.add_to_group("effects")
	get_parent().add_child(s)

	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(s, "global_position", to_pos, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(s.queue_free)


# Small star trail following Kirby during flight
func _start_flight_trail(kirby: Kirby, duration: float) -> void:
	var interval := 0.08
	var steps := int(duration / interval)
	for i in range(steps):
		if not is_instance_valid(kirby) or not kirby.is_riding_warp_star:
			break
		HitFX.spawn(self, "small_star", kirby.global_position + Vector2(randf_range(-4, 4), randf_range(-4, 4)))
		await get_tree().create_timer(interval, true).timeout
