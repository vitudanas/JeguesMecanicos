class_name NpcAccessories
extends RefCounted
## Chapeu, bone, gorro, oculos, mochila e sacola pros pedestres da cidade.
##
## POR QUE ISTO EXISTE. Os 84 pedestres saem de dois arquivos de personagem
## (`Female_Dressed` / `Male_Dressed`), com a mesma roupa e o mesmo cabelo.
## Tipo fisico, altura e cor ja variam por NPC desde 2026-08-03, mas isso e
## variacao de VOLUME e de TOM: de 20 m, que e a distancia em que se ve
## pedestre na rua, dois deles continuam sendo a mesma silhueta. O que separa
## uma pessoa da outra de longe e o contorno — chapeu, mochila, sacola.
##
## Montado com primitivas em codigo, e nao baixando um pacote de acessorios,
## pela mesma razao de sempre neste projeto: o mobiliario urbano
## (`StreetFurniture.gd`), as gambiarras (`GambiarraVisual.gd`) e a cabeca de
## jegue (`DonkeyHead.gd`) foram feitos assim. Pacote novo traria estilo novo, e
## mistura de estilo e o problema que este projeto ja corrigiu tres vezes.
##
## Preso num `BoneAttachment3D`, entao acompanha a animacao — pendurar no no do
## personagem faria o chapeu ficar parado no ar enquanto o boneco anda, que foi
## exatamente o bug do cabelo dos NPCs em 2026-08-03.

## Espaco de montagem: a origem do osso `Head`. Medido nos dois modelos, a
## cabeca ocupa dali x +/-0.12, y -0.05..+0.23 e z -0.16..+0.11 — e dessas
## medidas que saem as alturas abaixo, nao de tentativa e erro.
const TOPO_DA_CABECA := 0.23
const RAIO_DA_CABECA := 0.115

## Chance de um pedestre sair sem acessorio nenhum. Rua em que todo mundo usa
## chapeu le tao uniforme quanto rua em que ninguem usa.
const CHANCE_SEM_NADA := 0.34

const COURO := Color(0.36, 0.26, 0.19)
const LONA := Color(0.30, 0.34, 0.40)
const PALHA := Color(0.78, 0.68, 0.44)
const LA := Color(0.58, 0.24, 0.24)
const METAL := Color(0.22, 0.23, 0.25)

static var _cache: Dictionary = {}

static func _material(key: String, color: Color, rough := 0.85) -> StandardMaterial3D:
	var k := "mat_" + key
	if _cache.has(k):
		return _cache[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	_cache[k] = m
	return m

static func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material,
		rot := Vector3.ZERO) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)

static func _cyl(parent: Node3D, radius: float, height: float, pos: Vector3,
		mat: Material, rot := Vector3.ZERO) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)

