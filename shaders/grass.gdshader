shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx, world_vertex_coords;

// Tufo de grama instanciado (ver scripts/GrassField.gd).
//
// O modelo do nature-megakit vem com uma textura de gradiente verde-limao que
// nao combina com NADA do terreno — o campo ficava com uma faixa neon em cima
// de um chao verde-oliva. Aqui a cor sai da PALETA do chao (as mesmas cores de
// `shaders/ground.gdshader`) e da altura dentro do tufo, e a textura do modelo
// nem e amostrada.
//
// O que este shader resolve, alem da cor:
//   - VENTO. Campo parado le como plastico. A base fica presa e a ponta balanca
//     (peso h^2), na MESMA direcao pro campo inteiro: vento sorteado por tufo
//     le como bagunca, nao como vento.
//   - POP no limite do anel. O campo so existe perto do jogador; sem isso o
//     tufo aparece inteiro do nada quando ele anda. Aqui ele CRESCE do chao.
//   - Folha contra o sol. Grama e fina e a luz atravessa; sem BACKLIGHT o tufo
//     na contraluz fica preto e denuncia que e geometria colada.

// Altura do modelo em escala 1.0, em metros. Vem medida do proprio mesh pelo
// GrassField — chutar aqui e o que fazia a grama sair fora de escala.
uniform float model_height = 1.87;

uniform vec3 root_color : source_color = vec3(0.16, 0.23, 0.11);
uniform vec3 tip_color : source_color = vec3(0.40, 0.50, 0.24);
uniform vec3 dry_color : source_color = vec3(0.55, 0.52, 0.30);
uniform float dry_amount : hint_range(0.0, 1.0) = 0.45;

uniform float wind_strength : hint_range(0.0, 1.0) = 0.16;
uniform float wind_speed = 1.4;
uniform vec2 wind_dir = vec2(0.82, 0.57);

uniform float fade_start = 24.0;
uniform float fade_end = 34.0;

varying float v_h;
varying float v_tuft;
varying float v_patch;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	// A escala do proprio tufo: os tufos variam de tamanho, e normalizar a
	// altura por um valor fixo faria o vento pegar errado nos menores.
	float inst_scale = length(MODEL_MATRIX[1].xyz);
	float height = max(model_height * inst_scale, 0.001);

	vec3 local = VERTEX - origin;
	v_h = clamp(local.y / height, 0.0, 1.0);

	// Encolhe ate zero no limite do anel: o tufo "brota" em vez de aparecer.
	local *= 1.0 - smoothstep(fade_start, fade_end, distance(origin, CAMERA_POSITION_WORLD));

	float phase = dot(origin.xz, vec2(0.22, 0.31));
	float gust = sin(TIME * wind_speed + phase)
		+ 0.45 * sin(TIME * wind_speed * 2.3 + phase * 1.7);
	local.xz += normalize(wind_dir) * gust * wind_strength * height * v_h * v_h;

	VERTEX = origin + local;

	v_tuft = hash12(floor(origin.xz * 7.31));
	// Mancha larga (~9 m): e o que faz aparecer trecho seco e trecho verde no
	// campo, em vez de um chuvisco de cor tufo a tufo.
	v_patch = hash12(floor(origin.xz * 0.11) + vec2(13.7, 5.1));
}

void fragment() {
	// Sem cull, a face de tras chega com a normal invertida e fica preta.
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	vec3 c = mix(root_color, tip_color, v_h);
	c = mix(c, dry_color, smoothstep(0.45, 0.92, v_patch) * dry_amount);
	c *= mix(0.80, 1.20, v_tuft);

	ALBEDO = c;
	METALLIC = 0.0;
	ROUGHNESS = 0.92;
	SPECULAR = 0.15;
	// Folha fina: a luz atravessa.
	BACKLIGHT = vec3(0.32, 0.38, 0.22);
	// Base mais escura: e o que assenta o tufo no chao em vez de deixar ele
	// parecendo colado por cima.
	AO = mix(0.45, 1.0, v_h);
	AO_LIGHT_AFFECT = 0.7;
}
