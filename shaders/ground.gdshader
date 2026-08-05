shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Chao do mundo (a placa de 2200x2200 de Town.tscn).
//
// Historia curta: era UMA cor chapada; virou ruido fbm; e o ruido, por melhor
// que fosse, continuava lendo como feltro de perto. Agora e TEXTURA PBR CC0 de
// verdade (ambientCG), a mesma escolha que ja tinha tirado o aspecto de desenho
// das fachadas — cor, normal e rugosidade de grama, terra e cascalho.
//
// Duas coisas que fazem a diferenca entre "textura aplicada" e "terreno bonito":
//
// 1. ANTI-REPETICAO. Uma textura 2K repetindo num terreno de 2200 m vira uma
//    grade visivel. Cada camada e amostrada em DUAS escalas (uma fina e uma
//    ~3.7x maior, deslocada) e misturada por ruido: o olho perde o padrao.
// 2. MISTURA POR RUIDO, nao por linha. Grama, terra e cascalho se alternam por
//    fbm em escalas diferentes, entao nao ha fronteira reta em lugar nenhum.
//
// De longe tudo isso desliga (ver `detail_fade_*`): textura de 2K vista a 200 m
// e ruido de pixel, e a cor procedural sozinha ja resolve o horizonte.

uniform vec3 grass_color : source_color = vec3(0.30, 0.38, 0.21);
uniform vec3 grass_dry_color : source_color = vec3(0.46, 0.47, 0.28);
uniform vec3 dirt_color : source_color = vec3(0.37, 0.31, 0.24);
uniform vec3 gravel_color : source_color = vec3(0.44, 0.45, 0.36);

// Metade do lado da cidade: dentro dela o chao e batido/cascalho, fora vira
// campo. Sem isso a grama sobe pela calcada e o centro fica com cara de parque.
uniform float city_extent = 135.0;
uniform float city_fade = 115.0;

uniform float macro_scale = 0.007;   // manchas grandes (~140m)
uniform float meso_scale = 0.055;    // manchas medias (~18m)
uniform float micro_scale = 0.9;     // grao (~1m)
uniform float normal_strength : hint_range(0.0, 3.0) = 1.1;

// --------------------------------------------------------------- texturas PBR
uniform sampler2D grass_a_tex : source_color, filter_linear_mipmap_anisotropic, hint_default_white;
uniform sampler2D grass_a_nrm : filter_linear_mipmap_anisotropic, hint_normal;
uniform sampler2D grass_a_rgh : filter_linear_mipmap_anisotropic, hint_default_white;
uniform sampler2D grass_b_tex : source_color, filter_linear_mipmap_anisotropic, hint_default_white;
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap_anisotropic, hint_default_white;
uniform sampler2D dirt_nrm : filter_linear_mipmap_anisotropic, hint_normal;
uniform sampler2D dirt_rgh : filter_linear_mipmap_anisotropic, hint_default_white;
uniform sampler2D gravel_tex : source_color, filter_linear_mipmap_anisotropic, hint_default_white;

// Metros por repeticao da textura fina. O mundo esta em metros de verdade
// (jogador de 1.80), entao 2.2 da uma grama de escala critivel.
uniform float tex_size = 2.2;
// Quantas vezes a segunda amostra e maior. Nao inteiro DE PROPOSITO: com um
// multiplo inteiro as duas escalas batem e a repeticao volta a aparecer.
uniform float tex_macro_ratio = 3.7;
uniform float tex_strength : hint_range(0.0, 1.0) = 1.0;
uniform float detail_fade_start = 60.0;
uniform float detail_fade_end = 200.0;
// Piso de rugosidade: ver o comentario no fragment.
uniform float rough_floor : hint_range(0.0, 1.0) = 0.74;
uniform float ground_specular : hint_range(0.0, 1.0) = 0.15;

varying vec3 world_pos;

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

