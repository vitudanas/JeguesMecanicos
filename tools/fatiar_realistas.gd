extends Node
## Fatia os pacotes crus de `assets/realistas/` em PREDIOS individuais.
##
## POR QUE E PRECISO FATIAR. Quase nenhum pacote baixado e "um predio": o
## brownstone sao 70 malhas espalhadas por 319 m (um quarteirao inteiro), o
## european_pack3 sao 1427 malhas. O `CityBlocks` instancia UMA cena por lote,
## entao um pacote inteiro num lote so poria um bairro dentro de um terreno.
##
## E nenhum vem em metros: a caixa inteira varia de 4,8 m (village) a 69 km
## (city_pack_7). Cada pacote precisa do proprio fator, medido — nao existe um
## `building_scale` global que sirva pros 15, ao contrario do kit do Kenney.
##
## DUAS PASSADAS, de proposito:
##   godot --headless --path . tools/fatiar_realistas.tscn -- medir
##       agrupa e IMPRIME o que achou, sem gravar nada. E daqui que sai o fator
##       de escala de cada pacote (a tabela ESCALA abaixo).
##   godot --headless --path . tools/fatiar_realistas.tscn -- fatiar
##       grava as cenas em assets/realistas_prontos/.

const ORIGEM := "res://assets/realistas"
const DESTINO := "res://assets/realistas_prontos"

## Folga pra duas malhas contarem como o MESMO predio, como fracao da malha
## MEDIANA do pacote — e nao da cena inteira, que foi a primeira versao e nao
## funciona: num pacote de 69 km, 0,4% da cena da 276 m de cola e o arquivo
## inteiro vira uma peca so. O tamanho de uma malha, esse sim, acompanha a
## escala em que o pacote foi modelado.
const COLA := 0.05
var _cola := COLA

## ALTURA MEDIANA ALVO, em metros, de cada pacote — daqui sai a escala:
## `escala = ALVO / altura_mediana_medida`. Os valores saíram da passada de
## medir, com 3 m por andar como referência, e são conferidos na folha de
## contato (um pacote fora de escala é o defeito mais visível de todos).
##
## Pacote FORA da lista é ignorado de propósito. Sete ficaram de fora, e a razão
## é diferente em cada um — quatro por não dar pra fatiar por código:
##   city_pack_7             105 malhas agrupadas POR MATERIAL, cada uma com
##                           vários prédios fundidos, espalhadas por 69 km.
##   factory_low_poly        4 malhas de 10 km.
##   old_industrial_building 5 malhas de 3,4 km.
##   warehouses              UMA malha de 246 m com vários galpões fundidos.
## Esses quatro precisariam do Blender; ficam no disco, fora do jogo.
##
## E três que fatiam bem mas NÃO SERVEM — os três só apareceram na folha de
## contato, nenhum número os denunciaria:
##   low_poly_city_buildings  a "peça" é uma MAQUETE de skyline inteira fundida
##                            (dezenas de torres num bloco só).
##   simple_low_poly_village  cabanas medievais de palha: estilizadas, e mistura
##                            de estilo é o defeito que este projeto já corrigiu
##                            duas vezes (changelog 2026-08-02).
##   european_buildings_pack3 não são prédios: é ÁRVORE, banco, poste, coreto e
##                            ponte. Vão pra decoração de praça, não pra lote —
##                            ver CityBlocks.plaza_prop_scenes.
const ALVO_ALTURA := {
	"bordeaux_flat_1_corner_france": 18.4,
	"bordeaux_flat_2_corner_france": 18.6,
	"brownstone_building_set": 17.8,
	"downtown_buildings": 29.9,
	"european_buildings_pack3": 11.5,
	"industrial_buildings_sets": 12.5,
	"new_york_buildings": 21.0,
	"old_building_pack_lowpoly": 12.0,
	"tenement_house": 17.0,
}

