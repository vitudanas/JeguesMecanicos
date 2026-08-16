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
		var anims := PackedStringArray()
		if skel:
			for i in range(skel.get_bone_count()):
				var nome := str(skel.get_bone_name(i))
				if nome.to_lower().contains("head"):
					achados.append(nome)
				var y: float = skel.get_bone_global_rest(i).origin.y
				if y > topo_y:
					topo_y = y
					topo = nome
		var ap := _achar_player(inst)
		if ap:
			for lib_name in ap.get_animation_library_list():
				for anim_name in ap.get_animation_library(lib_name).get_animation_list():
					var full_name: String = ("%s/%s" % [lib_name, anim_name]) if lib_name != "" else str(anim_name)
					var anim: Animation = ap.get_animation(full_name)
					anims.append("%s %.2fs membros=%d movimento=%d" % [full_name,
						anim.length, _moving_limb_tracks(anim), _moving_tracks(anim)])
		print("%-46s cabeca=[%s] topo=%s anim=[%s]" % [entrada["id"],
			", ".join(achados) if achados.size() > 0 else "NENHUM", topo,
			", ".join(anims) if anims.size() > 0 else "NENHUMA"])
		inst.queue_free()
	get_tree().quit(0)

func _moving_limb_tracks(anim: Animation) -> int:
	var count := 0
	for i in range(anim.get_track_count()):
		var path := str(anim.track_get_path(i)).to_lower()
		if not ["thigh", "leg", "foot", "arm", "shoulder", "hand"].any(
				func(word: String) -> bool: return path.contains(word)):
			continue
		if _track_motion(anim, i) > 0.12:
			count += 1
	return count

func _moving_tracks(anim: Animation) -> int:
	var count := 0
	for i in range(anim.get_track_count()):
		if _track_motion(anim, i) > 0.12:
			count += 1
	return count

func _track_motion(anim: Animation, track: int) -> float:
	if anim.track_get_key_count(track) < 2:
		return 0.0
	var first: Variant = anim.track_get_key_value(track, 0)
	var largest := 0.0
	for key in range(1, anim.track_get_key_count(track)):
		var value: Variant = anim.track_get_key_value(track, key)
		if first is Quaternion and value is Quaternion:
			largest = maxf(largest, (first as Quaternion).angle_to(value as Quaternion))
		elif first is Vector3 and value is Vector3:
			var base := maxf((first as Vector3).length(), 1.0)
			largest = maxf(largest, (first as Vector3).distance_to(value as Vector3) / base)
	return largest

func _achar_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for c in node.get_children():
		var found := _achar_player(c)
		if found:
			return found
	return null
