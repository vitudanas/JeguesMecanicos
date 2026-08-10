extends Node
## Mede cada personagem baixado e GERA o catalogo que o jogo le.
##
## Existe porque "usar todos" so escala se ninguem precisar editar codigo por
## modelo. Com ~45 personagens, escrever uma linha a mao em `Appearance.MODELS`
## pra cada um seria 45 chances de errar a altura — e altura errada nao acusa em
## lugar nenhum, o personagem so nasce do tamanho errado (foi assim que os NPCs
## ficaram com 3,76 m por meses).
##
## O que ele mede em cada arquivo, e por que cada medida importa:
##
##   * ALTURA — converte "quero 1,80 m" em escala. Cada pacote vem numa escala
##     propria (medido: de 0,7 a 208 unidades).
##   * ESQUELETO — sem ossos o modelo e ESTATUA: nao anda. Dos 7 baixados em
##     2026-08-09, 6 estavam assim.
##   * ANIMACOES PROPRIAS — quem tem anda com as suas; quem so tem esqueleto
##     precisa da UAL1 por cima, e ai o esqueleto tem que bater.
##   * DEITADO — modelo exportado com Z pra cima entra de bruco no jogo.
##   * FACES — NPC aparece 72 vezes na tela e o jogador uma. E o numero que diz
##     onde cada modelo serve.
##
## MEDIR A ALTURA PELA CAIXA DA MALHA NAO FUNCIONA, e essa foi a causa de quase
## todo defeito da folha de contato de 2026-08-10 (personagem microscopico,
## gigante e deitado, com o catalogo jurando 1,80 m pra todos). Numa malha
## SKINADA os vertices ficam no espaco em que a malha foi autorada, e quem leva
## eles pro espaco do esqueleto e a bind pose — entao `mesh.get_aabb()` pode
## estar em outra unidade e ate em outro eixo que o resultado na tela. Medido
## nos recebidos: `casual_woman_in_brown_dress` da 0,019 na caixa da malha e
## 1,899 depois do skin (98x), e `animated_man` da 1471 contra 114 (13x). Por
## isso a altura sai do vertice JA LEVADO pelo skin — que e o que o
## renderizador desenha.
##
## Roda com:
##   godot --headless --path . tools/preparar_personagens.tscn

const PASTA := "res://assets/personagens"
const SAIDA := "res://assets/personagens/catalogo.gd"

## Acima disso o modelo so entra como opcao de JOGADOR (um na tela), nao como
## pedestre (72 na tela).
const FACES_PARA_NPC := 18000

## Modelos exportados olhando pro -Z. O jogo assume +Z (por isso o `PlayerVisual`
## gira 180); sem o giro extra estes andam DE COSTAS — o mesmo defeito que os
## carros de IA e os pedestres ja tiveram.
##
## Lista escrita a mao, e nao medida, porque nao ha sinal geometrico confiavel
## pra isso (ver o cabecalho de `MedirPersonagem.gd`: o teste pelo pe erra nos
## dois sentidos). Cada id aqui foi conferido na FOLHA DE CONTATO, onde o
## personagem aparece de costas pra camera. Ao acrescentar personagem novo, olhe
## a folha: quem sair mostrando a nuca entra aqui.
const DE_COSTAS: Array[String] = [
	"low_poly_female_lia",
	"old_man_spice_animated",
]

## Reprovados na FOLHA DE CONTATO, por defeito que nenhuma medida pega.
##
## As regras automaticas de `MedirPersonagem` cobrem o que da pra medir (sem
## osso, varios esqueletos, sentado, cenario junto). Isto aqui e o resto: cada
## um foi visto na foto, e o motivo fica escrito porque daqui a duas sessoes
## ninguem lembra por que este modelo especifico esta de fora.
const NAO_SERVE: Dictionary = {
	"kindred_league_of_legends_rigged":
		"na foto sai minusculo em cima de um pedestal, com uma malha de contorno solta",
	"danmachi_hestia":
		"vem com um disco de grama nos pes — pequeno demais pra regra de cenario pegar",
	"tomoko_kuroki_watamote":
		"nao aparece na foto: renderiza como uma sombra escura, sem material visivel",
}

