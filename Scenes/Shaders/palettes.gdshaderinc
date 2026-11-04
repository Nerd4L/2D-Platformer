// res://Scenes/Shaders/palettes.gdshaderinc

// 1. DROPDOWN IN THE INSPECTOR
uniform int palette_choice : hint_enum("Original", "Custom", "GameBoy Green", "Pink", "Peach", "Icy Blue", "Desert", "GameBoy Green (Other)") = 0;

// 2. INSPECTOR COLOR PICKERS for live testing
group_uniforms Custom_Palette_In_Inspector;
uniform vec4 custom_0 : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 custom_1 : source_color = vec4(0.66, 0.66, 0.66, 1.0);
uniform vec4 custom_2 : source_color = vec4(0.33, 0.33, 0.33, 1.0);
uniform vec4 custom_3 : source_color = vec4(0.0, 0.0, 0.0, 1.0);
group_uniforms;

// 3. MASTER COLOR DEFINITIONS (Uses palette_choice directly - no warnings!)
vec3 sample_pal(int idx) {
	if (idx < 0) return vec3(1.0); // Pure White
	int i = clamp(idx, 0, 3);

	switch (palette_choice) {
		case 1: // Custom (from Inspector)
			return vec3[4](custom_0.rgb, custom_1.rgb, custom_2.rgb, custom_3.rgb)[i];
		
		case 2: // GameBoy Green
			return vec3[4](
				vec3(155.0, 188.0,  15.0) / 255.0, // #9bbc0f
				vec3(139.0, 172.0,  15.0) / 255.0, // #8bac0f
				vec3(48.0,   98.0,  48.0) / 255.0, // #306230
				vec3(15.0,   56.0,  15.0) / 255.0  // #0f380f
			)[i];
			
		case 3: // Pink
			return vec3[4](
				vec3(252.0, 194.0, 228.0) / 255.0, // #fcc2e4
				vec3(252.0, 110.0, 204.0) / 255.0, // #fc6ecc
				vec3(132.0,  40.0,  92.0) / 255.0, // #84285c
				vec3(0.0,     0.0,   0.0) / 255.0  // #000000
			)[i];

		case 4: // Peach
			return vec3[4](
				vec3(252.0, 202.0, 196.0) / 255.0, // #fccac4
				vec3(252.0, 130.0, 116.0) / 255.0, // #fc8274
				vec3(140.0,  58.0,  40.0) / 255.0, // #8c3a28
				vec3(0.0,     0.0,   0.0) / 255.0  // #000000
			)[i];

		case 5: // Icy Blue
			return vec3[4](
				vec3(190.0, 240.0, 240.0) / 255.0, // #bef0f0
				vec3(130.0, 190.0, 240.0) / 255.0, // #82bef0
				vec3(60.0,  100.0, 180.0) / 255.0, // #3c64b4
				vec3(0.0,     0.0,   0.0) / 255.0  // #000000
			)[i];

		case 6: // Desert
			return vec3[4](
				vec3(255.0, 246.0, 211.0) / 255.0, // #fff6d3
				vec3(249.0, 168.0, 117.0) / 255.0, // #f9a875
				vec3(235.0, 107.0, 111.0) / 255.0, // #eb6b6f
				vec3(124.0,  63.0,  88.0) / 255.0  // #7c3f58
				//vec3(0.0,     0.0,   0.0) / 255.0 // #000000
			)[i];

		case 7: // GameBoy Green (Other)
			return vec3[4](
				vec3(88.0,  112.0,   0.0) / 255.0, // #587000
				vec3(61.0,   93.0,   0.0) / 255.0, // #3d5d00
				vec3(36.0,   76.0,   0.0) / 255.0, // #244c00
				vec3(32.0,   70.0,   0.0) / 255.0  // #204600
			)[i];

		default: // 0: Original Grayscale
			return vec3[4](
				vec3(255.0, 255.0, 255.0) / 255.0, // #ffffff
				vec3(169.0, 169.0, 169.0) / 255.0, // #a9a9a9
				vec3(84.0,   84.0,  84.0) / 255.0, // #545454
				vec3(0.0,     0.0,   0.0) / 255.0  // #000000
			)[i];
	}
}