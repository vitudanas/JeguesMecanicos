extends Node
## BURACOS na fileira de fachadas.
##
## O usuario notou vao entre construcoes em alguns quarteiroes e perguntou se era
## de proposito. Este teste responde com numero em vez de opiniao: percorre cada
## borda de quarteirao, projeta as construcoes daquela borda sobre o eixo da rua
## e mede os trechos SEM ninguem.
##
## Um pouco de vao e normal e ate desejavel (cidade de verdade tem terreno
## baldio, entrada de garagem, recuo). O que denuncia geracao mal resolvida e
## vao GRANDE e frequente — a fileira parece interrompida.
##
##   godot --headless --path . tools/verify/gaps_test.tscn

## Vao a partir do qual conta como buraco (m). Abaixo disso e recuo entre lotes.
const BURACO := 6.0

var town: Node3D

func _ready() -> void:
	town = (load("res://scenes/world/Town.tscn") as PackedScene).instantiate()
	add_child(town)
	await get_tree().process_frame
	_rodar()
	get_tree().quit()

func _caixa(body: Node3D) -> Rect2:
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

## Ha um lote com funcao (praca/posto/estacionamento/feira) neste quarteirao?
func _lote_especial(x0: float, x1: float, z0: float, z1: float) -> bool:
	for g in ["lote_praca", "lote_posto", "lote_estacionamento", "lote_feira"]:
		for n: Node3D in get_tree().get_nodes_in_group(g):
			var p := n.global_position
			if p.x > x0 - 2.0 and p.x < x1 + 2.0 and p.z > z0 - 2.0 and p.z < z1 + 2.0:
				return true
	return false

func _rodar() -> void:
	var blocos := town.get_node("CityBlocks")
	var ruas_x: Array = blocos.streets_x
	var ruas_z: Array = blocos.streets_z
	var recuo: float = blocos.road_clearance

	var caixas: Array[Rect2] = []
	for b in get_tree().get_nodes_in_group("city_building"):
		var r := _caixa(b)
		if r.size.x > 0.0:
			caixas.append(r)
	print("predios: %d | recuo da fachada: %.1f m" % [caixas.size(), recuo])

	# Faixa junto de cada borda: quem encosta na calcada daquele lado.
	var faixa := 14.0
	var total_borda := 0.0
	var total_vazio := 0.0
	var buracos: Array[float] = []
	var por_quarteirao := {}
	var vazias: Array = []   # bordas COMPLETAMENTE vazias

	for j in range(ruas_x.size() - 1):
		for i in range(ruas_z.size() - 1):
			var x0: float = float(ruas_z[i]) + recuo
			var x1: float = float(ruas_z[i + 1]) - recuo
			var z0: float = float(ruas_x[j]) + recuo
			var z1: float = float(ruas_x[j + 1]) - recuo
			if x1 - x0 < 2.0 or z1 - z0 < 2.0:
				continue
			var chave := "%d|%d" % [i, j]
			# Praca, posto, estacionamento e feira nao tem fachada — e nao devem
			# ter. Sem pular, cada lote especial aparece como 4 bordas vazias e
			# infla o numero: eram 40 "bordas vazias" que na verdade eram 10
			# lotes com funcao.
			if _lote_especial(x0, x1, z0, z1):
				continue
			for borda in range(4):
				var comp: float
				var ocupado: Array = []
				for r in caixas:
					var dentro: bool
					var a: float
					var b2: float
					match borda:
						0:   # sul: z encostado em z0
							dentro = r.position.y < z0 + faixa and r.end.y > z0 - 1.0 \
								and r.end.x > x0 and r.position.x < x1
							a = r.position.x
							b2 = r.end.x
						1:   # norte
							dentro = r.end.y > z1 - faixa and r.position.y < z1 + 1.0 \
								and r.end.x > x0 and r.position.x < x1
							a = r.position.x
							b2 = r.end.x
						2:   # oeste
							dentro = r.position.x < x0 + faixa and r.end.x > x0 - 1.0 \
								and r.end.y > z0 and r.position.y < z1
							a = r.position.y
							b2 = r.end.y
						_:   # leste
							dentro = r.end.x > x1 - faixa and r.position.x < x1 + 1.0 \
								and r.end.y > z0 and r.position.y < z1
							a = r.position.y
							b2 = r.end.y
					if dentro:
						ocupado.append([maxf(a, x0 if borda < 2 else z0),
							minf(b2, x1 if borda < 2 else z1)])
				comp = (x1 - x0) if borda < 2 else (z1 - z0)
				var ini: float = x0 if borda < 2 else z0
				total_borda += comp
				# Une os intervalos e mede o que sobrou.
				ocupado.sort_custom(func(p, q): return p[0] < q[0])
				var cursor := ini
				var vazio := 0.0
				for iv: Array in ocupado:
					if iv[0] > cursor:
						var g: float = iv[0] - cursor
						vazio += g
						if g >= BURACO:
							buracos.append(g)
							por_quarteirao[chave] = int(por_quarteirao.get(chave, 0)) + 1
					cursor = maxf(cursor, iv[1])
				var fim: float = ini + comp
				if fim > cursor:
					var g2: float = fim - cursor
					vazio += g2
					if g2 >= BURACO:
						buracos.append(g2)
						por_quarteirao[chave] = int(por_quarteirao.get(chave, 0)) + 1
				total_vazio += vazio
				# Guarda os piores com contexto, pra dizer ONDE e em que tipo de
				# quadra — sem isso so da pra adivinhar a causa.
				if vazio > comp * 0.9:
					vazias.append([comp, x1 - x0, z1 - z0, borda,
						(x0 + x1) * 0.5, (z0 + z1) * 0.5])

	buracos.sort()
	var soma := 0.0
	for g in buracos:
		soma += g
	print("\nborda de quarteirao somada: %.0f m" % total_borda)
	print("  ocupada por fachada:      %.0f m (%.0f%%)" % [
		total_borda - total_vazio, 100.0 * (total_borda - total_vazio) / maxf(total_borda, 1.0)])
	print("  vazia:                    %.0f m (%.0f%%)" % [
		total_vazio, 100.0 * total_vazio / maxf(total_borda, 1.0)])
	print("\nburacos >= %.0f m: %d | somam %.0f m (%.0f%% da borda)" % [
		BURACO, buracos.size(), soma, 100.0 * soma / maxf(total_borda, 1.0)])
	if not buracos.is_empty():
		print("  maior %.1f m | mediana %.1f m" % [
			buracos[buracos.size() - 1], buracos[buracos.size() / 2]])
	var quadras_com := por_quarteirao.size()
	print("  quarteiroes com pelo menos um buraco: %d de %d" % [
		quadras_com, (ruas_x.size() - 1) * (ruas_z.size() - 1)])

	print("\nBORDAS COMPLETAMENTE VAZIAS: %d" % vazias.size())
	var por_tamanho := {}
	var nomes := ["sul", "norte", "oeste", "leste"]
	for v: Array in vazias:
		var key := "%.0f x %.0f" % [v[1], v[2]]
		por_tamanho[key] = int(por_tamanho.get(key, 0)) + 1
	for k: String in por_tamanho:
		print("  miolo %s m -> %d borda(s) vazia(s)" % [k, por_tamanho[k]])
	for i in range(mini(6, vazias.size())):
		var v: Array = vazias[i]
		print("    %-6s de %5.1f m no quarteirao (%.0f, %.0f), miolo %.0f x %.0f" % [
			nomes[int(v[3])], v[0], v[4], v[5], v[1], v[2]])
