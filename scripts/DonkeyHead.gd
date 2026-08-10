class_name DonkeyHead
extends RefCounted
## Cabeca de jegue, montada com primitivas em codigo.
##
## O jogo se chama Jegues Mecanicos e o jogador e uma mulher com cabeca de
## jegue — nao existe modelo disso em pacote CC0 nenhum, e nao ha ferramenta de
## geracao de modelo 3D neste ambiente (ver changelog 2026-08-04). Entao vale a
## mesma escolha do mobiliario urbano (`StreetFurniture.gd`) e das gambiarras
## (`GambiarraVisual.gd`): montar com esfera, capsula e caixa.
##
## Espaco de montagem: o no nasce na origem do OSSO `Head` do esqueleto do
## personagem (medido: fica em y = 1.55 do modelo, com os eixos praticamente
## alinhados com o mundo, e o rosto olhando pro **+Z**). Todas as medidas abaixo
## sao em metros a partir dali.
##
## A caixa craniana e generosa DE PROPOSITO: ela precisa ENGOLIR a cabeca
## humana do modelo, que faz parte da mesma malha do corpo e por isso nao pode
## ser escondida sozinha. Medido no arquivo, a cabeca ocupa x ±0.12,
## y 1.50..1.78 e z -0.16..0.11 — ou seja, relativo ao osso, de -0.05 a +0.23
## em Y. O crânio abaixo cobre isso com folga.

## Malhas do personagem que somem quando a cabeca de jegue entra: cabelo, olhos
## e sobrancelha sao malhas SEPARADAS no .glb, entao dá pra escondê-las. A
## cabeça humana em si NAO da — ela faz parte da mesma malha do corpo —, e por
## isso o crânio abaixo tem que engolir ela.
##
## O cabelo entra por PREFIXO, e nao por nome exato: medido nos dois arquivos, o
## modelo feminino usa `Hair_Long` e o masculino `Hair_SimpleParted`. Com a
## lista de nomes fixos que existia aqui, o cabelo do homem continuava ligado e
## aparecia atravessando o crânio.
const HIDE_MESHES: Array[String] = ["Eyes", "Eyebrows"]
const HIDE_PREFIXES: Array[String] = ["Hair"]

## Esta malha some quando a cabeca de jegue entra?
static func is_head_part(mesh_name: String) -> bool:
	if HIDE_MESHES.has(mesh_name):
		return true
	for prefix: String in HIDE_PREFIXES:
		if mesh_name.begins_with(prefix):
			return true
	return false

const FUR := Color(0.45, 0.41, 0.38)        ## pelo cinza-pardo de jegue
const FUR_DARK := Color(0.30, 0.27, 0.25)
const MUZZLE := Color(0.82, 0.78, 0.72)     ## focinho e volta dos olhos claros
const MANE := Color(0.19, 0.16, 0.15)
const EYE := Color(0.06, 0.05, 0.05)
const WHITE := Color(0.94, 0.94, 0.92)
const NOSTRIL := Color(0.16, 0.13, 0.12)

## Crânio. A crina é montada A PARTIR destes números (não de uma curva escrita
## à mão do lado), então ela continua colada na cabeça se o crânio mudar.
const SKULL_CENTER := Vector3(0.0, 0.10, 0.01)
const SKULL_RADII := Vector3(0.15, 0.17, 0.18)
const SKULL_TILT := -8.0

## Contas da crina. Precisa ser denso o bastante pro raio de cada esfera passar
## do passo entre elas — é isso que funde a fileira numa crista só.
const MANE_SEGMENTS := 26
## Varredura da crina sobre o crânio, em graus: 0 é o alto da cabeça, negativo
## vai descendo por trás. Começa um pouco à frente do topo (onde nasce o
## topete) e morre embaixo da nuca.
const MANE_FROM := 25.0
const MANE_TO := -140.0

