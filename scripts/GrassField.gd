extends MultiMeshInstance3D
## Grama de GEOMETRIA em volta do jogador.
##
## Por que existe, depois de o chao ja ter textura PBR: textura plana de grama,
## por melhor que seja, le como carpete quando vista da altura dos olhos — foi
## exatamente o que aconteceu (o campo virou campo de golfe). O que da volume a
## um gramado e ter TUFOS de verdade pegando luz e sombra.
##
## Como nao explode o desempenho:
##   - MultiMesh: os N tufos sao UMA chamada de desenho, nao N nos.
##   - So perto: um anel de `radius` metros em volta do jogador. O resto do mapa
##     fica com a textura, que a essa distancia resolve.
##   - O campo INTEIRO nao e reposicionado a cada passo: so quando o jogador
##     anda mais que `refresh_step`, e ai as posicoes sao sorteadas de novo com
##     semente fixa por celula, entao a grama nao "dança" quando ele volta.

## Modelo do tufo. O nature-megakit ja esta no projeto e ja e usado no anel
## rural, entao nao traz estilo novo nem byte novo.
@export var tuft_scene: PackedScene
@export var count := 2600
@export var radius := 38.0
## Distancia andada que dispara um novo sorteio.
@export var refresh_step := 12.0
@export var scale_min := 0.5
@export var scale_max := 1.25
## Dentro da cidade nao nasce grama (mesmo criterio Chebyshev do chao e do anel
## rural: a grade de ruas e quadrada).
@export var city_extent := 128.0
@export var rng_seed := 20260804

var _player: Node3D = null
var _last_center := Vector3(1e9, 0, 1e9)
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	var mesh := _tuft_mesh()
	if mesh == null:
		push_warning("GrassField: sem modelo de tufo, nada foi criado")
		return
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = count
	# A grama nao projeta sombra: sao milhares de tufos, e a sombra deles custa
	# caro e some no gramado mesmo.
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# A caixa de visibilidade e definida em `_scatter`, acompanhando o centro do
	# espalhamento. Fixa em volta da origem do no (primeira versao) ela ficava a
	# centenas de metros dos tufos, e o Godot descartava o campo INTEIRO — a
	# grama simplesmente nao aparecia, sem erro nenhum no log.

func _tuft_mesh() -> Mesh:
	if tuft_scene == null:
		return null
	var inst := tuft_scene.instantiate()
	var found := _first_mesh(inst)
	var mesh: Mesh = found.mesh if found else null
	inst.free()
	return mesh

func _first_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		return n
	for c in n.get_children():
		var r := _first_mesh(c)
		if r:
			return r
	return null

func _process(_delta: float) -> void:
	if multimesh == null:
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D
		if _player == null:
			return
	var here := _player.global_position
	if Vector2(here.x - _last_center.x, here.z - _last_center.z).length() < refresh_step:
		return
	_last_center = here
	_scatter(here)

func _scatter(center: Vector3) -> void:
	# Semente amarrada a CELULA, nao ao tempo: voltando pro mesmo lugar, a grama
	# nasce igual. Sorteando livre, o gramado inteiro trocava de desenho a cada
	# refresh e o movimento aparecia com o canto do olho.
	var cell := Vector2i(int(floor(center.x / refresh_step)), int(floor(center.z / refresh_step)))
	_rng.seed = rng_seed + cell.x * 73856093 + cell.y * 19349663
	for i in range(count):
		var ang := _rng.randf() * TAU
		# sqrt pra densidade uniforme: sem ele a grama se amontoa no centro.
		var dist: float = sqrt(_rng.randf()) * radius
		var p := Vector3(center.x + cos(ang) * dist, 0.0, center.z + sin(ang) * dist)
		var s: float = _rng.randf_range(scale_min, scale_max)
		# Fora da cidade e fora do asfalto. A checagem e barata de proposito: um
		# raio por tufo, 2600 vezes, custaria mais que o campo inteiro.
		if maxf(absf(p.x), absf(p.z)) < city_extent:
			s = 0.0
		var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s, s))
		multimesh.set_instance_transform(i, Transform3D(basis, p))
	# Caixa em volta de ONDE os tufos estao agora, no espaco local do no.
	var local := to_local(center)
	custom_aabb = AABB(
		Vector3(local.x - radius, -3.0, local.z - radius),
		Vector3(radius * 2.0, 10.0, radius * 2.0))
