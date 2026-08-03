class_name CharacterVisual
extends RefCounted
## Monta o visual de um personagem Quaternius: corpo base + roupa + cabelo,
## todos skinados no MESMO esqueleto de 65 ossos (por isso da pra transplantar
## as malhas direto, sem retargeting). Usado por Pedestrian.gd e BuyerNPC.gd
## pra os dois ficarem com a mesma aparencia.
##
## Corpo e roupa vem de .gltf exportados separadamente, com bind pose levemente
## diferente, entao aparece pele por cima do tecido. Duas medidas combinadas
## resolvem sem efeito colateral visivel: inflar a roupa 5% e encolher o corpo
## 3% (o corpo do Quaternius e uma malha unica que INCLUI a cabeca, entao
## encolher demais — 0.9, como se tentou antes — deixa a cabeca menor que o
## resto de forma visivel).
const CLOTHES_INFLATE := 1.05
const BODY_SHRINK_UNDER_CLOTHES := 0.97

## Instancia o modelo, veste e devolve o no visual pronto (ja adicionado a parent).
static func build(parent: Node, model: PackedScene, outfit: PackedScene, hair: PackedScene,
		scale_factor := 1.0, rotation_y_degrees := 0.0) -> Node3D:
	if model == null:
		return null
	var visual := model.instantiate()
	parent.add_child(visual)
	if visual is Node3D:
		visual.scale = Vector3.ONE * scale_factor
		visual.rotation_degrees.y = rotation_y_degrees
	var skel := find_skeleton(visual)
	if skel:
		if outfit:
			for child in skel.get_children():
				if child is MeshInstance3D and child.name != "Eyes" and child.name != "Eyebrows":
					child.scale = Vector3.ONE * BODY_SHRINK_UNDER_CLOTHES
			attach_meshes(skel, outfit, CLOTHES_INFLATE)
		if hair:
			attach_meshes(skel, hair)
	return visual as Node3D

## Transplanta as MeshInstance3D de scene pro esqueleto base, descartando o
## Armature/Skeleton3D proprios de scene.
static func attach_meshes(base_skel: Skeleton3D, scene: PackedScene, inflate := 1.0) -> void:
	var temp := scene.instantiate()
	var temp_skel := find_skeleton(temp)
	if temp_skel:
		for child in temp_skel.get_children().duplicate():
			if child is MeshInstance3D:
				var skin: Skin = child.skin
				# Solta o dono antes de reparentar: senao o Godot avisa que o no
				# ficou com owner de uma cena que vai ser descartada.
				child.owner = null
				temp_skel.remove_child(child)
				base_skel.add_child(child)
				child.skeleton = NodePath("..")
				# Reatribuir o skin depois de trocar de esqueleto forca o Godot a
				# religar os ossos pelo nome; sem isso a malha fica parada na pose
				# de descanso (era o que fazia o cabelo flutuar solto).
				child.skin = skin
				if not is_equal_approx(inflate, 1.0):
					child.scale = Vector3.ONE * inflate
	temp.queue_free()

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
