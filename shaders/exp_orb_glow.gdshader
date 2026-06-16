shader_type canvas_item;
// 经验光芒发光球 — canvas_item 着色器
// 兼容所有渲染器（Forward+ / Mobile / Compatibility）
// 挂到 Sprite2D 的 material 上，纹理可用任意白圆或者纯白方形

// 光芒颜色（Inspector 中显示拾色器）
uniform vec4 glow_color : source_color = vec4(0.3, 0.75, 1.0, 1.0);
// 光晕半径倍率（1.0 = 原始大小）
uniform float glow_radius : hint_range(0.1, 3.0) = 1.0;
// 呼吸脉冲速度（0 = 不闪烁）
uniform float pulse_speed : hint_range(0.0, 10.0) = 5.0;

void fragment() {
	// 以纹理中心为原点
	vec2 center = UV - 0.5;
	float dist = length(center);

	// 内核：硬边小白点
	float core = 1.0 - smoothstep(0.0, 0.10 / glow_radius, dist);

	// 外光晕：大范围软渐变（smoothstep 天然抗锯齿）
	float glow = 1.0 - smoothstep(0.04, 0.42 / glow_radius, dist);

	// 混合：内核亮白 + 光晕半透明
	float alpha = mix(glow * 0.55, 1.0, core * 0.85);

	// 呼吸脉冲（正弦波在 0.75~1.0 之间摆动）
	float pulse = 0.75 + 0.25 * sin(TIME * pulse_speed);

	// 读取纹理自身的 alpha，与发光相乘（纹理可以是任意形状）
	float tex_alpha = texture(TEXTURE, UV).a;

	vec4 col = glow_color;
	col.a *= alpha * pulse * tex_alpha;

	COLOR = col;
}
