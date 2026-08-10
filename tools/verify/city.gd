extends Node
## Verificador da cidade: instancia o Town.tscn DE VERDADE e confere a
## geometria gerada contra a grade de ruas, em vez de confiar no que o codigo
## pretendia fazer. Le os parametros direto dos nos (streets_x, tile_size,
## road_half_width...), entao continua valendo depois de mexer na escala.
##
## Confere:
##  1. censo (predios, tiles de rua por tipo, mobiliario, casas de entrega)
##  2. continuidade da malha viaria (vao/sobreposicao entre tiles vizinhos)
##  3. predio invadindo o corredor da rua
##  4. predio dentro de predio
##  5. rota de trafego/pedestre cortando construcao
##  6. rota de trafego sobre o asfalto e pedestre sobre a calcada
##  7. entrega: NPC na calcada e zona do carro na pista
##  8. spawn de evento livre, quarteirao vazio, buraco/poca sobre o asfalto
##  9. anel rural: pe da montanha x cinturao x clusters x natureza x chao
## 10. alturas: carro de IA no asfalto, pedestre na calcada

var problems: Array[String] = []
var town: Node3D

func fail(msg: String) -> void:
	problems.append(msg)

func _ready() -> void:
	town = (load("res://scenes/world/Town.tscn") as PackedScene).instantiate()
	add_child(town)
	await get_tree().process_frame
	_run()

func _run() -> void:
	var streets_node := town.get_node("CityStreets")
	var blocks_node := town.get_node("CityBlocks")
	var streets_x: Array = streets_node.streets_x
	var streets_z: Array = streets_node.streets_z
	var tile: float = streets_node.tile_size
	var half_road: float = streets_node.road_half_width
	var sidewalk: float = streets_node.sidewalk_width
	var clearance: float = blocks_node.road_clearance
	# Grade NAO uniforme: o relatorio mostra a faixa, e nao um numero so.
	var gaps: Array[float] = []
	for i in range(streets_x.size() - 1):
		gaps.append(float(streets_x[i + 1]) - float(streets_x[i]))
	gaps.sort()
	var spacing: float = gaps[gaps.size() / 2]

	print("=== PARAMETROS ===")
	print("ruas: %d x %d | espacamento %.2f (= %.2f tiles de %.2f) | extent %.2f" % [
		streets_z.size(), streets_x.size(), spacing, spacing / tile, tile, streets_node.extent])
	print("pista +-%.2f | calcada %.2f | fachada a %.2f | building_scale %.2f" % [
		half_road, sidewalk, clearance, blocks_node.building_scale])
	print("quarteiroes %dx%d | miolo %.2fm | asfalto em y=%.2f | calcada em y=%.2f" % [
		streets_z.size() - 1, streets_x.size() - 1, spacing - 2.0 * clearance,
		streets_node.road_surface_y, streets_node.curb_height])

	_census(streets_x)
	_road_continuity(streets_node, streets_x, streets_z, tile)
	_buildings_vs_roads(streets_x, streets_z, half_road, sidewalk)
	_buildings_vs_buildings()
	_routes(streets_x, streets_z, half_road, clearance)
	_delivery(streets_x, streets_z, half_road, clearance)
	_event_spawns()
	_blocks(streets_x, streets_z, spacing)
	_hazards(streets_x, streets_z, half_road)
	_heights(streets_node)
	_rural()

	print("\n=== RESULTADO ===")
	if problems.is_empty():
		print("nenhum problema encontrado")
	else:
		print("%d problema(s):" % problems.size())
		var shown := 0
		for p in problems:
			print("  - " + p)
			shown += 1
			if shown >= 40:
				print("  ... (+%d)" % (problems.size() - shown))
				break
	get_tree().quit(0 if problems.is_empty() else 1)

# ---------------------------------------------------------------- utilitarios

