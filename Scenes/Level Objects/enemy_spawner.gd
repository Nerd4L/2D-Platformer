@tool
extends Marker2D
class_name EnemySpawner

enum DeeBehavior { PATROL, SLIDE, SLOW_WALK }
enum BrontoBehavior { WAVE, DIVE, BOUNCE }

@export_category("Enemy to Spawn")
@export var enemy_scene: PackedScene:
	set(val):
		enemy_scene = val
		# Automatically pull default patrol values from the chosen enemy scene
		if Engine.is_editor_hint() and enemy_scene:
			var temp = enemy_scene.instantiate()
			if "capped_patrol_tiles" in temp:
				patrol_tiles = temp.capped_patrol_tiles
			elif "patrol_tiles" in temp and temp.patrol_tiles > 0.0:
				patrol_tiles = temp.patrol_tiles

			if "capless_patrol_tiles" in temp:
				capless_patrol_tiles = temp.capless_patrol_tiles
			temp.free()

		notify_property_list_changed()
		queue_redraw()
@export var behavior: int = 0

@export var capless_patrol_tiles: float = 3.5:
	set(val):
		capless_patrol_tiles = maxf(val, 0.0)
		queue_redraw()

@export_group("Bronto Burt Flight Tuning")
@export var flight_speed_x: float = 38.0:
	set(val):
		flight_speed_x = val
		queue_redraw()
@export var flight_speed_y: float = 24.0:
	set(val):
		flight_speed_y = val
		queue_redraw()
@export var wave_frequency: float = 4.5:
	set(val):
		wave_frequency = maxf(val, 0.1)
		queue_redraw()
@export var wave_amplitude: float = 16.0:
	set(val):
		wave_amplitude = maxf(val, 0.0)
		queue_redraw()
@export_group("", "")

func _validate_property(property: Dictionary) -> void:
	var path: String = enemy_scene.resource_path.to_lower() if enemy_scene else ""
	var is_burt: bool = ("bronto" in path or "burt" in path)
	var is_cappy: bool = ("cappy" in path)

	# 1. Behavior Dropdown
	if property.name == "behavior":
		if "waddle_dee" in path:
			property.hint = PROPERTY_HINT_ENUM
			property.hint_string = "PATROL,SLIDE,SLOW_WALK"
		elif is_burt:
			property.hint = PROPERTY_HINT_ENUM
			property.hint_string = "WAVE,DIVE,BOUNCE,VERTICAL"
		elif "twizzy" in path:
			property.hint = PROPERTY_HINT_ENUM
			property.hint_string = "FLY,HOP"
		else:
			# Hide behavior dropdown if no scene or if Cappy (Cappy only patrols)
			property.usage &= ~PROPERTY_USAGE_EDITOR

	# 2. Cappy-only properties
	elif property.name == "capless_patrol_tiles":
		if not is_cappy:
			property.usage &= ~PROPERTY_USAGE_EDITOR

	# 3. Bronto Burt-only properties & Group Header
	elif property.name in ["flight_speed_x", "flight_speed_y", "wave_frequency", "wave_amplitude", "Bronto Burt Flight Tuning"]:
		if not is_burt:
			property.usage &= ~PROPERTY_USAGE_EDITOR

func _property_can_revert(property: StringName) -> bool:
	if property == &"patrol_tiles" or property == &"capless_patrol_tiles":
		return true
	return false


func _property_get_revert(property: StringName) -> Variant:
	var path: String = enemy_scene.resource_path.to_lower() if enemy_scene else ""
	var is_cappy: bool = ("cappy" in path)

	if property == &"patrol_tiles":
		return 1.5 if is_cappy else 0.0
	elif property == &"capless_patrol_tiles":
		return 3.5
	return null

const TILE_SIZE: float = 16.0
@export var patrol_tiles: float = 0.0: # Enter tiles as float (e.g. 2.0, 3.5)
	set(val):
		patrol_tiles = maxf(val, 0.0)
		queue_redraw()

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
			_spawn_enemy()
			can_spawn = false
	else:
		if not reset_zone.has_point(global_position):
			can_spawn = true


