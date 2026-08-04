extends Node
## ESCALA e COISA FLUTUANDO.
##
## Duas perguntas que nenhum teste anterior fazia:
##   1. os tamanhos batem com a realidade? (pessoa 1,80 m, carro 4,2 m, andar
##      de predio ~3 m, montanha bem maior que o predio mais alto)
##   2. tem coisa boiando no ar ou enterrada no chao?
##
## O item 2 e medido, nao olhado: pra cada malha do mundo, pega a base da caixa
## dela e joga um raio pra baixo ate bater em algo solido. Sobra = flutuando.
##
##   godot --headless --path . tools/verify/scale_test.tscn

## Referencias do mundo real, em metros.
const REAL := {
	"pessoa": 1.75,
	"carro": 4.30,
	"andar de predio": 3.0,
	"poste": 8.0,
	"casa terrea+1": 7.0,
}
## Sobra tolerada entre a base de uma malha e o que estiver embaixo.
const FLOAT_TOL := 0.40
## Quanto pode estar enterrado.
const SINK_TOL := 0.60

var problems: Array[String] = []
var main: Node
var space: PhysicsDirectSpaceState3D

func fail(msg: String) -> void:
	problems.append(msg)
	print("    FALHOU: " + msg)

func _ready() -> void:
	main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().physics_frame
	for i in range(90):
		await get_tree().physics_frame
	space = get_viewport().world_3d.direct_space_state
	await _run()
	print("\n=== RESULTADO ===")
	if problems.is_empty():
		print("escala coerente e nada flutuando")
	else:
		print("%d problema(s):" % problems.size())
		for p in problems:
			print("  - " + p)
	get_tree().quit(0 if problems.is_empty() else 1)

# ------------------------------------------------------------------- medidas

## Caixa da malha no espaco do MUNDO.
func _world_aabb(mi: VisualInstance3D) -> AABB:
	var local := mi.get_aabb()
	var xf := mi.global_transform
	var box := AABB(xf * local.position, Vector3.ZERO)
	for i in range(1, 8):
		box = box.expand(xf * (local.position + local.size * _corner(i)))
	return box

func _corner(i: int) -> Vector3:
	return Vector3(float(i & 1), float((i >> 1) & 1), float((i >> 2) & 1))

func _all_meshes(n: Node, out: Array[MeshInstance3D]) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null and (n as MeshInstance3D).visible:
		out.append(n)
	for c in n.get_children():
		_all_meshes(c, out)

## Nome da "familia" — o ancestral logo abaixo do Town. Sem isso o relatorio
## vira uma lista de `@Node3D@417` que nao diz nada sobre onde olhar.
func _family(n: Node, town: Node) -> String:
	var cur := n
	while cur != null and cur.get_parent() != town:
		cur = cur.get_parent()
		if cur == null:
			return "?"
	return String(cur.name) if cur else "?"

## Um "objeto colocado" e um filho direto de um gerador (CityBlocks, CityStreets,
## RuralScatter, fazenda, rota...) ou de um nivel a mais quando esse gerador so
## agrupa. E a unidade que faz sentido perguntar "isso esta no chao?".
func _placed_objects(town: Node) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for fam in town.get_children():
		var fam_name := String(fam.name)
		if fam_name in ["Ground", "RainFX", "MountainRange", "Environment",
				"DirectionalLight3D", "WorldEnvironment"]:
			continue
		# Nas rotas, o filho e um PathFollow3D e o agente vem embaixo dele — a
		# caixa combinada do PathFollow3D ja e a do agente, entao serve igual.
		for child in fam.get_children():
			if child is Node3D:
				out.append(child)
	return out

func _collect_rids(n: Node, out: Array[RID]) -> void:
	if n is CollisionObject3D:
		out.append((n as CollisionObject3D).get_rid())
	for c in n.get_children():
		_collect_rids(c, out)