## Caixa real da construcao: a CollisionShape3D que AutoCollisionBody gerou
## (nao uma estimativa), como Rect2 no plano XZ em coordenadas de mundo.
## Pegada da caixa de colisao NO MUNDO.
##
## A caixa pode estar GIRADA, e isso nao e detalhe: o predio do kit poe a rotacao
## no visual e deixa o corpo alinhado aos eixos, mas o predio gerado gira o
## proprio corpo. Lendo `size.x`/`size.z` cru, um lote virado 90 graus vem com
## largura e profundidade TROCADAS — e uma fileira perfeitamente alinhada aparece
## invadindo a rua e atravessando o vizinho (foi o que este verificador acusou na
## primeira rodada do gerador: 10 invasoes e 40 sobreposicoes, todas falsas).
## Alinhado aos eixos o resultado e identico ao de antes.
func _body_rect(body: Node3D) -> Rect2:
	for child in body.get_children():
		if child is CollisionShape3D and (child as CollisionShape3D).shape is BoxShape3D:
			var cs := child as CollisionShape3D
			var e: Vector3 = ((cs.shape as BoxShape3D).size) * 0.5
			var b := cs.global_transform.basis
			var ex: float = absf(b.x.x) * e.x + absf(b.y.x) * e.y + absf(b.z.x) * e.z
			var ez: float = absf(b.x.z) * e.x + absf(b.y.z) * e.y + absf(b.z.z) * e.z
			var c: Vector3 = cs.global_position
			return Rect2(c.x - ex, c.z - ez, ex * 2.0, ez * 2.0)
	return Rect2()

func _body_height(body: Node3D) -> float:
	for child in body.get_children():
		if child is CollisionShape3D and (child as CollisionShape3D).shape is BoxShape3D:
			return ((child as CollisionShape3D).shape as BoxShape3D).size.y
	return 0.0

func _city_buildings() -> Array:
	return get_tree().get_nodes_in_group("city_building")

## Altura (em mundo) do plano horizontal com mais vertices — a pista do tile.
func _modal_height(node: Node) -> float:
	var histogram := {}
	_collect_heights(node, histogram)
	var best := 0.0
	var best_count := -1
	for y: float in histogram:
		if int(histogram[y]) > best_count:
			best_count = histogram[y]
			best = y
	return best

func _collect_heights(node: Node, histogram: Dictionary) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		var mesh: Mesh = (node as MeshInstance3D).mesh
		var xform: Transform3D = (node as MeshInstance3D).global_transform
		for s in range(mesh.get_surface_count()):
			var verts: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			for v in verts:
				var y := snappedf((xform * v).y, 0.01)
				histogram[y] = int(histogram.get(y, 0)) + 1
	for child in node.get_children():
		_collect_heights(child, histogram)

## AABB de mundo das malhas de um no.
func _mesh_aabb(node: Node, accum: Transform3D) -> AABB:
	var t := accum
	var result := AABB()
	var has := false
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		result = (node as MeshInstance3D).global_transform * (node as MeshInstance3D).get_aabb()
		has = true
	for child in node.get_children():
		var c := _mesh_aabb(child, t)
		if c.size != Vector3.ZERO:
			if not has:
				result = c
				has = true
			else:
				result = result.merge(c)
	return result

func _seg_rect_hit(a: Vector2, b: Vector2, r: Rect2) -> bool:
	var steps := int(maxf(a.distance_to(b) / 0.5, 1.0))
	for i in range(steps + 1):
		if r.has_point(a.lerp(b, float(i) / steps)):
			return true
	return false

# ------------------------------------------------------------------- 1. censo

