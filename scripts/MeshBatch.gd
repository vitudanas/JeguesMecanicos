class_name MeshBatch
extends RefCounted
## Junta muitas pecas pequenas num UNICO MeshInstance3D, com uma superficie por
## material.
##
## Por que existe: as vitrines de rua sao montadas com primitivas (vidro,
## montante, porta, ripa de toldo, letreiro), e uma loja passa facil de 20 nos.
## Com ~180 lojas na cidade isso foram +700 a +2100 chamadas de desenho por
## quadro — medido comparando o mesmo ponto de vista com e sem as vitrines em
## `tools/verify/quality_shots.gd`. A geometria e barata; o que custa e a
## CHAMADA. Juntando por quarteirao, o desenho e exatamente o mesmo e o numero
## de chamadas cai pra uma por material.
##
## Cuidado ao usar: tudo que entra num lote passa a ser um objeto so pro
## descarte por frustum. Juntar coisas espalhadas pelo mapa inteiro faria a
## caixa do lote cobrir tudo e nada mais seria descartado — por isso a cidade
## junta POR QUARTEIRAO, nao por cidade.

var _surfaces: Dictionary = {}
var _count := 0

## Acrescenta uma malha ja transformada. O material identifica a superficie: os
## materiais de `StreetFurniture` sao cacheados e compartilhados, entao lojas
## diferentes com o mesmo toldo caem na mesma superficie.
func add(mesh: Mesh, material: Material, xform: Transform3D) -> void:
	if mesh == null or material == null:
		return
	var key: int = material.get_instance_id()
	if not _surfaces.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_surfaces[key] = {"st": st, "mat": material}
	for surface in range(mesh.get_surface_count()):
		(_surfaces[key]["st"] as SurfaceTool).append_from(mesh, surface, xform)
	_count += 1

func is_empty() -> bool:
	return _surfaces.is_empty()

func piece_count() -> int:
	return _count

## Constroi o no. Devolve null se nada foi acrescentado — quem chama nao precisa
## checar antes.
func build(node_name := "Lote") -> MeshInstance3D:
	if _surfaces.is_empty():
		return null
	var arr := ArrayMesh.new()
	var mats: Array[Material] = []
	for key: int in _surfaces:
		var st: SurfaceTool = _surfaces[key]["st"]
		# `index()` funde vertices repetidos: as pecas sao caixas, entao os 8
		# cantos aparecem 3 vezes cada antes disso.
		st.index()
		arr = st.commit(arr)
		mats.append(_surfaces[key]["mat"])
	var inst := MeshInstance3D.new()
	inst.name = node_name
	inst.mesh = arr
	for i in range(mats.size()):
		inst.set_surface_override_material(i, mats[i])
	return inst
