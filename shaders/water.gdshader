shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4  deep_color    : source_color = vec4(0.04, 0.18, 0.32, 0.92);
uniform vec4  shallow_color : source_color = vec4(0.08, 0.42, 0.48, 0.78);
uniform float wave_speed    : hint_range(0.0, 2.0)  = 0.4;
uniform float wave_height   : hint_range(0.0, 0.3)  = 0.06;
uniform float wave_scale    : hint_range(0.1, 5.0)  = 1.2;

void vertex() {
	float w1 = sin(VERTEX.x * wave_scale + TIME * wave_speed) * wave_height;
	float w2 = cos(VERTEX.z * wave_scale * 0.75 + TIME * wave_speed * 1.3) * wave_height * 0.6;
	float w3 = sin((VERTEX.x + VERTEX.z) * wave_scale * 0.4 + TIME * wave_speed * 0.7) * wave_height * 0.35;
	VERTEX.y += w1 + w2 + w3;

	// Normal aproximada desde derivadas de las ondas
	float dx = cos(VERTEX.x * wave_scale + TIME * wave_speed) * wave_height * wave_scale;
	float dz = sin(VERTEX.z * wave_scale * 0.75 + TIME * wave_speed * 1.3) * wave_height * wave_scale * 0.6;
	NORMAL = normalize(vec3(-dx, 1.0, -dz));
}

void fragment() {
	float depth_blend = 0.5 + 0.5 * sin(TIME * 0.18);
	ALBEDO      = mix(deep_color.rgb, shallow_color.rgb, depth_blend);
	ALPHA       = mix(deep_color.a,   shallow_color.a,   depth_blend);
	ROUGHNESS   = 0.04;    // muy pulido → refleja luz
	METALLIC    = 0.0;
	SPECULAR    = 0.98;    // máximo brillo especular
	// Pequeño tinte de espuma en los picos de onda
	float foam  = clamp(NORMAL.y - 0.95, 0.0, 1.0) * 8.0;
	ALBEDO     += vec3(foam * 0.25);
}
