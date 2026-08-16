class_name CharacterVisual
extends RefCounted
## Instancia o visual de um personagem e devolve o no pronto.
##
## Os personagens ja vem vestidos de um arquivo so (corpo + roupa + cabelo
## combinados por um script de Blender, ver changelog 2026-08-03) — antes isso
## era montado em runtime, transplantando malha por malha entre esqueletos, o
## que exigia remendos de escala pra pele nao aparecer por baixo do tecido.

## Tipos fisicos, gravados como shape key no proprio modelo (ver
## tools/build_characters.py). Cada entrada e um sorteio de peso por forma —
## e o que faz cada NPC ter um corpo diferente sem existir um arquivo de
## personagem por tipo. Formas que o modelo nao tem sao ignoradas em silencio
## (o masculino nao tem "Bust", por exemplo), entao a mesma tabela serve pros
## dois generos.
const BUILDS: Array[Dictionary] = [
	{"Skinny": Vector2(0.55, 1.0)},
	{},
	{"Bulk": Vector2(0.35, 0.85)},
	{"Belly": Vector2(0.5, 1.0), "Bulk": Vector2(0.15, 0.5)},
	{"Chest": Vector2(0.4, 0.9), "Bulk": Vector2(0.2, 0.6)},
]
## Formas so do modelo feminino. Busto e gluteo saem de degraus fixos
## sorteados de forma INDEPENDENTE: 5 degraus de busto x 4 de gluteo = 20
## combinacoes distintas (busto forte com quadril discreto, o oposto, os dois
## fortes, os dois discretos e tudo no meio). Sortear os dois juntos, ou com
## piso alto, fazia todas sairem parecidas — o que da variedade e o contraste
## entre as partes. O jitter em cima do degrau evita que duas do mesmo par
## fiquem identicas.
const BUST_STEPS: Array[float] = [0.12, 0.34, 0.56, 0.78, 1.0]
const BUTT_STEPS: Array[float] = [0.15, 0.43, 0.71, 1.0]
const SHAPE_JITTER := 0.07
## O quadril acompanha o gluteo (nao e sorteado a parte): gluteo grande com
## quadril estreito le como deformidade, nao como tipo fisico.
const HIPS_OF_BUTT := 0.7
## Multiplicadores em cima da textura (que ja tem o desenho de pele/tecido/fio
## de cabelo), nao cores chapadas — assim a variacao nao apaga o material.
## Tons deliberadamente pouco saturados: cor forte devolve o aspecto de desenho
## que a iluminacao de 2026-08-03 tirou.
const SKIN_TINTS: Array[Color] = [
	Color(1.0, 1.0, 1.0), Color(1.18, 1.12, 1.05), Color(0.86, 0.76, 0.66),
	Color(0.66, 0.55, 0.46), Color(1.08, 0.96, 0.86), Color(0.75, 0.66, 0.60),
]
const CLOTH_TINTS: Array[Color] = [
	Color(1.0, 1.0, 1.0), Color(0.78, 0.84, 0.98), Color(0.98, 0.80, 0.74),
	Color(0.82, 0.94, 0.80), Color(0.70, 0.70, 0.74), Color(0.94, 0.88, 0.66),
	Color(0.62, 0.66, 0.78), Color(0.88, 0.72, 0.58),
]
## Desvio leve pra modelo de terceiro (ver `_apply_tints`). Fraco de proposito:
## e pra dois pedestres do mesmo arquivo nao serem a mesma pessoa, nao pra
## repintar ninguem.
const GERAL_TINTS: Array[Color] = [
	Color(1.0, 1.0, 1.0), Color(1.07, 1.04, 1.0), Color(0.93, 0.95, 1.0),
	Color(1.0, 0.96, 0.93), Color(0.95, 0.97, 0.94), Color(0.90, 0.90, 0.92),
]
const HAIR_TINTS: Array[Color] = [
	Color(1.0, 1.0, 1.0), Color(0.38, 0.29, 0.24), Color(0.20, 0.17, 0.16),
	Color(1.45, 1.25, 0.80), Color(0.86, 0.86, 0.90), Color(0.90, 0.52, 0.30),
]

static func build(parent: Node, model: PackedScene, scale_factor := 1.0,
		rotation_y_degrees := 0.0) -> Node3D:
	if model == null:
		return null
	var visual := model.instantiate()
	parent.add_child(visual)
	if visual is Node3D:
		visual.scale = Vector3.ONE * scale_factor
		visual.rotation_degrees.y = rotation_y_degrees
	return visual as Node3D

## Sorteia tipo fisico e cores de um personagem ja instanciado.
static func randomize_appearance(visual: Node3D) -> void:
	if visual == null:
		return
	randomize_body(visual)
	randomize_colors(visual)
	# Chapeu, mochila, sacola. Tipo fisico e cor variam o VOLUME e o TOM; de 20
	# m — que e a distancia em que se ve pedestre na rua — o que separa uma
	# pessoa da outra e a SILHUETA. Ver NpcAccessories.gd.
	NpcAccessories.apply_random(visual)

