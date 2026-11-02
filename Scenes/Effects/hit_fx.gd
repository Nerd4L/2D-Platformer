class_name HitFX
extends RefCounted

const EFFECTS_PATH: String = "res://Animations/effects.tres"
const STARBURST_PATH: String = "res://Animations/star_burst_frames.tres"

static var _cached_effects: SpriteFrames = null
static var _cached_starburst: SpriteFrames = null


## Single unified spawner for all game effects.
## Example usage:
##   HitFX.spawn(self, "small_explosion", pos)
##   HitFX.spawn(self, "star_burst", pos) # Automatically picks a random 1-4
static func spawn(context: Variant, anim_name: String, global_pos: Vector2, flip_h: bool = false) -> void:
	# 1. Resolve animation name (auto-randomize "star_burst")
	var target_anim: String = anim_name
	if target_anim == "star_burst":
		target_anim = "star_burst%d" % randi_range(1, 4)

	# 2. Automatically resolve which SpriteFrames resource has this animation
	var frames: SpriteFrames = _get_frames_for_anim(target_anim)
	if not frames or not frames.has_animation(target_anim):
		push_warning("HitFX: Animation '%s' not found in effect resources!" % target_anim)
		return

	# 3. Resolve parent node
	var parent_node: Node = _resolve_parent(context)
	if not parent_node:
		return

	# 4. Create and play the one-shot effect
	var fx := AnimatedSprite2D.new()
	fx.sprite_frames = frames
	fx.z_index = 10
	fx.global_position = global_pos
	fx.flip_h = flip_h
	fx.add_to_group("effects")

	frames.set_animation_loop(target_anim, false)
	parent_node.add_child(fx)
	fx.play(target_anim)
	fx.animation_finished.connect(fx.queue_free)


## Auto-routes to star_burst_frames.tres or effects.tres on demand
static func _get_frames_for_anim(anim_name: String) -> SpriteFrames:
	if anim_name.begins_with("star_burst"):
		if not _cached_starburst and ResourceLoader.exists(STARBURST_PATH):
			_cached_starburst = load(STARBURST_PATH) as SpriteFrames
		return _cached_starburst
	else:
		if not _cached_effects and ResourceLoader.exists(EFFECTS_PATH):
			_cached_effects = load(EFFECTS_PATH) as SpriteFrames
		return _cached_effects


static func _resolve_parent(context: Variant) -> Node:
	if context is SceneTree:
		var st := context as SceneTree
		return st.current_scene if st.current_scene else st.root
	elif context is Node:
		var node := context as Node
		var tree: SceneTree = node.get_tree()
		if tree and tree.current_scene:
			return tree.current_scene
		return node.get_parent() if node.get_parent() else node
	return null
