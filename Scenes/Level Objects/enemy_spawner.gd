@tool
extends Marker2D
class_name EnemySpawner

enum DeeBehavior { PATROL, SLIDE, SLOW_WALK }

@export_category("Enemy to Spawn")
@export var enemy_scene: PackedScene
@export var behavior: DeeBehavior = DeeBehavior.PATROL
const TILE_SIZE: float = 16.0

@export var patrol_tiles: float = 0.0: # Enter tiles as float (e.g. 2.0, 3.5)
	set(val):
		patrol_tiles = maxf(val, 0.0)
		queue_redraw()

@export var face_camera_on_spawn: bool = true
@export var default_face_left: bool = true:
	set(val):
		default_face_left = val
		queue_redraw()

@export var snap_to_floor: bool = true

@export_category("Game Boy Screen Margins (in Pixels)")
@export var spawn_margin: float = 16.0
@export var reset_margin: float = 64.0
@export var enemy_despawn_margin: float = 64.0

var current_enemy: Node2D = null
var can_spawn: bool = true


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("resettable")


func reset_state() -> void:
	if is_instance_valid(current_enemy):
		current_enemy.queue_free()
		current_enemy = null
	can_spawn = true


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return

	var screen_rect: Rect2 = _get_camera_world_rect()
	
	if is_instance_valid(current_enemy):
		if "state" in current_enemy and current_enemy.state != 0:
			return
			
		var active_zone: Rect2 = screen_rect.grow(enemy_despawn_margin)
		if not active_zone.has_point(current_enemy.global_position):
			current_enemy.queue_free()
			current_enemy = null
		return

	var spawn_zone: Rect2 = screen_rect.grow(spawn_margin)
	var reset_zone: Rect2 = screen_rect.grow(reset_margin)

	if can_spawn:
		if spawn_zone.has_point(global_position):
			_spawn_enemy(screen_rect)
			can_spawn = false
	else:
		if not reset_zone.has_point(global_position):
			can_spawn = true


func _spawn_enemy(screen_rect: Rect2) -> void:
	if not enemy_scene:
		return
		
	var enemy := enemy_scene.instantiate() as Node2D
	
	var spawn_pos: Vector2 = global_position
	if snap_to_floor:
		var foot_offset: float = _get_enemy_foot_offset(enemy)
		spawn_pos = _get_floor_position_below(foot_offset)
	enemy.global_position = spawn_pos
	
	if "start_facing_left" in enemy:
		if face_camera_on_spawn:
			var cam_center_x: float = screen_rect.get_center().x
			enemy.start_facing_left = global_position.x >= cam_center_x
		else:
			enemy.start_facing_left = default_face_left
			
	get_parent().add_child(enemy)
	current_enemy = enemy

	if enemy.has_method("set_behavior"):
		enemy.set_behavior(behavior, patrol_tiles)


func _get_enemy_foot_offset(enemy: Node2D) -> float:
	var col := enemy.find_child("CollisionShape2D", true, false) as CollisionShape2D
	if col and col.shape:
		return col.position.y + col.shape.get_rect().end.y
	return 8.0


func _get_floor_position_below(foot_offset: float) -> Vector2:
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + Vector2(0.0, 200.0),
		(1 << 0) | (1 << 1)
	)
	var result: Dictionary = space_state.intersect_ray(query)
	if result:
		return Vector2(global_position.x, result.position.y - foot_offset)
	return global_position


func _get_camera_world_rect() -> Rect2:
	var viewport := get_viewport()
	var canvas_to_world: Transform2D = viewport.get_canvas_transform().affine_inverse()
	var visible_size: Vector2 = viewport.get_visible_rect().size
	var playfield_size := Vector2(visible_size.x, visible_size.y - 16.0)
	return Rect2(canvas_to_world * Vector2.ZERO, playfield_size)


# --- 2D Editor Debug Drawing ---
func _draw() -> void:
	if not Engine.is_editor_hint():
		return

	# Crosshair at spawn point
	var point_col := Color(0.2, 0.8, 0.2, 0.9) # Game Boy green
	draw_line(Vector2(-3.0, 0.0), Vector2(3.0, 0.0), point_col, 1.0)
	draw_line(Vector2(0.0, -3.0), Vector2(0.0, 3.0), point_col, 1.0)

	if patrol_tiles > 0.0:
		var patrol_px: float = patrol_tiles * TILE_SIZE
		var dir: float = -1.0 if default_face_left else 1.0
		var end_pt := Vector2(dir * patrol_px, 0.0)
		var line_col := Color(0.1, 0.9, 0.7, 0.85)

		# Patrol path line
		draw_line(Vector2.ZERO, end_pt, line_col, 1.0)
		
		# Start & End Ticks
		draw_line(Vector2(0.0, -4.0), Vector2(0.0, 4.0), line_col, 1.5)
		draw_line(end_pt + Vector2(0.0, -4.0), end_pt + Vector2(0.0, 4.0), line_col, 1.5)
