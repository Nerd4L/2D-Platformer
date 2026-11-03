shader_type canvas_item;
#include "res://Scenes/Shaders/palettes.gdshaderinc"

uniform bool is_screen_filter = false;
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

void fragment() {
	vec4 base_color = is_screen_filter ? texture(screen_texture, SCREEN_UV) : texture(TEXTURE, UV);

	if (base_color.a < 0.01) {
		discard;
	}

	float lum = dot(base_color.rgb, vec3(0.299, 0.587, 0.114));

	int shade_idx = 0;
	if (lum > 0.82) shade_idx = 0;
	else if (lum > 0.48) shade_idx = 1;
	else if (lum > 0.16) shade_idx = 2;
	else shade_idx = 3;

	// No need to pass palette_choice - sample_pal uses it directly!
	COLOR = vec4(sample_pal(shade_idx), base_color.a);
}