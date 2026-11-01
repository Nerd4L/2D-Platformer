class_name HitFX
extends RefCounted

const DEFAULT_FRAMES_PATH: String = "res://Animations/effects.tres"
static var _cached_frames: SpriteFrames = null


static func spawn(tree: SceneTree, anim_name: String, global_pos: Vector2, flip_h: bool = false, custom_frames: SpriteFrames = null) -> void:
	# 1. Resolve which SpriteFrames resource to use
	var frames: SpriteFrames = custom_frames
	if not frames:
		if not _cached_frames and ResourceLoader.exists(DEFAULT_FRAMES_PATH):
			_cached_frames = load(DEFAULT_FRAMES_PATH) as SpriteFrames
		frames = _cached_frames

	if not frames or not frames.has_animation(anim_name):
		print("WARNING: HitFX could not find animation named '", anim_name, "' in SpriteFrames!")
		return

	# 2. Create the AnimatedSprite2D effect node
	var fx := AnimatedSprite2D.new()
	fx.sprite_frames = frames
	fx.z_index = 10
	fx.global_position = global_pos
	fx.flip_h = flip_h
	
	# Ensure the explosion doesn't loop forever
	frames.set_animation_loop(anim_name, false)
	
	# 3. Add to the active scene root so it plays independently of the dying projectile!
	tree.current_scene.add_child(fx)
	fx.play(anim_name)
	fx.animation_finished.connect(fx.queue_free)


static func random_star_burst() -> String:
	return ["star_burst1", "star_burst2", "star_burst3", "star_burst4"].pick_random()
