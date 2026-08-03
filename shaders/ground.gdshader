shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Chao do mundo (a placa de 600x600 de Town.tscn).
//
// Problema que resolve: o chao era UMA cor chapada. Visto de perto passava,
// mas de longe a cidade lia como maquete em cima de uma mesa cinza — o tell
// mais forte que sobrou depois de texturizar as fachadas.
//
// Aqui o relevo e falso mas o ACABAMENTO e de verdade: ruido fbm em varias
// escalas define manchas de terra e grama, a normal sai da derivada do ruido
// fino (da micro-relevo sem custar geometria) e a rugosidade acompanha.
//
// Por que ruido em vez de textura baixada: uma foto de grama 1K repetindo num
// terreno de 600m vira listra visivel, e o ruido em 3 escalas nao repete.
// De quebra nao custa nenhum byte no build.

uniform vec3 grass_color : source_color = vec3(0.30, 0.38, 0.21);
uniform vec3 grass_dry_color : source_color = vec3(0.46, 0.47, 0.28);
uniform vec3 dirt_color : source_color = vec3(0.37, 0.31, 0.24);
uniform vec3 gravel_color : source_color = vec3(0.44, 0.45, 0.36);

// Metade do lado da cidade: dentro dela o chao e mais batido/terroso, fora
// vira campo. Sem isso a grama sobe pela calcada e o centro fica com cara de
// parque.
uniform float city_extent = 135.0;
uniform float city_fade = 115.0;

uniform float macro_scale = 0.007;   // manchas grandes (~140m)
uniform float meso_scale = 0.055;    // manchas medias (~18m)
uniform float micro_scale = 0.9;     // grao (~1m)
uniform float normal_strength : hint_range(0.0, 3.0) = 1.1;

varying vec3 world_pos;

// Ruido de valor + fbm. Barato e suficiente: o que importa aqui e quebrar a
// uniformidade, nao simular solo.
float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
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
}

void fragment() {
	vec2 p = world_pos.xz;

	float macro = fbm(p * macro_scale);
	float meso = fbm(p * meso_scale);
	float micro = fbm(p * micro_scale);

	// 0 = miolo da cidade, 1 = campo aberto. Chebyshev, casando com o formato
	// quadrado da grade de ruas (o mesmo criterio do anel rural).
	float chebyshev = max(abs(p.x), abs(p.y));
	float country = smoothstep(city_extent - city_fade, city_extent + city_fade, chebyshev);

	vec3 field = mix(grass_dry_color, grass_color, smoothstep(0.35, 0.7, macro));
	vec3 urban = mix(gravel_color, dirt_color, smoothstep(0.4, 0.65, macro));
	vec3 base = mix(urban, field, country);

	// Manchas de terra pelada tambem no campo: campo 100% verde le como feltro.
	base = mix(base, dirt_color, smoothstep(0.62, 0.85, meso) * 0.55);
	// Grao: MODULA em torno de 1.0 em vez de multiplicar direto, senao o chao
	// inteiro escurece (mesma armadilha ja documentada no city_surface).
	base *= mix(0.82, 1.18, micro);

	ALBEDO = base;
	METALLIC = 0.0;
	ROUGHNESS = mix(0.78, 1.0, micro);

	// Micro-relevo: a normal sai da inclinacao do ruido fino, entao o chao
	// pega luz rasante como superficie irregular em vez de espelho fosco.
	float e = 0.35;
	float hx = fbm((p + vec2(e, 0.0)) * micro_scale) - fbm((p - vec2(e, 0.0)) * micro_scale);
	float hz = fbm((p + vec2(0.0, e)) * micro_scale) - fbm((p - vec2(0.0, e)) * micro_scale);
	NORMAL = normalize(NORMAL + (TANGENT * -hx + BINORMAL * -hz) * normal_strength);
}
