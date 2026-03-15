shader_type canvas_item;

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float dist = length(uv);
	float vignette = smoothstep(0.3, 1.25, dist);
	COLOR = vec4(1.0, 0.45, 0.0, vignette * 0.78);
}
