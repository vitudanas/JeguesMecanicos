extends Node3D
## Grama de GEOMETRIA em volta do jogador.
##
## Por que existe, depois de o chao ja ter textura PBR: textura plana de grama,
## por melhor que seja, le como carpete quando vista da altura dos olhos — foi
## exatamente o que aconteceu (o campo virou campo de golfe). O que da volume a
## um gramado e ter TUFOS de verdade pegando luz e sombra.
##
## ALTURA EM METROS, NAO EM ESCALA. A primeira versao expunha `scale_min/max`
## sobre um modelo de 1.87 m, entao "escala 1.25" era grama de 2.34 m — mais
## alta que o jogador, e ninguem notou porque o numero na cena nao dizia nada
## sobre tamanho. Aqui se declara a altura desejada e a escala sai da altura
## MEDIDA do modelo.
##
## Como nao explode o desempenho:
##   - MultiMesh: os N tufos de uma camada sao UMA chamada de desenho.
##   - So perto: um anel em volta do jogador. O resto do mapa fica com a
##     textura do chao, que a essa distancia resolve.
##   - O campo so e re-sorteado quando o jogador anda mais que `refresh_step`,
##     e com semente por CELULA, entao voltar pro mesmo lugar da a mesma grama.
##   - O chao e medido numa GRADE grossa de raios (algumas centenas por
##     refresh), nao um raio por tufo: e o que permite a grama acompanhar o
##     relevo e ainda assim nao nascer em cima de laje, calcada ou asfalto.

const GRASS_SHADER := preload("res://shaders/grass.gdshader")

## Camadas, em arrays paralelos (mesmo padrao de `diagonal_starts`/`_ends` em
## CityStreets.gd). Duas camadas dao o que uma so nao da: um tapete baixo e
## denso que fecha o chao, e tufos altos esparsos que quebram a linha.
@export var layer_scenes: Array[PackedScene] = []
@export var layer_counts: Array[int] = []
@export var layer_height_min: Array[float] = []  ## metros
@export var layer_height_max: Array[float] = []  ## metros
@export var layer_radius: Array[float] = []      ## metros

## Distancia andada que dispara um novo sorteio.
@export var refresh_step := 10.0

## Dentro da cidade nao nasce grama (criterio Chebyshev, casando com o formato
## quadrado da grade de ruas — o mesmo do chao e do anel rural).
@export var city_extent := 128.0

## Cores puxadas da paleta do chao (`shaders/ground.gdshader`): a grama de
## geometria e a textura do chao TEM que ser da mesma familia, senao o campo
## fica com um tapete neon por cima de um chao verde-oliva — que era o defeito.
@export var root_color := Color(0.15, 0.22, 0.10)
@export var tip_color := Color(0.38, 0.47, 0.23)
@export var dry_color := Color(0.54, 0.51, 0.30)
@export var wind_strength := 0.16

## Passo da grade de sondagem do chao. Menor = grama acompanha melhor o relevo
## e respeita melhor a borda de uma laje, mas custa mais raio por refresh.
@export var probe_step := 2.5
## Inclinacao maxima onde nasce grama (cosseno da normal): encosta de montanha
## acima disso fica pelada, que e o que acontece no mundo.
@export var max_slope_cos := 0.80

@export var rng_seed := 20260804

## Onde a grama PODE nascer. Qualquer outro corpo (laje da oficina, meio-fio,
## asfalto, predio) barra o tufo por construcao — sem lista de excecao pra
## manter atualizada.
const NATURAL_GROUPS := ["terreno_natural", "mountain"]

var _player: Node3D = null
var _last_center := Vector3(1e9, 0, 1e9)
var _rng := RandomNumberGenerator.new()
var _fields: Array[MultiMeshInstance3D] = []
var _road_rects: Array[Rect2] = []

## Sondagem do chao da rodada atual: altura por celula e se cabe grama ali.
var _probe_y: PackedFloat32Array = PackedFloat32Array()
var _probe_ok: PackedByteArray = PackedByteArray()
var _probe_origin := Vector2.ZERO
var _probe_cols := 0

## Fracao da densidade cheia (0 a 1), vinda do menu de graficos. A grama e o
## sistema mais caro em primitivas por quadro, entao e o primeiro botao que faz
## diferenca numa maquina fraca.
var _density := 1.0

func set_density(value: float) -> void:
	var v: float = clampf(value, 0.0, 1.0)
	if is_equal_approx(v, _density):
		return
	_density = v
	for i in range(_fields.size()):
		_fields[i].multimesh.instance_count = int(_count(i) * _density)
	# Forca o proximo `_process` a re-espalhar: sem isso o campo so muda quando
	# o jogador andar `refresh_step`, e o menu parece nao ter feito nada.
	_last_center = Vector3(1e9, 0, 1e9)

