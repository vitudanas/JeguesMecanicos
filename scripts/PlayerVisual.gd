class_name PlayerVisual
extends RefCounted
## Monta o corpo do jogador a partir do que estiver no autoload `Appearance`.
##
## Reaproveita os mesmos personagens prontos que os pedestres usam
## (`Female_Dressed.glb` / `Male_Dressed.glb`, corpo + roupa + cabelo num
## arquivo so, gerados por `tools/build_characters.py`) — nao traz modelo novo e
## nao reintroduz mistura de estilo. O que muda em relacao a um NPC:
##
##   * as formas do corpo NAO sao sorteadas: saem do que o jogador montou na
##     tela de personagem;
##   * com a cabeca de jegue ligada, cabelo, olhos e sobrancelha somem e a
##     cabeca humana e coberta pela cabeca montada em `DonkeyHead.gd`;
##   * a cabeca vai num `BoneAttachment3D` do osso `Head`, entao acompanha a
##     animacao em vez de ficar flutuando — foi exatamente esse o bug do cabelo
##     dos NPCs em 2026-08-03.
##
## Esta funcao e o UNICO caminho de montagem: o jogador de verdade e o preview
## 3D da tela de personagem chamam a mesma coisa. E de proposito — preview que
## monta o boneco por conta propria deixa de provar o que o jogador vai ver.

const ANIM_LIB := preload("res://assets/quaternius/universal-animation-library-1/Animations/UAL1_Standard.glb")

## O modelo olha pro +Z; o -Z de um CharacterBody3D e a frente. Sem os 180 o
## jogador anda de costas — mesma correcao dos pedestres e dos carros de IA.
const FACING_DEGREES := 180.0

## Quanto girar o visual pra frente do modelo cair no -Z do no (a frente do
## corpo). Quem foi exportado olhando pro -Z ja esta certo e nao leva giro
## nenhum — a lista de quem e quem esta em `tools/preparar_personagens.gd`,
## conferida na folha de contato.
##
## Publico porque a folha de contato precisa da MESMA conta pra virar cada
## personagem de frente pra camera: com o giro escrito nos dois lugares, a foto
## deixaria de provar o que o jogador ve.
static func facing_degrees() -> float:
	return 0.0 if bool(Appearance.model().get("de_costas", false)) else FACING_DEGREES

## Nome das animacoes dentro da UAL1 (a UAL2 gratuita nao tem caminhada normal,
## ver changelog 2026-08-03).
const IDLE_ANIM := "Idle"
const WALK_ANIM := "Walk"
const RUN_ANIM := "Run"

## Monta tudo debaixo de `parent` e devolve a raiz do visual.
static func build(parent: Node3D) -> Node3D:
	var scene := Appearance.model_scene()
	if scene == null:
		push_warning("PlayerVisual: modelo '%s' nao carregou" % Appearance.model_id)
		return null
	var visual := scene.instantiate() as Node3D
	visual.name = "Visual"
	parent.add_child(visual)
	visual.rotation_degrees.y = facing_degrees()
	# Modelo exportado com Z pra cima renderiza DE BRUCOS, e ai o unico jeito e
	# deitar o no de volta — o arquivo nao traz essa informacao.
	#
	# Hoje NENHUM dos 46 recebidos cai aqui, e isso e uma correcao de 2026-08-10:
	# o `preparar_personagens` decidia isso pela caixa da malha crua e marcava 11
	# falsos positivos, entao o jogo DEITAVA no chao quem estava de pe no
	# arquivo. Medindo depois do skin (que e o que a tela desenha) a pergunta
	# passou a ser a certa. O mecanismo fica, defensivo, pro dia em que chegar um
	# modelo de fato deitado.
	var entrada := Appearance.model()
	if bool(entrada.get("deitado", false)):
		visual.rotation_degrees.x = 90.0
	# A altura pedida vira escala do visual. O `Player` escala junto a capsula e
	# a cabeca — visual e colisao com alturas diferentes poe o boneco flutuando
	# ou enterrado.
	visual.scale = Vector3.ONE * Appearance.visual_scale()

	apply_shape(visual)
	apply_tints(visual)
	if Appearance.donkey_head:
		_hide_human_head_parts(visual)
		_attach_donkey_head(visual)
	_setup_animation(visual)
	return visual

## Escreve os pesos do `Appearance` nas shape keys do modelo ja instanciado.
## Publico porque a tela de personagem chama isso a cada arrasto de slider, em
## vez de remontar o boneco inteiro (remontar perde a pose da animacao e pisca).
static func apply_shape(node: Node, weights: Dictionary = {}) -> void:
	var values: Dictionary = weights if not weights.is_empty() else Appearance.active_shapes()
	_write_shapes(node, values)

static func _write_shapes(node: Node, weights: Dictionary) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		for shape_name: String in weights:
			var idx := mi.find_blend_shape_by_name(shape_name)
			if idx >= 0:
				mi.set_blend_shape_value(idx, weights[shape_name])
	for c in node.get_children():
		_write_shapes(c, weights)

