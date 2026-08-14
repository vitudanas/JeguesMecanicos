extends StaticBody3D
## Corpo estatico generico pra props/predios de asset packs (Kenney):
## instancia a cena visual como filha e gera sozinho uma CollisionShape3D
## (BoxShape3D) do tamanho exato do mesh, sem precisar calcular AABB na
## mao pra cada modelo. Usado pelos predios da cidade (ver Town.tscn).

@export var visual_scene: PackedScene
@export var visual_scale := 1.0
@export var visual_rotation_y_degrees := 0.0
## Acabamento de superficie (ver CitySurface.gd): "concreto", "reboco",
## "tijolo"... Vazio = mantem o material original do modelo.
##
## Opt-in de proposito, em vez de aplicar sozinho em todo modelo do kit: quem
## gera cidade (CityBlocks/CityOutskirts) ja aplica o proprio acabamento com a
## cor sorteada, e aplicar duas vezes seria so desperdicio. Serve pros modelos
## do kit colocados a mao numa cena — a oficina, por exemplo.
@export var surface_kind := ""
@export var surface_tint := Color(0.88, 0.87, 0.84)
## Colisao pela silhueta na altura de trafego, e nao pelo AABB inteiro (ver
## `_footprint`). Serve pra ARVORE, cuja copa larga vira parede invisivel.
##
## Opt-in, e nao automatico, por um efeito colateral medido: ligado num PREDIO, a
## colisao deixa de cobrir a laje do telhado, e os props de cobertura (caixa
## d'agua, ar condicionado) passam a nao ter nada solido embaixo — o verificador
## acusou 9 deles boiando a ate 11,6 m. Quem planta vegetacao liga; quem planta
## construcao, nao.
@export var slim_collision := false

func _ready() -> void:
	if visual_scene == null:
		return
	var visual := visual_scene.instantiate()
	add_child(visual)
	if visual is Node3D:
		visual.scale = Vector3.ONE * visual_scale
		visual.rotation_degrees.y = visual_rotation_y_degrees
	var aabb := _compute_local_aabb(visual, Transform3D.IDENTITY)
	if aabb.size == Vector3.ZERO:
		return
	# A LARGURA sai da silhueta na altura em que se trafega; a ALTURA continua
	# sendo a do modelo inteiro (senao daria pra passar por cima).
	var foot := _footprint(visual, aabb) if slim_collision else Rect2(
		Vector2(aabb.position.x, aabb.position.z), Vector2(aabb.size.x, aabb.size.z))
	var shape := BoxShape3D.new()
	shape.size = Vector3(foot.size.x, aabb.size.y, foot.size.y)
	var coll := CollisionShape3D.new()
	coll.shape = shape
	coll.position = Vector3(foot.get_center().x,
		aabb.position.y + aabb.size.y / 2.0, foot.get_center().y)
	add_child(coll)

	if surface_kind != "":
		CitySurface.apply(visual, surface_tint, surface_kind)

## Faixa de altura, a partir da base do modelo, que decide a LARGURA da colisao.
## Cobre carro (1.0 m) e jogador (1.8 m) com folga.
const BAND_LOW := 0.15
const BAND_HIGH := 2.0
## Piso da largura: tronco fininho ainda tem que dar pra bater.
const MIN_FOOTPRINT := 0.3
## So encolhe quando o modelo e DRASTICAMENTE mais largo em cima do que embaixo
## — que e a arvore (18 m de copa sobre 1,6 m de tronco). Um predio difere ~1,4 m
## por causa de degrau/beiral, e encolher ELE tem efeito colateral: a colisao
## deixa de cobrir a laje, e os props de telhado passam a nao ter nada solido
## embaixo (o verificador de flutuacao acusou 9 malhas boiando a ate 11,6 m).
# 2,2 m: a twisted-tree mede 6,7 m pela copa e 4,1 m na faixa do carro.
# Com 2,5 ela caia exatamente no lado errado do limiar e deixava 2,6 m de ar
# solido. Predios continuam fora porque nao ativam `slim_collision`.
const SHRINK_MIN := 2.2

## Pegada horizontal da malha na faixa de trafego.
##
## Antes a colisao era o AABB inteiro do modelo, e isso e uma PAREDE INVISIVEL
## em qualquer modelo mais largo em cima do que embaixo — arvore, principalmente.
## Medido no mundo real do jogo: 426 corpos com colisao muito mais larga que a
## malha na altura do carro, o pior com **18 m de colisao para um tronco de
## 1,6 m** (16 m de ar solido). Dava pra bater numa arvore a 8 m de distancia
## dela, vendo o caminho livre — foi assim que a estrada de terra ficou com uma
## parede perto da oficina.
##
## Predio nao muda nada: parede e vertical, entao a silhueta na faixa e igual ao
## AABB e o `SHRINK_MIN` deixa como estava. Sem lista de excecao por modelo.
func _footprint(visual: Node, aabb: AABB) -> Rect2:
	var full := Rect2(Vector2(aabb.position.x, aabb.position.z),
		Vector2(aabb.size.x, aabb.size.z))
	var low := aabb.position.y + BAND_LOW
	var high := aabb.position.y + BAND_HIGH
	var min_v := Vector2(INF, INF)
	var max_v := Vector2(-INF, -INF)
	var found := false
	for entry in _mesh_transforms(visual, Transform3D.IDENTITY):
		var mi: MeshInstance3D = entry[0]
		var xf: Transform3D = entry[1]
		for s in range(mi.mesh.get_surface_count()):
			var arrays := mi.mesh.surface_get_arrays(s)
			if arrays.size() <= Mesh.ARRAY_VERTEX:
				continue
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			# Malha densa nao precisa de todo vertice pra dar a largura, e isto
			# roda pra centenas de props no carregamento.
			var step: int = maxi(1, verts.size() / 600)
			for i in range(0, verts.size(), step):
				var w: Vector3 = xf * verts[i]
				if w.y < low or w.y > high:
					continue
				found = true
				min_v.x = minf(min_v.x, w.x)
				min_v.y = minf(min_v.y, w.z)
				max_v.x = maxf(max_v.x, w.x)
				max_v.y = maxf(max_v.y, w.z)
	# Nada na faixa (prop mais baixo que ela, ou suspenso): mantem o AABB, que
	# e o comportamento antigo e continua correto nesses casos.
	if not found:
		return full
	var band := Rect2(min_v, (max_v - min_v).max(Vector2(MIN_FOOTPRINT, MIN_FOOTPRINT)))
	if full.size.x - band.size.x < SHRINK_MIN and full.size.y - band.size.y < SHRINK_MIN:
		return full
	return band

## Cada MeshInstance3D com a transformada acumulada ate ele.
func _mesh_transforms(node: Node, accum: Transform3D, out: Array = []) -> Array:
	var t := accum
	if node is Node3D:
		t = accum * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		out.append([node, t])
	for child in node.get_children():
		_mesh_transforms(child, t, out)
	return out

func _compute_local_aabb(node: Node, accum: Transform3D) -> AABB:
	var t := accum
	if node is Node3D:
		t = accum * node.transform
	var result := AABB()
	var has_result := false
	if node is MeshInstance3D and node.mesh:
		result = t * node.get_aabb()
		has_result = true
	for child in node.get_children():
		var caabb := _compute_local_aabb(child, t)
		if caabb.size != Vector3.ZERO or (caabb.position != Vector3.ZERO and not has_result):
			if not has_result:
				result = caabb
				has_result = true
			else:
				result = result.merge(caabb)
	return result
