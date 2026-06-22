shader_type canvas_item;
render_mode blend_mix;

uniform float shake_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float blur_samples : hint_range(0.0, 4.0) = 2.0;
uniform vec2 shake_direction = vec2(1.0, 0.0);

void fragment() {
	if (shake_intensity <= 0.01) {
		COLOR = texture(TEXTURE, UV);
	} else {
		vec2 texel = TEXTURE_PIXEL_SIZE * shake_intensity * 8.0;
		vec4 col = vec4(0.0);
		float count = 0.0;

		int samples = int(blur_samples) * 2 + 1;
		for (int i = -4; i <= 4; i++) {
			float offset = float(i) / float(samples);
			vec2 sample_uv = UV + texel * offset * shake_direction;
			col += texture(TEXTURE, sample_uv);
			count += 1.0;
		}

		col /= count;

		float flicker = 1.0 - shake_intensity * 0.15;
		col.rgb *= flicker;

		COLOR = col;
	}
}
