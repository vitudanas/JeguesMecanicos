@tool
extends EditorScenePostImport
## Tira dos personagens baixados as SHAPE KEYS que o jogo nunca usa.
##
## Por que: varios modelos vem de gerador de personagem (Character Creator,
## Daz) e carregam a biblioteca facial inteira — medido nos recebidos, 148 a 176
## morph targets por arquivo. Cada morph guarda uma copia das posicoes (e
## normais, e tangentes) de TODOS os vertices, entao eles dominam o arquivo:
## `old_man_spice` tem 138 MB de `scene.bin` pra 78 mil faces, e sozinhos os
## quatro modelos assim somavam 240 MB do `.pck`.
##
## O jogo so usa as sete formas de corpo que `tools/build_characters.py` grava
## nos dois personagens NATIVOS (busto, gluteo, quadril, peitoral, barriga,
## porte, magreza) — e esses moram em `assets/quaternius/`, fora do alcance
## deste script. Modelo de terceiro que por acaso traga uma forma com um desses
## nomes fica intacto.
##
## Ligado arquivo a arquivo por `tools/preparar_import_personagens.py`
## (`import_script/path` no `.import`), e nao no projeto inteiro, de proposito.

const FORMAS_USADAS := ["Bust", "Butt", "Hips", "Chest", "Belly", "Bulk", "Skinny"]

func _post_import(scene: Node) -> Object:
	var tiradas := 0
	for mi in _malhas(scene):
		var mesh := mi.mesh as ArrayMesh
		if mesh == null or mesh.get_blend_shape_count() == 0:
			continue
		var usa := false
		for b in range(mesh.get_blend_shape_count()):
			if FORMAS_USADAS.has(str(mesh.get_blend_shape_name(b))):
				usa = true
				break
		if usa:
			continue
		var limpa := _sem_formas(mesh)
		# So troca se a malha nova ficou INTEIRA. Sem esta trava, a primeira
		# versao deste script deixava `mi.mesh` com zero superficie quando o
		# remonte falhava — ou seja, o personagem sumia da tela em vez de so
		# manter os morphs.
		if limpa == null or limpa.get_surface_count() != mesh.get_surface_count():
			print("  [personagem] '%s' nao pode ser remontada, morphs mantidos" % mi.name)
			continue
		tiradas += mesh.get_blend_shape_count()
		mi.mesh = limpa
	if tiradas > 0:
		# A trilha de shape key sobrevive na animacao e passa a apontar pra nada,
		# o que enche o log de aviso a cada quadro.
		for ap in _players(scene):
			for lib_nome in ap.get_animation_library_list():
				var lib := ap.get_animation_library(lib_nome)
				for a in lib.get_animation_list():
					_limpar_trilhas(lib.get_animation(a))
		print("  [personagem] %d shape key(s) sem uso removidas" % tiradas)
	return scene

## Remonta a malha superficie por superficie, sem os morph targets. Os arrays
## de osso e peso vem junto em `surface_get_arrays`, entao o skin continua.
##
## Devolve nulo quando NAO da pra remontar com seguranca: superficie com canal
## customizado (`ARRAY_CUSTOM*`) nao faz o caminho de volta — `surface_get_arrays`
## devolve o canal ja decodificado e `add_surface_from_arrays` exige os bytes
## crus, entao a superficie sairia invalida. Nesses o morph fica, que custa
## tamanho mas nao quebra nada.
func _sem_formas(mesh: ArrayMesh) -> ArrayMesh:
	var novo := ArrayMesh.new()
	novo.resource_name = mesh.resource_name
	for s in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(s)
		for custom in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2,
				Mesh.ARRAY_CUSTOM3]:
			if arrays[custom] != null:
				return null
		novo.add_surface_from_arrays(mesh.surface_get_primitive_type(s), arrays)
		if novo.get_surface_count() != s + 1:
			return null
		novo.surface_set_material(s, mesh.surface_get_material(s))
		novo.surface_set_name(s, mesh.surface_get_name(s))
	return novo

func _limpar_trilhas(anim: Animation) -> void:
	for t in range(anim.get_track_count() - 1, -1, -1):
		if anim.track_get_type(t) == Animation.TYPE_BLEND_SHAPE:
			anim.remove_track(t)

func _malhas(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		out.append(node as MeshInstance3D)
	for c in node.get_children():
		out.append_array(_malhas(c))
	return out

func _players(node: Node) -> Array[AnimationPlayer]:
	var out: Array[AnimationPlayer] = []
	if node is AnimationPlayer:
		out.append(node as AnimationPlayer)
	for c in node.get_children():
		out.append_array(_players(c))
	return out