func _census(streets_x: Array) -> void:
	print("\n=== CENSO ===")
	var buildings := _city_buildings()
	var tallest := 0.0
	var hsum := 0.0
	var area := 0.0
	for b in buildings:
		var h := _body_height(b)
		tallest = maxf(tallest, h)
		hsum += h
		var r := _body_rect(b)
		area += r.size.x * r.size.y
	print("predios: %d | altura media %.1fm | mais alto %.1fm" % [
		buildings.size(), hsum / maxf(buildings.size(), 1), tallest])

	# Quanto da cidade sai do gerador (ver BuildingFactory/CityBlocks). Contagem
	# ZERO com a taxa ligada e falha dura, e nao um numero curioso no relatorio:
	# ja aconteceu de um gerador inteiro nao rodar (id de recurso colidindo, em
	# 2026-08-09) e o verificador seguir dizendo "nenhum problema".
	var blocos := town.get_node("CityBlocks")
	var gerados := get_tree().get_nodes_in_group("predio_gerado").size()
	var realistas := 0
	for b in buildings:
		if b.has_method("get") and str(b.get("visual_scene")).contains("realistas_prontos"):
			realistas += 1
	var taxa: float = blocos.get("generated_ratio")
	var so_realista: bool = bool(blocos.get("usar_realistas"))
	print("gerados: %d | realistas: %d | do kit: %d | de %d" % [
		gerados, realistas, buildings.size() - gerados - realistas, buildings.size()])

	# Contagem ZERO no gerador ligado e falha dura, e nao um numero curioso no
	# relatorio: ja aconteceu de um gerador inteiro nao rodar (id de recurso
	# colidindo, 2026-08-09) e o verificador seguir dizendo "nenhum problema".
	if so_realista:
		# Cidade realista: o gerador de geometria fica desligado de proposito, e
		# quem tem que existir sao os modelos fatiados.
		if realistas == 0:
			fail("a cidade e realista mas nenhum predio veio de realistas_prontos")
		if gerados > 0:
			fail("%d predio(s) gerados numa cidade que devia ser so realista" % gerados)
	else:
		if taxa > 0.0 and gerados == 0:
			fail("taxa de geracao e %.2f mas nenhum predio gerado existe na cidade" % taxa)
		if taxa < 1.0 and gerados == buildings.size() and buildings.size() > 0:
			fail("taxa de geracao e %.2f mas TODO predio saiu do gerador" % taxa)

	var span: float = float(streets_x[streets_x.size() - 1]) - float(streets_x[0])
	print("ocupacao: %.0f m2 em %.0f m2 = %.0f%%" % [area, span * span, 100.0 * area / (span * span)])

	# Conta por GRUPO quando o asfalto e gerado, e por caminho de cena quando sao
	# os tiles do kit. Peca gerada nao tem `scene_file_path`, entao contar so por
	# caminho devolvia ZERO em tudo — e o verificador acusava "algum gerador nao
	# rodou" numa cidade cuja rua estava inteira na tela.
	var tiles := {"straight": 0, "crossroad": 0, "crossing": 0, "end": 0, "light": 0}
	var por_grupo := {"straight": "via_reta", "crossroad": "via_cruzamento",
		"crossing": "via_faixa"}
	for key: String in por_grupo:
		tiles[key] = get_tree().get_nodes_in_group(por_grupo[key]).size()
	for child in town.get_node("CityStreets").get_children():
		var path: String = child.scene_file_path
		for key: String in ["straight", "crossroad", "crossing", "end"]:
			if path.contains("road-" + key):
				tiles[key] += 1
		if path.contains("light-"):
			tiles["light"] += 1
	print("tiles de rua: %s" % [tiles])
	var furniture := get_tree().get_nodes_in_group("street_furniture").size()
	var houses := get_tree().get_nodes_in_group("delivery_house").size()
	print("mobiliario: %d | props de telhado: %d | casas de entrega: %d" % [
		furniture, get_tree().get_nodes_in_group("rooftop_prop").size(), houses])
	print("cinturao: %d | natureza: %d | montanhas: %d" % [
		town.get_node("CityOutskirts").get_child_count(),
		town.get_node("NatureScatter").get_child_count(),
		town.get_node("MountainRange").get_child_count()])

	# Contagem zero e sintoma de gerador que nao rodou (ja aconteceu: um erro
	# de parse zerou a cordilheira e a verificacao passou calada).
	for pair: Array in [["predios", buildings.size()], ["tiles retos", tiles["straight"]],
			["faixas de pedestre", tiles["crossing"]], ["casas de entrega", houses],
			["mobiliario urbano", furniture]]:
		if int(pair[1]) == 0:
			fail("ZERO %s — algum gerador nao rodou" % pair[0])

# ------------------------------------------- 2. continuidade da malha viaria

