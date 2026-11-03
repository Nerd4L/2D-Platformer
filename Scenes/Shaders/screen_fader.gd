class_name ScreenFader
extends CanvasLayer

static var instance: ScreenFader = null

const SHADER_RES: Shader = preload("res://Scenes/Shaders/screen_fader.gdshader")

var color_rect: ColorRect
var _material: ShaderMaterial

func _ready() -> void:
	instance = self
	layer = 100
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_rect()


func _setup_rect() -> void:
	if not color_rect:
		color_rect = get_node_or_null("ColorRect") as ColorRect
		if not color_rect:
			color_rect = ColorRect.new()
			color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			add_child(color_rect)

	_material = ShaderMaterial.new()
	_material.shader = SHADER_RES
	color_rect.material = _material


static func fade(to_white: bool, step_delay: float = 0.055) -> void:
	if not instance:
		var fader := ScreenFader.new()
		var tree := Engine.get_main_loop() as SceneTree
		if tree and tree.root:
			tree.root.add_child(fader)

	await instance._do_fade(to_white, step_delay)


func _do_fade(to_white: bool, step_delay: float = 0.038) -> void:
	visible = true
	# 7-step progression
	var steps: Array = [1, 2, 3, 4, 5, 6, 7] if to_white else [6, 5, 4, 3, 2, 1, 0]

	if not to_white:
		_material.set_shader_parameter("fade_step", 7)
		await get_tree().create_timer(step_delay, true).timeout

	for s in steps:
		_material.set_shader_parameter("fade_step", s)
		await get_tree().create_timer(step_delay, true).timeout

	if not to_white:
		visible = false