func _spawn_enemy() -> void:
	var enemy := enemy_scene.instantiate() as Node2D
	
	var spawn_pos: Vector2 = global_position
	var is_flying: bool = enemy.get("is_flying") == true
	
	if snap_to_floor and not is_flying:
		var foot_offset: float = _get_enemy_foot_offset(enemy)
		spawn_pos = _get_floor_position_below(foot_offset)
		
	enemy.global_position = spawn_pos
	
	if "start_facing_left" in enemy:
			enemy.start_facing_left = default_face_left
			
	get_parent().add_child(enemy)
	current_enemy = enemy

	if enemy.has_method("set_behavior"):
		enemy.set_behavior(behavior, patrol_tiles)
	
	if "capped_patrol_tiles" in enemy and patrol_tiles > 0.0:
		enemy.capped_patrol_tiles = patrol_tiles
	if "capless_patrol_tiles" in enemy and capless_patrol_tiles > 0.0:
		enemy.capless_patrol_tiles = capless_patrol_tiles
	
	if "flight_speed_x" in enemy:
		enemy.flight_speed_x = flight_speed_x
		enemy.flight_speed_y = flight_speed_y
		enemy.wave_frequency = wave_frequency
		enemy.wave_amplitude = wave_amplitude


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
	var point_col := Color(0.2, 0.8, 0.2, 0.9)
	draw_line(Vector2(-3.0, 0.0), Vector2(3.0, 0.0), point_col, 1.0)
	draw_line(Vector2(0.0, -3.0), Vector2(0.0, 3.0), point_col, 1.0)

	var path: String = enemy_scene.resource_path.to_lower() if enemy_scene else ""
	var is_burt: bool = ("bronto" in path or "burt" in path)
	var is_cappy: bool = ("cappy" in path)
	var dir_x: float = -1.0 if default_face_left else 1.0
	var line_col := Color(0.1, 0.9, 0.7, 0.85)
	
	# Inside _draw(): Add under your standard patrol drawing block:
	if is_cappy:
		# Draw Capless Panic Patrol range in amber 3px below the main line
		if capless_patrol_tiles > 0.0:
			var capless_px: float = capless_patrol_tiles * TILE_SIZE
			var amber_col := Color(1.0, 0.65, 0.2, 0.8)
			var end_capless := Vector2(dir_x * capless_px, 3.0)
			
			draw_line(Vector2(0.0, 3.0), end_capless, amber_col, 1.0)
			draw_line(Vector2(0.0, 1.0), Vector2(0.0, 5.0), amber_col, 1.5)
			draw_line(end_capless + Vector2(0.0, -2.0), end_capless + Vector2(0.0, 2.0), amber_col, 1.5)

	# --- BRONTO BURT WAVE FLIGHT PREVIEW ---
	if is_burt and behavior == 0: # Behavior 0 = WAVE
		# If patrol_tiles is 0, preview 2 full wave cycles (or at least 4 tiles)
		var wavelength_px: float = (flight_speed_x * (TAU / wave_frequency))
		var total_px: float = (patrol_tiles * TILE_SIZE) if patrol_tiles > 0.0 else maxf(wavelength_px * 2.0, 64.0)

		# Physical vertical displacement = amplitude / frequency
		var max_disp_y: float = wave_amplitude / wave_frequency

		# Draw faint upper and lower amplitude boundary rails
		var rail_col := Color(0.1, 0.9, 0.7, 0.2)
		draw_line(Vector2(0.0, -max_disp_y), Vector2(dir_x * total_px, -max_disp_y), rail_col, 1.0)
		draw_line(Vector2(0.0, max_disp_y), Vector2(dir_x * total_px, max_disp_y), rail_col, 1.0)

		# Plot the sine wave curve
		var points: PackedVector2Array = []
		var sample_count: int = int(clampf(total_px * 0.75, 20.0, 120.0))

		for i in range(sample_count + 1):
			var t_ratio: float = float(i) / float(sample_count)
			var px: float = t_ratio * total_px
			var time_t: float = px / maxf(flight_speed_x, 1.0)
			var py: float = -sin(wave_frequency * time_t) * max_disp_y
			points.append(Vector2(dir_x * px, py))

		draw_polyline(points, line_col, 1.0)

		# Start & End Ticks
		draw_line(Vector2(0.0, -max_disp_y - 2.0), Vector2(0.0, max_disp_y + 2.0), line_col, 1.5)
		var end_x: float = dir_x * total_px
		draw_line(Vector2(end_x, -max_disp_y - 2.0), Vector2(end_x, max_disp_y + 2.0), line_col, 1.5)
		return

	# --- STANDARD STRAIGHT / VERTICAL PATROL DRAWING ---
	if patrol_tiles > 0.0:
		var patrol_px: float = patrol_tiles * TILE_SIZE
		var is_vertical: bool = (is_burt and behavior == 3) # Index 3 = VERTICAL

		var end_pt: Vector2
		if is_vertical:
			end_pt = Vector2(0.0, patrol_px)
			draw_line(Vector2.ZERO, end_pt, line_col, 1.0)
			draw_line(Vector2(-4.0, 0.0), Vector2(4.0, 0.0), line_col, 1.5)
			draw_line(end_pt + Vector2(-4.0, 0.0), end_pt + Vector2(4.0, 0.0), line_col, 1.5)
		else:
			end_pt = Vector2(dir_x * patrol_px, 0.0)
			draw_line(Vector2.ZERO, end_pt, line_col, 1.0)
			draw_line(Vector2(0.0, -4.0), Vector2(0.0, 4.0), line_col, 1.5)
			draw_line(end_pt + Vector2(0.0, -4.0), end_pt + Vector2(0.0, 4.0), line_col, 1.5)