## Peça menor que isto (depois da escala) não é prédio, é prop solto — poste,
## lixeira, pedaço de calçada que veio junto no pacote.
const MIN_LARGURA := 3.5
const MIN_ALTURA := 3.0
## E peça maior que isto não cabe em lote nenhum: é uma quadra inteira que o
## agrupamento não conseguiu separar.
const MAX_LARGURA := 60.0

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var modo: String = args[0] if args.size() > 0 else "medir"
	if args.size() > 1:
		_cola = float(args[1])
	var dir := DirAccess.open(ORIGEM)
	if dir == null:
		print("sem %s" % ORIGEM)
		get_tree().quit(1)
		return
	for pasta in dir.get_directories():
		if pasta.begins_with("_"):
			continue
		_processar(pasta, modo)
	if modo != "medir":
		_gravar_catalogo()
	get_tree().quit()

## Escreve um catálogo com os caminhos LITERAIS do que foi fatiado.
##
## A alternativa era varrer o diretório em runtime, e ela tem um defeito que já
## quebrou este jogo: o auditor do `.pck` acha dependência procurando literais
## `res://` no código, então um caminho montado por varredura fica INVISÍVEL pra
## ele — a cidade nasceria vazia só no binário exportado, sem nenhum erro em
## desenvolvimento (é o irmão do bug do `SettingsMenu.tscn`, 2026-08-04).
func _gravar_catalogo() -> void:
	var d := DirAccess.open(DESTINO)
	if d == null:
		return
	var por_pacote := {}
	for f in d.get_files():
		if not f.ends_with(".scn"):
			continue
		var pacote := f.substr(0, f.length() - 7)
		if not por_pacote.has(pacote):
			por_pacote[pacote] = []
		(por_pacote[pacote] as Array).append(f)
	var nomes := por_pacote.keys()
	nomes.sort()
	var linhas := PackedStringArray()
	linhas.append("class_name CatalogoRealistas")
	linhas.append("extends RefCounted")
	linhas.append("## GERADO por tools/fatiar_realistas.gd — nao editar na mao.")
	linhas.append("##")
	linhas.append("## Caminhos literais de proposito: e assim que o auditor do")
	linhas.append("## `.pck` (tools/verify/pack_audit.py) enxerga estas cenas.")
	linhas.append("")
	linhas.append("const POR_PACOTE := {")
	for nome: String in nomes:
		var arqs: Array = por_pacote[nome]
		arqs.sort()
		linhas.append("\t\"%s\": [" % nome)
		for f: String in arqs:
			linhas.append("\t\t\"%s/%s\"," % [DESTINO, f])
		linhas.append("\t],")
	linhas.append("}")
	linhas.append("")
	var arq := FileAccess.open("%s/catalogo.gd" % DESTINO, FileAccess.WRITE)
	if arq == null:
		print("nao consegui gravar o catalogo")
		return
	arq.store_string("\n".join(linhas))
	arq.close()
	print("catalogo: %d pacote(s)" % nomes.size())

func _processar(pasta: String, modo: String) -> void:
	var caminho := "%s/%s/scene.gltf" % [ORIGEM, pasta]
	if not ResourceLoader.exists(caminho):
		print("%-34s (sem scene.gltf)" % pasta)
		return
	var cena := load(caminho) as PackedScene
	if cena == null:
		print("%-34s NAO CARREGOU" % pasta)
		return
	var raiz := cena.instantiate()
	add_child(raiz)

	var malhas: Array = []              # [MeshInstance3D, AABB de mundo]
	_coletar(raiz, malhas)
	if malhas.is_empty():
		print("%-34s sem malha" % pasta)
		raiz.queue_free()
		return

	var tams: Array[float] = []
	for m in malhas:
		var s: Vector3 = (m[1] as AABB).size
		tams.append(maxf(s.x, s.z))
	tams.sort()
	var grupos := _agrupar(malhas, tams[tams.size() / 2] * _cola)

	# Estatistica das alturas: e dela que sai o fator de escala do pacote.
	var alturas: Array[float] = []
	var larguras: Array[float] = []
	for g: Array in grupos:
		var b: AABB = _caixa(g, malhas)
		alturas.append(b.size.y)
		larguras.append(maxf(b.size.x, b.size.z))
	alturas.sort()
	larguras.sort()
	var med_h: float = alturas[alturas.size() / 2]
	var med_w: float = larguras[larguras.size() / 2]
	if modo == "medir":
		print("%-34s %4d pecas | altura med %8.3f (min %8.3f max %8.3f) | largura med %8.3f" % [
			pasta, grupos.size(), med_h, alturas[0], alturas[alturas.size() - 1], med_w])
		raiz.queue_free()
		return

	if not ALVO_ALTURA.has(pasta):
		print("%-34s PULADO (nao da pra fatiar por codigo)" % pasta)
		raiz.queue_free()
		return
	var escala: float = float(ALVO_ALTURA[pasta]) / maxf(med_h, 0.0001)
	DirAccess.make_dir_recursive_absolute(DESTINO)
	var gravados := 0
	var recusados := 0
	for g: Array in grupos:
		if _gravar(pasta, gravados, g, malhas, escala):
			gravados += 1
		else:
			recusados += 1
	print("%-34s escala %7.3f | %2d gravados, %2d recusados (fora de tamanho)" % [
		pasta, escala, gravados, recusados])
	raiz.queue_free()