## Ponto na superfície do crânio para um ângulo da varredura acima.
## `lift` > 1 põe o ponto pra fora da casca — é o que faz a crina se destacar
## em vez de sumir dentro do crânio.
static func _skull_point(angle_deg: float, lift: float) -> Vector3:
	var a := deg_to_rad(angle_deg)
	var offset := Vector3(0.0, SKULL_RADII.y * cos(a), SKULL_RADII.z * sin(a)) * lift
	return SKULL_CENTER + offset.rotated(Vector3.RIGHT, deg_to_rad(SKULL_TILT))

static func _material(color: Color, rough := 0.72) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = 0.0
	return m

static func _sphere(parent: Node3D, size: Vector3, pos: Vector3, color: Color,
		rot := Vector3.ZERO, rough := 0.72) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 20
	mesh.rings = 12
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _material(color, rough)
	mi.scale = size
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi

static func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color,
		rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _material(color)
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi

## Monta a cabeca. O +Z do no devolvido e a direcao do FOCINHO.
static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "CabecaDeJegue"

	# ------------------------------------------------------------- crânio
	# Engole a cabeca humana (ver o comentario do topo). Ligeiramente ovalado e
	# inclinado pra frente, que e o formato de cabeca de equino.
	# A escala de `_sphere` é o DIÂMETRO (a esfera base tem raio 0.5), por isso
	# o dobro dos raios.
	_sphere(root, SKULL_RADII * 2.0, SKULL_CENTER, FUR,
		Vector3(deg_to_rad(SKULL_TILT), 0.0, 0.0))
	# Testa/topete: a saliencia entre as orelhas.
	_sphere(root, Vector3(0.22, 0.14, 0.20), Vector3(0.0, 0.235, 0.03), FUR)

	# ------------------------------------------------------------- focinho
	# Duas peças: o cano do nariz (mais fino) e a boca/venta (mais clara). Um
	# focinho de peça só sai como bico e não lê como jegue.
	#
	# A ponta tem que ser MAIS ESTREITA que o cano: na primeira versão ela era
	# mais larga (0.20 contra 0.19) e formava um degrau, então lia como um bulbo
	# pálido grudado na cara em vez de focinho. Ela também recuou pra sobrepor
	# mais o cano — o que emenda as duas peças em uma forma só.
	# O cano CAI da testa pra ponta (12°, era 6°) e ficou mais curto: esticado e
	# quase na horizontal, o focinho lia como tubo de tamanduá. Cabeça de equino
	# tem a linha do nariz descendo.
	_sphere(root, Vector3(0.185, 0.175, 0.27), Vector3(0.0, 0.038, 0.185), FUR,
		Vector3(deg_to_rad(12.0), 0.0, 0.0))
	_sphere(root, Vector3(0.170, 0.155, 0.175), Vector3(0.0, -0.005, 0.272), MUZZLE)
	# Beiço de baixo, um pouco solto — é o detalhe que dá o ar bocó do bicho.
	_sphere(root, Vector3(0.128, 0.078, 0.118), Vector3(0.0, -0.050, 0.272), MUZZLE)

	for side in [-1.0, 1.0]:
		# Ventas. Pequenas DE PROPÓSITO: na primeira versão mediam 4.5 x 5.5 cm
		# e, quase pretas sobre o focinho claro, liam como um SEGUNDO par de
		# olhos no meio da cara (o bicho parecia ter quatro). Inclinadas pra
		# fora, que é o desenho da venta de equino.
		_sphere(root, Vector3(0.030, 0.040, 0.032), Vector3(side * 0.044, 0.010, 0.340),
			NOSTRIL, Vector3(0.0, 0.0, deg_to_rad(side * 18.0)), 0.45)
		# ------------------------------------------------------------ olhos
		# Bem pro lado da cabeça, como em qualquer herbívoro — olho de frente
		# lê como pessoa fantasiada.
		_sphere(root, Vector3(0.075, 0.085, 0.075), Vector3(side * 0.125, 0.145, 0.115),
			EYE, Vector3.ZERO, 0.18)
		# Brilho: sem ele o olho preto vira buraco (a mesma lição da fachada).
		# Pequeno — a 2.6 cm ele tomava metade do olho e virava olho esbugalhado
		# de desenho, não reflexo.
		_sphere(root, Vector3(0.018, 0.018, 0.018),
			Vector3(side * 0.140, 0.172, 0.142), WHITE, Vector3.ZERO, 0.1)
		# Pálpebra clara por cima, que é o que marca a cara de jegue.
		_sphere(root, Vector3(0.095, 0.045, 0.09), Vector3(side * 0.122, 0.185, 0.11),
			MUZZLE)

		# --------------------------------------------------------- orelhas
		# A assinatura do bicho: longas, estreitas e abertas pra fora. Uma
		# cápsula dá a ponta arredondada sem custar geometria.
		var ear := Node3D.new()
		ear.position = Vector3(side * 0.085, 0.235, -0.01)
		ear.rotation = Vector3(deg_to_rad(-12.0), 0.0, deg_to_rad(side * -20.0))
		root.add_child(ear)
		var outer := CapsuleMesh.new()
		outer.radius = 0.5
		outer.height = 2.0
		outer.radial_segments = 12
		outer.rings = 6
		var ear_mi := MeshInstance3D.new()
		ear_mi.mesh = outer
		ear_mi.material_override = _material(FUR)
		ear_mi.scale = Vector3(0.085, 0.17, 0.055)
		ear_mi.position = Vector3(0.0, 0.17, 0.0)
		ear.add_child(ear_mi)
		# Miolo claro, levemente à frente: é o que faz a orelha ter FRENTE e
		# não parecer um chifre.
		var inner := CapsuleMesh.new()
		inner.radius = 0.5
		inner.height = 2.0
		inner.radial_segments = 10
		inner.rings = 5
		var inner_mi := MeshInstance3D.new()
		inner_mi.mesh = inner
		inner_mi.material_override = _material(MUZZLE)
		inner_mi.scale = Vector3(0.05, 0.145, 0.03)
		inner_mi.position = Vector3(0.0, 0.165, 0.022)
		ear.add_child(inner_mi)

	# --------------------------------------------------------------- crina
	# Faixa escura descendo da testa pela nuca.
	#
	# Duas versões erradas antes desta, as duas pelo mesmo motivo — a crina
	# ficava SOLTA da cabeça em vez de nascer nela:
	#   1. 5 esferas espaçadas e inclinadas uma a uma: girar cada uma afastava
	#      as pontas do eixo longo e saía um colar de contas soltas.
	#   2. contas densas ao longo de uma curva escrita à mão: virou um tubo
	#      levantado no meio da nuca, tipo lagarta.
	# Agora os pontos saem da PRÓPRIA casca do crânio (`_skull_point`), só um
	# pouco pra fora: metade de cada esfera fica enterrada, então o que aparece
	# é uma crista rente à cabeça — que é como crina de burro se comporta.
	for i in range(MANE_SEGMENTS):
		var t := float(i) / float(MANE_SEGMENTS - 1)
		# Larga em cima e afinando pra nuca, senão a crista sai reta.
		var wide := lerpf(0.105, 0.052, t)
		var thick := lerpf(0.058, 0.034, t)
		_sphere(root, Vector3(wide, thick, thick),
			_skull_point(lerpf(MANE_FROM, MANE_TO, t), 1.02), MANE, Vector3.ZERO, 0.85)

	# Topete caído na testa, entre as orelhas. Achatado: alto demais ele lia
	# como um chifre no meio do crânio.
	_sphere(root, Vector3(0.105, 0.048, 0.10), Vector3(0.0, 0.272, 0.064), MANE,
		Vector3(deg_to_rad(32.0), 0.0, 0.0), 0.85)

	# ----------------------------------------------------------------- boca
	_box(root, Vector3(0.090, 0.011, 0.046), Vector3(0.0, -0.028, 0.326), FUR_DARK,
		Vector3(deg_to_rad(12.0), 0.0, 0.0))

	return root
