extends Node
## ESCALA da rua e do que fica nela: mobiliario urbano, faixa de pedestre,
## lotes especiais e o cinturao de transicao.
##
## Existe porque a cidade mudou de tamanho duas vezes (predios realistas de
## altura media 18 m, e a rua alargada de 4,8 para 11,4 m de pista) e o
## mobiliario foi calibrado ANTES disso. Cada peca aqui e medida contra duas
## referencias que nao mudam: o jogador de 1,80 m e a largura real da pista
## lida do proprio `CityStreets` da cena.
##
## Roda com:
##   godot --headless --path . tools/verify/street_test.tscn

const REFERENCIA_HUMANA := 1.80

## Altura plausivel de cada peca, em metros. Nao sao chutes: semaforo de rua
## real tem 3 a 4 m ate o cabecote, abrigo de onibus 2,4 a 3 m, poste 6 a 9 m.
## Grupo -> altura plausivel em metros. Sao medidas de rua de verdade: semaforo
## com braco sobre a pista tem 5 a 6 m ate o topo do poste, abrigo de onibus 2,5
## a 3,4 m, banco menos de 1,2 m.
##
## Por GRUPO, e nao por nome de no: irmaos de nome repetido viram "@Node3D@N", e
## a primeira versao deste teste classificou 300 dos 302 props como "?" por
## causa disso — a mesma armadilha que ja fez um verificador achar 2 semaforos
## de 50 (changelog 2026-08-03).
const FAIXAS := {
	"semaforo": Vector2(4.0, 6.5),
	"ponto_onibus": Vector2(2.4, 3.6),
	"banco": Vector2(0.5, 1.3),
}

var problems: Array[String] = []
var main: Node
var streets: Node = null

func fail(msg: String) -> void:
	problems.append(msg)
	print("    FALHOU: " + msg)

func ok(msg: String) -> void:
	print("    ok: " + msg)

func _ready() -> void:
	main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().physics_frame
	streets = _find_by_script(main, "CityStreets.gd")
	if streets == null:
		fail("nao achei o CityStreets na cena")
		_finish()
		return
	_secao_rua()
	_secao_mobiliario()
	_secao_lotes()
	_secao_cinturao()
	_secao_arvores()
	_finish()

func _finish() -> void:
	print("\n=== RESULTADO ===")
	if problems.is_empty():
		print("rua, mobiliario, lotes e cinturao em escala")
	else:
		print("%d problema(s):" % problems.size())
		for p in problems:
			print("  - " + p)
	get_tree().quit(0 if problems.is_empty() else 1)

# ---------------------------------------------------------------------- rua

var _half := 0.0
var _sidewalk := 0.0

func _secao_rua() -> void:
	print("\n[1] a rua")
	_half = float(streets.get("road_half_width"))
	_sidewalk = float(streets.get("sidewalk_width"))
	print("    pista %.1f m de largura | calcada %.1f m de cada lado | fachada a %.1f m do eixo"
		% [_half * 2.0, _sidewalk, _half + _sidewalk])
	# Duas faixas de 3,5 m mais duas de estacionamento e o perfil de rua urbana
	# de verdade. Abaixo de 8 m a rua le como viela ao lado de predio de 18 m.
	if _half * 2.0 < 8.0:
		fail("pista de %.1f m — estreita demais pra escala dos predios" % (_half * 2.0))
	if _sidewalk < 2.0:
		fail("calcada de %.1f m — nao cabe pedestre ao lado do mobiliario" % _sidewalk)

# --------------------------------------------------------------- mobiliario

