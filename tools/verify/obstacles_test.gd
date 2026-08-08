extends Node
## Duas perguntas que so o mundo montado responde:
##
##   [1] PAREDE INVISIVEL — onde existe colisao sem desenho por perto. Ja
##       aconteceu de verdade: a cordilheira gerava a colisao numa malha grossa
##       e a mais fina no desenho, e sobrava um quad inteiro de colisao alem da
##       encosta visivel — 41 paredes, ate 27 m de sobra (2026-08-04).
##
##   [2] ESTRADA DE TERRA ENTULHADA — a fita da estrada nao tem colisao de
##       proposito, entao nada impede um espalhador de plantar arvore ou pedra
##       EM CIMA dela. Quem dirige da cidade pra oficina passa por ali.
##
## Os dois casos sao invisiveis pra qualquer teste de carga: o jogo sobe limpo
## com os dois presentes.
##
##   godot --headless --path . tools/verify/obstacles_test.tscn

## Quanto a colisao pode passar do desenho antes de contar como parede.
const WALL_MARGIN := 0.9
## Corpo com desenho menor que isto e considerado sem desenho nenhum.
const NO_VISUAL_SIZE := 0.05
## Quanto das pontas da estrada de terra e LIGACAO e nao pista: o comeco encosta
## na ultima rua asfaltada e o fim entra no patio da oficina.
const JUNCTION_SLACK := 12.0
const YARD_SLACK := 22.0

var problems: Array[String] = []
var town: Node = null

