extends Area2D
class_name AirPuff

@export var speed: float = 200.0
@export var decel: float = 300.0
@export var wait_time: float = 0.15
@export var enemy_hitbox_size: Vector2 = Vector2(12.0, 12.0)
@export var hit_fx_frames: SpriteFrames


var dir: float = 1.0
var current_speed: float = 125.0
var has_hit: bool = false

@onready var spr: Sprite2D = get_node_or_null("Sprite2D")
@onready var anim_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")


func _ready() -> void:
	add_to_group("resettable")
	# The 12x4 Area2D collider ONLY checks Layer 1 (Ground/Walls) so it glides over ledges!
	collision_mask = 1 << 0
	current_speed = speed
	
	if spr:
		spr.flip_h = dir < 0.0

	body_entered.connect(_on_body_entered)


func reset_state() -> void:
	queue_free()


func _physics_process(delta: float) -> void:
	if has_hit:
		return
	
	global_position.x += dir * current_speed * delta
	current_speed = move_toward(current_speed, 0.0, decel * delta)
	
	# Check a full 12x12 hitbox against Layer 4 (Enemies) every physics frame!
	if _check_enemy_hit():
		return
	
	if wait_time <= 0:
		queue_free()
	elif current_speed <= 5.0:
		current_speed = 0.0
		wait_time -= delta
		return

func _check_enemy_hit() -> bool:
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	var rect := RectangleShape2D.new()
	rect.size = enemy_hitbox_size
	query.shape = rect
	query.transform = global_transform
	query.collision_mask = 1 << 3 # Layer 4: Enemies
	
	var hits: Array[Dictionary] = space_state.intersect_shape(query, 1)
	if not hits.is_empty():
		var enemy: Node2D = hits[0].collider as Node2D
		if enemy:
			has_hit = true
			set_deferred("monitoring", false)
			global_position = enemy.global_position
			enemy.queue_free()
			_spawn_hit_fx(["star_burst1", "star_burst2", "star_burst3", "star_burst4"].pick_random())
			return true
	return false


func _on_body_entered(body: Node2D) -> void:
	if has_hit:
		return
	has_hit = true
	set_deferred("monitoring", false)
	
	if body is TileMapLayer:
		global_position = _get_hit_tile_pos(body)
	_spawn_hit_fx("boom")


func _get_hit_tile_pos(tilemap: TileMapLayer) -> Vector2:
	for x_dist in [6.5, 2.0, 0.0]:
		var probe_x: float = global_position.x + dir * x_dist
		for y_offset in [0.0, 2.0, -2.0]:
			var cell: Vector2i = tilemap.local_to_map(tilemap.to_local(Vector2(probe_x, global_position.y + y_offset)))
			var tile_data: TileData = tilemap.get_cell_tile_data(cell)
			if tile_data and tile_data.get_collision_polygons_count(0) > 0:
				return tilemap.to_global(tilemap.map_to_local(cell))
				
	var fallback_cell: Vector2i = tilemap.local_to_map(tilemap.to_local(Vector2(global_position.x + dir * 6.5, global_position.y)))
	return tilemap.to_global(tilemap.map_to_local(fallback_cell))


func _spawn_hit_fx(anim_name: String) -> void:
	z_index = 10
	# Hide the static puff Sprite2D so only the explosion animation shows!
	if spr:
		spr.visible = false
		
	var frames: SpriteFrames = hit_fx_frames
	if not frames and anim_sprite:
		frames = anim_sprite.sprite_frames
		
	if frames and frames.has_animation(anim_name):
		var fx := AnimatedSprite2D.new()
		fx.sprite_frames = frames
		frames.set_animation_loop(anim_name, false)
		add_child(fx)
		fx.flip_h = dir < 0.0
		fx.play(anim_name)
		await fx.animation_finished
		
	queue_free()
