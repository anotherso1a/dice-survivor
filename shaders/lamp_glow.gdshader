shader_type canvas_item;
render_mode blend_add;

uniform vec4 glow_color : source_color = vec4(1.0, 0.75, 0.30, 1.0);
uniform float glow_radius : hint_range(0.5, 5.0) = 2.0;
uniform float pulse_speed : hint_range(0.0, 5.0) = 2.0;
uniform float pulse_amount : hint_range(0.0, 0.5) = 0.15;

void fragment() {
	vec2 center = UV - 0.5;
	float dist = length(center) / glow_radius;

	float glow = 1.0 - smoothstep(0.0, 1.0, dist);
	glow = pow(glow, 2.5);

	float core = 1.0 - smoothstep(0.0, 0.15, dist);
	core = pow(core, 3.0);

	float pulse = 1.0 + sin(TIME * pulse_speed) * pulse_amount;

	float tex_alpha = texture(TEXTURE, UV).a;

	COLOR = glow_color;
	COLOR.a = (glow * 0.6 + core * 0.4) * pulse * tex_alpha;
}
