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
const HIDE_MESHES: Array[String] = ["Hair_Long", "Eyes", "Eyebrows"]

const FUR := Color(0.45, 0.41, 0.38)        ## pelo cinza-pardo de jegue
const FUR_DARK := Color(0.30, 0.27, 0.25)
const MUZZLE := Color(0.82, 0.78, 0.72)     ## focinho e volta dos olhos claros
const MANE := Color(0.19, 0.16, 0.15)
const EYE := Color(0.06, 0.05, 0.05)
const WHITE := Color(0.94, 0.94, 0.92)
const NOSTRIL := Color(0.12, 0.10, 0.10)

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
	_sphere(root, Vector3(0.30, 0.34, 0.36), Vector3(0.0, 0.10, 0.01), FUR,
		Vector3(deg_to_rad(-8.0), 0.0, 0.0))
	# Testa/topete: a saliencia entre as orelhas.
	_sphere(root, Vector3(0.22, 0.14, 0.20), Vector3(0.0, 0.235, 0.03), FUR)

	# ------------------------------------------------------------- focinho
	# Duas peças: o cano do nariz (mais fino) e a boca/venta (mais larga e
	# clara). Um focinho de peça só sai como bico e não lê como jegue.
	_sphere(root, Vector3(0.19, 0.18, 0.30), Vector3(0.0, 0.045, 0.20), FUR,
		Vector3(deg_to_rad(6.0), 0.0, 0.0))
	_sphere(root, Vector3(0.20, 0.17, 0.20), Vector3(0.0, 0.005, 0.31), MUZZLE)
	# Beiço de baixo, um pouco solto — é o detalhe que dá o ar bocó do bicho.
	_sphere(root, Vector3(0.15, 0.09, 0.14), Vector3(0.0, -0.055, 0.315), MUZZLE)

	for side in [-1.0, 1.0]:
		# Ventas
		_sphere(root, Vector3(0.045, 0.055, 0.04), Vector3(side * 0.052, 0.02, 0.395),
			NOSTRIL, Vector3.ZERO, 0.45)
		# ------------------------------------------------------------ olhos
		# Bem pro lado da cabeça, como em qualquer herbívoro — olho de frente
		# lê como pessoa fantasiada.
		_sphere(root, Vector3(0.075, 0.085, 0.075), Vector3(side * 0.125, 0.145, 0.115),
			EYE, Vector3.ZERO, 0.18)
		# Brilho: sem ele o olho preto vira buraco (a mesma lição da fachada).
		_sphere(root, Vector3(0.026, 0.026, 0.026),
			Vector3(side * 0.142, 0.175, 0.145), WHITE, Vector3.ZERO, 0.1)
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
	# Faixa escura descendo da testa pela nuca. Vai encolhendo, senão vira uma
	# crista reta de brinquedo.
	var mane_steps := [
		[Vector3(0.055, 0.12, 0.075), Vector3(0.0, 0.275, -0.045), 0.0],
		[Vector3(0.06, 0.13, 0.09), Vector3(0.0, 0.245, -0.105), -18.0],
		[Vector3(0.06, 0.12, 0.09), Vector3(0.0, 0.175, -0.155), -34.0],
		[Vector3(0.055, 0.10, 0.08), Vector3(0.0, 0.09, -0.175), -52.0],
		[Vector3(0.05, 0.08, 0.07), Vector3(0.0, 0.01, -0.175), -66.0],
	]
	for step: Array in mane_steps:
		_sphere(root, step[0], step[1], MANE, Vector3(deg_to_rad(step[2]), 0.0, 0.0), 0.85)

	# Topete caído na testa, entre as orelhas.
	_sphere(root, Vector3(0.10, 0.06, 0.09), Vector3(0.0, 0.275, 0.055), MANE,
		Vector3(deg_to_rad(28.0), 0.0, 0.0), 0.85)

	# ----------------------------------------------------------------- boca
	_box(root, Vector3(0.115, 0.012, 0.055), Vector3(0.0, -0.028, 0.365), FUR_DARK,
		Vector3(deg_to_rad(6.0), 0.0, 0.0))

	return root