func _secao_mobiliario() -> void:
	print("\n[2] mobiliario urbano")
	var props := get_tree().get_nodes_in_group("street_furniture")
	if props.is_empty():
		fail("nenhum mobiliario urbano na cidade")
		return
	print("    %d pecas no total" % props.size())

	for grupo: String in FAIXAS:
		var lista := get_tree().get_nodes_in_group(grupo)
		if lista.is_empty():
			fail("nenhum '%s' na cidade" % grupo)
			continue
		var alturas: Array[float] = []
		var fora_da_calcada := 0
		var pior_dist := 0.0
		for p in lista:
			var n := p as Node3D
			var box := _world_aabb(n)
			alturas.append(box.size.y)
			var dist := _dist_ao_eixo(n.global_position)
			# Tem que ficar na calcada: do meio-fio pra dentro e pista, da
			# fachada pra fora e dentro do predio. O banco de praca fica longe
			# de rua nenhuma, entao so o que e de RUA entra nesta conta.
			if grupo == "banco":
				continue
			if dist < _half or dist > _half + _sidewalk + 0.5:
				fora_da_calcada += 1
				pior_dist = maxf(pior_dist, absf(dist - (_half + _sidewalk * 0.5)))
		alturas.sort()
		var mediana: float = alturas[alturas.size() / 2]
		print("    %-14s %3d | altura %.2f m (%.1fx o jogador)"
			% [grupo, lista.size(), mediana, mediana / REFERENCIA_HUMANA])
		var faixa: Vector2 = FAIXAS[grupo]
		if mediana < faixa.x or mediana > faixa.y:
			fail("%s com %.2f m — fora da faixa plausivel de %.1f a %.1f m"
				% [grupo, mediana, faixa.x, faixa.y])
		if fora_da_calcada > 0:
			fail("%s: %d de %d fora da calcada (pior %.1f m do meio da calcada)"
				% [grupo, fora_da_calcada, lista.size(), pior_dist])

	# Faixa de pedestre: a tinta tem que atravessar a pista inteira, senao ela
	# le como listra solta no asfalto.
	var faixas := get_tree().get_nodes_in_group("via_faixa")
	var tintas := get_tree().get_nodes_in_group("via_faixa_barra")
	print("    travessias: %d pavimentos, %d barras de faixa" % [faixas.size(), tintas.size()])
	if faixas.is_empty():
		fail("nenhuma faixa de pedestre na cidade")
	else:
		# A barra tem que cruzar a pista quase inteira: barra curta le como
		# listra solta no meio do asfalto.
		var barra := _world_aabb(tintas[tintas.size() / 2] as Node3D)
		var comprimento: float = maxf(barra.size.x, barra.size.z)
		var largura: float = minf(barra.size.x, barra.size.z)
		print("    barra da faixa: %.2f m de largura x %.1f m atravessando (pista %.1f m)"
			% [largura, comprimento, _half * 2.0])
		if comprimento < _half * 2.0 * 0.75:
			fail("barra da faixa com %.1f m numa pista de %.1f m" % [comprimento, _half * 2.0])

# -------------------------------------------------------------------- lotes

func _secao_lotes() -> void:
	print("\n[3] lotes especiais")
	for grupo: String in ["lote_posto", "lote_praca", "lote_estacionamento", "lote_feira"]:
		var nos := get_tree().get_nodes_in_group(grupo)
		if nos.is_empty():
			print("    %-16s (sem grupo — nao da pra medir)" % grupo)
			continue
		var alturas: Array[float] = []
		for n in nos:
			alturas.append(_world_aabb(n as Node3D).size.y)
		alturas.sort()
		print("    %-16s %d | altura ate %.1f m" % [grupo, nos.size(), alturas[-1]])

# ----------------------------------------------------------------- cinturao