func _road_continuity(streets_node: Node, streets_x: Array, streets_z: Array, tile: float) -> void:
	var lanes := {}
	for child in streets_node.get_children():
		var path: String = child.scene_file_path
		# Kit: pelo caminho da cena. Gerado: por grupo — peca gerada nao tem
		# caminho, e sem este ramo a checagem media ZERO faixa e passava calada.
		var e_via := path.contains("road-straight") or path.contains("road-crossroad") \
			or path.contains("road-crossing") or path.contains("road-end") \
			or child.is_in_group("via_reta") or child.is_in_group("via_cruzamento")
		if not e_via:
			continue
		var p: Vector3 = child.position
		for z in streets_x:
			if absf(p.z - float(z)) < 0.01:
				lanes.get_or_add("z%.2f" % float(z), []).append(p.x)
		for x in streets_z:
			if absf(p.x - float(x)) < 0.01:
				lanes.get_or_add("x%.2f" % float(x), []).append(p.z)

	var gaps := 0
	var overlaps := 0
	for key: String in lanes:
		var vals: Array = lanes[key]
		vals.sort()
		for i in range(1, vals.size()):
			var d: float = float(vals[i]) - float(vals[i - 1])
			if d < 0.01:
				continue
			if d > tile + 0.02:
				gaps += 1
				if gaps <= 4:
					fail("VAO na rua %s entre %.2f e %.2f (%.2f, esperado %.2f)" % [
						key, vals[i - 1], vals[i], d, tile])
			elif d < tile - 0.02:
				overlaps += 1
				if overlaps <= 4:
					fail("SOBREPOSICAO na rua %s em %.2f (%.2f)" % [key, vals[i], d])
	print("\nmalha viaria: %d faixas, %d vaos, %d sobreposicoes" % [lanes.size(), gaps, overlaps])

# ------------------------------------------------- 3. predio invadindo a rua

func _buildings_vs_roads(streets_x: Array, streets_z: Array, half_road: float,
		sidewalk: float) -> void:
	var corridor := half_road + sidewalk
	var bad := 0
	for b in _city_buildings():
		var r := _body_rect(b)
		for z in streets_x:
			if r.position.y < float(z) + corridor and r.end.y > float(z) - corridor:
				bad += 1
				if bad <= 6:
					fail("predio em (%.1f, %.1f) invade a rua z=%.1f" % [
						r.get_center().x, r.get_center().y, float(z)])
				break
		for x in streets_z:
			if r.position.x < float(x) + corridor and r.end.x > float(x) - corridor:
				bad += 1
				if bad <= 6:
					fail("predio em (%.1f, %.1f) invade a rua x=%.1f" % [
						r.get_center().x, r.get_center().y, float(x)])
				break
	print("predio x rua: %d invasoes" % bad)

# --------------------------------------------------- 4. predio dentro de predio

func _buildings_vs_buildings() -> void:
	var rects: Array[Rect2] = []
	for b in _city_buildings():
		rects.append(_body_rect(b))
	var bad := 0
	for i in range(rects.size()):
		for j in range(i + 1, rects.size()):
			var inter := rects[i].intersection(rects[j])
			# Encostar e o objetivo (fileira de fachadas); atravessar nao.
			if inter.size.x > 0.3 and inter.size.y > 0.3:
				bad += 1
				if bad <= 6:
					fail("predios se atravessam em (%.1f, %.1f), sobra %.2f x %.2f" % [
						inter.get_center().x, inter.get_center().y, inter.size.x, inter.size.y])
	print("predio x predio: %d sobreposicoes" % bad)

# ------------------------------------------------------------------ 5/6. rotas

