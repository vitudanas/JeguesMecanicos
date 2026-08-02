extends StaticBody3D
## Corpo estatico generico pra props/predios de asset packs (Kenney):
## instancia a cena visual como filha e gera sozinho uma CollisionShape3D
## (BoxShape3D) do tamanho exato do mesh, sem precisar calcular AABB na
## mao pra cada modelo. Usado pelos predios da cidade (ver Town.tscn).

@export var visual_scene: PackedScene
@export var visual_scale := 1.0
@export var visual_rotation_y_degrees := 0.0

func _ready() -> void:
	if visual_scene == null:
		return
	var visual := visual_scene.instantiate()
	add_child(visual)
	if visual is Node3D:
		visual.scale = Vector3.ONE * visual_scale
		visual.rotation_degrees.y = visual_rotation_y_degrees
	var aabb := _compute_local_aabb(visual, Transform3D.IDENTITY)
	if aabb.size == Vector3.ZERO:
		return
	var shape := BoxShape3D.new()
	shape.size = aabb.size
	var coll := CollisionShape3D.new()
	coll.shape = shape
	coll.position = aabb.position + aabb.size / 2.0
	add_child(coll)

func _compute_local_aabb(node: Node, accum: Transform3D) -> AABB:
	var t := accum
	if node is Node3D:
		t = accum * node.transform
	var result := AABB()
	var has_result := false
	if node is MeshInstance3D and node.mesh:
		result = t * node.get_aabb()
		has_result = true
	for child in node.get_children():
		var caabb := _compute_local_aabb(child, t)
		if caabb.size != Vector3.ZERO or (caabb.position != Vector3.ZERO and not has_result):
			if not has_result:
				result = caabb
				has_result = true
			else:
				result = result.merge(caabb)
	return result
