class_name CharacterVisual
extends RefCounted
## Instancia o visual de um personagem e devolve o no pronto.
##
## Os personagens ja vem vestidos de um arquivo so (corpo + roupa + cabelo
## combinados por um script de Blender, ver changelog 2026-08-03) — antes isso
## era montado em runtime, transplantando malha por malha entre esqueletos, o
## que exigia remendos de escala pra pele nao aparecer por baixo do tecido.

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