static func _sphere(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 14
	mesh.rings = 8
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.scale = size
	mi.position = pos
	parent.add_child(mi)

# ------------------------------------------------------------------ pecas

## Bone: copa arredondada mais aba pra frente (+Z e a direcao do rosto).
static func _bone_de_aba() -> Node3D:
	var root := Node3D.new()
	root.name = "Bone"
	var pano := _material("bone", LONA)
	_sphere(root, Vector3(0.25, 0.17, 0.25), Vector3(0.0, TOPO_DA_CABECA - 0.02, 0.0), pano)
	_box(root, Vector3(0.22, 0.018, 0.13), Vector3(0.0, TOPO_DA_CABECA - 0.055, 0.135),
		pano, Vector3(deg_to_rad(-6.0), 0.0, 0.0))
	return root

## Chapeu de palha: aba larga em volta, copa baixa. E a silhueta mais
## reconhecivel de longe, que e o ponto deste arquivo.
static func _chapeu_de_palha() -> Node3D:
	var root := Node3D.new()
	root.name = "ChapeuDePalha"
	var palha := _material("palha", PALHA)
	_cyl(root, 0.235, 0.02, Vector3(0.0, TOPO_DA_CABECA - 0.045, 0.0), palha)
	_cyl(root, 0.125, 0.13, Vector3(0.0, TOPO_DA_CABECA + 0.03, 0.0), palha)
	_cyl(root, 0.128, 0.035, Vector3(0.0, TOPO_DA_CABECA - 0.015, 0.0),
		_material("fita", COURO))
	return root

## Gorro de la, colado no cranio.
static func _gorro() -> Node3D:
	var root := Node3D.new()
	root.name = "Gorro"
	var la := _material("la", LA, 0.95)
	_sphere(root, Vector3(0.255, 0.21, 0.255), Vector3(0.0, TOPO_DA_CABECA - 0.06, 0.0), la)
	_cyl(root, 0.132, 0.05, Vector3(0.0, TOPO_DA_CABECA - 0.12, 0.0), la)
	return root

## Oculos: duas lentes e a ponte. Pequeno de proposito — grande vira fantasia.
static func _oculos() -> Node3D:
	var root := Node3D.new()
	root.name = "Oculos"
	var vidro := _material("lente", Color(0.12, 0.14, 0.18), 0.25)
	var haste := _material("haste", METAL, 0.4)
	for lado in [-1.0, 1.0]:
		_box(root, Vector3(0.052, 0.038, 0.012),
			Vector3(lado * 0.042, 0.085, 0.108), vidro)
		_box(root, Vector3(0.012, 0.008, 0.10),
			Vector3(lado * 0.072, 0.088, 0.05), haste)
	_box(root, Vector3(0.032, 0.008, 0.010), Vector3(0.0, 0.088, 0.108), haste)
	return root

## Mochila: vai nas COSTAS (-Z), presa ao tronco. E o acessorio que mais muda a
## silhueta de perfil.
static func _mochila() -> Node3D:
	var root := Node3D.new()
	root.name = "Mochila"
	var lona := _material("mochila", LONA, 0.9)
	_box(root, Vector3(0.26, 0.34, 0.15), Vector3(0.0, 0.02, -0.16), lona)
	_box(root, Vector3(0.20, 0.11, 0.06), Vector3(0.0, -0.06, -0.245),
		_material("bolso", COURO, 0.9))
	for lado in [-1.0, 1.0]:
		_box(root, Vector3(0.045, 0.30, 0.05), Vector3(lado * 0.10, 0.03, -0.055), lona)
	return root

## Sacola de compras na mao. Presa ao tronco tambem — pendurar no osso da mao
## exigiria pose de mao fechada, que a animacao de caminhada nao tem.
static func _sacola() -> Node3D:
	var root := Node3D.new()
	root.name = "Sacola"
	var papel := _material("sacola", Color(0.72, 0.62, 0.46), 0.95)
	_box(root, Vector3(0.17, 0.22, 0.10), Vector3(0.20, -0.30, 0.06), papel)
	_box(root, Vector3(0.015, 0.09, 0.015), Vector3(0.16, -0.15, 0.06), papel)
	_box(root, Vector3(0.015, 0.09, 0.015), Vector3(0.24, -0.15, 0.06), papel)
	return root

# ------------------------------------------------------------------ sorteio

## Acessorios de CABECA (excludentes entre si — ninguem usa gorro por baixo do
## chapeu) e de TRONCO (podem somar com o de cabeca).
const CABECA := ["nada", "bone", "chapeu", "gorro"]
const TRONCO := ["nada", "nada", "mochila", "sacola"]

## Poe acessorios sorteados num personagem ja instanciado.
##
## Devolve a lista do que foi posto, pra quem chama (e o verificador) poder
## contar combinacoes — sem isso nao da pra provar que a rua ficou variada.
static func apply_random(visual: Node3D, rng: RandomNumberGenerator = null) -> Array[String]:
	var usados: Array[String] = []
	if visual == null:
		return usados
	var skeleton := CharacterVisual.find_skeleton(visual)
	if skeleton == null:
		return usados
	if _rand(rng) < CHANCE_SEM_NADA:
		return usados

	var na_cabeca: String = CABECA[_randi(rng, CABECA.size())]
	if na_cabeca != "nada":
		var peca := _montar(na_cabeca)
		if peca != null and _pendurar(skeleton, "Head", peca):
			usados.append(na_cabeca)
	# Oculos entram a parte: convivem com qualquer chapeu.
	if _rand(rng) < 0.22:
		if _pendurar(skeleton, "Head", _oculos()):
			usados.append("oculos")

	var no_tronco: String = TRONCO[_randi(rng, TRONCO.size())]
	if no_tronco != "nada":
		var peca2 := _montar(no_tronco)
		# Os ossos da coluna se chamam `spine_01..03`, em MINUSCULO com
		# underscore — medido no arquivo. A primeira versao pedia "Chest" e
		# "Spine" (que e como o resto do projeto fala do esqueleto) e
		# `find_bone` devolvia -1: mochila e sacola simplesmente nao apareciam,
		# em silencio, enquanto chapeu e oculos funcionavam. `spine_03` e o mais
		# alto, na altura dos ombros.
		if peca2 != null and (_pendurar(skeleton, "spine_03", peca2)
				or _pendurar(skeleton, "spine_02", peca2)):
			usados.append(no_tronco)
	return usados

static func _montar(nome: String) -> Node3D:
	match nome:
		"bone":
			return _bone_de_aba()
		"chapeu":
			return _chapeu_de_palha()
		"gorro":
			return _gorro()
		"mochila":
			return _mochila()
		"sacola":
			return _sacola()
	return null

static func _pendurar(skeleton: Skeleton3D, osso: String, peca: Node3D) -> bool:
	var idx := skeleton.find_bone(osso)
	if idx < 0:
		peca.queue_free()
		return false
	var attach := BoneAttachment3D.new()
	attach.name = "Acessorio" + peca.name
	skeleton.add_child(attach)
	attach.bone_idx = idx
	attach.add_child(peca)
	return true

## Sorteio: aceita um RNG proprio (pra resultado repetivel) e cai no global
## quando nao vem nenhum — mesmo padrao dos outros espalhadores do projeto.
static func _rand(rng: RandomNumberGenerator) -> float:
	return rng.randf() if rng != null else randf()

static func _randi(rng: RandomNumberGenerator, n: int) -> int:
	return (rng.randi() % n) if rng != null else (randi() % n)
