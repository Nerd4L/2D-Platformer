class_name ScreenFader
extends CanvasLayer

static var instance: ScreenFader

@onready var color_rect: ColorRect = $ColorRect
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
	layer = 100
	visible = false
	instance = self
	
	if not color_rect:
		color_rect = ColorRect.new()
		color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		color_rect.size = Vector2(160.0, 128.0)
		add_child(color_rect)
		
	var shader := Shader.new()
	shader.code = FADE_SHADER_CODE
	_material = ShaderMaterial.new()
	_material.shader = shader
	color_rect.material = _material

## 3-step authentic Game Boy palette wipe:
## to_white = true: 0 -> 1 -> 2 -> 3
## to_white = false: 3 -> 2 -> 1 -> 0
func fade(to_white: bool, step_delay: float = 0.055) -> void:
	visible = true
	var steps: Array[int] = [1, 2, 3] if to_white else [2, 1, 0]
	
	if not to_white:
		_material.set_shader_parameter("fade_step", 3)
		await get_tree().create_timer(step_delay).timeout

	for s in steps:
		_material.set_shader_parameter("fade_step", s)
		await get_tree().create_timer(step_delay).timeout

	if not to_white:
		visible = false
