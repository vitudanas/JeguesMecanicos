extends Node
## FOLHA DE CONTATO de todos os personagens jogaveis, lado a lado, com regua.
##
## Numero nenhum diz se o personagem esta DE PE, virado pra frente e no tamanho
## certo. Os arquivos recebidos provam isso: as escalas vao de 0,01 m a 1013 m
## no arquivo e quatro deles vem DEITADOS (exportador com Z pra cima). O
## `preparar_personagens` detecta e o `PlayerVisual` corrige — mas quem confirma
## e a foto.
##
## Cada personagem sai ao lado de uma regua de 2 m listrada a cada 10 cm, com a
## faixa de 1,80 destacada: sem referencia de tamanho no quadro nao da pra
## julgar escala, e foi assim que os NPCs ficaram com 3,76 m por meses.
##
##   godot --path . tools/verify/personagens_sheet.tscn

const OUT_DIR := "user://personagens_sheet"
const POR_LINHA := 5
const PASSO := 1.4   ## metros entre um personagem e o outro

var _stage: Node3D
var _camera: Camera3D
var _saved: Dictionary = {}
var problems: Array[String] = []

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	_saved = {"model": Appearance.model_id, "donkey": Appearance.donkey_head,
		"height": Appearance.height}
	_build_stage()
	await _folha()
	Appearance.model_id = str(_saved["model"])
	Appearance.donkey_head = bool(_saved["donkey"])
	Appearance.height = float(_saved["height"])
	Appearance.save_settings()

	print("")
	if problems.is_empty():
		print("=== RESULTADO ===\n%d personagens na folha — OLHE as fotos"
			% Appearance.models().size())
	else:
		print("=== PROBLEMAS (%d) ===" % problems.size())
		for p in problems:
			print("  - %s" % p)
	print("fotos em: %s" % ProjectSettings.globalize_path(OUT_DIR))
	get_tree().quit(0 if problems.is_empty() else 1)

func _build_stage() -> void:
	_stage = Node3D.new()
	add_child(_stage)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.18, 0.22)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.58, 0.62, 0.74)
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	_stage.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30, 35, 0)
	key.light_energy = 1.5
	_stage.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-16, -130, 0)
	fill.light_energy = 0.6
	_stage.add_child(fill)
	_camera = Camera3D.new()
	_camera.fov = 40.0
	_camera.current = true
	_stage.add_child(_camera)

## Regua de 2 m: a referencia que transforma "parece grande" em "tem 2,4 m".
func _regua(pos: Vector3) -> void:
	for i in range(20):
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.06, 0.1, 0.06)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.position = pos + Vector3(0.0, 0.05 + i * 0.1, 0.0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.78, 0.15) if i == 17 \
			else (Color(0.88, 0.88, 0.9) if i % 2 == 0 else Color(0.28, 0.3, 0.34))
		mi.material_override = mat
		_stage.add_child(mi)

func _folha() -> void:
	var modelos := Appearance.models()
	print("%d personagens jogaveis" % modelos.size())
	var linhas: int = int(ceil(float(modelos.size()) / float(POR_LINHA)))
	for linha in range(linhas):
		var montados: Array[Node3D] = []
		var inicio := linha * POR_LINHA
		var fim: int = mini(inicio + POR_LINHA, modelos.size())
		for i in range(inicio, fim):
			var m: Dictionary = modelos[i]
			Appearance.model_id = str(m["id"])
			# Sem cabeca de jegue: aqui o que se julga e o CORPO — de pe, virado
			# pra frente e no tamanho certo.
			Appearance.donkey_head = false
			Appearance.height = 1.80
			var holder := Node3D.new()
			_stage.add_child(holder)
			holder.position = Vector3((i - inicio) * PASSO, 0.0, 0.0)
			var corpo := PlayerVisual.build(holder)
			if corpo == null:
				problems.append("%s: nao montou" % m["id"])
				continue
			corpo.rotation_degrees.y = 0.0   # encarando a camera, que fica no +Z
			montados.append(holder)
			# A medida vai junto da foto: ler "2,4 m" ao lado do boneco e o que
			# transforma "parece estranho" em defeito acionavel.
			var caixa := _aabb(corpo)
			print("  %-42s %.2f m de altura na cena" % [m["id"], caixa.size.y])
			if caixa.size.y < 1.2 or caixa.size.y > 2.6:
				problems.append("%s: %.2f m na cena (pedi 1,80)" % [m["id"], caixa.size.y])
		_regua(Vector3(float(fim - inicio) * PASSO, 0.0, 0.0))

		var largura: float = float(fim - inicio + 1) * PASSO
		var centro := Vector3(largura * 0.5 - PASSO * 0.5, 0.95, 0.0)
		_camera.position = centro + Vector3(0.0, 0.0, largura * 1.15 + 1.5)
		_camera.look_at(centro, Vector3.UP)
		await _shot("linha_%d" % (linha + 1))

		for h in montados:
			_stage.remove_child(h)
			h.queue_free()
		for c in _stage.get_children():
			if c is MeshInstance3D:
				_stage.remove_child(c)
				c.queue_free()
		await get_tree().process_frame

func _shot(nome: String) -> void:
	for i in range(10):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [OUT_DIR, nome])
	print("  foto: %s" % nome)

func _aabb(root: Node) -> AABB:
	var box := AABB()
	var first := true
	for mi in _malhas(root):
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var world := mi.global_transform * mi.mesh.get_aabb()
		if first:
			box = world
			first = false
		else:
			box = box.merge(world)
	return box

func _malhas(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		out.append(node as MeshInstance3D)
	for c in node.get_children():
		out.append_array(_malhas(c))
	return out
