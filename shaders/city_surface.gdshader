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

// ------------------------------------------------- PRETO PURO E VIDRO NO KIT
// Duas regioes do atlas precisam de tratamento proprio, e sao coisas
// diferentes — renderizar um modelo do kit com o material original mostra a
// intencao do artista:
//
// 1. PRETO PURO ocupa um quarto do atlas (medido: 65536 dos 262144 pixels) e e
//    o EMBASAMENTO TERREO (a faixa da loja, o batente da porta, as molduras).
//    Preto puro nao reage a luz nenhuma: no jogo a faixa de baixo de TODOS os
//    predios lia como um buraco na fachada — o defeito mais grave da cidade
//    vista do chao. Aqui ele vira um plinto escuro DE VERDADE, que continua
//    escuro mas recebe luz, grao e sujeira como qualquer parede.
// 2. AZUL e a JANELA. E nela que entra o vidro: metalico e liso, refletindo o
//    ceu HDRI. Janela de predio e reflexo, nao cor — e isso e o que mais rende
//    numa fachada de longe.
uniform vec3 plinth_color : source_color = vec3(0.26, 0.26, 0.285);

uniform bool glass_enabled = true;
/// Quanto o azul precisa dominar o vermelho/verde pra contar como janela.
uniform float glass_blue_min : hint_range(0.0, 0.5) = 0.10;
uniform float glass_blue_max : hint_range(0.0, 0.5) = 0.22;
uniform vec3 glass_tint : source_color = vec3(0.46, 0.53, 0.62);
uniform float glass_roughness : hint_range(0.0, 1.0) = 0.12;
// Reflexo de ceu sozinho nao basta: numa rua estreita a parede nao ve o ceu e a
// janela volta a ser um buraco. Duas coisas resolvem, e as duas existem no
// predio de verdade — a luz de dentro e o brilho rasante do vidro.
uniform vec3 glass_emission : source_color = vec3(0.055, 0.065, 0.085);
uniform float glass_fresnel : hint_range(0.0, 1.0) = 0.30;

// ------------------------------------------------------------- ENVELHECIMENTO
// Fachada limpa e uniforme de baixo a cima e coisa de maquete. Na rua, o metro
// e meio de baixo pega respingo e fuligem. So vale pra parede (peso pela
// inclinacao da normal) e so onde for pedido — o asfalto usa o mesmo shader e
// esta na mesma altura.
uniform float grime_amount : hint_range(0.0, 1.0) = 0.0;
uniform float grime_height = 2.6;
uniform vec3 grime_color : source_color = vec3(0.34, 0.32, 0.29);

// Sombreamento facetado. Medido: 530 das 1252 faces do predio do kit vem
// marcadas como SUAVES, com a normal de vertice desviando ate 45 graus da
// normal da face — e dai que vem o aspecto de sabonete, a quina existe na
// geometria mas o sombreado passa por cima dela. Recalcular a normal por
// derivada de tela devolve a quina sem tocar na malha.
uniform bool flat_shading = true;

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
	vec4 raw = texture(atlas, UV);
	// Janela e plinto identificados no atlas CRU: com o tint aplicado, uma
	// fachada escura ou azulada entraria na conta e o predio inteiro mudaria
	// de material.
	float glass = 0.0;
	if (glass_enabled) {
		float blue = raw.b - max(raw.r, raw.g);
		glass = smoothstep(glass_blue_min, glass_blue_max, blue);
	}
	// Levanta o preto ANTES do tint, senao um plinto lido como preto continua
	// preto depois de multiplicado por qualquer cor.
	float raw_luma = dot(raw.rgb, vec3(0.2126, 0.7152, 0.0722));
	raw.rgb = max(raw.rgb, plinth_color * (1.0 - smoothstep(0.0, 0.10, raw_luma)));

	vec4 base = raw * tint;

	float luma = dot(base.rgb, vec3(0.2126, 0.7152, 0.0722));
	base.rgb = mix(vec3(luma), base.rgb, saturation);

	float green = clamp(base.g - max(base.r, base.b), 0.0, 1.0) * 3.0;
	base.rgb = mix(base.rgb, vec3(luma) * vec3(0.97, 1.0, 0.94),
		clamp(green, 0.0, 1.0) * green_tame);

	float scale = 1.0 / max(detail_size, 0.001);
	vec3 n = normalize(world_normal);
	if (flat_shading) {
		// A derivada de tela da a normal da FACE, mas com o sinal dependendo
		// da orientacao do triangulo na tela — sem realinhar pelo hemisferio
		// da normal interpolada, metade das fachadas fica virada pro lado
		// oposto da luz e a cidade inteira renderiza PRETA (foi o que
		// aconteceu no primeiro teste).
		vec3 face_view = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
		NORMAL = face_view * sign(dot(face_view, NORMAL));
		// O triplanar tambem passa a usar a face: com a normal suavizada a
		// mistura das tres projecoes borrava na quina.
		vec3 face_world = normalize(cross(dFdx(world_pos), dFdy(world_pos)));
		n = face_world * sign(dot(face_world, n));
	}

	// O grao MODULA a cor do kit em torno de 1.0 (nao substitui e nao escurece
	// no geral): acima do cinza medio clareia, abaixo escurece. Multiplicar
	// direto pela textura, como eu tinha feito antes, derrubava a fachada
	// inteira — tijolo tem luminancia media bem baixa e a cidade ficou preta.
	vec3 grain = triplanar(detail_color, world_pos, n, scale);
	float g = dot(grain, vec3(0.3333));
	base.rgb *= mix(1.0, g / 0.5, detail_strength);

	// Sujeira de rua: so na parede (|n.y| pequeno) e so no metro e meio de
	// baixo, com a borda bagunçada pelo proprio grao — linha reta de sujeira
	// entrega que foi pintada.
	if (grime_amount > 0.001) {
		float wall = 1.0 - clamp(abs(n.y), 0.0, 1.0);
		float low = 1.0 - smoothstep(0.0, grime_height, world_pos.y + (g - 0.5) * 0.9);
		base.rgb = mix(base.rgb, grime_color, low * wall * grime_amount * (1.0 - glass));
	}

	float rough = mix(roughness_min, roughness_max,
		triplanar(detail_roughness, world_pos, n, scale).r);
	vec3 nrm_map = mix(vec3(0.5, 0.5, 1.0),
		triplanar(detail_normal, world_pos, n, scale), normal_strength);

	if (glass > 0.001) {
		// Metalico: e o que faz o Godot usar a cor como TINGIMENTO do reflexo
		// do ceu em vez de cor propria. Vidro de predio nao tem cor propria.
		METALLIC = mix(0.0, 0.82, glass);
		ROUGHNESS = mix(rough, glass_roughness, glass);
		// Sem grao de concreto e sem relevo no vidro: os dois denunciam na hora.
		nrm_map = mix(nrm_map, vec3(0.5, 0.5, 1.0), glass);
		base.rgb = mix(base.rgb, glass_tint, glass);
		float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 4.0);
		EMISSION = glass * (glass_emission + vec3(fres) * glass_fresnel);
	} else {
		METALLIC = 0.0;
		ROUGHNESS = rough;
	}

	ALBEDO = base.rgb;
	NORMAL_MAP = nrm_map;
}