func _run() -> void:
	var town := main.get_node("Town")
	print("=== ESCALA E FLUTUACAO ===\n")

	# ------------------------------------------------------- 1. referencias
	print("[1] referencias vivas do mundo")
	var player := get_tree().get_first_node_in_group("player")
	var ped_h := 0.0
	for p in get_tree().get_nodes_in_group("pedestrian"):
		var boxes: Array[MeshInstance3D] = []
		_all_meshes(p, boxes)
		for m in boxes:
			ped_h = maxf(ped_h, _world_aabb(m).size.y)
		if ped_h > 0.0:
			break
	var car_len := 0.0
	for v in get_tree().get_nodes_in_group("vehicle"):
		if v.rig:
			car_len = maxf(car_len, v.rig.body_aabb.size.z)
	print("    pedestre: %.2f m (real ~%.2f)" % [ped_h, REAL["pessoa"]])
	print("    carro:    %.2f m (real ~%.2f)" % [car_len, REAL["carro"]])
	if player:
		print("    jogador:  capsula de 1.80 m")

	# ---------------------------------------------- 2. altura das construcoes
	print("\n[2] altura das construcoes (andar de verdade tem ~3 m)")
	var by_family: Dictionary = {}
	var meshes: Array[MeshInstance3D] = []
	_all_meshes(town, meshes)
	print("    %d malhas visiveis no mundo" % meshes.size())
	for fam: String in ["CityBlocks", "CityOutskirts", "Workshop", "MountainRange",
			"Farm1", "Farm2", "Farm3", "Farm4", "Farm5",
			"Scrapyard1", "Scrapyard2", "Scrapyard3", "Junkyard", "NatureScatter"]:
		var node := town.get_node_or_null(fam)
		if node == null:
			continue
		var hs: Array[float] = []
		for child in node.get_children():
			var sub: Array[MeshInstance3D] = []
			_all_meshes(child, sub)
			var box := AABB()
			var first := true
			for m in sub:
				if first:
					box = _world_aabb(m)
					first = false
				else:
					box = box.merge(_world_aabb(m))
			if not first and box.size.y > 0.5:
				hs.append(box.size.y)
		if hs.is_empty():
			continue
		hs.sort()
		var total := 0.0
		for v in hs:
			total += v
		by_family[fam] = hs
		print("    %-14s n=%3d | min %5.1f | mediana %5.1f | media %5.1f | max %6.1f m" % [
			fam, hs.size(), hs[0], hs[hs.size() / 2], total / float(hs.size()), hs[-1]])

	# A montanha tem que ser MUITO maior que o predio mais alto, senao o anel
	# vira morrinho e o mapa perde a escala.
	if by_family.has("CityBlocks") and by_family.has("MountainRange"):
		var tallest: float = (by_family["CityBlocks"] as Array)[-1]
		var peak: float = (by_family["MountainRange"] as Array)[-1]
		print("    predio mais alto %.1f m | pico mais alto %.1f m | razao %.1fx" % [
			tallest, peak, peak / maxf(tallest, 0.01)])
		if peak < tallest * 3.0:
			fail("montanha so %.1fx o predio mais alto: nao le como montanha" % (peak / tallest))

	# ------------------------------------------------------- 3. flutuando
	# Por OBJETO INTEIRO, nao por malha solta. Medindo malha a malha, a
	# luminaria no alto do poste, o cabelo do pedestre e o telhado de um predio
	# aparecem todos como "flutuando" — eles estao presos a algo acima do chao.
	# O que interessa e a base do objeto como um todo.
	print("\n[3] o que esta boiando no ar (por objeto inteiro)")
	var floating: Array = []
	var checked := 0
	var suspended := 0
	for obj in _placed_objects(town):
		# Coisa que fica no ar de proposito, apoiada em outra estrutura (a
		# cobertura do posto sobre os pilares). Marcada na fonte, nao adivinhada
		# aqui — afrouxar o limiar pra calar esses casos esconderia flutuacao de
		# verdade.
		if obj.is_in_group("suspenso"):
			suspended += 1
			continue
		var sub: Array[MeshInstance3D] = []
		_all_meshes(obj, sub)
		if sub.is_empty():
			continue
		var box := _world_aabb(sub[0])
		for i in range(1, sub.size()):
			box = box.merge(_world_aabb(sub[i]))
		if box.size.y > 60.0 or box.size.x > 300.0 or box.size.y < 0.12:
			continue
		checked += 1
		var from := Vector3(box.position.x + box.size.x * 0.5, box.position.y + 0.05,
			box.position.z + box.size.z * 0.5)
		var q := PhysicsRayQueryParameters3D.create(from, from - Vector3(0, 60.0, 0))
		# Sem isto o teste MENTE: o Godot ignora a forma em que o raio nasce
		# dentro, entao um prop pousado na laje (que fica abaixo do topo da caixa
		# de colisao do predio) tinha o raio atravessando o predio inteiro e
		# batendo no chao — 84 props apareceram como "boiando a 33 m" estando
		# exatamente onde deveriam.
		q.hit_from_inside = true
		# O proprio objeto fica de fora: senao o raio bate na colisao dele mesmo
		# e a sobra da sempre zero.
		var rids: Array[RID] = []
		_collect_rids(obj, rids)
		q.exclude = rids
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			continue
		var gap: float = from.y - float(hit["position"].y) - 0.05
		if gap > FLOAT_TOL:
			var who := String((hit["collider"] as Node).name)
			var wp := (hit["collider"] as Node).get_parent()
			if wp:
				who = "%s/%s" % [String(wp.name), who]
			floating.append({"fam": _family(obj, town), "node": String(obj.name),
				"gap": gap, "pos": from, "hit": who})
	print("    %d objetos conferidos | %d suspensos de proposito | %d boiando acima de %.2f m" % [
		checked, suspended, floating.size(), FLOAT_TOL])
	floating.sort_custom(func(a, b): return a["gap"] > b["gap"])
	var per_family: Dictionary = {}
	for f in floating:
		per_family[f["fam"]] = int(per_family.get(f["fam"], 0)) + 1
	for fam: String in per_family:
		print("      %-18s %d" % [fam, per_family[fam]])
	for i in range(mini(12, floating.size())):
		var f = floating[i]
		print("      %6.2f m no ar | %s / %s em (%.0f, %.0f, %.0f) | raio bateu em %s" % [
			f["gap"], f["fam"], f["node"], f["pos"].x, f["pos"].y, f["pos"].z, f["hit"]])
	if floating.size() > 0:
		fail("%d malhas flutuando (a pior a %.1f m do chao)" % [
			floating.size(), floating[0]["gap"]])