var _problemas: Array[String] = []

func _ready() -> void:
	var arquivos := _achar_modelos(PASTA)
	print("=== PREPARAR PERSONAGENS ===")
	if arquivos.is_empty():
		print("nenhum personagem em %s" % PASTA)
		print("  (baixe em glTF, largue os .zip na raiz e rode:")
		print("   tools/receber_modelos.sh personagens)")
		get_tree().quit(0)
		return
	print("%d arquivo(s) encontrados\n" % arquivos.size())

	var entradas: Array[Dictionary] = []
	for caminho: String in arquivos:
		var d := _medir(caminho)
		if d.is_empty():
			continue
		entradas.append(d)
		print("%-44s %8.2f (desenho %5.1fx) | %4d ossos | %2d anim | %6d faces | %s%s"
			% [d["id"], d["altura"], d["desenho"], d["ossos"], d["animacoes"],
				d["faces"], d["serve"], "  DEITADO" if d["deitado"] else ""])
		if not bool(d["jogavel"]):
			_problemas.append("%s: %s" % [d["id"], d["motivo"]])
		if str(d["suspeita"]) != "":
			_problemas.append("%s: medida duvidosa — %s (usei a dos ossos)"
				% [d["id"], d["suspeita"]])

	_gerar_catalogo(entradas)
	var jogaveis := 0
	for e: Dictionary in entradas:
		if bool(e["jogavel"]):
			jogaveis += 1
	print("\n%d de %d entram como JOGAVEL" % [jogaveis, entradas.size()])
	if not _problemas.is_empty():
		print("\navisos:")
		for p in _problemas:
			print("  - " + p)
	print("\ncatalogo gerado em %s" % SAIDA)
	print("OLHE a folha de contato antes de confiar na orientacao de cada um:")
	print("  godot --path . tools/verify/personagens_sheet.tscn")
	get_tree().quit(0)

## Procura `scene.gltf`/`.glb` em cada subpasta (o formato que o Sketchfab
## entrega).
func _achar_modelos(raiz: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(raiz)
	if dir == null:
		return out
	dir.list_dir_begin()
	var nome := dir.get_next()
	while nome != "":
		if dir.current_is_dir() and not nome.begins_with("_") and not nome.begins_with("."):
			for candidato: String in ["scene.gltf", "scene.glb", "scene.fbx"]:
				var caminho := "%s/%s/%s" % [raiz, nome, candidato]
				if ResourceLoader.exists(caminho):
					out.append(caminho)
					break
		nome = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out

func _medir(caminho: String) -> Dictionary:
	var cena := load(caminho) as PackedScene
	if cena == null:
		_problemas.append("%s: nao carregou" % caminho)
		return {}
	var inst := cena.instantiate() as Node3D
	if inst == null:
		return {}
	add_child(inst)

	var medida := MedirPersonagem.medir(inst)
	var ossos: int = medida["ossos"]
	var animacoes := 0
	var ap := _achar_player(inst)
	if ap:
		for lib_name in ap.get_animation_library_list():
			animacoes += ap.get_animation_library(lib_name).get_animation_list().size()
	var faces := 0
	var formas: Array[String] = []
	for mi in _malhas(inst):
		if mi.mesh:
			for s in range(mi.mesh.get_surface_count()):
				faces += mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX].size() / 3
			# Shape keys DO MODELO. Os dois personagens nativos tem as sete do
			# `tools/build_characters.py`; modelo de terceiro em geral nao tem
			# nenhuma, e a tela precisa saber disso pra nao mostrar slider morto.
			for b in range(mi.mesh.get_blend_shape_count()):
				var nome_forma := str(mi.mesh.get_blend_shape_name(b))
				if not formas.has(nome_forma):
					formas.append(nome_forma)

	var pasta := caminho.get_base_dir().get_file()
	inst.queue_free()
	var motivo := str(medida["motivo"])
	if motivo == "" and NAO_SERVE.has(pasta):
		motivo = str(NAO_SERVE[pasta])
	return {
		"id": pasta,
		"caminho": caminho,
		"altura": medida["altura"],
		"desenho": float(medida["maior_desenho"]) / maxf(float(medida["altura"]), 0.001),
		"ossos": ossos,
		"animacoes": animacoes,
		"faces": faces,
		"deitado": medida["deitado"],
		"de_costas": DE_COSTAS.has(pasta),
		"formas": formas,
		"jogavel": motivo == "",
		"motivo": motivo,
		"suspeita": medida["suspeita"],
		"serve": ("jogador + NPC" if faces <= FACES_PARA_NPC else "jogador") \
			if motivo == "" else "cenario",
	}