## Grava um grupo como uma cena de predio. Retorna false se a peca nao for um
## predio (prop pequeno demais, ou quadra inteira que nao separou).
##
## A escala e a rotacao sao ASSADAS nos filhos, e o no raiz fica na identidade.
## Nao e detalhe: o `AutoCollisionBody` escreve `visual.scale` no no que
## instancia, entao escala guardada na raiz seria sobrescrita em silencio.
func _gravar(pasta: String, indice: int, grupo: Array, malhas: Array,
		escala: float) -> bool:
	var caixa := _caixa(grupo, malhas)
	var giro := _giro_da_fachada(grupo, malhas)
	# Largura e profundidade DEPOIS do giro: um quarto de volta troca X por Z, e
	# medir antes faria o filtro de tamanho julgar o prédio deitado.
	var trocou: bool = absf(sin(giro)) > 0.5
	var larg: float = (caixa.size.z if trocou else caixa.size.x) * escala
	var prof: float = (caixa.size.x if trocou else caixa.size.z) * escala
	var alt: float = caixa.size.y * escala
	if larg < MIN_LARGURA or alt < MIN_ALTURA or prof < 1.0:
		return false
	if larg > MAX_LARGURA:
		return false

	# Origem no CENTRO da planta, no chao — o que o CityBlocks espera de qualquer
	# construcao.
	var origem := Vector3(caixa.get_center().x, caixa.position.y, caixa.get_center().z)
	var ajuste := Transform3D(Basis(Vector3.UP, giro).scaled(Vector3.ONE * escala),
		Vector3.ZERO)

	var raiz := Node3D.new()
	raiz.name = "Predio"
	for i in grupo:
		var mi: MeshInstance3D = malhas[i][0]
		var copia := MeshInstance3D.new()
		copia.name = mi.name
		copia.mesh = mi.mesh
		for s in range(mi.get_surface_override_material_count()):
			copia.set_surface_override_material(s, mi.get_surface_override_material(s))
		var rel := mi.global_transform
		rel.origin -= origem
		copia.transform = ajuste * rel
		raiz.add_child(copia)
		copia.owner = raiz

	var cena := PackedScene.new()
	if cena.pack(raiz) != OK:
		raiz.free()
		return false
	# `.scn` (binario), e nao `.tscn`: a malha vai EMBUTIDA na cena — o que e o
	# que queremos, porque assim o predio nao depende mais do `.gltf` cru — e em
	# texto cada vertice vira um numero escrito por extenso. O bordeaux sozinho
	# deu 15 MB de `.tscn` contra 3,2 MB do pacote inteiro de origem.
	var alvo := "%s/%s_%02d.scn" % [DESTINO, pasta, indice]
	var erro := ResourceSaver.save(cena, alvo)
	raiz.free()
	return erro == OK

