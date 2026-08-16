extends Node
## Os personagens baixados servindo de PEDESTRE na cidade de verdade.
##
## Existe porque "jogavel" e "NPC" sao dois caminhos DIFERENTES de montagem: o
## jogador passa por `PlayerVisual` e o pedestre por `Pedestrian`/
## `CharacterVisual`. Um modelo pode estar certo num e errado no outro — a
## animacao, por exemplo: a UAL1 procura osso por NOME e nao casa com esqueleto
## de terceiro, entao sem tratamento o pedestre anda pela cidade em T-POSE.
##
##   godot --headless --path . tools/verify/npc_test.tscn

const MAIN := preload("res://scenes/main/Main.tscn")

## Altura plausivel de pedestre na rua. A rota sorteia +/-7% em cima de 1,75.
const ALTURA_MIN := 1.55
const ALTURA_MAX := 1.95

var problems: Array[String] = []
var _fim: Dictionary = {}

func _ready() -> void:
	var mundo := MAIN.instantiate()
	add_child(mundo)
	for i in range(30):
		await get_tree().process_frame

	var peds := get_tree().get_nodes_in_group("pedestrian")
	print("=== NPC ===\n%d pedestres na cidade" % peds.size())
	if peds.is_empty():
		fail("nenhum pedestre")
		_terminar()
		return

	await _secao_variedade(peds)
	await _secao_animacao(peds)
	await _secao_altura(peds)
	await _secao_visivel(peds)
	_terminar()

## Quantos modelos DIFERENTES a rua tem. Era 2 (os dois nativos), e e o numero
## que responde "todo pedestre tem a mesma cara".
func _secao_variedade(peds: Array) -> void:
	var modelos: Dictionary = {}
	for p in peds:
		var cena: PackedScene = p.get("character_model")
		if cena:
			modelos[cena.resource_path] = int(modelos.get(cena.resource_path, 0)) + 1
	print("\n[1] variedade")
	print("    %d modelos distintos entre %d pedestres" % [modelos.size(), peds.size()])
	var model_names := PackedStringArray()
	for path in modelos:
		model_names.append("%s=%d" % [str(path).get_base_dir().get_file(), modelos[path]])
	model_names.sort()
	print("    %s" % ", ".join(model_names))
	var first_scene: PackedScene = peds[0].get("character_model")
	print("    primeiro da rota: %s" % (first_scene.resource_path if first_scene else "?"))
	var pool_size := Appearance.npc_models().size()
	print("    pool elegivel: %d modelos" % pool_size)
	if pool_size < 18:
		fail("pool de NPC regrediu para %d modelos (piso 18)" % pool_size)
	if modelos.size() < 15:
		fail("so %d modelo(s) distinto(s) na rua" % modelos.size())
	else:
		ok("%d modelos distintos" % modelos.size())
	_fim["variedade"] = true

## Pedestre parado em T-pose e o defeito classico de misturar esqueleto com
## biblioteca de animacao de outro pacote.
func _secao_animacao(peds: Array) -> void:
	print("\n[2] todo pedestre esta ANIMADO")
	var mudos: Array[String] = []
	var procedural := 0
	var retarget_com_quadril := PackedStringArray()
	var progresso_antes: Dictionary = {}
	var pose_antes: Dictionary = {}
	for p in peds:
		var ap := _achar_player(p)
		var has_fallback: bool = p.has_locomotion_animation() if p.has_method("has_locomotion_animation") else false
		if p.has_method("locomotion_kind") and p.locomotion_kind() == "procedural":
			procedural += 1
		if ap != null and ap.has_meta("mixamo_retarget"):
			var current := ap.current_animation
			var anim := ap.get_animation(current) if ap.has_animation(current) else null
			if anim != null:
				for track in range(anim.get_track_count()):
					var path := anim.track_get_path(track)
					if path.get_subname_count() > 0 and \
							str(path.get_subname(0)).to_lower().contains("hips"):
						var scene: PackedScene = p.get("character_model")
						var model_name := scene.resource_path.get_base_dir().get_file() if scene else "?"
						if not retarget_com_quadril.has(model_name):
							retarget_com_quadril.append(model_name)
		if (ap == null or not ap.is_playing()) and not has_fallback:
			var cena: PackedScene = p.get("character_model")
			var nome: String = cena.resource_path.get_base_dir().get_file() if cena else "?"
			if not mudos.has(nome):
				mudos.append(nome)
		if p.has_method("locomotion_progress"):
			progresso_antes[p.get_instance_id()] = p.locomotion_progress()
		if p.has_method("locomotion_pose_snapshot"):
			pose_antes[p.get_instance_id()] = p.locomotion_pose_snapshot()
	if mudos.is_empty():
		ok("os %d pedestres estao tocando animacao (%d fallback procedural)" % [peds.size(), procedural])
	else:
		fail("modelo(s) sem animacao tocando (T-pose na rua): %s" % ", ".join(mudos))
	if procedural > 0:
		fail("%d pedestre(s) ainda dependem de locomocao procedural" % procedural)
	if retarget_com_quadril.is_empty():
		ok("retarget Mixamo preserva o quadril-base e a orientacao vertical")
	else:
		fail("retarget voltou a girar o quadril e pode deitar NPCs: %s" % ", ".join(retarget_com_quadril))
	# Verifica movimento temporal, nao apenas o estado nominal do AnimationPlayer.
	await get_tree().create_timer(0.25).timeout
	var congelados := 0
	var poses_congeladas := 0
	var modelos_pose_congelada := PackedStringArray()
	for p in peds:
		var antes := float(progresso_antes.get(p.get_instance_id(), -1.0))
		var depois := float(p.locomotion_progress()) if p.has_method("locomotion_progress") else -1.0
		if antes < 0.0 or depois < 0.0 or absf(depois - antes) < 0.001:
			congelados += 1
		var before: Dictionary = pose_antes.get(p.get_instance_id(), {})
		var after: Dictionary = p.locomotion_pose_snapshot() \
			if p.has_method("locomotion_pose_snapshot") else {}
		var max_angle := 0.0
		for bone in before:
			if after.has(bone):
				max_angle = maxf(max_angle,
					(before[bone] as Quaternion).angle_to(after[bone] as Quaternion))
		if max_angle < 0.005:
			poses_congeladas += 1
			var scene: PackedScene = p.get("character_model")
			var model_name := scene.resource_path.get_base_dir().get_file() if scene else "?"
			if not modelos_pose_congelada.has(model_name):
				modelos_pose_congelada.append(model_name)
	if congelados == 0:
		ok("os %d clipes avancaram durante 0,25 s" % peds.size())
	else:
		fail("%d pedestre(s) com clipe congelado ou sem progresso" % congelados)
	if poses_congeladas == 0:
		ok("os %d pedestres mudaram a pose dos membros" % peds.size())
	else:
		fail("%d pedestre(s) com relogio ativo mas pose de membros congelada: %s" % [
			poses_congeladas, ", ".join(modelos_pose_congelada)])
	_fim["animacao"] = true