## O catalogo sai com caminhos LITERAIS de proposito: e assim que o auditor do
## `.pck` (tools/verify/pack_audit.py) enxerga estas cenas. Caminho montado por
## varredura em runtime fica invisivel pra ele, e o jogo nasceria sem
## personagem SO no binario exportado.
func _gerar_catalogo(entradas: Array[Dictionary]) -> void:
	var texto := """class_name CatalogoPersonagens
extends RefCounted
## GERADO por tools/preparar_personagens.gd — nao editar na mao.
##
## Cada entrada traz a altura MEDIDA do arquivo (e ela que converte "quero
## 1,80 m" em escala), quantos ossos e quantas animacoes proprias.
##
## `jogavel` e falso pra quem nao e UMA pessoa de pe: estatua sem osso, cena com
## varios personagens dentro, ou modelo que vem sentado/com cenario junto. Esses
## continuam catalogados (servem de cenario), mas fora da lista do menu.

const PERSONAGENS: Array[Dictionary] = [
"""
	for e: Dictionary in entradas:
		texto += '\t{"id": "%s", "rotulo": "%s", "caminho": "%s",\n' % [
			e["id"], _rotulo(str(e["id"])), e["caminho"]]
		texto += '\t\t"altura_modelo": %.4f, "ossos": %d, "animacoes": %d,\n' % [
			e["altura"], e["ossos"], e["animacoes"]]
		var lista_formas: Array = e.get("formas", [])
		var aspas: Array[String] = []
		for f: String in lista_formas:
			aspas.append('"%s"' % f)
		texto += '\t\t"faces": %d, "deitado": %s, "de_costas": %s, "jogavel": %s,\n' % [
			e["faces"], "true" if e["deitado"] else "false",
			"true" if e["de_costas"] else "false",
			"true" if e["jogavel"] else "false"]
		if str(e["motivo"]) != "":
			texto += '\t\t"motivo": "%s",\n' % e["motivo"]
		texto += '\t\t"formas": [%s]},\n' % ", ".join(PackedStringArray(aspas))
	texto += "]\n"
	var f := FileAccess.open(SAIDA, FileAccess.WRITE)
	if f == null:
		_problemas.append("nao consegui gravar %s" % SAIDA)
		return
	f.store_string(texto)
	f.close()

## "casual_man_character" -> "Casual Man Character"
func _rotulo(id: String) -> String:
	var partes := id.split("_")
	var out: Array[String] = []
	for p: String in partes:
		if p.length() > 0:
			out.append(p.substr(0, 1).to_upper() + p.substr(1))
	return " ".join(PackedStringArray(out))

# ------------------------------------------------------------------ utilidade
##
## A medida de verdade (altura, orientacao, se e uma pessoa de pe) mora em
## `tools/MedirPersonagem.gd`, com dono unico: a folha de contato le a MESMA
## medida, senao as duas contam historias diferentes sobre o mesmo arquivo.

func _malhas(node: Node) -> Array[MeshInstance3D]:
	return MedirPersonagem.malhas_de(node)

func _achar_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for c in node.get_children():
		var f := _achar_player(c)
		if f:
			return f
	return null