func _secao_cinturao() -> void:
	print("\n[4] cinturao de transicao (a moldura da cidade)")
	var belt := _find_by_script(main, "CityOutskirts.gd")
	if belt == null:
		fail("nao achei o CityOutskirts")
		return
	# O pool de onde o cinturao escolhe. Sem ele nao da pra saber se a borda do
	# campo nao afina porque o sorteio esta errado ou porque NAO EXISTE modelo
	# baixo o bastante no catalogo — sao consertos diferentes.
	var pool: Array = belt.call("_pool")
	if pool.is_empty():
		fail("pool do cinturao vazio")
	else:
		var baixos := 0
		var menor := INF
		var maior := 0.0
		for e: Dictionary in pool:
			var h := float(e.get("altura", 0.0))
			menor = minf(menor, h)
			maior = maxf(maior, h)
			if h <= 8.0:
				baixos += 1
		print("    pool: %d modelos, de %.1f a %.1f m | %d com ate 8 m"
			% [pool.size(), menor, maior, baixos])

	var alturas: Array[float] = []
	var pacotes: Dictionary = {}
	for c in (belt as Node).get_children():
		var box := _world_aabb(c as Node3D)
		if box.size.y <= 0.01:
			continue
		alturas.append(box.size.y)
		var origem := _pacote(c)
		pacotes[origem] = int(pacotes.get(origem, 0)) + 1
	if alturas.is_empty():
		fail("cinturao vazio")
		return
	alturas.sort()
	var mediana: float = alturas[alturas.size() / 2]
	print("    %d construcoes | altura %.1f m (mediana), de %.1f a %.1f m"
		% [alturas.size(), mediana, alturas[0], alturas[-1]])
	for p: String in pacotes:
		print("      %4d de %s" % [pacotes[p], p])

	# O degrade e a razao de existir do cinturao: perto da cidade tem que ser
	# mais alto que na borda do campo. Medido em dois aneis, nao no total —
	# uma mediana boa esconde um anel plano.
	var dentro: Array[float] = []
	var fora: Array[float] = []
	var inner := float(belt.get("inner_extent"))
	var outer := float(belt.get("outer_extent"))
	var meio := (inner + outer) * 0.5
	for c in (belt as Node).get_children():
		var n := c as Node3D
		if n == null:
			continue
		var h := _world_aabb(n).size.y
		if h <= 0.01:
			continue
		var d: float = maxf(absf(n.global_position.x), absf(n.global_position.z))
		if d < meio:
			dentro.append(h)
		else:
			fora.append(h)
	if dentro.is_empty() or fora.is_empty():
		fail("cinturao so tem construcao de um lado do anel")
	else:
		dentro.sort()
		fora.sort()
		var h_dentro: float = dentro[dentro.size() / 2]
		var h_fora: float = fora[fora.size() / 2]
		print("    degrade: %.1f m colado na cidade (%d) -> %.1f m na borda do campo (%d)"
			% [h_dentro, dentro.size(), h_fora, fora.size()])
		if h_fora >= h_dentro:
			fail("o cinturao nao afina: %.1f m na borda contra %.1f m na cidade"
				% [h_fora, h_dentro])

	# Densidade: um anel ralo demais nao le como transicao, le como casa solta
	# no mato. O perimetro sai do proprio anel medido.
	var perimetro := 8.0 * (inner + outer) * 0.5
	var por_100m := 100.0 * float(alturas.size()) / perimetro
	print("    densidade: %.1f construcoes por 100 m de anel" % por_100m)
	if por_100m < 2.0:
		fail("cinturao ralo: %.1f construcoes por 100 m" % por_100m)

	# A cidade e 100% realista desde 2026-08-09. Um cinturao do kit estilizado
	# encosta na cidade lado a lado — que e exatamente a mistura de estilo que
	# este projeto ja corrigiu duas vezes.
	var do_kit := 0
	for p: String in pacotes:
		if p.contains("kenney"):
			do_kit += int(pacotes[p])
	if do_kit > 0:
		fail("%d construcoes do cinturao vem do kit Kenney, e a cidade e realista" % do_kit)

	# Escala: comparar com as construcoes da BORDA da cidade, que ficam a poucos
	# metros dali. E a comparacao que o jogador faz com o olho.
	var borda := _altura_borda_cidade()
	print("    borda da cidade ao lado: %.1f m (mediana)" % borda)
	if borda > 0.0 and mediana < borda * 0.25:
		fail("cinturao com %.1f m contra %.1f m da cidade ao lado — degrau grande demais"
			% [mediana, borda])

func _altura_borda_cidade() -> float:
	var blocks := _find_by_script(main, "CityBlocks.gd")
	if blocks == null:
		return 0.0
	var belt := _find_by_script(main, "CityOutskirts.gd")
	var limite := float(belt.get("inner_extent")) if belt else 0.0
	var alturas: Array[float] = []
	for c in (blocks as Node).get_children():
		if not (c is Node3D):
			continue
		var p: Vector3 = (c as Node3D).global_position
		# So as construcoes do anel externo: sao elas que ficam lado a lado com
		# o cinturao.
		if maxf(absf(p.x), absf(p.z)) < limite - 60.0:
			continue
		var h := _world_aabb(c as Node3D).size.y
		if h > 0.5:
			alturas.append(h)
	if alturas.is_empty():
		return 0.0
	alturas.sort()
	return alturas[alturas.size() / 2]

# ---------------------------------------------------------------------- arvores

## Arvore fora de escala e o defeito mais facil de cometer e o mais dificil de
## notar: ela nao tem porta nem janela pra denunciar o tamanho. Aqui a conta e
## contra o jogador de 1,80 m — uma arvore de rua tem 6 a 15 m, e acima de 20 m
## ela vira sequoia ao lado de uma casa.
const ARVORE_MIN := 4.0
const ARVORE_MAX := 20.0

