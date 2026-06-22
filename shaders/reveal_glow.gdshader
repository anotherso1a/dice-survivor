shader_type canvas_item;
render_mode blend_mix;

uniform float reveal_progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 glow_color : source_color = vec4(1.0, 0.9, 0.4, 1.0);
uniform float glow_radius : hint_range(0.0, 2.0) = 1.0;

void fragment() {
	vec4 base = texture(TEXTURE, UV);

	float dist = length(UV - 0.5);

	float reveal = smoothstep(0.5, 0.0, reveal_progress);
	float edge_glow = smoothstep(0.35, 0.5, reveal_progress)
		- smoothstep(0.1, 0.3, reveal_progress);

	float flash = smoothstep(0.0, 0.1, reveal_progress)
		- smoothstep(0.2, 0.4, reveal_progress);
	flash *= (1.0 - dist * 2.0);

	COLOR = base;

	COLOR.rgb += glow_color.rgb * edge_glow * 0.6;
	COLOR.rgb += glow_color.rgb * flash * 1.2;
	COLOR.a = base.a + edge_glow * 0.3 + flash * 0.5;
}
