extends Node
## Lista as animacoes que vieram dentro de cada personagem baixado.
##
## Serve pra decidir o que `PlayerVisual._usar_animacao_propria` consegue mapear:
## quem tem varios clipes pode ter idle/walk/run separados; quem tem um so anda
## e para com o mesmo.
##
##   godot --headless --path . tools/verify/diag_personagens.tscn

const PASTA := "res://assets/personagens"

func _ready() -> void:
	for caminho: String in _achar():
		var cena := load(caminho) as PackedScene
		if cena == null:
			continue
		var inst := cena.instantiate() as Node3D
		add_child(inst)
		var ap := _achar_player(inst)
		var nomes := PackedStringArray()
		if ap:
			for lib in ap.get_animation_library_list():
				for a in ap.get_animation_library(lib).get_animation_list():
					nomes.append(str(a))
		if nomes.size() > 1:
			print("%-44s %s" % [caminho.get_base_dir().get_file(), ", ".join(nomes)])
		inst.queue_free()
	get_tree().quit(0)

func _achar_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for c in node.get_children():
		var f := _achar_player(c)
		if f:
			return f
	return null

func _achar() -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(PASTA)
	if dir == null:
		return out
	dir.list_dir_begin()
	var nome := dir.get_next()
	while nome != "":
		if dir.current_is_dir() and not nome.begins_with("_") and not nome.begins_with("."):
			for candidato: String in ["scene.gltf", "scene.glb"]:
				var c := "%s/%s/%s" % [PASTA, nome, candidato]
				if ResourceLoader.exists(c):
					out.append(c)
					break
		nome = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out