## Corpo: um tipo fisico sorteado da tabela + as formas femininas, quando o
## modelo as tem.
static func randomize_body(visual: Node3D) -> void:
	var weights: Dictionary = {}
	var build: Dictionary = BUILDS[randi() % BUILDS.size()]
	for shape_name: String in build:
		var span: Vector2 = build[shape_name]
		weights[shape_name] = randf_range(span.x, span.y)
	var bust := _jittered(BUST_STEPS[randi() % BUST_STEPS.size()])
	var butt := _jittered(BUTT_STEPS[randi() % BUTT_STEPS.size()])
	weights["Bust"] = bust
	weights["Butt"] = butt
	weights["Hips"] = _jittered(butt * HIPS_OF_BUTT)
	_apply_blend_shapes(visual, weights)

## Cor de pele, roupa e cabelo. As malhas do personagem dividem materiais
## (roupa e uma so pra corpo/braco/perna/pe), e materiais vindos do .glb sao
## COMPARTILHADOS entre todas as instancias da cena — por isso cada superficie
## recebe uma copia como surface_override_material, senao pintar um pedestre
## pintaria a cidade inteira junto.
static func randomize_colors(visual: Node3D) -> void:
	var tints := {
		"skin": SKIN_TINTS[randi() % SKIN_TINTS.size()],
		"cloth": CLOTH_TINTS[randi() % CLOTH_TINTS.size()],
		"hair": HAIR_TINTS[randi() % HAIR_TINTS.size()],
		# Pros modelos baixados, que nao tem material reconhecivel por nome.
		"geral": GERAL_TINTS[randi() % GERAL_TINTS.size()],
	}
	_apply_tints(visual, tints)

static func _jittered(value: float) -> float:
	return clampf(value + randf_range(-SHAPE_JITTER, SHAPE_JITTER), 0.0, 1.0)

static func _apply_blend_shapes(node: Node, weights: Dictionary) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		for shape_name: String in weights:
			var index := mesh_instance.find_blend_shape_by_name(shape_name)
			if index >= 0:
				mesh_instance.set_blend_shape_value(index, weights[shape_name])
	for child in node.get_children():
		_apply_blend_shapes(child, weights)

static func _apply_tints(node: Node, tints: Dictionary) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var mesh := mesh_instance.mesh
		if mesh:
			for surface in range(mesh.get_surface_count()):
				var source := mesh_instance.get_active_material(surface) as StandardMaterial3D
				if source == null:
					continue
				var kind := _material_kind(source.resource_name)
				if kind == "":
					# Material de modelo BAIXADO: o nome nao casa com nenhuma das
					# tres categorias (elas sao dos dois personagens nativos). Sem
					# tratamento, todos os pedestres daquele modelo saem
					# IDENTICOS — o `street_test` pegou 10 iguais em 72. Aqui vai
					# so um leve desvio de brilho/tom por NPC: o suficiente pra
					# dois nao serem a mesma pessoa, e fraco o bastante pra nao
					# pintar ninguem de roxo.
					var leve := source.duplicate() as StandardMaterial3D
					leve.albedo_color = source.albedo_color * (tints["geral"] as Color)
					mesh_instance.set_surface_override_material(surface, leve)
					continue
				var copy := source.duplicate() as StandardMaterial3D
				# Multiplica a cor que a superficie ja tinha: a roupa de baixo
				# pintada pelo script do Blender nao tem textura, so cor, entao
				# tingir por cima e o que mantem ela combinando com o tecido.
				copy.albedo_color = source.albedo_color * (tints[kind] as Color)
				mesh_instance.set_surface_override_material(surface, copy)
	for child in node.get_children():
		_apply_tints(child, tints)

## Classifica a superficie pelo nome do material que veio do .glb
## (MI_Superhero_Female, MI_Peasant, MI_Hair_2, MI_Eyes...).
static func _material_kind(material_name: String) -> String:
	if material_name.contains("Superhero") or material_name.contains("Regular"):
		return "skin"
	if material_name.contains("Peasant") or material_name.contains("Under"):
		return "cloth"
	if material_name.contains("Hair"):
		return "hair"
	return ""

## O esqueleto tem os ossos que a UAL1 (Quaternius) anima? `spine_01` e o
## marcador: e o nome que aquele pacote usa e que nenhum dos modelos de terceiro
## recebidos usa (medido nos 44). Sem esta checagem, as trilhas procuram osso por
## NOME, nenhuma casa, o Godot enche o log de `_update_caches` e o boneco fica em
## T-pose andando pela cidade.
static func esqueleto_compativel(visual: Node3D) -> bool:
	var skeleton := find_skeleton(visual)
	return skeleton != null and skeleton.find_bone("spine_01") >= 0