## Quanto girar o predio pra FACHADA olhar pro -Z, que e o lado que o
## `CityBlocks` vira pra rua.
##
## A primeira versao so punha o lado mais LONGO em X, e metade dos predios saiu
## de COSTAS pra rua — a folha de contato do brownstone mostrou fileira de parede
## de tijolo lisa onde devia ter janela e escada de entrada. Largura e
## profundidade nao dizem onde e a frente.
##
## O sinal usado e a DENSIDADE DE GEOMETRIA por lado: fachada tem janela, cornija
## e portal modelados, fundo e uma parede quase chapada. Contar vertice por
## direcao separa os dois sem precisar de textura nem de nome de material — num
## brownstone tipico a frente tem varias vezes mais vertice que os fundos.
func _giro_da_fachada(grupo: Array, malhas: Array) -> float:
	# Ordem casada com os giros: +X, -X, +Z, -Z.
	var lados := [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]
	var peso := [0.0, 0.0, 0.0, 0.0]
	for i in grupo:
		var mi: MeshInstance3D = malhas[i][0]
		var base := mi.global_transform.basis
		var mesh: Mesh = mi.mesh
		for s in range(mesh.get_surface_count()):
			var arr := mesh.surface_get_arrays(s)
			if arr.size() <= Mesh.ARRAY_NORMAL or arr[Mesh.ARRAY_NORMAL] == null:
				continue
			var normais: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			# Malha densa nao precisa de todo vertice pra dizer pra onde ela olha.
			var passo: int = maxi(1, normais.size() / 4000)
			for k in range(0, normais.size(), passo):
				var n: Vector3 = (base * normais[k]).normalized()
				# So o que olha pros lados: telhado e chao nao dizem nada aqui.
				if absf(n.y) > 0.6:
					continue
				for d in range(4):
					if n.dot(lados[d]) > 0.72:
						peso[d] += 1.0
						break
	var melhor := 0
	for d in range(1, 4):
		if peso[d] > peso[melhor]:
			melhor = d
	# Giro que leva o lado escolhido pro -Z.
	return [PI * 0.5, -PI * 0.5, PI, 0.0][melhor]

## Une malhas cujas pegadas em XZ se tocam (com folga). Uniao por busca simples:
## a quantidade de pecas por pacote e pequena o bastante pra nao precisar de
## estrutura melhor, e um algoritmo simples aqui e mais facil de conferir.
func _agrupar(malhas: Array, folga: float) -> Array:
	var pai: Array[int] = []
	for i in range(malhas.size()):
		pai.append(i)
	for i in range(malhas.size()):
		for j in range(i + 1, malhas.size()):
			if _perto(malhas[i][1], malhas[j][1], folga):
				var a := _raiz(pai, i)
				var b := _raiz(pai, j)
				if a != b:
					pai[a] = b
	var mapa := {}
	for i in range(malhas.size()):
		var r := _raiz(pai, i)
		if not mapa.has(r):
			mapa[r] = []
		(mapa[r] as Array).append(i)
	var saida: Array = []
	for k in mapa:
		saida.append(mapa[k])
	return saida

func _raiz(pai: Array[int], i: int) -> int:
	var r := i
	while pai[r] != r:
		r = pai[r]
	while pai[i] != r:
		var n := pai[i]
		pai[i] = r
		i = n
	return r

## So XZ: dois andares do mesmo predio nao se tocam em Y mas sao o mesmo predio.
func _perto(a: AABB, b: AABB, folga: float) -> bool:
	return a.position.x - folga < b.position.x + b.size.x \
		and b.position.x - folga < a.position.x + a.size.x \
		and a.position.z - folga < b.position.z + b.size.z \
		and b.position.z - folga < a.position.z + a.size.z

func _caixa(grupo: Array, malhas: Array) -> AABB:
	var b: AABB = malhas[grupo[0]][1]
	for i in grupo:
		b = b.merge(malhas[i][1])
	return b

func _coletar(no: Node, saida: Array) -> void:
	if no is MeshInstance3D and (no as MeshInstance3D).mesh:
		var mi := no as MeshInstance3D
		saida.append([mi, mi.global_transform * mi.get_aabb()])
	for c in no.get_children():
		_coletar(c, saida)
