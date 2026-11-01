class_name Door
extends Area2D

@export var target_position_node: Marker2D
@export var target_camera_room: ReferenceRect

var player_inside: CharacterBody2D = null

func _ready() -> void:
	add_to_group("doors")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inside = body as CharacterBody2D
		if body.has_method("set_current_door"):
			body.set_current_door(self)

func _on_body_exited(body: Node2D) -> void:
	if body == player_inside:
		if body.has_method("set_current_door"):
			body.set_current_door(null)
		player_inside = null

func is_player_aligned(player_pos: Vector2) -> bool:
	var door_col := get_node_or_null("CollisionShape2D") as Node2D
	var door_y: float = door_col.global_position.y if door_col else global_position.y
	var dy: float = player_pos.y - door_y
	return dy <= 2.0 and dy >= -12.0
