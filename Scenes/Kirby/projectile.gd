extends Area2D
class_name Projectile

enum Type { STAR, AIR_PUFF }

@export var type: Type = Type.STAR
@export var star_speed: float = 200.0
@export var star_max_distance: float = 160.0

@export var puff_start_speed: float = 200.0
@export var puff_decel: float = 300.0
@export var wait_time: float = 0.15

@export var enemy_hitbox_size: Vector2 = Vector2(12.0, 12.0)
@export var fx_frames: SpriteFrames

@onready var star_anim: AnimatedSprite2D = get_node_or_null("StarSprite")
@onready var puff_spr: Sprite2D = get_node_or_null("PuffSprite")

var dir: float = 1.0
var current_speed: float = 0.0
var distance_traveled: float = 0.0
var has_hit: bool = false
var current_wait: float = 0.15


func _ready() -> void:
	add_to_group("resettable")
	# Area2D collider only detects Layer 1 (Ground/Walls) for 12x4 terrain gliding
	collision_mask = 1 << 0
	body_entered.connect(_on_body_entered)


func setup(proj_type: Type, facing_dir: float) -> void:
	type = proj_type
	dir = facing_dir
	current_wait = wait_time

	if type == Type.STAR:
		current_speed = star_speed
		if puff_spr:
			puff_spr.visible = false
		if star_anim:
			star_anim.visible = true
			star_anim.flip_h = dir < 0.0
			star_anim.play("rotate")
	elif type == Type.AIR_PUFF:
		current_speed = puff_start_speed
		if star_anim:
			star_anim.visible = false
		if puff_spr:
			puff_spr.visible = true
			puff_spr.flip_h = dir < 0.0


func _physics_process(delta: float) -> void:
	if has_hit:
		return

	if type == Type.AIR_PUFF:
		current_speed = move_toward(current_speed, 0.0, puff_decel * delta)
		if current_speed <= 5.0:
			current_speed = 0.0
			current_wait -= delta
			if current_wait <= 0.0:
				queue_free()
				return

	var step: float = current_speed * delta
	global_position.x += dir * step
	distance_traveled += absf(step)

	# 1. Full 12x12 hitbox check against Layer 4 (Enemies)
	if _check_enemy_hit():
		return

	# 2. Max distance check (for Star)
	if type == Type.STAR and distance_traveled >= star_max_distance:
		queue_free()


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
			var burst_pos: Vector2 = enemy.global_position
			enemy.queue_free()
			HitFX.spawn(get_tree(), HitFX.random_star_burst(), burst_pos, dir < 0.0, fx_frames)
			queue_free()
			return true
	return false


func _on_body_entered(body: Node2D) -> void:
	if has_hit:
		return
	has_hit = true
	set_deferred("monitoring", false)

	if body is TileMapLayer:
		var boom_pos: Vector2 = _get_hit_tile_pos(body)
		HitFX.spawn(get_tree(), "boom", boom_pos, false, fx_frames)
	else:
		HitFX.spawn(get_tree(), "boom", global_position, false, fx_frames)

	queue_free()


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


func reset_state() -> void:
	queue_free()
