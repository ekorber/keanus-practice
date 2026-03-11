shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix;

void fragment() {
	float w = 0.06;
	float ex = step(1.0 - w, UV.x) + step(UV.x, w);
	float ey = step(1.0 - w, UV.y) + step(UV.y, w);
	ALBEDO = vec3(1.0);
	ALPHA = clamp(ex + ey, 0.0, 1.0);
}
