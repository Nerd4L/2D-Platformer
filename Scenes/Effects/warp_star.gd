class_name WarpStar
extends Area2D

@export_category("Destination")
@export var target_camera_room: ReferenceRect  # Room1_Forest
@export var target_marker: Marker2D           # Marker on the forest ledge where it crashes!
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
	await get_tree().create_timer(0.35, true).timeout

	# 4. LEVITATE UP AND BACKWARDS
	var start_pos: Vector2 = kirby.global_position
	var levitate_pos: Vector2 = start_pos + Vector2(-5.0, -12.0)
	var levitate_duration: float = 1.0
	
	var lev_tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	lev_tween.tween_property(kirby, "global_position", levitate_pos, levitate_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await lev_tween.finished
	
	await get_tree().create_timer(0.2, true).timeout

	# 5. SMOOTH CAMERA GLIDE: Pan the camera boundaries to the forest
	if target_camera_room:
		kirby.smooth_expand_camera_room(target_camera_room, 2)

	await get_tree().create_timer(0.2, true).timeout

	# 6. THE FLIGHT ACROSS THE CLOUDS:
	var forest_landing_pos: Vector2 = target_marker.global_position
	var forest_sky_pos: Vector2 = forest_landing_pos + Vector2(-5.0, -85.0)
	
	var plunge_pos: Vector2 = start_pos + Vector2(55.0, 45.0)
	var plunge_duration: float = 2
	var rise_duration: float = 1.0
	
	# Start small_star trail following him across the clouds
	_start_flight_trail(kirby, 1.6)

	var flight_tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	flight_tween.tween_property(kirby, "global_position", plunge_pos, plunge_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	flight_tween.tween_property(kirby, "global_position", forest_sky_pos, rise_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await flight_tween.finished

	# 7. CRASH INTO THE FOREST (Slow, graceful drop as small_star)
	await _handle_forest_crash(kirby, forest_sky_pos, forest_landing_pos, 2.0)

	# 8. FADE OUT Cutscene Complete
	await get_tree().create_timer(0.35, true).timeout
	await ScreenFader.fade(true)

	if target_scene:
		get_tree().change_scene_to_packed(target_scene)


func _handle_forest_crash(kirby: Kirby, sky_start: Vector2, landing_pos: Vector2, duration: float) -> void:
	# Keep Kirby hidden inside the star!
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

	# Drop slowly from the sky
	var drop_tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	drop_tween.tween_property(drop_star, "global_position", landing_pos, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await drop_tween.finished
	drop_star.queue_free()

	# --- BOOM CRASH EFFECT! ---
	HitFX.spawn(self, "small_explosion", landing_pos)


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
