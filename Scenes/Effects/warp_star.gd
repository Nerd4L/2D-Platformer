class_name WarpStar
extends Area2D

@export_category("Destination")
@export var target_scene: PackedScene
@export var target_marker: Marker2D
@export var target_camera_room: ReferenceRect

@export_category("Flight Tuning")
@export var launch_angle_degrees: float = -35.0 # Up and to the right
@export var flight_speed: float = 240.0
@export var flight_distance: float = 220.0

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
		_start_launch_sequence(body as Kirby)


func _start_launch_sequence(kirby: Kirby) -> void:
	set_deferred("monitoring", false)

	# 1. Hide the idle star sprite (Kirby's animation has both Kirby and the star!)
	if anim_sprite:
		anim_sprite.visible = false

	# 2. Kirby locks controls and snaps to the star
	kirby.mount_warp_star(self)

	# 3. Brief charge-up pause (0.35s)
	await get_tree().create_timer(0.35, true).timeout

	# 4. Flight Departure Arc (Tweens Kirby directly into the sky!)
	var flight_dir: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(launch_angle_degrees))
	var flight_duration: float = flight_distance / flight_speed
	var target_pos: Vector2 = kirby.global_position + flight_dir * flight_distance

	# Spawn trail sparkles behind Kirby as he flies
	_start_star_trail(kirby, flight_duration)

	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(kirby, "global_position", target_pos, flight_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished

	# 5. Fade to white as Kirby sails off-screen
	await ScreenFader.fade(true)

	# 6. Transition to Destination
	if target_scene:
		get_tree().change_scene_to_packed(target_scene)
	elif target_marker:
		kirby.global_position = target_marker.global_position
		if target_camera_room:
			kirby.set_camera_room(target_camera_room)
		kirby.dismount_warp_star()
		await ScreenFader.fade(false)


func _start_star_trail(kirby: Kirby, duration: float) -> void:
	var interval := 0.08
	var steps := int(duration / interval)
	for i in range(steps):
		if not is_instance_valid(kirby) or not kirby.is_riding_warp_star:
			break
		HitFX.spawn(self, "star_burst", kirby.global_position + Vector2(randf_range(-6, 6), randf_range(-6, 6)))
		await get_tree().create_timer(interval, true).timeout
