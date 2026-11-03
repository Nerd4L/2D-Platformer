class_name HUD
extends CanvasLayer

@export_category("Pip Textures")
@export var pip_full_texture: Texture2D
@export var pip_empty_texture: Texture2D

@onready var pip_container: HBoxContainer = get_node_or_null("Container/PipContainer")
@onready var score_container: HBoxContainer = get_node_or_null("Container/ScoreContainer")
@onready var lives_tens: TextureRect = get_node_or_null("Container/LivesContainer/LivesNumber1")
@onready var lives_units: TextureRect = get_node_or_null("Container/LivesContainer/LivesNumber2")

var pip_nodes: Array[TextureRect] = []
var score_digits: Array[TextureRect] = []

func _ready() -> void:
	# Make Lives AtlasTextures unique so modifying one doesn't affect the other
	if lives_tens and lives_tens.texture is AtlasTexture:
		lives_tens.texture = lives_tens.texture.duplicate()
	if lives_units and lives_units.texture is AtlasTexture:
		lives_units.texture = lives_units.texture.duplicate()

	# Gather health pips from PipContainer
	if pip_container:
		for child in pip_container.get_children():
			if child is TextureRect:
				pip_nodes.append(child)

	# Gather score digits from ScoreContainer
	if score_container:
		for child in score_container.get_children():
			if child is TextureRect:
				if child.texture is AtlasTexture:
					child.texture = child.texture.duplicate()
				score_digits.append(child)

	# Auto-connect to Kirby
	var player_node: Node = get_tree().get_first_node_in_group("player")
	if player_node:
		connect_to_kirby(player_node)


func connect_to_kirby(kirby: Node) -> void:
	if kirby.has_signal("health_changed") and not kirby.health_changed.is_connected(set_health):
		kirby.health_changed.connect(set_health)
	if kirby.has_signal("lives_changed") and not kirby.lives_changed.is_connected(set_lives):
		kirby.lives_changed.connect(set_lives)
	if kirby.has_signal("score_changed") and not kirby.score_changed.is_connected(set_score):
		kirby.score_changed.connect(set_score)

	# Initialize values immediately
	if "current_health" in kirby and "max_health" in kirby:
		set_health(kirby.current_health, kirby.max_health)
	if "lives" in kirby:
		set_lives(kirby.lives)
	if "score" in kirby:
		set_score(kirby.score)


func set_health(current: int, _max_val: int) -> void:
	for i in range(pip_nodes.size()):
		if i < current:
			if pip_full_texture:
				pip_nodes[i].texture = pip_full_texture
			pip_nodes[i].visible = true
		else:
			if pip_empty_texture:
				pip_nodes[i].texture = pip_empty_texture
			else:
				pip_nodes[i].visible = false


## Updates the authentic 2-digit life counter (e.g. 4 -> "04")
func set_lives(lives_count: int) -> void:
	var count: int = clampi(lives_count, 0, 99)
	var tens: int = floori(float(count) / 10.0)
	var units: int = count % 10

	set_digit(lives_tens, tens)
	set_digit(lives_units, units)


## Formats score with blank leading digits (e.g. 100 -> "   100", 0 -> "     0")
func set_score(score_val: int) -> void:
	if score_digits.is_empty():
		return

	var score_str: String = str(clampi(score_val, 0, 999999))
	var num_blanks: int = score_digits.size() - score_str.length()

	for i in range(score_digits.size()):
		if i < num_blanks:
			# Blank leading digit
			set_digit(score_digits[i], -1)
		else:
			# Visible digit
			var char_idx: int = i - num_blanks
			var digit_val: int = score_str[char_idx].to_int()
			set_digit(score_digits[i], digit_val)


## Reusable helper for ANY TextureRect in the HUD showing digits 0-9 (or -1 for blank)
func set_digit(tex_rect: TextureRect, value: int) -> void:
	if not tex_rect or not (tex_rect.texture is AtlasTexture):
		return

	# Negative value (-1) hides the digit while keeping its 8x8 container spacing!
	if value < 0:
		tex_rect.self_modulate.a = 0.0
		return

	# Show visible digit
	tex_rect.self_modulate.a = 1.0

	var atlas_tex := tex_rect.texture as AtlasTexture
	var digit_w: float = atlas_tex.region.size.x
	var digit_h: float = atlas_tex.region.size.y

	var digit: int = clampi(value, 0, 9)
	var col: int = digit % 5
	var row: int = floori(float(digit) / 5.0)

	atlas_tex.region.position = Vector2(col * digit_w, row * digit_h)
