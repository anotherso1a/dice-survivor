shader_type canvas_item;
render_mode blend_mix;

uniform vec4 stone_a : source_color = vec4(0.28, 0.25, 0.22, 1.0);
uniform vec4 stone_b : source_color = vec4(0.32, 0.28, 0.24, 1.0);
uniform vec4 stone_c : source_color = vec4(0.24, 0.22, 0.19, 1.0);
uniform vec4 mortar_color : source_color = vec4(0.15, 0.13, 0.11, 1.0);
uniform float tile_size : hint_range(8.0, 64.0) = 16.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV * (256.0 / tile_size);
	vec2 tile = floor(uv);
	vec2 local_uv = fract(uv);

	float gap = 0.12;
	float in_tile_x = step(gap, local_uv.x) * step(gap, 1.0 - gap);
	float in_tile_y = step(gap, local_uv.y) * step(gap, 1.0 - gap);
	float in_tile = in_tile_x * in_tile_y;

	float h = hash(tile);
	int pick = int(h * 3.0);

	vec4 tile_color = stone_a;
	if (pick == 1) { tile_color = stone_b; }
	if (pick == 2) { tile_color = stone_c; }

	float highlight = smoothstep(0.4, 0.5, local_uv.x) * smoothstep(0.5, 0.4, local_uv.x);
	highlight *= smoothstep(0.4, 0.5, local_uv.y) * smoothstep(0.5, 0.4, local_uv.y);
	tile_color.rgb += highlight * 0.04;

	COLOR = mix(mortar_color, tile_color, in_tile);
	COLOR.a = 1.0;
}