func _routes(streets_x: Array, streets_z: Array, half_road: float, clearance: float) -> void:
	var rects: Array[Rect2] = []
	for b in _city_buildings():
		rects.append(_body_rect(b))
	for b in town.get_node("CityOutskirts").get_children():
		if b is StaticBody3D:
			rects.append(_body_rect(b))

	var hits := 0
	var off_road := 0
	for child in town.get_children():
		var pts = child.get("route_points")
		if pts == null or (pts as Array).is_empty():
			continue
		var is_ped: bool = child.get("pedestrian_count") != null
		for i in range(pts.size()):
			var a: Vector3 = pts[i]
			var b: Vector3 = pts[(i + 1) % pts.size()]
			for r in rects:
				if _seg_rect_hit(Vector2(a.x, a.z), Vector2(b.x, b.z), r):
					hits += 1
					if hits <= 6:
						fail("rota %s corta construcao perto de (%.1f, %.1f)" % [
							child.name, r.get_center().x, r.get_center().y])
					break
			var axis := ""
			var fixed := 0.0
			if absf(a.z - b.z) < 0.01:
				axis = "z"
				fixed = a.z
			elif absf(a.x - b.x) < 0.01:
				axis = "x"
				fixed = a.x
			if axis == "":
				continue
			var axes: Array = streets_x if axis == "z" else streets_z
			var best := INF
			for s in axes:
				best = minf(best, absf(fixed - float(s)))
			if is_ped:
				if best < half_road or best > clearance:
					off_road += 1
					fail("pedestre %s: perna %s=%.2f a %.2f do eixo (calcada e %.2f-%.2f)" % [
						child.name, axis, fixed, best, half_road, clearance])
			elif best > half_road - 0.3:
				off_road += 1
				fail("trafego %s: perna %s=%.2f a %.2f do eixo (pista ate %.2f)" % [
					child.name, axis, fixed, best, half_road])
	print("rotas: %d cruzam construcao, %d fora da pista/calcada" % [hits, off_road])

# ------------------------------------------------------------- 7. entregas

func _delivery(streets_x: Array, streets_z: Array, half_road: float, clearance: float) -> void:
	var houses := get_tree().get_nodes_in_group("delivery_house")
	var bad_npc := 0
	var bad_car := 0
	for h: Node3D in houses:
		var front: Vector3 = h.get_meta("front_position")
		var facing: Vector3 = h.get_meta("front_facing")
		# A CarZone do BuyerNPC fica no +Z local dele, que aponta pra rua.
		var car_pos := front + facing * 3.5
		var d_npc := INF
		var d_car := INF
		for z in streets_x:
			d_npc = minf(d_npc, absf(front.z - float(z)))
			d_car = minf(d_car, absf(car_pos.z - float(z)))
		for x in streets_z:
			d_npc = minf(d_npc, absf(front.x - float(x)))
			d_car = minf(d_car, absf(car_pos.x - float(x)))
		if d_npc < half_road or d_npc > clearance + 0.2:
			bad_npc += 1
			if bad_npc <= 4:
				fail("entrega: NPC a %.2f do eixo (calcada e %.2f-%.2f)" % [
					d_npc, half_road, clearance])
		if d_car > half_road:
			bad_car += 1
			if bad_car <= 4:
				fail("entrega: zona do carro a %.2f do eixo (pista ate %.2f)" % [d_car, half_road])
	print("entregas: %d casas, %d NPC fora da calcada, %d zona fora da pista" % [
		houses.size(), bad_npc, bad_car])

# --------------------------------------------------------- 8. spawn de evento

func _event_spawns() -> void:
	var rects: Array[Rect2] = []
	for b in _city_buildings():
		rects.append(_body_rect(b))
	var bad := 0
	var points := get_tree().get_nodes_in_group("event_spawn_point")
	for m: Node3D in points:
		var p := m.global_position
		var box := Rect2(p.x - 3.0, p.z - 3.0, 6.0, 6.0)
		for r in rects:
			var inter := r.intersection(box)
			if inter.size.x > 0.01 and inter.size.y > 0.01:
				bad += 1
				fail("spawn de evento em (%.1f, %.1f) cai dentro de construcao" % [p.x, p.z])
				break
	print("spawns de evento: %d pontos, %d bloqueados" % [points.size(), bad])

# ------------------------------------------------------ 8b. censo por quadra

## Em qual intervalo da lista de ruas cai uma coordenada, ou -1 se estiver fora.
##
## Por BUSCA, e nao dividindo por um espacamento unico. A grade deixou de ser
## uniforme (quadras de 45, 67.5 e 90 m), e a divisao mapeava o predio pro
## quarteirao errado: quadras cheias apareciam vazias e outras contavam em
## dobro. O verificador reprovou a cidade 3 vezes por um defeito que era DELE.
func _faixa(v: float, ruas: Array) -> int:
	for i in range(ruas.size() - 1):
		if v >= float(ruas[i]) and v < float(ruas[i + 1]):
			return i
	return -1

