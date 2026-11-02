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
	
	# Make the AtlasTexture unique to this node so changing its region 
	# doesn't affect other atlas textures sharing the same sprite sheet
	if lives_number and lives_number.texture is AtlasTexture:
		lives_number.texture = lives_number.texture.duplicate()


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


func set_lives(lives_count: int) -> void:
	set_digit(lives_number, lives_count)

func set_digit(tex_rect: TextureRect, value: int) -> void:
	if not tex_rect or not (tex_rect.texture is AtlasTexture):
		return

	var atlas_tex := tex_rect.texture as AtlasTexture
	var digit_w: float = atlas_tex.region.size.x
	var digit_h: float = atlas_tex.region.size.y

	var digit: int = clampi(value, 0, 9)
	var col: int = digit % 5
	var row: int = floori(float(digit) / 5.0) # Floating point division eliminates the warning

	atlas_tex.region.position = Vector2(col * digit_w, row * digit_h)
