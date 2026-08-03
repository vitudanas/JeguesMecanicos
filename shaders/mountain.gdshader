shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Superficie das montanhas geradas por scripts/MountainRange.gd.
//
// A cor NAO vem de textura: vem da propria forma. Rocha na encosta ingreme,
// mato na parte baixa e suave, neve no alto — que e o que faz uma montanha ler
// como montanha e nao como pedra grande. Uma textura de rocha repetindo numa
// encosta de 100m viraria listra, e o mesmo tom em todo o volume achataria a
// silhueta.
//
// Mesmo fbm de shaders/ground.gdshader, pra montanha e chao terem o mesmo grao
// e a transicao no pe da encosta nao ter emenda.

uniform vec3 rock_color : source_color = vec3(0.38, 0.37, 0.36);
uniform vec3 rock_dark : source_color = vec3(0.24, 0.23, 0.24);
uniform vec3 grass_color : source_color = vec3(0.29, 0.36, 0.21);
uniform vec3 snow_color : source_color = vec3(0.86, 0.88, 0.92);

uniform float grass_max_height = 42.0;   // ate onde o mato sobe
uniform float snow_min_height = 104.0;   // de onde a neve comeca
uniform float slope_rock = 0.62;         // acima disso e rocha exposta
uniform float detail_scale = 0.35;
uniform float normal_strength : hint_range(0.0, 3.0) = 1.4;

varying vec3 world_pos;
varying vec3 world_normal;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
		mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float total = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		total += value_noise(p) * amp;
		p *= 2.03;
		amp *= 0.5;
	}
	return total;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(world_normal);
	// 0 = plano, 1 = parede.
	float slope = clamp(1.0 - n.y, 0.0, 1.0);

	// Amostra pelo plano dominante: numa parede quase vertical o XZ estica a
	// textura em faixas verticais.
	vec2 p = abs(n.y) > 0.6 ? world_pos.xz : (abs(n.x) > abs(n.z) ? world_pos.zy : world_pos.xy);
	float grain = fbm(p * detail_scale);
	float macro = fbm(p * 0.035);

	vec3 rock = mix(rock_dark, rock_color, grain);
	// A quebra rocha/mato acompanha o ruido, senao vira uma linha de nivel
	// perfeita em volta da montanha inteira.
	float grass_line = grass_max_height * (0.7 + 0.6 * macro);
	float grassiness = (1.0 - smoothstep(grass_line * 0.55, grass_line, world_pos.y))
		* (1.0 - smoothstep(slope_rock - 0.18, slope_rock, slope));
	vec3 base = mix(rock, grass_color * mix(0.8, 1.2, grain), grassiness);

	float snow_line = snow_min_height * (0.85 + 0.35 * macro);
	// Neve so pega onde nao e parede: penhasco vertical fica limpo, que e o que
	// da leitura de pico rochoso com neve nas prateleiras.
	float snowiness = smoothstep(snow_line, snow_line * 1.35, world_pos.y)
		* (1.0 - smoothstep(0.45, 0.75, slope));
	base = mix(base, snow_color * mix(0.92, 1.05, grain), snowiness);

	ALBEDO = base;
	METALLIC = 0.0;
	ROUGHNESS = mix(0.92, 0.55, snowiness);

	float e = 0.7;
	float hx = fbm((p + vec2(e, 0.0)) * detail_scale) - fbm((p - vec2(e, 0.0)) * detail_scale);
	float hz = fbm((p + vec2(0.0, e)) * detail_scale) - fbm((p - vec2(0.0, e)) * detail_scale);
	NORMAL = normalize(NORMAL + (TANGENT * -hx + BINORMAL * -hz) * normal_strength);
}
