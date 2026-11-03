shader_type canvas_item;

// Dropdown to pick preset palettes in the Inspector
uniform int palette_choice : hint_enum("Original", "Pink", "Peach", "GB Green", "Custom") = 0;

// Toggle this ON if putting on a full-screen ColorRect post-processing layer
uniform bool is_screen_filter = false;
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

// Custom palette slots (only used if palette_choice is set to "Custom")
group_uniforms Custom_Palette;
uniform vec4 custom_color_0 : source_color = vec4(1.0, 1.0, 1.0, 1.0); // Lightest (White)
uniform vec4 custom_color_1 : source_color = vec4(0.66, 0.66, 0.66, 1.0); // Light Gray
uniform vec4 custom_color_2 : source_color = vec4(0.33, 0.33, 0.33, 1.0); // Dark Gray
uniform vec4 custom_color_3 : source_color = vec4(0.0, 0.0, 0.0, 1.0); // Darkest (Black)

// Pre-defined Palette Palettes
const vec3 GB_ORIGINAL[4] = vec3[4](
	vec3(1.0, 1.0, 1.0),             // #ffffff
	vec3(0.6627, 0.6627, 0.6627),    // #a9a9a9
	vec3(0.3294, 0.3294, 0.3294),    // #545454
	vec3(0.0, 0.0, 0.0)              // #000000
);

const vec3 PINK_PALETTE[4] = vec3[4](
	vec3(0.9882, 0.7608, 0.8941),    // #fcc2e4
	vec3(0.9882, 0.4314, 0.8000),    // #fc6ecc
	vec3(0.3294, 0.3294, 0.3294),    // #545454 (base)
	vec3(0.0, 0.0, 0.0)              // #000000 (base)
);

const vec3 PEACH_PALETTE[4] = vec3[4](
	vec3(0.9882, 0.7922, 0.7686),    // #fccac4
	vec3(0.9882, 0.5098, 0.4549),    // #fc8274
	vec3(0.3294, 0.3294, 0.3294),    // #545454 (base)
	vec3(0.0, 0.0, 0.0)              // #000000 (base)
);

const vec3 GB_GREEN_PALETTE[4] = vec3[4](
	vec3(0.6078, 0.7373, 0.0588),    // #9BBC0F
	vec3(0.5451, 0.6745, 0.0588),    // #8BAC0F
	vec3(0.1882, 0.3843, 0.1882),    // #306230
	vec3(0.0588, 0.2196, 0.0588)     // #0F380F
);


void fragment() {
	// 1. Sample either the screen or the sprite texture
	vec4 base_color;
	if (is_screen_filter) {
		base_color = texture(screen_texture, SCREEN_UV);
	} else {
		base_color = texture(TEXTURE, UV);
	}

	// Preserve transparency for sprites
	if (base_color.a < 0.01) {
		discard;
	}

	// 2. Calculate perceived brightness (luminance)
	float lum = dot(base_color.rgb, vec3(0.299, 0.587, 0.114));

	// 3. Determine which of the 4 Game Boy shades this pixel belongs to (0 to 3)
	int shade_idx = 0;
	if (lum > 0.82) {
		shade_idx = 0; // White
	} else if (lum > 0.48) {
		shade_idx = 1; // Light Gray
	} else if (lum > 0.16) {
		shade_idx = 2; // Dark Gray
	} else {
		shade_idx = 3; // Black
	}

	// 4. Map the shade to the chosen palette
	vec3 out_rgb = base_color.rgb;

	switch (palette_choice) {
		case 0: // Original Grayscale
			out_rgb = GB_ORIGINAL[shade_idx];
			break;
		case 1: // Pink (Kirby)
			out_rgb = PINK_PALETTE[shade_idx];
			break;
		case 2: // Peach (Waddle Dee)
			out_rgb = PEACH_PALETTE[shade_idx];
			break;
		case 3: // GB Green (Classic DMG)
			out_rgb = GB_GREEN_PALETTE[shade_idx];
			break;
		case 4: // Custom
			if (shade_idx == 0) out_rgb = custom_color_0.rgb;
			else if (shade_idx == 1) out_rgb = custom_color_1.rgb;
			else if (shade_idx == 2) out_rgb = custom_color_2.rgb;
			else out_rgb = custom_color_3.rgb;
			break;
	}

	COLOR = vec4(out_rgb, base_color.a);
}