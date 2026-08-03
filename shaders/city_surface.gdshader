shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Superficie das construcoes e do asfalto da cidade.
//
// Problema que resolve: as texturas do kit Kenney sao imagens de 64x64 em
// paleta — cor chapada, sem grao, sem normal map, sem roughness. E dai que vem
// o aspecto de desenho, nao da iluminacao (medido em 2026-08-03). Trocar o kit
// inteiro nao resolveria barato: kit modular realista e gratuito nao existe, e
// toda a geracao da cidade esta calibrada no modulo desse kit.
//
// Entao aqui a geometria continua a mesma e so o ACABAMENTO muda:
// - o atlas do kit continua no albedo, senao janela e porta somem (elas sao
//   desenhadas na textura, nao modeladas);
// - por cima entra um material PBR de verdade (CC0, ambientCG) em TRIPLANAR,
//   que dispensa UV decente — e o caso aqui, o UV do kit aponta pro atlas;
// - o triplanar entra como grao + normal + roughness, nao substituindo a cor.
//
// A dessaturacao e um controle a parte: o telhado verde-limao do kit suburbano
// e o elemento mais cartunesco da cidade, e ele vive na textura, nao no
// material — nao da pra trocar so a cor dele sem mexer no atlas.

uniform sampler2D atlas : source_color, filter_linear_mipmap, hint_default_white;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float saturation : hint_range(0.0, 1.0) = 0.62;

uniform sampler2D detail_color : source_color, filter_linear_mipmap, hint_default_white;
uniform sampler2D detail_normal : filter_linear_mipmap, hint_normal;
uniform sampler2D detail_roughness : filter_linear_mipmap, hint_default_white;

// Metros de mundo por repeticao da textura (o mundo esta em metros de verdade).
uniform float detail_size : hint_range(0.2, 12.0) = 2.4;
uniform float detail_strength : hint_range(0.0, 1.0) = 0.35;
// O verde-limao do telhado do kit suburbano e o ponto mais cartunesco da
// cidade, e ele vive DENTRO do atlas — nao da pra trocar so a cor dele por
// fora. Aqui o quanto de verde puro sobra vira cinza-esverdeado.
uniform float green_tame : hint_range(0.0, 1.0) = 0.75;
uniform float normal_strength : hint_range(0.0, 2.0) = 1.0;
uniform float roughness_min : hint_range(0.0, 1.0) = 0.55;
uniform float roughness_max : hint_range(0.0, 1.0) = 0.95;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Amostra a textura pelas tres projecoes e mistura pelo peso da normal: e o
// que permite usar textura de verdade num modelo cujo UV esta ocupado com o
// atlas de cor do kit.
vec3 triplanar(sampler2D tex, vec3 p, vec3 n, float scale) {
	vec3 blend = pow(abs(n), vec3(4.0));
	blend /= max(blend.x + blend.y + blend.z, 0.0001);
	vec3 sx = texture(tex, p.zy * scale).rgb;
	vec3 sy = texture(tex, p.xz * scale).rgb;
	vec3 sz = texture(tex, p.xy * scale).rgb;
	return sx * blend.x + sy * blend.y + sz * blend.z;
}

void fragment() {
	vec4 base = texture(atlas, UV) * tint;

	float luma = dot(base.rgb, vec3(0.2126, 0.7152, 0.0722));
	base.rgb = mix(vec3(luma), base.rgb, saturation);

	float green = clamp(base.g - max(base.r, base.b), 0.0, 1.0) * 3.0;
	base.rgb = mix(base.rgb, vec3(luma) * vec3(0.97, 1.0, 0.94),
		clamp(green, 0.0, 1.0) * green_tame);

	float scale = 1.0 / max(detail_size, 0.001);
	vec3 n = normalize(world_normal);

	// O grao MODULA a cor do kit em torno de 1.0 (nao substitui e nao escurece
	// no geral): acima do cinza medio clareia, abaixo escurece. Multiplicar
	// direto pela textura, como eu tinha feito antes, derrubava a fachada
	// inteira — tijolo tem luminancia media bem baixa e a cidade ficou preta.
	vec3 grain = triplanar(detail_color, world_pos, n, scale);
	float g = dot(grain, vec3(0.3333));
	base.rgb *= mix(1.0, g / 0.5, detail_strength);

	ALBEDO = base.rgb;
	METALLIC = 0.0;
	NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0),
		triplanar(detail_normal, world_pos, n, scale), normal_strength);
	ROUGHNESS = mix(roughness_min, roughness_max,
		triplanar(detail_roughness, world_pos, n, scale).r);
}