func _ready() -> void:
	add_to_group("grass_field")
	var n: int = layer_scenes.size()
	if n == 0:
		push_warning("GrassField: nenhuma camada configurada, nada foi criado")
		return
	for i in range(n):
		var field := _make_layer(i)
		if field:
			_fields.append(field)
	if _fields.is_empty():
		push_warning("GrassField: nenhuma camada valida")

func _make_layer(i: int) -> MultiMeshInstance3D:
	var scene: PackedScene = layer_scenes[i]
	if scene == null:
		return null
	var inst := scene.instantiate()
	var source := _first_mesh(inst)
	var mesh: Mesh = source.mesh if source else null
	inst.free()
	if mesh == null:
		push_warning("GrassField: camada %d sem malha" % i)
		return null

	# A altura do modelo e MEDIDA, nao chutada: e dela que sai a escala, e
	# tambem e ela que o shader usa pra saber onde e a ponta da folha.
	var model_h: float = maxf(mesh.get_aabb().size.y, 0.001)

	var field := MultiMeshInstance3D.new()
	field.name = "Camada%d" % i
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = _count(i)
	field.multimesh = mm
	# A grama nao projeta sombra: sao dezenas de milhares de tufos, e a sombra
	# deles custa caro e some no proprio gramado.
	field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var mat := ShaderMaterial.new()
	mat.shader = GRASS_SHADER
	mat.set_shader_parameter("model_height", model_h)
	mat.set_shader_parameter("root_color", root_color)
	mat.set_shader_parameter("tip_color", tip_color)
	mat.set_shader_parameter("dry_color", dry_color)
	mat.set_shader_parameter("wind_strength", wind_strength)
	var r := _radius(i)
	# O tufo encolhe ate sumir no ultimo terco do anel, em vez de piscar na
	# borda. Comeca antes do raio, senao nao sobra distancia pra encolher.
	mat.set_shader_parameter("fade_start", r * 0.70)
	mat.set_shader_parameter("fade_end", r)
	field.material_override = mat
	add_child(field)
	field.set_meta("model_height", model_h)
	return field

func _count(i: int) -> int:
	return layer_counts[i] if i < layer_counts.size() else 4000

func _radius(i: int) -> float:
	return layer_radius[i] if i < layer_radius.size() else 28.0

func _height_range(i: int) -> Vector2:
	var lo: float = layer_height_min[i] if i < layer_height_min.size() else 0.22
	var hi: float = layer_height_max[i] if i < layer_height_max.size() else 0.45
	return Vector2(lo, maxf(hi, lo))

func _first_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		return n
	for c in n.get_children():
		var r := _first_mesh(c)
		if r:
			return r
	return null

func _process(_delta: float) -> void:
	if _fields.is_empty():
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D
		if _player == null:
			return
		_collect_roads()
	var here := _player.global_position
	if Vector2(here.x - _last_center.x, here.z - _last_center.z).length() < refresh_step:
		return
	_last_center = here
	_probe_ground(here)
	for i in range(_fields.size()):
		_scatter(i, here)

## A estrada de terra nao tem colisao de proposito (ver DirtRoad.gd), entao a
## sondagem por raio nao a enxerga — a grama nasceria no meio dela. Os trechos
## sao lidos do proprio no, e nao copiados como numero magico aqui.
func _collect_roads() -> void:
	_road_rects.clear()
	for node in get_tree().get_nodes_in_group("dirt_road"):
		var pts: Array = node.get("points")
		var w: float = float(node.get("width")) * 0.5 + 0.6
		if pts == null or pts.size() < 2:
			continue
		var base := Vector2(node.global_position.x, node.global_position.z)
		for i in range(pts.size() - 1):
			var a: Vector2 = base + pts[i]
			var b: Vector2 = base + pts[i + 1]
			var r := Rect2(a, Vector2.ZERO).expand(b).grow(w)
			_road_rects.append(r)

func _on_road(p: Vector2) -> bool:
	for r in _road_rects:
		if r.has_point(p):
			return true
	return false

## Mede o chao numa grade grossa: altura e se a grama pode nascer ali. Um raio
## por TUFO seria dezenas de milhares por refresh; por celula sao algumas
## centenas, e a resolucao ainda e fina o bastante pra a grama parar na borda
## de uma laje.
func _probe_ground(center: Vector3) -> void:
	var reach := 0.0
	for i in range(_fields.size()):
		reach = maxf(reach, _radius(i))
	_probe_cols = int(ceil(reach * 2.0 / probe_step)) + 1
	_probe_origin = Vector2(center.x - reach, center.z - reach)
	var total := _probe_cols * _probe_cols
	_probe_y.resize(total)
	_probe_ok.resize(total)

	var space := get_world_3d().direct_space_state
	for gz in range(_probe_cols):
		for gx in range(_probe_cols):
			var wx := _probe_origin.x + gx * probe_step
			var wz := _probe_origin.y + gz * probe_step
			var q := PhysicsRayQueryParameters3D.create(
				Vector3(wx, center.y + 60.0, wz), Vector3(wx, center.y - 120.0, wz))
			var hit := space.intersect_ray(q)
			var idx := gz * _probe_cols + gx
			if hit.is_empty():
				_probe_y[idx] = 0.0
				_probe_ok[idx] = 0
				continue
			_probe_y[idx] = float(hit["position"].y)
			var nrm: Vector3 = hit["normal"]
			var body: Node = hit["collider"]
			var natural := false
			for g in NATURAL_GROUPS:
				if body.is_in_group(g):
					natural = true
					break
			_probe_ok[idx] = 1 if (natural and nrm.y >= max_slope_cos) else 0

