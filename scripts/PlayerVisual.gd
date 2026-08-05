class_name PlayerVisual
extends RefCounted
## Monta o corpo do jogador: a mulher de cabeca de jegue.
##
## Reaproveita o mesmo personagem feminino que os pedestres usam
## (`Female_Dressed.glb`, corpo + roupa + cabelo num arquivo so, gerado por
## `tools/build_characters.py`) — nao traz modelo novo e nao reintroduz mistura
## de estilo. O que muda em relacao a um NPC:
##
##   * as formas do corpo sao FIXAS, nao sorteadas (o jogador e sempre a mesma
##     personagem);
##   * cabelo, olhos e sobrancelha somem, e a cabeca humana e coberta pela
##     cabeca de jegue montada em `DonkeyHead.gd`;
##   * a cabeca vai num `BoneAttachment3D` do osso `Head`, entao acompanha a
##     animacao em vez de ficar flutuando — foi exatamente esse o bug do cabelo
##     dos NPCs em 2026-08-03.

const MODEL := preload("res://assets/quaternius/characters-dressed/Female_Dressed.glb")
const ANIM_LIB := preload("res://assets/quaternius/universal-animation-library-1/Animations/UAL1_Standard.glb")

## Formas do corpo, na escala 0..1 das shape keys do modelo (ver
## `CharacterVisual.BUILDS`). Bunda grande mas nao exagerada e peito medio:
## 0.72 fica no terceiro dos quatro degraus que os NPCs usam, e 0.50 no meio
## dos cinco de busto — ou seja, acima da media da cidade sem ir no maximo.
const BUST := 0.50
const BUTT := 0.72
## O quadril acompanha o gluteo pelo mesmo motivo do NPC: bunda grande com
## quadril estreito le como deformidade, nao como tipo fisico.
const HIPS := BUTT * 0.7

## O modelo olha pro +Z; o -Z de um CharacterBody3D e a frente. Sem os 180 o
## jogador anda de costas — mesma correcao dos pedestres e dos carros de IA.
const FACING_DEGREES := 180.0

## Nome das animacoes dentro da UAL1 (a UAL2 gratuita nao tem caminhada normal,
## ver changelog 2026-08-03).
const IDLE_ANIM := "Idle"
const WALK_ANIM := "Walk"
const RUN_ANIM := "Run"

## Monta tudo debaixo de `parent` e devolve a raiz do visual.
static func build(parent: Node3D) -> Node3D:
	var visual := MODEL.instantiate() as Node3D
	visual.name = "Visual"
	parent.add_child(visual)
	visual.rotation_degrees.y = FACING_DEGREES

	_apply_shape(visual)
	_hide_human_head_parts(visual)
	_attach_donkey_head(visual)
	_setup_animation(visual)
	return visual

static func _apply_shape(node: Node) -> void:
	var weights := {"Bust": BUST, "Butt": BUTT, "Hips": HIPS}
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		for shape_name: String in weights:
			var idx := mi.find_blend_shape_by_name(shape_name)
			if idx >= 0:
				mi.set_blend_shape_value(idx, weights[shape_name])
	for c in node.get_children():
		_apply_shape(c)

static func _hide_human_head_parts(visual: Node3D) -> void:
	for mesh_name: String in DonkeyHead.HIDE_MESHES:
		var node := visual.find_child(mesh_name, true, false)
		if node is MeshInstance3D:
			(node as MeshInstance3D).visible = false

static func _attach_donkey_head(visual: Node3D) -> void:
	var skeleton := CharacterVisual.find_skeleton(visual)
	if skeleton == null:
		push_warning("PlayerVisual: personagem sem Skeleton3D, cabeca nao foi presa")
		return
	var bone := skeleton.find_bone("Head")
	if bone < 0:
		push_warning("PlayerVisual: esqueleto sem osso 'Head'")
		return
	var attach := BoneAttachment3D.new()
	attach.name = "CabecaAttach"
	skeleton.add_child(attach)
	attach.bone_idx = bone
	attach.add_child(DonkeyHead.build())

static func _setup_animation(visual: Node3D) -> AnimationPlayer:
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
