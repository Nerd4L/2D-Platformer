shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform int fade_step : hint_range(0, 7) = 0;

void fragment() {
	vec4 col = texture(screen_tex, SCREEN_UV);
	float t = float(fade_step) / 7.0;
	COLOR = vec4(mix(col.rgb, vec3(1.0), t), 1.0);
}