func _blocks(streets_x: Array, streets_z: Array, _spacing: float) -> void:
	var contents := {}
	for group in ["city_building", "city_prop", "lote_praca", "lote_posto",
			"lote_estacionamento", "lote_feira"]:
		for n: Node3D in get_tree().get_nodes_in_group(group):
			var p := n.global_position
			var i := _faixa(p.x, streets_z)
			var j := _faixa(p.z, streets_x)
			if i < 0 or j < 0:
				continue
			var key := "%d|%d" % [i, j]
			contents[key] = int(contents.get(key, 0)) + 1
	var empty := 0
	for j in range(streets_x.size() - 1):
		for i in range(streets_z.size() - 1):
			if int(contents.get("%d|%d" % [i, j], 0)) == 0:
				empty += 1
				fail("quarteirao vazio no centro (%.0f, %.0f)" % [
					(float(streets_z[i]) + float(streets_z[i + 1])) * 0.5,
					(float(streets_x[j]) + float(streets_x[j + 1])) * 0.5])
	print("\nquarteiroes: %d, vazios: %d | praca %d posto %d estacionamento %d feira %d" % [
		(streets_x.size() - 1) * (streets_z.size() - 1), empty,
		get_tree().get_nodes_in_group("lote_praca").size(),
		get_tree().get_nodes_in_group("lote_posto").size(),
		get_tree().get_nodes_in_group("lote_estacionamento").size(),
		get_tree().get_nodes_in_group("lote_feira").size()])

# ------------------------------------------- 8c. buracos e pocas sobre a pista

func _hazards(streets_x: Array, streets_z: Array, half_road: float) -> void:
	var bad := 0
	var count := 0
	# Por GRUPO, e varrendo a arvore inteira: os buracos deixaram de ser filhos
	# diretos do Town (agora nascem do CityHazards) e passaram a ser irmaos de
	# mesmo nome, que o Godot renomeia pra @Area3D@N. Contando por nome e por
	# filho direto, o censo deu ZERO com 41 buracos na cena.
	var alvos: Array[Node] = []
	alvos.append_array(get_tree().get_nodes_in_group("buraco"))
	alvos.append_array(get_tree().get_nodes_in_group("poca"))
	for child in alvos:
		var is_pothole: bool = child.is_in_group("buraco")
		count += 1
		var r := 1.1 if is_pothole else 2.5
		var p := (child as Node3D).global_position
		var best := INF
		for z in streets_x:
			best = minf(best, absf(p.z - float(z)))
		for x in streets_z:
			best = minf(best, absf(p.x - float(x)))
		if best + r > half_road:
			bad += 1
			fail("%s em (%.1f, %.1f) passa do asfalto (%.2f + raio %.1f > %.1f)" % [
				child.name, p.x, p.z, best, r, half_road])
	print("buracos/pocas: %d, %d fora da pista" % [count, bad])

# ------------------------------------------------------------- 10. alturas

