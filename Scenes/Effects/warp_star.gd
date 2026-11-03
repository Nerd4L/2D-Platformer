@tool
class_name WarpStar
extends Area2D

@export_category("Debug Line")
@export var show_debug_spline: bool = false

@export_category("Destination")
@export var target_camera_room: ReferenceRect  # Room1_Forest
@export var levitate_marker: Marker2D          # Marker where he levitates to at the start
@export var forest_marker: Marker2D            # Marker where the small star crashes in the forest
@export var target_scene: PackedScene          # (For future levels)

@export_category("Visual Flight Path Choreography")
@export var flight_path_container: Node2D
@export var levitate_duration: float = 0.6
@export var flight_duration: float = 4
@export var pre_flight_camera_lead: float = 0.2
@export var camera_pan_duration: float = 6
@export var forest_crash_duration: float = 3

@export_category("Flight Tuning")
@export var flight_faces_right: bool = true


@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D

var is_activated: bool = false

func _ready() -> void:
	if Engine.is_editor_hint():
		return

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

	# 1. Hide idle star
	if anim_sprite:
		anim_sprite.visible = false

	# 2. Board star and face right
	kirby.mount_warp_star(self, flight_faces_right)

	# 3. 4 SMALL STARS SHOOT OUT (Screenshot 1: Sideways K-pattern)
	_spawn_4_star_burst(kirby.global_position)
	await get_tree().create_timer(0.35, true).timeout

	# 4. LEVITATE UP AND BACKWARDS	
	var start_pos: Vector2 = kirby.global_position
	var levitate_pos: Vector2 = levitate_marker.global_position
	var lev_tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	lev_tween.tween_property(kirby, "global_position", levitate_pos, levitate_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	await get_tree().create_timer(0.2, true).timeout

	# -------------------------------------------------------------------------
	# 5. CAMERA: Pans all the way to the right camera limit
	# -------------------------------------------------------------------------
	var cam: Camera2D = kirby.cam
	var start_cam_pos: Vector2 = cam.get_screen_center_position() if cam else start_pos
	var target_cam_x: float = start_cam_pos.x + 300.0

	if target_camera_room and cam:
		var rect: Rect2 = target_camera_room.get_global_rect()
		cam.limit_right = max(cam.limit_right, int(rect.end.x))
		var viewport_half_w: float = get_viewport_rect().size.x * 0.5
		target_cam_x = rect.end.x - viewport_half_w

		# Camera begins gently gliding to the right immediately!
		var cam_tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		cam_tween.tween_method(func(t: float):
			if is_instance_valid(cam):
				var current_pan_x: float = lerpf(start_cam_pos.x, target_cam_x, t)
				cam.global_position = Vector2(current_pan_x, start_cam_pos.y)
		, 0.0, 1.0, camera_pan_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	await lev_tween.finished
	await get_tree().create_timer(pre_flight_camera_lead, true).timeout

	# -------------------------------------------------------------------------
	# 6. BUILD SMOOTH SPLINE FROM SCENE MARKERS
	# -------------------------------------------------------------------------
	var curve := _build_curve_from_markers(levitate_pos)
	var curve_len: float = curve.get_baked_length()

	var flight_tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	flight_tween.tween_method(func(t: float):
		if is_instance_valid(kirby):
			kirby.global_position = curve.sample_baked(t * curve_len)
	, 0.0, 1.0, flight_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	# Start trail of small_stars
	await get_tree().create_timer(0.12, true).timeout
	_start_flight_trail(kirby, flight_duration)

	await flight_tween.finished
	# await get_tree().create_timer(0.1, true).timeout

	# 7. CRASH INTO THE FOREST
	var forest_landing_pos: Vector2 = forest_marker.global_position
	var forest_sky_pos: Vector2 = forest_landing_pos + Vector2(-5.0, -85.0)
	await _handle_forest_crash(kirby, forest_sky_pos, forest_landing_pos, forest_crash_duration)

	# 8. FADE OUT CUTSCENE COMPLETE
	await get_tree().create_timer(0.4, true).timeout
	await ScreenFader.fade(true)

	if target_scene:
		get_tree().change_scene_to_packed(target_scene)


## Automatically connects your scene markers into a silky-smooth spline!
func _build_curve_from_markers(start_pos: Vector2) -> Curve2D:
	var curve := Curve2D.new()
	curve.bake_interval = 4.0

	var points: Array[Vector2] = [start_pos]

	if flight_path_container:
		for child in flight_path_container.get_children():
			if child is Node2D:
				points.append(child.global_position)

	# Auto-calculate smooth Catmull-Rom tangents so the curve is completely smooth
	for i in range(points.size()):
		var p_curr: Vector2 = points[i]
		var p_prev: Vector2 = points[max(i - 1, 0)]
		var p_next: Vector2 = points[min(i + 1, points.size() - 1)]

		var tangent: Vector2 = (p_next - p_prev) * 0.25
		curve.add_point(p_curr, -tangent, tangent)

	return curve


func _handle_forest_crash(kirby: Kirby, sky_start: Vector2, landing_pos: Vector2, duration: float) -> void:
	kirby.visible = false

	var drop_star := AnimatedSprite2D.new()
	var effects_frames: SpriteFrames = load("res://Animations/effects.tres") as SpriteFrames
	if effects_frames and effects_frames.has_animation("small_star"):
		drop_star.sprite_frames = effects_frames
		drop_star.play("small_star")
	drop_star.z_index = 10
	drop_star.global_position = sky_start
	get_parent().add_child(drop_star)

	# Slow graceful drop from the sky
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
		Vector2(-24.0, -4.0),  # Bottom-Left
		Vector2(24.0, -4.0)    # Bottom-Right
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
	var interval := 0.12
	var steps := int(duration / interval)
	var prev_pos: Vector2 = kirby.global_position

	for i in range(steps):
		if not is_instance_valid(kirby) or not kirby.is_riding_warp_star:
			break

		# 1. Calculate the exact backwards direction from Kirby's movement!
		var move_vec: Vector2 = kirby.global_position - prev_pos
		var back_dir: Vector2
		if move_vec.length_squared() > 0.5:
			back_dir = -move_vec.normalized()
		else:
			back_dir = Vector2(-1.0, 0.0)

		# 2. Add a slight random cone spray
		back_dir = back_dir.rotated(randf_range(-0.35, 0.35))
		prev_pos = kirby.global_position

		# 3. Shoot star backwards!
		_spawn_trailing_star(kirby.global_position, back_dir)

		await get_tree().create_timer(interval, true).timeout

func _spawn_trailing_star(spawn_pos: Vector2, shoot_dir: Vector2) -> void:
	var s := AnimatedSprite2D.new()
	var frames: SpriteFrames = load("res://Animations/effects.tres") as SpriteFrames
	if frames and frames.has_animation("small_star"):
		s.sprite_frames = frames
		s.play("small_star")
	s.z_index = 10
	s.global_position = spawn_pos
	s.add_to_group("effects")
	get_parent().add_child(s)

	# Drifts backwards 14–22px away from flight direction as it sparkles
	var drift_dist: float = randf_range(14.0, 22.0)
	var target_pos: Vector2 = spawn_pos + shoot_dir * drift_dist

	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(s, "global_position", target_pos, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(s.queue_free)

# -----------------------------------------------------------------------------
# LIVE EDITOR PATH PREVIEW
# -----------------------------------------------------------------------------
func _process(_delta: float) -> void:
	# Continuously redraws in the 2D editor as you move markers
	if Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	# Only draw in the editor or in debug builds
	if not Engine.is_editor_hint() and not OS.is_debug_build():
		return
	if not flight_path_container:
		return
	if not show_debug_spline:
		return

	# Kirby levitates up
	var curve := _build_curve_from_markers(levitate_marker.global_position)
	var baked := curve.get_baked_points()
	if baked.size() < 2:
		return

	# Convert world points to local coordinates for drawing
	var local_pts: PackedVector2Array = []
	for pt in baked:
		local_pts.append(to_local(pt))

	# Draws a golden rollercoaster spline connecting all your markers!
	draw_polyline(local_pts, Color("ffd700"), 1.0, true)

	# Draws a small red dot at each marker point
	if flight_path_container:
		for child in flight_path_container.get_children():
			if child is Node2D:
				draw_circle(to_local(child.global_position), 2.5, Color("ff0000ff"))