func _secao_arvores() -> void:
	print("\n[5] arvores")
	var por_lugar := {"campo": [], "cidade": []}
	_coletar_arvores(main, por_lugar)
	for lugar: String in por_lugar:
		var alturas: Array = por_lugar[lugar]
		if alturas.is_empty():
			print("    %-8s nenhuma" % lugar)
			continue
		alturas.sort()
		var mediana: float = alturas[alturas.size() / 2]
		print("    %-8s %5d arvores | %.1f m (mediana), de %.1f a %.1f m (%.1fx o jogador)"
			% [lugar, alturas.size(), mediana, alturas[0], alturas[-1],
				mediana / REFERENCIA_HUMANA])
		if alturas[-1] > ARVORE_MAX:
			fail("arvore de %.1f m no %s — %.0fx o jogador"
				% [alturas[-1], lugar, alturas[-1] / REFERENCIA_HUMANA])
		if mediana < ARVORE_MIN:
			fail("arvores do %s com mediana de %.1f m — arbusto, nao arvore" % [lugar, mediana])

	# Densidade do campo: o usuario pediu MUITAS arvores na zona rural, e "muitas"
	# so quer dizer alguma coisa por area.
	var scatter := _find_by_script(main, "RuralScatter.gd")
	if scatter != null and not por_lugar["campo"].is_empty():
		var r_out := float(scatter.get("outer_radius"))
		var r_in := float(scatter.get("inner_extent"))
		var area := PI * r_out * r_out - 4.0 * r_in * r_in
		var por_hectare := 10000.0 * float(por_lugar["campo"].size()) / maxf(area, 1.0)
		print("    campo: %.1f arvores por hectare" % por_hectare)
		if por_hectare < 3.0:
			fail("campo ralo: %.1f arvores por hectare" % por_hectare)

func _coletar_arvores(node: Node, out: Dictionary) -> void:
	var path := node.scene_file_path
	# Classificada pelo ARQUIVO de origem, nao pelo nome do no: nome repetido
	# vira "@Node3D@N" e nao diz nada.
	# Duas fontes de arvore: o `nature-megakit` no campo e o
	# `european_buildings_pack3` nas pracas (o pacote que, apesar do nome, so
	# tem arvore, banco, poste e coreto — ver CityBlocks._arvores_realistas).
	# O segundo tambem traz banco e poste, entao a altura minima e o que separa
	# arvore de mobiliario.
	var eh_natureza := path.contains("nature-megakit") \
		and (path.contains("tree") or path.contains("pine"))
	var eh_praca := path.contains("european_buildings_pack3")
	if eh_natureza or eh_praca:
		var h := _world_aabb(node).size.y
		if h > (3.0 if eh_praca else 0.5):
			var p: Vector3 = (node as Node3D).global_position if node is Node3D else Vector3.ZERO
			var lugar := "campo" if maxf(absf(p.x), absf(p.z)) > 300.0 else "cidade"
			(out[lugar] as Array).append(h)
		return
	for c in node.get_children():
		_coletar_arvores(c, out)

# ------------------------------------------------------------------ utilidade

func _tipo(node: Node3D) -> String:
	var n := String(node.name)
	if n.begins_with("@"):
		# "@Node3D@57" nao diz nada; o tipo vem do primeiro filho nomeado.
		for c in node.get_children():
			if not String(c.name).begins_with("@"):
				return "?" + String(c.name)
		return "?"
	# "Semaforo2" -> "Semaforo"
	while n.length() > 0 and n[n.length() - 1].is_valid_int():
		n = n.substr(0, n.length() - 1)
	return n

func _pacote(node: Node) -> String:
	var path := node.scene_file_path
	if path == "":
		for c in node.get_children():
			var p := _pacote(c)
			if p != "?":
				return p
		return "?"
	var partes := path.split("/")
	return "/".join(partes.slice(2, 4)) if partes.size() > 4 else path

## Distancia do ponto ate o eixo de rua mais proximo (a grade e ortogonal, entao
## e a menor distancia a uma das linhas).
func _dist_ao_eixo(p: Vector3) -> float:
	var eixos_x: Array = streets.get("streets_x")   # ruas leste-oeste (valor em Z)
	var eixos_z: Array = streets.get("streets_z")   # ruas norte-sul (valor em X)
	var melhor := INF
	for z: float in eixos_x:
		melhor = minf(melhor, absf(p.z - z))
	for x: float in eixos_z:
		melhor = minf(melhor, absf(p.x - x))
	return melhor

func _find_by_script(root: Node, file_name: String) -> Node:
	var s: Script = root.get_script() as Script
	if s != null and s.resource_path.ends_with(file_name):
		return root
	for c in root.get_children():
		var f := _find_by_script(c, file_name)
		if f:
			return f
	return null

func _world_aabb(root: Node) -> AABB:
	var box := AABB()
	var first := true
	for mi in _all_meshes(root):
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var world := mi.global_transform * mi.mesh.get_aabb()
		if first:
			box = world
			first = false
		else:
			box = box.merge(world)
	return box

func _all_meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		out.append(node as MeshInstance3D)
	for c in node.get_children():
		out.append_array(_all_meshes(c))
	return out
