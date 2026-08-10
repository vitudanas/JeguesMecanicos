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
##     propria (medido nos 7 primeiros: de 1,0 a 145 unidades de caixa).
##   * ESQUELETO — sem ossos o modelo e ESTATUA: nao anda. Dos 7 baixados em
##     2026-08-09, 6 estavam assim.
##   * ANIMACOES PROPRIAS — quem tem anda com as suas; quem so tem esqueleto
##     precisa da UAL1 por cima, e ai o esqueleto tem que bater.
##   * DEITADO — modelo exportado com Z pra cima entra de bruco no jogo. Se a
##     caixa e mais comprida em Z que em Y, e isso.
##   * FACES — NPC aparece 72 vezes na tela e o jogador uma. E o numero que diz
##     onde cada modelo serve.
##
## Roda com:
##   godot --headless --path . tools/preparar_personagens.tscn

const PASTA := "res://assets/personagens"
const SAIDA := "res://assets/personagens/catalogo.gd"

## Acima disso o modelo so entra como opcao de JOGADOR (um na tela), nao como
## pedestre (72 na tela).
const FACES_PARA_NPC := 18000

## Altura humana plausivel. Fora disso e quase certo que o arquivo esta em outra
## unidade (centimetro, polegada) — o que nao impede de usar, porque a escala
## sai da altura medida, mas vale sair no relatorio.
const ALTURA_MIN := 1.20
const ALTURA_MAX := 2.30

var _linhas: Array[String] = []
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
		print("%-38s %5.2f m | %3d ossos | %2d anim | %6d faces | %s%s"
			% [d["id"], d["altura"], d["ossos"], d["animacoes"], d["faces"],
				d["serve"], "  DEITADO" if d["deitado"] else ""])
		if d["ossos"] == 0:
			_problemas.append("%s: sem esqueleto — so serve de estatua" % d["id"])
		elif d["altura"] < ALTURA_MIN or d["altura"] > ALTURA_MAX:
			_problemas.append("%s: %.2f m no arquivo (fora do humano; a escala corrige, mas confira)"
				% [d["id"], d["altura"]])

	_gerar_catalogo(entradas)
	print("\n%d de %d entram como JOGAVEL" % [
		entradas.filter(func(e): return e["ossos"] > 0).size(), entradas.size()])
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

	var caixa := _aabb(inst)
	var ossos := 0
	var skel := CharacterVisual.find_skeleton(inst)
	if skel:
		ossos = skel.get_bone_count()
	var animacoes := 0
	var ap := _achar_player(inst)
	if ap:
		for lib_name in ap.get_animation_library_list():
			animacoes += ap.get_animation_library(lib_name).get_animation_list().size()
	var faces := 0
	for mi in _malhas(inst):
		if mi.mesh:
			for s in range(mi.mesh.get_surface_count()):
				faces += mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX].size() / 3

	# Deitado: exportador com Z pra cima. A altura util passa a ser o Z.
	var deitado: bool = caixa.size.z > caixa.size.y * 1.4
	var altura: float = caixa.size.z if deitado else caixa.size.y

	var pasta := caminho.get_base_dir().get_file()
	inst.queue_free()
	return {
		"id": pasta,
		"caminho": caminho,
		"altura": altura,
		"ossos": ossos,
		"animacoes": animacoes,
		"faces": faces,
		"deitado": deitado,
		"serve": ("jogador + NPC" if faces <= FACES_PARA_NPC else "jogador") \
			if ossos > 0 else "estatua",
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
## 1,80 m" em escala), quantos ossos e quantas animacoes proprias. Modelo com
## `ossos == 0` e estatua: nao anda, e por isso nao entra como jogavel.

const PERSONAGENS: Array[Dictionary] = [
"""
	for e: Dictionary in entradas:
		texto += '\t{"id": "%s", "rotulo": "%s", "caminho": "%s",\n' % [
			e["id"], _rotulo(str(e["id"])), e["caminho"]]
		texto += '\t\t"altura_modelo": %.4f, "ossos": %d, "animacoes": %d,\n' % [
			e["altura"], e["ossos"], e["animacoes"]]
		texto += '\t\t"faces": %d, "deitado": %s},\n' % [
			e["faces"], "true" if e["deitado"] else "false"]
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

func _aabb(root: Node) -> AABB:
	var box := AABB()
	var first := true
	for mi in _malhas(root):
		if mi.mesh == null:
			continue
		var world := mi.global_transform * mi.mesh.get_aabb()
		if first:
			box = world
			first = false
		else:
			box = box.merge(world)
	return box

func _malhas(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		out.append(node as MeshInstance3D)
	for c in node.get_children():
		out.append_array(_malhas(c))
	return out

func _achar_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for c in node.get_children():
		var f := _achar_player(c)
		if f:
			return f
	return null
