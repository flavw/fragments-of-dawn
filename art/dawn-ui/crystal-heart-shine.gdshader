shader_type canvas_item;

void fragment() {
	vec4 ruby = texture(TEXTURE, UV);
	float phase = mod(TIME, 6.0) / 1.3;
	float diagonal = UV.x + UV.y * 0.30;
	float distance_to_light = abs(diagonal - (phase * 1.6 - 0.15));
	float shine = (1.0 - smoothstep(0.0, 0.075, distance_to_light)) * step(phase, 1.0);
	COLOR *= vec4(ruby.rgb + vec3(0.25, 0.23, 0.18) * shine, ruby.a);
}
