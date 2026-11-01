class_name HUD
extends CanvasLayer

@export_category("Pip Textures")
@export var pip_full_texture: Texture2D
@export var pip_empty_texture: Texture2D

@onready var hbox: HBoxContainer = $Container/HBoxContainer
@onready var lives_number: TextureRect = get_node_or_null("Container/LivesNumber")

var pip_nodes: Array[TextureRect] = []

func _ready() -> void:
	# Cache all the Pip TextureRects inside the HBoxContainer
	if hbox:
		for child in hbox.get_children():
			if child is TextureRect:
				pip_nodes.append(child)

	# Safely connect to the player without needing a rigid class type
	var player_node: Node = get_tree().get_first_node_in_group("player")
	if player_node:
		connect_to_kirby(player_node)


func connect_to_kirby(kirby: Node) -> void:
	if kirby.has_signal("health_changed") and not kirby.health_changed.is_connected(set_health):
		kirby.health_changed.connect(set_health)
	if kirby.has_signal("lives_changed") and not kirby.lives_changed.is_connected(set_lives):
		kirby.lives_changed.connect(set_lives)

	# Initialize values immediately
	if "current_health" in kirby and "max_health" in kirby:
		set_health(kirby.current_health, kirby.max_health)
	if "lives" in kirby:
		set_lives(kirby.lives)


func set_health(current: int, _max_val: int) -> void:
	for i in range(pip_nodes.size()):
		if i < current:
			# Health notch is filled
			if pip_full_texture:
				pip_nodes[i].texture = pip_full_texture
			pip_nodes[i].visible = true
		else:
			# Health notch is empty
			if pip_empty_texture:
				pip_nodes[i].texture = pip_empty_texture
			else:
				pip_nodes[i].visible = false


func set_lives(_lives_count: int) -> void:
	# Ready for when we hook up the lives number texture
	pass
