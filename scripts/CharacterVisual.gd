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