## Altura do chao na posicao, ou INF se ali nao cabe grama. A celula so vale se
## ela E as 3 vizinhas do quadrado couberem: com uma so, a grama avanca meio
## passo por cima da borda da laje e fica com o tufo saindo do concreto.
func _ground_at(p: Vector2) -> float:
	var fx := (p.x - _probe_origin.x) / probe_step
	var fz := (p.y - _probe_origin.y) / probe_step
	var gx := int(floor(fx))
	var gz := int(floor(fz))
	if gx < 0 or gz < 0 or gx + 1 >= _probe_cols or gz + 1 >= _probe_cols:
		return INF
	var y := -INF
	for dz: int in [0, 1]:
		for dx: int in [0, 1]:
			var idx: int = (gz + dz) * _probe_cols + (gx + dx)
			if _probe_ok[idx] == 0:
				return INF
			y = maxf(y, _probe_y[idx])
	return y

func _scatter(layer: int, center: Vector3) -> void:
	var field := _fields[layer]
	var mm := field.multimesh
	var radius := _radius(layer)
	var hr := _height_range(layer)
	var model_h: float = field.get_meta("model_height")
	# `instance_count` (nao o `count` configurado): e ele que o menu de graficos
	# reduz, e espalhar alem dele estouraria o MultiMesh.
	var count: int = mm.instance_count

	# Semente amarrada a CELULA, nao ao tempo: voltando pro mesmo lugar, a grama
	# nasce igual. Sorteando livre, o gramado inteiro trocava de desenho a cada
	# refresh e o movimento aparecia com o canto do olho.
	var cell := Vector2i(int(floor(center.x / refresh_step)), int(floor(center.z / refresh_step)))
	_rng.seed = rng_seed + layer * 7919 + cell.x * 73856093 + cell.y * 19349663

	for i in range(count):
		# Tufos em MOLHO, nao um a um: grama de verdade cresce em moita, e
		# posicao puramente uniforme le como chuvisco regular. A cada poucos
		# tufos sorteia um novo centro de moita e o resto cai em volta dele.
		var ang := _rng.randf() * TAU
		# Com `dist = u^p * R`, a densidade por AREA fica proporcional a
		# `d^(1/p - 2)`: p = 0.5 e densidade uniforme, e so acima disso ela
		# cresce perto do jogador. A primeira versao usava 0.40, que da
		# `d^+0.5` — ou seja, o oposto do que eu queria, e o primeiro plano
		# (onde o tufo mais aparece) saia pelado.
		var dist: float = pow(_rng.randf(), 0.80) * radius
		var p := Vector2(center.x + cos(ang) * dist, center.z + sin(ang) * dist)
		var clump := _rng.randf_range(0.0, 0.9)
		p += Vector2(cos(ang * 3.1 + i), sin(ang * 5.7 + i)) * clump

		var s := 0.0
		var y := 0.0
		if maxf(absf(p.x), absf(p.y)) >= city_extent and not _on_road(p):
			var g := _ground_at(p)
			if g != INF:
				y = g
				# Altura sorteada em METROS e convertida pela altura medida do
				# modelo: e o que garante que "0.45" na cena seja 45 cm na tela.
				s = _rng.randf_range(hr.x, hr.y) / model_h

		var basis := Basis(Vector3.UP, _rng.randf() * TAU)
		if s > 0.0:
			# Um pouco mais largo que alto ou vice-versa: tufo clonado com a
			# mesma proporcao N mil vezes fica com cara de carimbo.
			basis = basis.scaled(Vector3(s * _rng.randf_range(0.85, 1.2), s,
				s * _rng.randf_range(0.85, 1.2)))
			# Tomba de leve: tufo perfeitamente em pe le como poste.
			basis = Basis(Vector3.RIGHT, _rng.randf_range(-0.14, 0.14)) * basis
		else:
			basis = basis.scaled(Vector3.ZERO)
		mm.set_instance_transform(i, Transform3D(basis, Vector3(p.x, y, p.y)))

	# Caixa em volta de ONDE os tufos estao agora, no espaco local do no. Fixa
	# em volta da origem do no (primeira versao) ela ficava a centenas de metros
	# dos tufos e o Godot descartava o campo INTEIRO — a grama simplesmente nao
	# aparecia, sem erro nenhum no log.
	var local := to_local(center)
	field.custom_aabb = AABB(
		Vector3(local.x - radius, -3.0, local.z - radius),
		Vector3(radius * 2.0, 12.0, radius * 2.0))
