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

uniform vec3 rock_color : source_color = vec3(0.31, 0.33, 0.34);
uniform vec3 rock_dark : source_color = vec3(0.18, 0.21, 0.23);
uniform vec3 grass_color : source_color = vec3(0.23, 0.30, 0.20);
uniform vec3 snow_color : source_color = vec3(0.67, 0.72, 0.76);

// Alturas recalibradas quando a serra passou de 138 m pra 320 m: com os valores
// antigos (mato ate 42, neve a partir de 104) quase todo maciço virava pico
// nevado e o mato sumia num tapete no pe.
uniform float grass_max_height = 92.0;   // ate onde o mato sobe
uniform float snow_min_height = 255.0;   // neve vira acento, nao parede branca
uniform float slope_rock = 0.62;         // acima disso e rocha exposta
uniform float detail_scale = 0.35;
// Estratos: a rocha de uma encosta de verdade tem camadas, e e o que dá leitura
// de "montanha" numa silhueta grande. Sem isso a encosta e uma mancha cinza
// uniforme, por mais alta que seja.
uniform float strata_freq = 0.09;
uniform float strata_strength : hint_range(0.0, 1.0) = 0.34;
// Detalhe fino de perto (~30 cm), que some com a distancia pra nao cintilar.
uniform float fine_scale = 3.2;
uniform float fine_fade_start = 40.0;
uniform float fine_fade_end = 220.0;
uniform float normal_strength : hint_range(0.0, 3.0) = 1.4;

// PBR de rocha por cima da cor procedural — mesma tecnica ja usada nas fachadas
// (shaders/city_surface.gdshader): a COR continua saindo da forma (rocha na
// encosta, mato embaixo, neve no alto), e a textura entra so como grao, normal e
// rugosidade. Cor vinda de textura estragaria a leitura de altitude, e uma
// textura de rocha esticada numa encosta de 300 m viraria listra.
uniform sampler2D detail_color : source_color, filter_linear_mipmap, hint_default_white;
uniform sampler2D detail_normal : filter_linear_mipmap, hint_normal;
uniform sampler2D detail_roughness : filter_linear_mipmap, hint_default_white;
// Metros por repeticao da textura.
uniform float detail_size = 6.0;
uniform float detail_strength : hint_range(0.0, 1.0) = 0.55;

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

// Triplanar: a encosta nao tem UV util (a malha e um campo de altura gerado), e
// projetar so por XZ esticaria a textura numa parede vertical ate virar listra.
vec3 triplanar(sampler2D tex, vec3 pos, vec3 n, float scale) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= max(w.x + w.y + w.z, 0.0001);
	return texture(tex, pos.zy * scale).rgb * w.x
		+ texture(tex, pos.xz * scale).rgb * w.y
		+ texture(tex, pos.xy * scale).rgb * w.z;
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

	// Camadas de rocha: bandas quase horizontais, onduladas pelo ruido pra nao
	// virarem linha de nivel perfeita. E o detalhe que mais rende numa encosta
	// grande, porque aparece de longe.
	float strata = fract(world_pos.y * strata_freq + macro * 2.4 + grain * 0.6);
	float band = smoothstep(0.0, 0.45, strata) * smoothstep(1.0, 0.55, strata);
	vec3 rock = mix(rock_dark, rock_color, grain);
	rock *= mix(1.0 - strata_strength * 0.5, 1.0 + strata_strength * 0.5, band);
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

	// Grao de rocha de verdade por cima. MODULA em torno de 1.0 em vez de
	// multiplicar direto: multiplicar escurece tudo, porque a luminancia media da
	// textura e bem abaixo de 1 — armadilha ja documentada no city_surface, onde
	// a cidade inteira ficou quase preta.
	float scale = 1.0 / max(detail_size, 0.001);
	vec3 grain_tex = triplanar(detail_color, world_pos, n, scale);
	float lum = dot(grain_tex, vec3(0.299, 0.587, 0.114));
	// So na parte rochosa: neve e mato nao tem cara de concreto.
	float rocky = (1.0 - snowiness) * (1.0 - grassiness);
	base *= mix(1.0, mix(0.72, 1.28, lum), detail_strength * rocky);

	ALBEDO = base;
	METALLIC = 0.0;
	float rough_tex = triplanar(detail_roughness, world_pos, n, scale).r;
	ROUGHNESS = mix(mix(0.92, 0.55, snowiness), rough_tex, detail_strength * rocky * 0.6);

	float e = 0.7;
	float hx = fbm((p + vec2(e, 0.0)) * detail_scale) - fbm((p - vec2(e, 0.0)) * detail_scale);
	float hz = fbm((p + vec2(0.0, e)) * detail_scale) - fbm((p - vec2(0.0, e)) * detail_scale);
	vec3 nrm = NORMAL + (TANGENT * -hx + BINORMAL * -hz) * normal_strength;

	// Aspereza fina de perto: sem isso, chegar no pe da serra mostra uma parede
	// lisa, porque o menor detalhe da encosta tinha 3 m.
	float fine = 1.0 - smoothstep(fine_fade_start, fine_fade_end, length(VERTEX));
	if (fine > 0.001) {
		float ef = 0.08;
		float fx = fbm((p + vec2(ef, 0.0)) * fine_scale) - fbm((p - vec2(ef, 0.0)) * fine_scale);
		float fz = fbm((p + vec2(0.0, ef)) * fine_scale) - fbm((p - vec2(0.0, ef)) * fine_scale);
		nrm += (TANGENT * -fx + BINORMAL * -fz) * normal_strength * 0.9 * fine;
		ALBEDO *= mix(1.0, mix(0.88, 1.12, fbm(p * fine_scale)), fine);
	}
	// Normal da textura de rocha, no mesmo triplanar. E o que da relevo de
	// verdade na encosta: sem ela a superficie so tem o relevo do ruido, que e
	// suave demais pra ler como pedra.
	vec3 tex_n = triplanar(detail_normal, world_pos, n, scale) * 2.0 - 1.0;
	nrm += (TANGENT * tex_n.x + BINORMAL * tex_n.y) * detail_strength * rocky * 1.2;
	NORMAL = normalize(nrm);
}
