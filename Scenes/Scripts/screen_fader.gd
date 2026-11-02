class_name ScreenFader
extends CanvasLayer

static var instance: ScreenFader = null

var color_rect: ColorRect
var _material: ShaderMaterial

const FADE_SHADER_CODE: String = """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform int fade_step : hint_range(0, 3) = 0;

void fragment() {
	vec4 col = texture(screen_tex, SCREEN_UV);
	float lum = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	int shade = int(round(lum * 3.0));
	shade = min(shade + fade_step, 3);
	COLOR = vec4(vec3(float(shade) / 3.0), 1.0);
}
"""

func _ready() -> void:
	instance = self
	layer = 100
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS # Runs even when the game is paused!
	_setup_rect()


func _setup_rect() -> void:
	if not color_rect:
		color_rect = get_node_or_null("ColorRect") as ColorRect
		if not color_rect:
			color_rect = ColorRect.new()
			color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			# Automatically expands to fill 100% of any viewport size or orientation
			color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			add_child(color_rect)

	var shader := Shader.new()
	shader.code = FADE_SHADER_CODE
	_material = ShaderMaterial.new()
	_material.shader = shader
	color_rect.material = _material


## Usage: await ScreenFader.fade(true)  (fades to white)
##        await ScreenFader.fade(false) (fades from white to game)
static func fade(to_white: bool, step_delay: float = 0.055) -> void:
	
	# Auto-instantiate if ScreenFader was not pre-placed in the scene
	if not instance:
		var fader := ScreenFader.new()
		var tree := Engine.get_main_loop() as SceneTree
		if tree and tree.root:
			tree.root.add_child(fader)

	await instance._do_fade(to_white, step_delay)


func _do_fade(to_white: bool, step_delay: float) -> void:
	visible = true
	var steps: Array = [1, 2, 3] if to_white else [2, 1, 0]

	if not to_white:
		_material.set_shader_parameter("fade_step", 3)
		await get_tree().create_timer(step_delay, true).timeout

	for s in steps:
		_material.set_shader_parameter("fade_step", s)
		await get_tree().create_timer(step_delay, true).timeout

	if not to_white:
		visible = false
