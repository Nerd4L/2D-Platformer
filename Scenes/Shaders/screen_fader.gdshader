shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform int fade_step : hint_range(0, 7) = 0;

const vec3 GB_ORIGINAL[4] = vec3[4](
	vec3(1.0, 1.0, 1.0),
	vec3(0.6627, 0.6627, 0.6627),
	vec3(0.3294, 0.3294, 0.3294),
	vec3(0.0, 0.0, 0.0)
);

const vec3 PINK_PAL[4] = vec3[4](
	vec3(0.9882, 0.7608, 0.8941),
	vec3(0.9882, 0.4314, 0.8000),
	vec3(0.3294, 0.3294, 0.3294),
	vec3(0.0, 0.0, 0.0)
);

const vec3 PEACH_PAL[4] = vec3[4](
	vec3(0.9882, 0.7922, 0.7686),
	vec3(0.9882, 0.5098, 0.4549),
	vec3(0.3294, 0.3294, 0.3294),
	vec3(0.0, 0.0, 0.0)
);

const vec3 GREEN_PAL[4] = vec3[4](
	vec3(0.6078, 0.7373, 0.0588),
	vec3(0.5451, 0.6745, 0.0588),
	vec3(0.1882, 0.3843, 0.1882),
	vec3(0.0588, 0.2196, 0.0588)
);

vec3 sample_pal(int pal_type, int idx) {
	if (idx < 0) return vec3(1.0, 1.0, 1.0); // Above shade 0 = Pure White
	if (idx > 3) idx = 3;
	if (pal_type == 1) return PINK_PAL[idx];
	if (pal_type == 2) return PEACH_PAL[idx];
	if (pal_type == 3) return GREEN_PAL[idx];
	return GB_ORIGINAL[idx];
}

vec3 get_7step_color(int pal_type, int shade_idx, int step) {
	if (step <= 0) return sample_pal(pal_type, shade_idx);
	if (step >= 7) return vec3(1.0, 1.0, 1.0);

	// Each step is a 0.5 shift (half-step in-between colors on odd steps!)
	float pos = float(shade_idx) - (float(step) * 0.5);
	if (pos <= -1.0) {
		return vec3(1.0, 1.0, 1.0);
	}

	int lower_idx = int(floor(pos));
	int upper_idx = lower_idx + 1;
	float frac = pos - float(lower_idx);

	vec3 c_lower = sample_pal(pal_type, lower_idx);
	vec3 c_upper = sample_pal(pal_type, upper_idx);

	// Smoothly blends the half-step between the two palette colors
	return mix(c_lower, c_upper, frac);
}

void fragment() {
	vec4 col = texture(screen_tex, SCREEN_UV);

	if (fade_step <= 0) {
		COLOR = col;
	} else if (fade_step >= 7) {
		COLOR = vec4(1.0, 1.0, 1.0, 1.0);
	} else {
		float lum = dot(col.rgb, vec3(0.299, 0.587, 0.114));

		int pal_type = 0; // 0 = Grayscale, 1 = Pink, 2 = Peach, 3 = Green
		int shade_idx = 0;

		// Green (dominant Green)
		if (col.g > col.r + 0.05 && col.g > col.b + 0.1) {
			pal_type = 3;
			if (lum > 0.62) shade_idx = 0;
			else if (lum > 0.45) shade_idx = 1;
			else if (lum > 0.24) shade_idx = 2;
			else shade_idx = 3;
		}
		// Pink (Red high, Blue > Green)
		else if (col.r > 0.85 && col.b > col.g + 0.05) {
			pal_type = 1;
			shade_idx = (col.g > 0.6) ? 0 : 1;
		}
		// Peach (Red high, Green > Blue)
		else if (col.r > 0.85 && col.g > col.b + 0.05) {
			pal_type = 2;
			shade_idx = (col.g > 0.65) ? 0 : 1;
		}
		// Grayscale Base
		else {
			pal_type = 0;
			if (lum > 0.82) shade_idx = 0;
			else if (lum > 0.48) shade_idx = 1;
			else if (lum > 0.16) shade_idx = 2;
			else shade_idx = 3;
		}

		vec3 out_rgb = get_7step_color(pal_type, shade_idx, fade_step);
		COLOR = vec4(out_rgb, 1.0);
	}
}