## Pele, roupa e cabelo. Cada superficie recebe uma COPIA do material: material
## vindo de `.glb` e compartilhado entre todas as instancias da cena, entao
## pintar direto pintaria os pedestres da cidade junto (licao de 2026-08-03).
static func apply_tints(node: Node, tints: Dictionary = {}) -> void:
	var values: Dictionary = tints if not tints.is_empty() else Appearance.tints()
	_write_tints(node, values)

static func _write_tints(node: Node, tints: Dictionary) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var mesh := mi.mesh
		if mesh:
			for surface in range(mesh.get_surface_count()):
				var source := mi.get_active_material(surface) as StandardMaterial3D
				if source == null:
					continue
				var kind := CharacterVisual._material_kind(source.resource_name)
				if kind == "":
					continue
				# Cor neutra nao precisa de material proprio: solta o override e
				# deixa o material que veio do `.glb` valer. Isso e o caso PADRAO
				# do jogo (as tres paletas comecam no multiplicador 1,1,1), e sem
				# esta saida cada personagem nascia com 8 materiais duplicados
				# que so repetem o original. Soltar tambem e o que faz voltar pra
				# cor neutra na tela realmente voltar.
				if (tints[kind] as Color).is_equal_approx(Color(1, 1, 1)):
					mi.set_surface_override_material(surface, null)
					continue
				# `get_active_material` ja devolve o override quando existe, entao
				# arrastar o slider duas vezes multiplicaria a cor de novo em cima
				# da anterior e o personagem iria escurecendo. A cor base vem
				# sempre da malha.
				var base := mesh.surface_get_material(surface) as StandardMaterial3D
				if base == null:
					base = source
				var copy := base.duplicate() as StandardMaterial3D
				copy.albedo_color = base.albedo_color * (tints[kind] as Color)
				mi.set_surface_override_material(surface, copy)
	for c in node.get_children():
		_write_tints(c, tints)

## Esconde o que a cabeca de jegue substitui. Cabelo e escondido por PREFIXO, e
## nao por nome exato: medido, o feminino usa `Hair_Long` e o masculino
## `Hair_SimpleParted` — com a lista de nomes fixos, o cabelo do homem ficava
## dentro do cranio do jegue.
static func _hide_human_head_parts(visual: Node3D) -> void:
	_hide_recursive(visual)

static func _hide_recursive(node: Node) -> void:
	if node is MeshInstance3D and DonkeyHead.is_head_part(node.name):
		(node as MeshInstance3D).visible = false
	for c in node.get_children():
		_hide_recursive(c)

## Quem sabe achar o osso, medir a cabeca do modelo e encaixar a de jegue do
## tamanho certo e o proprio `DonkeyHead` — aqui era `find_bone("Head")`, que só
## funcionava nos dois personagens nativos: dos 44 modelos, só eles chamam o
## osso de `Head` (os outros usam `mixamorig_Head`, `CC_Base_Head`, `Bip01_Head`,
## `head_Armature`...).
static func _attach_donkey_head(visual: Node3D) -> void:
	if DonkeyHead.attach_to(visual, Appearance.height) == null:
		push_warning("PlayerVisual: '%s' nao tem osso de cabeca reconhecivel"
			% Appearance.model_id)

## Anima o personagem.
##
## A UAL1 (Quaternius) so serve pra quem tem o esqueleto dela: as trilhas
## procuram osso por NOME, e num esqueleto de terceiro nenhuma casa — o Godot
## enche o log de `_update_caches` e o boneco fica em T-pose. Medido nos
## recebidos: 38 modelos jogaveis, e a maioria tem esqueleto proprio.
##
## Entao a regra e: esqueleto compativel usa a UAL1 (que tem idle/walk/run
## separados, o que o jogo precisa); os outros usam a animacao QUE VEIO no
## arquivo — quase todos trazem pelo menos um ciclo de caminhada, que foi
## justamente o filtro do garimpo.
static func _setup_animation(visual: Node3D) -> AnimationPlayer:
	# Esqueleto de terceiro nao casa com a UAL1; quem sabe disso e o
	# `CharacterVisual`, compartilhado com os pedestres — a regra e a mesma pros
	# dois e valor repetido em dois lugares vira dois valores.
	if not CharacterVisual.esqueleto_compativel(visual):
		var proprio := CharacterVisual.animar_com_o_proprio(visual)
		if proprio:
			proprio.play("idle")
		return proprio
	var lib := AnimationLibrary.new()
	var any := false
	for pair: Array in [["idle", IDLE_ANIM], ["walk", WALK_ANIM], ["run", RUN_ANIM]]:
		var anim := CharacterVisual.extract_animation(ANIM_LIB, pair[1])
		if anim:
			anim.loop_mode = Animation.LOOP_LINEAR
			lib.add_animation(pair[0], anim)
			any = true
	if not any:
		return null
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	visual.add_child(player)
	player.add_animation_library("", lib)
	player.play("idle")
	return player