## Caminhada do proprio acervo usada como doadora para personagens Mixamo que
## vieram somente com pose/idle. Esses modelos compartilham a nomenclatura e a
## hierarquia do rig; copiamos apenas ROTACOES dos ossos equivalentes, nunca a
## translacao/escala do arquivo doador (cada pacote veio numa unidade diferente).
const MIXAMO_WALK_SCENE := "res://assets/personagens/low_poly_female/scene.gltf"
static var _mixamo_walk_source: Animation = null

static func tem_rig_mixamo(visual: Node3D) -> bool:
	var skeleton := find_skeleton(visual)
	if skeleton == null:
		return false
	var bones := _bone_map(skeleton)
	for required in ["hips", "leftupleg", "leftleg", "rightupleg", "rightleg",
			"leftarm", "rightarm"]:
		if not bones.has(required):
			return false
	return true

## Retarget deterministico entre rigs Mixamo: o AnimationPlayer novo tem como
## raiz o visual e cada trilha aponta para o Skeleton3D real do modelo alvo.
static func animar_com_mixamo(visual: Node3D) -> AnimationPlayer:
	var target := find_skeleton(visual)
	if target == null or not tem_rig_mixamo(visual):
		return null
	var source := _mixamo_walk_animation()
	if source == null:
		return null
	var target_bones := _bone_map(target)
	var retargeted := Animation.new()
	retargeted.length = source.length
	retargeted.loop_mode = Animation.LOOP_LINEAR
	var skeleton_path := visual.get_path_to(target)
	var copied := 0
	for source_track in range(source.get_track_count()):
		if source.track_get_type(source_track) != Animation.TYPE_ROTATION_3D:
			continue
		var path := source.track_get_path(source_track)
		if path.get_subname_count() == 0:
			continue
		var key := _bone_key(str(path.get_subname(0)))
		if not target_bones.has(key):
			continue
		# A rotacao absoluta do quadril tambem carrega a conversao de eixos do
		# arquivo doador. Em alguns pacotes Mixamo ela deita o personagem inteiro
		# mesmo quando todos os membros animam corretamente. O PathFollow ja move
		# o corpo; preservamos o quadril na pose-base do alvo e retargetamos apenas
		# tronco e membros.
		if key == "hips":
			continue
		var track := retargeted.add_track(Animation.TYPE_ROTATION_3D)
		retargeted.track_set_path(track, NodePath("%s:%s" % [skeleton_path,
			target_bones[key]]))
		retargeted.track_set_interpolation_type(track,
			source.track_get_interpolation_type(source_track))
		retargeted.track_set_interpolation_loop_wrap(track,
			source.track_get_interpolation_loop_wrap(source_track))
		for k in range(source.track_get_key_count(source_track)):
			retargeted.track_insert_key(track, source.track_get_key_time(source_track, k),
				source.track_get_key_value(source_track, k),
				source.track_get_key_transition(source_track, k))
		copied += 1
	if copied < 12:
		return null
	var player := AnimationPlayer.new()
	player.set_meta("mixamo_retarget", true)
	player.root_node = NodePath("..")
	visual.add_child(player)
	var lib := AnimationLibrary.new()
	lib.add_animation("walk", retargeted)
	lib.add_animation("run", retargeted)
	player.add_animation_library("", lib)
	return player

static func _mixamo_walk_animation() -> Animation:
	if _mixamo_walk_source != null:
		return _mixamo_walk_source
	var scene := load(MIXAMO_WALK_SCENE) as PackedScene
	if scene == null:
		return null
	var temp := scene.instantiate()
	var player := _achar_player(temp)
	if player:
		for name in player.get_animation_list():
			if str(name).to_lower().contains("walk"):
				_mixamo_walk_source = player.get_animation(name)
				break
	temp.free()
	return _mixamo_walk_source

static func _bone_map(skeleton: Skeleton3D) -> Dictionary:
	var out := {}
	for i in range(skeleton.get_bone_count()):
		out[_bone_key(skeleton.get_bone_name(i))] = skeleton.get_bone_name(i)
	return out

static func _bone_key(bone_name: String) -> String:
	var value := bone_name.to_lower().replace(":", "_")
	value = value.replace("mixamorig1_", "").replace("mixamorig_", "")
	var parts := value.split("_")
	if parts.size() > 1 and str(parts[-1]).is_valid_int():
		parts.resize(parts.size() - 1)
	return "".join(parts)