// Anti-repeticao: a amostra grande MODULA a fina, nao se mistura com ela.
//
// Misturar 50/50 duas amostras da mesma textura e fazer media, e media apaga
// justamente o contraste que da o detalhe — a grama saiu lisa feito campo de
// golfe na primeira tentativa. Modulando (a amostra grande so clareia ou
// escurece a fina) o detalhe fica inteiro e a repeticao some do mesmo jeito.
vec3 detiled(sampler2D tex, vec2 p, float scale, float blend) {
	vec3 fine = texture(tex, p * scale).rgb;
	// Deslocada e girada: sem isso as duas amostras caem no mesmo ponto e a
	// segunda escala nao acrescenta nada.
	vec2 q = (p + vec2(37.4, 19.1)) * (scale / tex_macro_ratio);
	vec3 coarse = texture(tex, vec2(q.y, -q.x)).rgb;
	float cl = dot(coarse, vec3(0.299, 0.587, 0.114));
	return fine * mix(1.0, clamp(cl * 2.0, 0.55, 1.5), blend);
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

	// ------------------------------------------------------- cor procedural
	// Continua sendo a base: e ela que vale de longe, quando a textura some.
	vec3 field = mix(grass_dry_color, grass_color, smoothstep(0.35, 0.7, macro));
	vec3 urban = mix(gravel_color, dirt_color, smoothstep(0.4, 0.65, macro));
	vec3 base = mix(urban, field, country);
	base = mix(base, dirt_color, smoothstep(0.62, 0.85, meso) * 0.55);
	base *= mix(0.82, 1.18, micro);

	ROUGHNESS = mix(0.78, 1.0, micro);
	vec3 nrm = NORMAL;
	float e = 0.35;
	float hx = fbm((p + vec2(e, 0.0)) * micro_scale) - fbm((p - vec2(e, 0.0)) * micro_scale);
	float hz = fbm((p + vec2(0.0, e)) * micro_scale) - fbm((p - vec2(0.0, e)) * micro_scale);
	nrm += (TANGENT * -hx + BINORMAL * -hz) * normal_strength;

	// ----------------------------------------------------------- textura PBR
	float near = 1.0 - smoothstep(detail_fade_start, detail_fade_end, length(VERTEX));
	float amount = near * tex_strength;
	if (amount > 0.002) {
		float scale = 1.0 / max(tex_size, 0.001);
		// Quanto usar da amostra grande: varia pelo terreno, senao a propria
		// mistura vira um padrao.
		float blend = 0.35 + 0.3 * meso;

		// Duas gramas alternando por mancha grande: uma so, por melhor que
		// seja, ainda le como carpete quando cobre 2 km.
		vec3 g = mix(detiled(grass_a_tex, p, scale, blend),
			detiled(grass_b_tex, p, scale * 0.83, blend),
			smoothstep(0.35, 0.65, macro));
		vec3 d = detiled(dirt_tex, p, scale * 1.15, blend);
		vec3 gr = detiled(gravel_tex, p, scale * 1.4, blend);

		// Terra invade a grama nas manchas medias — campo 100% verde le como
		// feltro, e chao de cidade e mais batido que gramado.
		vec3 country_tex = mix(g, d, smoothstep(0.60, 0.86, meso) * 0.75);
		vec3 city_tex = mix(gr, d, smoothstep(0.4, 0.7, macro));
		vec3 tex = mix(city_tex, country_tex, country);

		// A textura vira a cor de perto. Pra nao ter degrau na transicao pro
		// longe (onde ela some), o BRILHO dela e aproximado do tom procedural —
		// por ESCALA, nao por mistura. Misturar com a cor da paleta lavava o
		// detalhe todo; escalar move o tom e preserva o contraste.
		float tex_lum = dot(tex, vec3(0.299, 0.587, 0.114));
		float base_lum = dot(base, vec3(0.299, 0.587, 0.114));
		vec3 matched = tex * clamp(base_lum / max(tex_lum, 0.001), 0.55, 1.7);
		// Metade do tom proprio da textura preservado: puxar 100% pra paleta
		// devolveria o aspecto de cor chapada que a textura veio resolver.
		vec3 tinted = mix(tex, matched, 0.55);
		base = mix(base, tinted, amount);

		// Normal e rugosidade da camada dominante (grama no campo, terra na
		// cidade): amostrar as quatro triplicaria o custo sem aparecer.
		vec3 tn = mix(detiled(dirt_nrm, p, scale * 1.15, blend),
			detiled(grass_a_nrm, p, scale, blend), country) * 2.0 - 1.0;
		nrm += (TANGENT * tn.x + BINORMAL * tn.y) * amount * 1.3;
		// O mapa de rugosidade entra MODULANDO uma faixa fosca, nao como valor
		// absoluto. O Grass004 do ambientCG tem rugosidade media 0.26 (bem
		// lustroso, feito pra grama molhada de estudio): usado cru, com o ceu
		// HDRI por cima, o campo inteiro ganhava um brilho especular branco e
		// lia como carpete lavado. Terra e grama sao foscas.
		float rgh = mix(detiled(dirt_rgh, p, scale * 1.15, blend).r,
			detiled(grass_a_rgh, p, scale, blend).r, country);
		ROUGHNESS = mix(ROUGHNESS, mix(rough_floor, 1.0, rgh), amount * 0.9);
	}

	ALBEDO = base;
	METALLIC = 0.0;
	// Chao de campo nao espelha. O padrao (0.5) somado ao ceu claro era metade
	// do aspecto de "plastico" que sobrava depois da textura entrar.
	SPECULAR = ground_specular;
	NORMAL = normalize(nrm);
}
