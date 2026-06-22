shader_type canvas_item;
render_mode blend_mix;

uniform float grain_scale : hint_range(0.5, 5.0) = 1.0;
uniform float grain_intensity : hint_range(0.0, 1.0) = 0.5;
uniform vec4 wood_dark : source_color = vec4(0.11, 0.06, 0.03, 1.0);
uniform vec4 wood_mid : source_color = vec4(0.16, 0.09, 0.05, 1.0);
uniform vec4 wood_light : source_color = vec4(0.20, 0.12, 0.07, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

void fragment() {
	vec2 uv = UV * 256.0 * grain_scale;

	float grain = 0.0;
	float amp = 1.0;
	float freq = 1.0;
	for (int i = 0; i < 3; i++) {
		grain += noise(uv * freq) * amp;
		freq *= 2.0;
		amp *= 0.5;
	}
	grain /= 1.75;

	float vertical_stretch = sin(UV.y * 32.0 + grain * 3.0) * 0.5 + 0.5;
	float ring = sin(UV.x * 8.0 + grain * 2.0 + vertical_stretch * 1.5) * 0.5 + 0.5;

	float combined = mix(grain, ring, 0.4);

	float threshold_low = 0.3;
	float threshold_high = 0.65;
	float pixelated = floor(combined * 16.0) / 16.0;

	vec4 col = wood_dark;
	if (pixelated > threshold_high) {
		col = wood_light;
	} else if (pixelated > threshold_low) {
		col = wood_mid;
	}

	COLOR = mix(col, wood_mid, 1.0 - grain_intensity);
	COLOR.a = 1.0;
}