## Altura na RUA. Cada modelo vem numa escala propria no arquivo (de 0,7 a 208
## unidades), entao aqui se cobra que a conversao pra metros valeu pra todos —
## sem ela metade da cidade sai de anao e a outra metade de gigante.
func _secao_altura(peds: Array) -> void:
	print("\n[3] altura de cada pedestre na rua")
	var fora: Array[String] = []
	var menor := 99.0
	var maior := 0.0
	for p in peds:
		# O visual e o filho que TEM ESQUELETO. Pegando "o primeiro Node3D que
		# nao e o FallbackMesh" eu pegava a CollisionShape3D, media zero e o
		# teste passava sem ter medido nada.
		var visual: Node3D = null
		for c in (p as Node3D).get_children():
			if c is Node3D and CharacterVisual.find_skeleton(c) != null:
				visual = c as Node3D
				break
		if visual == null:
			continue
		var alto: float = float(MedirPersonagem.medir(visual)["altura"])
		if alto <= 0.0:
			continue
		menor = minf(menor, alto)
		maior = maxf(maior, alto)
		if alto < ALTURA_MIN or alto > ALTURA_MAX:
			var cena: PackedScene = p.get("character_model")
			var nome: String = cena.resource_path.get_base_dir().get_file() if cena else "?"
			if not fora.has(nome):
				fora.append("%s (%.2f m)" % [nome, alto])
	print("    de %.2f m a %.2f m" % [menor, maior])
	if maior <= 0.0:
		fail("nao consegui medir a altura de nenhum pedestre")
	elif fora.is_empty():
		ok("todos entre %.2f e %.2f m" % [ALTURA_MIN, ALTURA_MAX])
	else:
		fail("fora da faixa: %s" % ", ".join(fora))
	_fim["altura"] = true

## Pedestre INVISIVEL e o pior caso: ele continua solido, entao o jogador bate
## num corpo que nao esta na tela (o `obstacles_test` acusa como parede
## invisivel).
func _secao_visivel(peds: Array) -> void:
	print("\n[4] todo pedestre APARECE")
	var sumidos: Array[String] = []
	for p in peds:
		var visiveis := 0
		for mi in MedirPersonagem.malhas_de(p):
			if mi.mesh != null and mi.is_visible_in_tree() and mi.name != "FallbackMesh":
				visiveis += 1
		if visiveis == 0:
			var cena: PackedScene = p.get("character_model")
			var nome: String = cena.resource_path.get_base_dir().get_file() if cena else "SEM MODELO"
			if not sumidos.has(nome):
				sumidos.append(nome)
	if sumidos.is_empty():
		ok("os %d pedestres tem malha visivel" % peds.size())
	else:
		fail("modelo(s) invisivel(is) na rua: %s" % ", ".join(sumidos))
	_fim["visivel"] = true

func _achar_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for c in node.get_children():
		var f := _achar_player(c)
		if f:
			return f
	return null

func ok(msg: String) -> void:
	print("    ok: " + msg)

func fail(msg: String) -> void:
	problems.append(msg)

## Cada secao marca que chegou ao fim. Sem isto, um erro de script no meio
## abortava a funcao e o teste terminava dizendo "nenhum problema" com metade das
## perguntas nao feitas — ja aconteceu no `economy_test` em 2026-08-09.
func _terminar() -> void:
	for chave: String in ["variedade", "animacao", "altura", "visivel"]:
		if not _fim.has(chave):
			problems.append("a secao '%s' nao chegou ao fim (erro no meio?)" % chave)
	print("")
	if problems.is_empty():
		print("=== RESULTADO ===\nnenhum problema encontrado")
	else:
		print("=== PROBLEMAS (%d) ===" % problems.size())
		for p in problems:
			print("  - " + p)
	get_tree().quit(0 if problems.is_empty() else 1)