## Carro de IA e pedestre sao cinematicos: a altura vem do ponto da rota, entao
## errar isso deixa eles flutuando (ou enterrados) e nenhuma fisica corrige.
func _heights(streets_node: Node) -> void:
	var road_top: float = streets_node.road_surface_y
	var walk_top: float = streets_node.curb_height
	var bad_car := 0
	var worst_car := 0.0
	for car: Node3D in get_tree().get_nodes_in_group("traffic_car"):
		var gap: float = car.global_position.y - road_top
		if absf(gap) > 0.06:
			bad_car += 1
			worst_car = gap if absf(gap) > absf(worst_car) else worst_car
	var bad_ped := 0
	var worst_ped := 0.0
	for ped: Node3D in get_tree().get_nodes_in_group("pedestrian"):
		var gap: float = ped.global_position.y - walk_top
		if absf(gap) > 0.08:
			bad_ped += 1
			worst_ped = gap if absf(gap) > absf(worst_ped) else worst_ped
	# O topo REAL da laje de asfalto na cena, nao o valor pedido: medir o tile
	# depois de escalar ja enterrou a rua inteira uma vez.
	# Altura da PISTA, nao do topo da caixa: o ponto mais alto do tile e o
	# acostamento da borda, e alinhar por ele ja enterrou a rua inteira uma vez.
	# A pista e o plano horizontal com mais vertices.
	var measured := -999.0
	for child in streets_node.get_children():
		if child is Node3D and (child.scene_file_path.contains("road-straight")
				or child.is_in_group("via_reta")):
			measured = _modal_height(child)
			break
	print("\nalturas: asfalto pedido y=%.2f, medido na cena y=%.2f | calcada y=%.2f" % [
		road_top, measured, walk_top])
	if absf(measured - road_top) > 0.03:
		fail("o topo do asfalto esta em %.3f, deveria estar em %.2f" % [measured, road_top])
	print("  carros de IA fora do asfalto: %d (pior desvio %+.3f m)" % [bad_car, worst_car])
	print("  pedestres fora da calcada: %d (pior desvio %+.3f m)" % [bad_ped, worst_ped])
	if bad_car > 0:
		fail("%d carros de IA flutuando/enterrados (pior %+.3f m)" % [bad_car, worst_car])
	if bad_ped > 0:
		fail("%d pedestres flutuando/enterrados (pior %+.3f m)" % [bad_ped, worst_ped])

# ------------------------------------------------- 9. anel rural e cordilheira

func _rural() -> void:
	var belt: Node = town.get_node("CityOutskirts")
	var belt_outer: float = belt.outer_extent
	var feet: Array = []
	for body: Node3D in town.get_node("MountainRange").get_children():
		var aabb := AABB()
		for c in body.get_children():
			if c is MeshInstance3D:
				aabb = (c as MeshInstance3D).get_aabb()
		var r: float = maxf(aabb.size.x, aabb.size.z) * 0.5
		feet.append({"p": Vector2(body.global_position.x, body.global_position.z), "r": r})
	if feet.is_empty():
		fail("nenhum macico gerado (script da cordilheira nao rodou?)")
	var closest := INF
	for f in feet:
		closest = minf(closest, float(f["p"].length()) - float(f["r"]))
	print("\ncordilheira: %d macicos, pe mais interno a %.0f do centro" % [feet.size(), closest])
	if closest < belt_outer:
		fail("encosta entra no cinturao (pe a %.0f, cinturao ate %.0f)" % [closest, belt_outer])

	for name: String in ["Farm1", "Farm2", "Farm3", "Farm4", "Farm5",
			"Scrapyard1", "Scrapyard2", "Scrapyard3", "Workshop", "Junkyard"]:
		var node: Node3D = town.get_node(name)
		var pos := Vector2(node.global_position.x, node.global_position.z)
		var cluster_r := 25.0
		for b in belt.get_children():
			if not (b is StaticBody3D):
				continue
			var r := _body_rect(b)
			if r.get_center().distance_to(pos) < cluster_r + maxf(r.size.x, r.size.y) * 0.5:
				fail("construcao do cinturao em (%.0f, %.0f) encosta em %s" % [
					r.get_center().x, r.get_center().y, name])
				break
		for f in feet:
			if float(pos.distance_to(f["p"])) - float(f["r"]) - cluster_r < 0.0:
				fail("%s fica DENTRO da base de um macico" % name)
				break

	var buried := 0
	for child in town.get_node("NatureScatter").get_children():
		var pos := Vector2(child.global_position.x, child.global_position.z)
		for f in feet:
			if pos.distance_to(f["p"]) < float(f["r"]):
				buried += 1
				break
	if buried > 0:
		fail("%d props de natureza caem na encosta (plantados em y=0)" % buried)

	var ground_half: float = (town.get_node("Ground/Shape").shape as BoxShape3D).size.x * 0.5
	var farthest := 0.0
	for f in feet:
		farthest = maxf(farthest, float(f["p"].length()) + float(f["r"]))
	print("chao: meia-largura %.0f | ponto mais distante %.0f | natureza na encosta %d" % [
		ground_half, farthest, buried])
	if farthest > ground_half:
		fail("montanha passa da borda do chao (%.0f > %.0f)" % [farthest, ground_half])
