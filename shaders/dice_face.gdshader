shader_type canvas_item;
render_mode blend_mix;

uniform vec4 dice_bg : source_color = vec4(0.90, 0.87, 0.80, 1.0);
uniform vec4 dice_dot : source_color = vec4(0.08, 0.06, 0.04, 1.0);
uniform float flash_intensity : hint_range(0.0, 1.0) = 0.0;
uniform int face_value : hint_range(0, 6) = 0;

float dot_at(vec2 uv, float cx, float cy) {
	vec2 target = vec2(cx, cy);
	float d = length(uv - target);
	return 1.0 - smoothstep(0.08, 0.10, d);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 local_uv = UV;

	float border = 1.0 - smoothstep(0.90, 1.0, local_uv.x)
		* (1.0 - smoothstep(0.0, 0.10, local_uv.x))
		* (1.0 - smoothstep(0.90, 1.0, local_uv.y))
		* (1.0 - smoothstep(0.0, 0.10, local_uv.y));

	vec4 bg = dice_bg * 0.92;
	bg = mix(bg, dice_bg * 1.08, border);

	float dots = 0.0;

	int v = face_value;

	if (v == 1) {
		dots += dot_at(local_uv, 0.5, 0.5);
	}
	if (v == 2) {
		dots += dot_at(local_uv, 0.3, 0.3);
		dots += dot_at(local_uv, 0.7, 0.7);
	}
	if (v == 3) {
		dots += dot_at(local_uv, 0.3, 0.3);
		dots += dot_at(local_uv, 0.5, 0.5);
		dots += dot_at(local_uv, 0.7, 0.7);
	}
	if (v == 4) {
		dots += dot_at(local_uv, 0.25, 0.25);
		dots += dot_at(local_uv, 0.75, 0.25);
		dots += dot_at(local_uv, 0.25, 0.75);
		dots += dot_at(local_uv, 0.75, 0.75);
	}
	if (v == 5) {
		dots += dot_at(local_uv, 0.25, 0.25);
		dots += dot_at(local_uv, 0.75, 0.25);
		dots += dot_at(local_uv, 0.50, 0.50);
		dots += dot_at(local_uv, 0.25, 0.75);
		dots += dot_at(local_uv, 0.75, 0.75);
	}
	if (v == 6) {
		dots += dot_at(local_uv, 0.25, 0.2);
		dots += dot_at(local_uv, 0.75, 0.2);
		dots += dot_at(local_uv, 0.25, 0.5);
		dots += dot_at(local_uv, 0.75, 0.5);
		dots += dot_at(local_uv, 0.25, 0.8);
		dots += dot_at(local_uv, 0.75, 0.8);
	}

	COLOR = bg;
	COLOR.rgb = mix(COLOR.rgb, dice_dot.rgb, dots);

	float flash = sin(TIME * 20.0) * 0.5 + 0.5;
	COLOR.rgb += vec3(1.0, 0.9, 0.3) * flash_intensity * flash * 0.3;

	if (flash_intensity > 0.01) {
		COLOR.a = 1.0;
	} else {
		COLOR.a = mix(0.0, 1.0, tex.a > 0.1 ? 1.0 : 0.5);
	}
}
