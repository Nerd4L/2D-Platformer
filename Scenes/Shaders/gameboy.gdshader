shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform sampler2D prev_frame_texture : filter_nearest;

// Named dropdown options in the Inspector
uniform int palette_mode : hint_enum("Game Boy Green:0", "Game Boy Pocket:1") = 0;

// --- Controls ---
uniform float grid_intensity : hint_range(0.0, 1.0) = 0.45;
uniform bool enable_blur = true;
uniform float lcd_blur : hint_range(0.0, 1.0) = 0.25;
uniform bool enable_ghosting = true;
uniform float ghost_persistence : hint_range(0.0, 0.95) = 0.65;
uniform vec2 native_resolution = vec2(160.0, 144.0);

// Your exact Game Boy Pocket colors
const vec3 POCKET_0 = vec3(0.34, 0.37, 0.28); // #575e48
const vec3 POCKET_1 = vec3(0.23, 0.25, 0.20); // #3b4134
const vec3 POCKET_2 = vec3(0.11, 0.13, 0.12); // #1d221e
const vec3 POCKET_3 = vec3(0.05, 0.07, 0.05); // #0d120e

// Your exact Game Boy Green colors
const vec3 DMG_0 = vec3(0.35, 0.44, 0.00); // #587000
const vec3 DMG_1 = vec3(0.24, 0.36, 0.00); // #3d5d00
const vec3 DMG_2 = vec3(0.14, 0.30, 0.00); // #244c00
const vec3 DMG_3 = vec3(0.13, 0.27, 0.00); // #204600

// Your exact gap colors
const vec3 DMG_GAP    = vec3(0.48, 0.48, 0.48);
const vec3 POCKET_GAP = vec3(0.48, 0.48, 0.48);

vec3 get_palette_color(int mode, int idx) {
	if (mode == 0) {
		if (idx == 0) return DMG_0;
		if (idx == 1) return DMG_1;
		if (idx == 2) return DMG_2;
		return DMG_3;
	} else {
		if (idx == 0) return POCKET_0;
		if (idx == 1) return POCKET_1;
		if (idx == 2) return POCKET_2;
		return POCKET_3;
	}
}

int get_shade(vec2 uv) {
	vec4 s = texture(screen_texture, uv);
	float l = dot(s.rgb, vec3(0.299, 0.587, 0.114));
	return 3 - int(clamp(floor(l * 3.99), 0.0, 3.0));
}

void fragment() {
	vec2 pixel_coord = UV * native_resolution;
	vec2 subpixel_fract = fract(pixel_coord);

	// 1. Quantize current pixel into 4 shades
	int shade_idx = get_shade(UV);
	vec3 color = get_palette_color(palette_mode, shade_idx);

	// 2. Optical LCD Blur (actually softens edges across neighboring screen pixels)
	if (enable_blur && lcd_blur > 0.0) {
		vec2 p = (1.0 / native_resolution) * (lcd_blur * 1.25);
		vec3 s1 = get_palette_color(palette_mode, get_shade(UV + vec2(p.x, 0.0)));
		vec3 s2 = get_palette_color(palette_mode, get_shade(UV - vec2(p.x, 0.0)));
		vec3 s3 = get_palette_color(palette_mode, get_shade(UV + vec2(0.0, p.y)));
		vec3 s4 = get_palette_color(palette_mode, get_shade(UV - vec2(0.0, p.y)));
		vec3 blur_avg = (s1 + s2 + s3 + s4) * 0.25;
		color = mix(color, blur_avg, lcd_blur);
	}

	// 3. LCD Ghosting: Blends in color space so static contrast is 100% untouched
	if (enable_ghosting) {
		vec4 prev = texture(prev_frame_texture, UV);
		vec3 dark_trail = min(color, prev.rgb);
		color = mix(color, dark_trail, ghost_persistence * 0.7);
	}

	// 4. LCD Matrix Grid Lines
	vec2 border = step(vec2(0.75), subpixel_fract);
	float grid = max(border.x, border.y);
	vec3 gap_color = (palette_mode == 0) ? DMG_GAP : POCKET_GAP;
	color = mix(color, gap_color, grid * grid_intensity);

	COLOR = vec4(color, 1.0);
}