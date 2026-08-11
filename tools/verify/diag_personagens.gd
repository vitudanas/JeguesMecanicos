extends Node
## Levanta o que varia de rig pra rig nos personagens baixados: nome do osso da
## cabeca e nome das animacoes.
##
## Serve pra decidir regra em cima de DADO, e nao de chute — nome de osso varia
## por pacote, e foi por supor `Chest`/`Spine` (o arquivo usa `spine_01`) que a
## mochila dos NPCs nao aparecia.
##
##   godot --headless --path . tools/verify/diag_personagens.tscn

func _ready() -> void:
	for entrada: Dictionary in Appearance.models():
		var cena := load(str(entrada["caminho"])) as PackedScene
		if cena == null:
			continue
		var inst := cena.instantiate() as Node3D
		add_child(inst)
		var skel := CharacterVisual.find_skeleton(inst)
		var achados := PackedStringArray()
		var topo := ""
		var topo_y := -1e9
		if skel:
			for i in range(skel.get_bone_count()):
				var nome := str(skel.get_bone_name(i))
				if nome.to_lower().contains("head"):
					achados.append(nome)
				var y: float = skel.get_bone_global_rest(i).origin.y
				if y > topo_y:
					topo_y = y
					topo = nome
		print("%-46s cabeca=[%s]  topo=%s" % [entrada["id"],
			", ".join(achados) if achados.size() > 0 else "NENHUM", topo])
		inst.queue_free()
	get_tree().quit(0)
