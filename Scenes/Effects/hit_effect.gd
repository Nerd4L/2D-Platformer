class_name HitEffect
extends AnimatedSprite2D

const BURST_ANIMS: Array[String] = ["star_burst1", "star_burst2", "star_burst3", "star_burst4"]

func _ready() -> void:
	z_index = 10
	animation_finished.connect(queue_free)
	play_random_burst()

func play_random_burst() -> void:
	if not sprite_frames:
		queue_free()
		return
		
	# Find available burst animations
	var valid: Array[String] = []
	for anim in BURST_ANIMS:
		if sprite_frames.has_animation(anim):
			valid.append(anim)
			
	if not valid.is_empty():
		play(valid[randi() % valid.size()])
	else:
		# Fallback to default if names differ
		play()

## Static helper so any script can spawn a starburst in one line
static func spawn_at(parent: Node, pos: Vector2, effect_scene: PackedScene = null) -> void:
	var scene_to_use: PackedScene = effect_scene
	if not scene_to_use:
		scene_to_use = load("res://scenes/effects/hit_effect.tscn") as PackedScene
	if scene_to_use:
		var inst := scene_to_use.instantiate() as Node2D
		inst.global_position = pos
		parent.add_child(inst)