## Usa o AnimationPlayer que veio DENTRO do arquivo, apelidando as animacoes de
## "idle"/"walk"/"run". Um clipe por estado quando ha mais de um; com um so, o
## personagem anda e para com o mesmo, que e melhor que T-pose.
##
## Publico e aqui (e nao no `PlayerVisual`) porque pedestre e jogador precisam
## exatamente da mesma coisa: os dois montam modelo de terceiro e os dois
## precisam que ele se mexa.
static func animar_com_o_proprio(visual: Node3D, usar_primeiro_como_fallback := true) -> AnimationPlayer:
	var player := _achar_player(visual)
	if player == null:
		return null
	var nomes := PackedStringArray()
	for lib_name in player.get_animation_library_list():
		for a in player.get_animation_library(lib_name).get_animation_list():
			nomes.append(("%s/%s" % [lib_name, a]) if lib_name != "" else str(a))
	if nomes.is_empty():
		return null
	var declared_locomotion := _scene_declares_locomotion(visual)
	var moving_clip := _best_moving_animation(player, nomes) if declared_locomotion else ""
	var lib := player.get_animation_library("")
	if lib == null:
		lib = AnimationLibrary.new()
		player.add_animation_library("", lib)
	for pedido: Array in [["idle", ["idle", "stand", "pose"]],
			["walk", ["walk", "jog"]], ["run", ["run", "sprint", "jog"]]]:
		var apelido: String = pedido[0]
		if lib.has_animation(apelido):
			continue
		var escolhido := _melhor_animacao(nomes, pedido[1], usar_primeiro_como_fallback)
		if escolhido == "" and apelido in ["walk", "run"]:
			escolhido = moving_clip
		var anim: Animation = player.get_animation(escolhido) if escolhido != "" else null
		if anim:
			anim.loop_mode = Animation.LOOP_LINEAR
			lib.add_animation(apelido, anim)
	return player

static func _scene_declares_locomotion(visual: Node3D) -> bool:
	var path := visual.scene_file_path.to_lower()
	for word in ["walk", "walking", "run", "running"]:
		if path.contains(word):
			return true
	return false

static func _best_moving_animation(player: AnimationPlayer, names: PackedStringArray) -> String:
	var best := ""
	var best_score := 0
	for name in names:
		var anim := player.get_animation(name)
		var score := animation_limb_motion_score(anim)
		# Clipe generico de dezenas de segundos costuma ser uma timeline/cena,
		# nao um ciclo de passada. `character_girl_animated_walk` mede 32,9 s e
		# ficava congelada no intervalo pratico mesmo com o relogio avançando.
		if anim != null and anim.length >= 0.35 and anim.length <= 5.0 \
				and score > best_score:
			best = name
			best_score = score
	return best if best_score >= 4 else ""

## Quantas trilhas de membros mudam de rotacao de verdade ao longo do clipe.
## Um arquivo com 66 ossos e uma pose unica devolve zero; uma caminhada Mixamo
## do acervo mede 29. Publico para o catalogo/teste usarem o mesmo criterio.
static func animation_limb_motion_score(anim: Animation) -> int:
	if anim == null:
		return 0
	var score := 0
	for track in range(anim.get_track_count()):
		if anim.track_get_type(track) != Animation.TYPE_ROTATION_3D \
				or anim.track_get_key_count(track) < 2:
			continue
		var path := str(anim.track_get_path(track)).to_lower()
		var is_limb := false
		for word in ["thigh", "upleg", "leg", "foot", "arm", "shoulder", "hand"]:
			if path.contains(word):
				is_limb = true
				break
		if not is_limb:
			continue
		var first: Quaternion = anim.track_get_key_value(track, 0) as Quaternion
		var largest := 0.0
		for key in range(1, anim.track_get_key_count(track)):
			var value: Quaternion = anim.track_get_key_value(track, key) as Quaternion
			largest = maxf(largest, first.angle_to(value))
		if largest > 0.12:
			score += 1
	return score

static func _melhor_animacao(nomes: PackedStringArray, palavras: Array,
		usar_primeiro_como_fallback := true) -> String:
	for palavra: String in palavras:
		for n in nomes:
			if n.to_lower().contains(palavra):
				return n
	return nomes[0] if usar_primeiro_como_fallback else ""

static func _achar_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for c in node.get_children():
		var f := _achar_player(c)
		if f:
			return f
	return null

static func find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := find_skeleton(child)
		if found:
			return found
	return null

## Extrai um Animation nomeado de uma cena de animacao (as libs da Quaternius
## trazem dezenas num AnimationPlayer so).
static func extract_animation(scene: PackedScene, anim_name: String) -> Animation:
	if scene == null:
		return null
	var temp := scene.instantiate()
	var anim: Animation = null
	var player := temp.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player:
		for lib_name in player.get_animation_library_list():
			var lib := player.get_animation_library(lib_name)
			if lib.has_animation(anim_name):
				anim = lib.get_animation(anim_name)
				break
	temp.free()
	return anim