func _ready() -> void:
	var main := (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	add_child(main)
	for i in range(8):
		await get_tree().process_frame
		await get_tree().physics_frame
	town = main.get_node_or_null("Town")
	if town == null:
		push_error("Town nao encontrada")
		get_tree().quit(1)
		return

	_check_walls()
	_check_silhouette()
	_check_dirt_roads()
	_probe_corridor()

	print("")
	if problems.is_empty():
		print("=== RESULTADO ===")
		print("sem parede invisivel e sem entulho na estrada de terra")
		get_tree().quit(0)
	else:
		print("=== PROBLEMAS (%d) ===" % problems.size())
		for p in problems:
			print("  - %s" % p)
		get_tree().quit(1)

# ------------------------------------------------------------ parede invisivel

func _check_walls() -> void:
	print("[1] parede invisivel (colisao sem desenho por baixo)")
	var bodies: Array[CollisionObject3D] = []
	_all_bodies(town, bodies)
	var offenders: Array = []
	var orphans: Array = []
	for body in bodies:
		# Area3D e gatilho (zona de entrega, buraco, poca): ela NAO barra
		# ninguem, entao colisao sem desenho ali e o projeto, nao defeito.
		if body is Area3D:
			continue
		var col := _collision_aabb(body)
		if col.size == Vector3.ZERO:
			continue
		var vis := _visual_aabb(body)
		if vis.size.length() < NO_VISUAL_SIZE:
			orphans.append([body, col])
			continue
		var over := _overhang(col, vis)
		if over > WALL_MARGIN:
			offenders.append([body, over, col, vis])

	offenders.sort_custom(func(a, b): return a[1] > b[1])
	print("    %d corpos solidos conferidos" % bodies.size())
	if orphans.is_empty():
		print("    nenhum corpo solido sem desenho")
	else:
		print("    %d corpo(s) SOLIDO(S) SEM DESENHO:" % orphans.size())
		for o in orphans.slice(0, 12):
			var b: Node = o[0]
			var c: AABB = o[1]
			print("      %-42s em %s, caixa %.1f x %.1f x %.1f"
				% [_path(b), _v(c.get_center()), c.size.x, c.size.y, c.size.z])
		problems.append("%d corpo solido sem nenhum desenho (parede invisivel)" % orphans.size())

	if offenders.is_empty():
		print("    nenhuma colisao passando mais de %.2f m do desenho" % WALL_MARGIN)
	else:
		print("    %d corpo(s) com colisao muito maior que o desenho:" % offenders.size())
		for o in offenders.slice(0, 12):
			print("      %-42s sobra %.1f m" % [_path(o[0]), o[1]])
		problems.append("%d corpo com colisao passando mais de %.1f m do desenho"
			% [offenders.size(), WALL_MARGIN])

## Quanto a caixa de colisao passa da caixa do desenho, no pior eixo horizontal.
## So X e Z: sobra em Y e telhado/base, nao barra quem anda.
func _overhang(col: AABB, vis: AABB) -> float:
	var worst := 0.0
	for axis in [0, 2]:
		worst = maxf(worst, vis.position[axis] - col.position[axis])
		worst = maxf(worst, (col.position[axis] + col.size[axis])
			- (vis.position[axis] + vis.size[axis]))
	return worst

# ------------------------------------------- parede invisivel de verdade

## Faixa de altura que importa: e por onde passam carro e jogador. Acima disso a
## colisao pode ser larga a vontade — ninguem esbarra numa copa a 6 m.
## Tem que bater com a faixa do `AutoCollisionBody`, que e quem gera a forma.
## Com faixas diferentes (0.3-2.2 aqui contra 0.15-2.0 la) tres casas apareciam
## com "1.4 m de ar solido" que era so um degrau de base a 0.2 m, dentro da
## faixa do gerador e fora da daqui — medida discordando de si mesma, nao bug.
const BAND_LOW := 0.15
const BAND_HIGH := 2.0
## Quanto a colisao pode ser mais larga que a MALHA nessa faixa. Tem que bater
## com o `SHRINK_MIN` do `AutoCollisionBody`: cobrar aqui mais do que o gerador
## encolhe la seria reprovar por uma regra que ninguem aplica.
const SILHOUETTE_SLACK := 2.5
## So corpos grandes interessam; poste e lixeira nao tem o que esconder.
const SILHOUETTE_MIN := 2.5

## A checagem [1] compara caixa de colisao com caixa de desenho — e por isso NAO
## enxerga o pior caso de todos: uma ARVORE. O `AutoCollisionBody` gera a caixa a
## partir do AABB da malha, entao pra uma arvore de copa larga a colisao e um
## bloco de 9 x 9 m que casa PERFEITAMENTE com o desenho ("sobra 0.00 m") e
## mesmo assim e parede invisivel: na altura do carro so existe um tronco fino, e
## o resto e ar que barra.
##
## O jeito certo de perguntar e comparar a colisao com a MALHA NA ALTURA DO
## CARRO, nao com a caixa dela.
func _check_silhouette() -> void:
	print("\n[2] colisao larga onde a malha e fina (arvore = parede invisivel)")
	var bodies: Array[CollisionObject3D] = []
	_all_bodies(town, bodies)
	var bad: Array = []
	var info: Array = []
	for body in bodies:
		if body is Area3D or body is RigidBody3D:
			continue
		# Colisao de MALHA (trimesh) nao pode gerar parede invisivel: ela E a
		# superficie desenhada. A caixa envolvente dela e enorme e nao significa
		# nada — e por isso as 44 montanhas apareciam no topo desta lista, com
		# ate 41 m de "ar solido" que nao existe. O defeito so mora em forma
		# PRIMITIVA aproximando malha complexa.
		if _has_concave_shape(body):
			continue
		var col := _collision_aabb(body)
		var foot: float = maxf(col.size.x, col.size.z)
		if foot < SILHOUETTE_MIN:
			continue
		# Predio e galpao sao macicos: a malha na faixa e tao larga quanto a
		# caixa, entao eles caem fora sozinhos, sem lista de excecao.
		var mesh_span := _mesh_span_in_band(body, col)
		if mesh_span < 0.0:
			continue
		if foot - mesh_span <= SILHOUETTE_SLACK:
			continue
		# PREDIO fica de fora, e a razao e uma troca medida: encolher a colisao
		# de um predio faz ela deixar de cobrir a laje, e os props de cobertura
		# (caixa d'agua, ar condicionado) passam a nao ter nada solido embaixo —
		# 9 deles apareceram boiando a ate 11,6 m quando o encolhimento era
		# automatico. Prop de vegetacao nao tem esse problema, e e nele que mora
		# a parede invisivel de verdade. Continua listado, mas nao reprova.
		if body.is_in_group("city_building"):
			info.append([body, foot, mesh_span, col.get_center()])
			continue
		bad.append([body, foot, mesh_span, col.get_center()])
	bad.sort_custom(func(a, b): return (a[1] - a[2]) > (b[1] - b[2]))
	print("    %d corpo(s) com colisao larga e malha fina na altura do carro" % bad.size())
	for b in bad.slice(0, 15):
		print("      %-38s em %s | colisao %.1f m, malha %.1f m -> %.1f m de ar solido"
			% [_path(b[0]), _v(b[3]), b[1], b[2], b[1] - b[2]])
	if not info.is_empty():
		print("    %d predio(s) com terreo recuado (colisao mantida de proposito):" % info.size())
		for b in info.slice(0, 6):
			print("      %-38s em %s | colisao %.1f m, malha %.1f m"
				% [_path(b[0]), _v(b[3]), b[1], b[2]])
	if not bad.is_empty():
		problems.append("%d corpo com colisao muito mais larga que a malha na altura do carro"
			% bad.size())

func _has_concave_shape(body: CollisionObject3D) -> bool:
	for child in body.get_children():
		if child is CollisionShape3D:
			var s := (child as CollisionShape3D).shape
			if s is ConcavePolygonShape3D or s is HeightMapShape3D:
				return true
	return false

## Maior extensao horizontal da MALHA na faixa de altura do carro, medida nos
## vertices. -1 quando nao ha vertice nenhum na faixa.
func _mesh_span_in_band(body: Node, col: AABB) -> float:
	var meshes: Array[MeshInstance3D] = []
	_all_meshes(body, meshes)
	var low := col.position.y + BAND_LOW
	var high := col.position.y + BAND_HIGH
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	var found := false
	for mi in meshes:
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		for s in range(mi.mesh.get_surface_count()):
			var arrays := mi.mesh.surface_get_arrays(s)
			if arrays.size() <= Mesh.ARRAY_VERTEX:
				continue
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var xf := mi.global_transform
			# Malha densa nao precisa de todo vertice pra dar a largura.
			var step: int = maxi(1, verts.size() / 900)
			for i in range(0, verts.size(), step):
				var w: Vector3 = xf * verts[i]
				if w.y < low or w.y > high:
					continue
				found = true
				min_x = minf(min_x, w.x)
				max_x = maxf(max_x, w.x)
				min_z = minf(min_z, w.z)
				max_z = maxf(max_z, w.z)
	if not found:
		return -1.0
	return maxf(max_x - min_x, max_z - min_z)

# --------------------------------------------------------- estrada de terra

func _check_dirt_roads() -> void:
	print("\n[2] entulho em cima da estrada de terra")
	var roads := get_tree().get_nodes_in_group("dirt_road")
	if roads.is_empty():
		problems.append("nenhuma estrada de terra no grupo 'dirt_road'")
		return
	for road in roads:
		var segments := _road_segments(road)
		if segments.is_empty():
			problems.append("estrada '%s' sem pontos" % road.name)
			continue
		var half: float = float(road.width) * 0.5
		var blockers: Array = []
		var junction: int = 0
		for obj in _placed(town):
			# A propria estrada e o chao nao contam.
			if obj == road or obj.is_in_group("dirt_road") or obj.is_in_group("terreno_natural"):
				continue
			var box := _visual_aabb(obj)
			if box.size == Vector3.ZERO:
				continue
			var c := box.get_center()
			var p := Vector2(c.x, c.z)
			# Raio do objeto no plano: o que decide se ele invade a pista.
			var r: float = maxf(box.size.x, box.size.z) * 0.5
			var d := _distance_to_road(p, segments)
			if d >= half + r:
				continue
			# AS DUAS PONTAS SAO LIGACAO, NAO ENTULHO: a estrada nasce na ultima
			# rua asfaltada e morre dentro do patio da oficina, entao encostar
			# no asfalto de um lado e no barracao do outro e o desenho. Sem esta
			# separacao o teste acusa 17 "obstaculos" e some com o unico que
			# importa no meio deles.
			var along := _along_road(p, segments)
			var total_len := _road_length(segments)
			if along < JUNCTION_SLACK or along > total_len - YARD_SLACK:
				junction += 1
				continue
			blockers.append([obj, d, r, _solid(obj), p])
		blockers.sort_custom(func(a, b): return a[1] < b[1])
		print("    %s: %.0f m de extensao, largura %.1f m" % [
			road.name, _road_length(segments), road.width])
		print("      %d objeto(s) nas pontas (ligacao com rua/patio, esperado)" % junction)
		if blockers.is_empty():
			print("      pista livre no meio")
		else:
			print("      %d objeto(s) NO MEIO DA PISTA:" % blockers.size())
			for b in blockers:
				print("        %-38s em %s, eixo a %.1f m, raio %.1f%s"
					% [_path(b[0]), "(%.0f, %.0f)" % [b[4].x, b[4].y], b[1], b[2],
						"  [SOLIDO]" if b[3] else "  (so visual)"])
			problems.append("%d objeto no meio da estrada '%s'" % [blockers.size(), road.name])

## Distancia percorrida ao longo do eixo ate o ponto mais proximo de `p`.
func _along_road(p: Vector2, segments: Array) -> float:
	var best := INF
	var best_along := 0.0
	var walked := 0.0
	for s in segments:
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var ab := b - a
		var len_ab := ab.length()
		var t: float = 0.0 if len_ab < 0.001 \
			else clampf((p - a).dot(ab) / (len_ab * len_ab), 0.0, 1.0)
		var d := p.distance_to(a + ab * t)
		if d < best:
			best = d
			best_along = walked + t * len_ab
		walked += len_ab
	return best_along

func _road_length(segments: Array) -> float:
	var total := 0.0
	for s in segments:
		total += (s[1] as Vector2).distance_to(s[0] as Vector2)
	return total

# ------------------------------------------------------- sonda do corredor

## Caixa do carro (o `drive_test` mede 1.81 x 1.01 x 4.22). E ELA que decide se
## a estrada esta livre: comparar caixa de colisao com caixa de desenho responde
## "a colisao e maior que o desenho?", que NAO e a mesma pergunta que "o carro
## passa aqui?". Um corpo pode ter desenho do tamanho certo e mesmo assim estar
## plantado no meio da pista.
const CAR_BOX := Vector3(1.81, 1.01, 4.22)
const PROBE_STEP := 2.0
## Altura do centro da caixa acima do chao medido.
const PROBE_LIFT := 0.75

func _probe_corridor() -> void:
	print("\n[3] o carro passa? (caixa do carro varrida pela pista)")
	var space := get_viewport().world_3d.direct_space_state
	var shape := BoxShape3D.new()
	shape.size = CAR_BOX
	for road in get_tree().get_nodes_in_group("dirt_road"):
		var segments := _road_segments(road)
		if segments.is_empty():
			continue
		var half: float = float(road.width) * 0.5 - CAR_BOX.x * 0.5
		var total := _road_length(segments)
		var hits: Dictionary = {}
		var blocked := 0
		var samples := 0
		var walked := 0.0
		while walked <= total:
			for lane in [-half * 0.6, 0.0, half * 0.6]:
				var p := _point_along(segments, walked, lane)
				var y := _ground_y(space, p)
				if is_inf(y):
					continue
				samples += 1
				var params := PhysicsShapeQueryParameters3D.new()
				params.shape = shape
				params.transform = Transform3D(Basis(), Vector3(p.x, y + PROBE_LIFT, p.y))
				params.collide_with_bodies = true
				params.collide_with_areas = false
				var found := space.intersect_shape(params, 8)
				if found.is_empty():
					continue
				blocked += 1
				for f in found:
					var col: Node = f["collider"]
					var key := _path(col)
					if not hits.has(key):
						hits[key] = {"n": 0, "em": walked, "no": col}
					hits[key]["n"] += 1
			walked += PROBE_STEP
		print("    %s: %d posicoes testadas, %d barradas" % [road.name, samples, blocked])
		if hits.is_empty():
			print("      corredor livre de ponta a ponta")
			continue
		var keys: Array = hits.keys()
		keys.sort_custom(func(a, b): return hits[a]["n"] > hits[b]["n"])
		for k in keys:
			var info: Dictionary = hits[k]
			var node: Node = info["no"]
			var vis := _visual_aabb(node)
			var visible_here := vis.size.length() > NO_VISUAL_SIZE
			var col := _collision_aabb(node as CollisionObject3D) if node is CollisionObject3D else AABB()
			# Nao basta dizer QUE barra: pra decidir se e parede invisivel ou
			# obstaculo honesto e preciso ver o desenho ao lado da colisao.
			print("      %-38s %d pos., a %.0f m | colisao %.1fx%.1fx%.1f | desenho %.1fx%.1fx%.1f | sobra %.2f m%s"
				% [k, info["n"], info["em"],
					col.size.x, col.size.y, col.size.z,
					vis.size.x, vis.size.y, vis.size.z,
					_overhang(col, vis),
					"" if visible_here else "   *** SEM DESENHO ***"])
			if not visible_here:
				problems.append("parede invisivel na estrada: %s" % k)

## Ponto a `dist` metros do inicio, deslocado `lane` metros pro lado.
func _point_along(segments: Array, dist: float, lane: float) -> Vector2:
	var walked := 0.0
	for s in segments:
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var seg := (b - a).length()
		if walked + seg >= dist or s == segments[-1]:
			var dir := (b - a).normalized()
			var nrm := Vector2(-dir.y, dir.x)
			return a + dir * clampf(dist - walked, 0.0, seg) + nrm * lane
		walked += seg
	return segments[-1][1]

func _ground_y(space: PhysicsDirectSpaceState3D, p: Vector2) -> float:
	var q := PhysicsRayQueryParameters3D.create(
		Vector3(p.x, 200.0, p.y), Vector3(p.x, -50.0, p.y))
	var hit := space.intersect_ray(q)
	return float(hit["position"].y) if hit.has("position") else INF

## Tem corpo solido? Prop so visual em cima da estrada e feio; solido e PAREDE.
func _solid(n: Node) -> bool:
	if n is StaticBody3D or n is RigidBody3D:
		return true
	for c in n.get_children():
		if _solid(c):
			return true
	return false

## Segmentos do eixo da estrada, em coordenada de mundo.
func _road_segments(road: Node3D) -> Array:
	var out: Array = []
	var pts: Array = road.points
	var origin := road.global_position
	for i in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		out.append([Vector2(a.x + origin.x, a.y + origin.z),
			Vector2(b.x + origin.x, b.y + origin.z)])
	return out

func _distance_to_road(p: Vector2, segments: Array) -> float:
	var best := INF
	for s in segments:
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var ab := b - a
		var t: float = 0.0 if ab.length_squared() < 0.0001 \
			else clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best

# ------------------------------------------------------------------ utilidades

## Objetos "plantados" no mundo: um nivel util de agrupamento, pra nao medir
## folha por folha (a licao de 2026-08-04: a unidade da pergunta e o OBJETO).
func _placed(root: Node, out: Array[Node3D] = []) -> Array[Node3D]:
	for child in root.get_children():
		if child is Node3D:
			var n := child as Node3D
			if _has_mesh(n) and n.get_child_count() < 40:
				out.append(n)
			else:
				_placed(n, out)
	return out

func _has_mesh(n: Node) -> bool:
	if n is MeshInstance3D:
		return true
	for c in n.get_children():
		if _has_mesh(c):
			return true
	return false

func _visual_aabb(root: Node) -> AABB:
	var meshes: Array[MeshInstance3D] = []
	_all_meshes(root, meshes)
	var box := AABB()
	var first := true
	for mi in meshes:
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var world := mi.global_transform * mi.mesh.get_aabb()
		if first:
			box = world
			first = false
		else:
			box = box.merge(world)
	return box

func _all_meshes(n: Node, out: Array[MeshInstance3D]) -> void:
	if n is MeshInstance3D:
		out.append(n as MeshInstance3D)
	for c in n.get_children():
		_all_meshes(c, out)

func _all_bodies(n: Node, out: Array[CollisionObject3D]) -> void:
	if n is CollisionObject3D:
		out.append(n as CollisionObject3D)
	for c in n.get_children():
		_all_bodies(c, out)

func _collision_aabb(body: CollisionObject3D) -> AABB:
	var box := AABB()
	var first := true
	for child in body.get_children():
		if not (child is CollisionShape3D):
			continue
		var cs := child as CollisionShape3D
		if cs.shape == null or cs.disabled:
			continue
		var local := cs.shape.get_debug_mesh().get_aabb()
		var world := cs.global_transform * local
		if first:
			box = world
			first = false
		else:
			box = box.merge(world)
	return box

func _path(n: Node) -> String:
	var p := str(n.get_path())
	return p.substr(maxi(0, p.length() - 42))

func _v(p: Vector3) -> String:
	return "(%.0f, %.0f)" % [p.x, p.z]
