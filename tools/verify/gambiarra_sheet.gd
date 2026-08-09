extends Node
## FOLHA DE CONTATO das gambiarras: os 12 itens do catalogo, lado a lado.
##
## Oito deles nasceram de uma vez (os graus barato e caprichado de cada ponto) e
## sao geometria montada em codigo — nenhum numero diz se "arame de cabide" LE
## como arame de cabide. Aqui cada um e renderizado de perto, com o nome, na
## mesma escala em que aparece no carro.
##
##   godot --path . tools/verify/gambiarra_sheet.tscn

const OUT_DIR := "user://gambiarra_sheet"
const PART_SCENE := preload("res://scenes/vehicle/parts/GambiarraPart.tscn")

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	# Fundo neutro e luz chapada: aqui a pergunta e a FORMA da peca, nao como
	# ela fica no ambiente do jogo.
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.30, 0.32, 0.35)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.76, 0.80)
	e.ambient_light_energy = 0.9
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, -35.0, 0.0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)

	var cam := Camera3D.new()
	cam.fov = 38.0
	add_child(cam)
	cam.make_current()
	await get_tree().process_frame
	await _run(cam)
	print("fotos em: %s" % ProjectSettings.globalize_path(OUT_DIR))
	get_tree().quit()

## Mede a largura real da peca montada. Espacar por um numero fixo nao funciona:
## a fita tem 16 cm e a chapa de compensado tem 60 — com passo unico ou os itens
## se atravessam (visto na primeira folha) ou sobra deserto no quadro.
func _largura(part: Node3D) -> float:
	var caixa := AABB()
	var primeiro := true
	for filho in part.get_children():
		if not (filho is Node3D):
			continue
		for m in (filho as Node3D).get_children():
			if m is MeshInstance3D:
				var mi := m as MeshInstance3D
				var b: AABB = mi.transform * mi.get_aabb()
				caixa = b if primeiro else caixa.merge(b)
				primeiro = false
	return 0.2 if primeiro else maxf(caixa.size.x, 0.12)

func _run(cam: Camera3D) -> void:
	var pontos: Array[String] = ["hood", "radiator", "mirror", "bumper"]
	for point: String in pontos:
		var holder := Node3D.new()
		add_child(holder)
		# Monta os tres primeiro, mede, e so entao posiciona.
		var pecas: Array[Node3D] = []
		var larguras: Array[float] = []
		for grau in range(Economy.GRAUS):
			var part := PART_SCENE.instantiate()
			holder.add_child(part)
			part.setup(Economy.gambiarra_option(point, grau))
			(part as RigidBody3D).freeze = true
			pecas.append(part)
			larguras.append(_largura(part))
		var vao := 0.22
		var total := larguras[0] + larguras[1] + larguras[2] + vao * 2.0
		var x := -total * 0.5
		for grau in range(Economy.GRAUS):
			var opt := Economy.gambiarra_option(point, grau)
			var cx: float = x + larguras[grau] * 0.5
			pecas[grau].position = Vector3(cx, 0.0, 0.0)
			var etiqueta := Label3D.new()
			etiqueta.text = "%d · %s\nR$ %d · %s" % [grau + 1, opt["nome"],
				Economy.gambiarra_price(opt, 300), Economy.gambiarra_grade(opt)]
			etiqueta.font_size = 30
			etiqueta.pixel_size = total * 0.0009
			etiqueta.position = Vector3(cx, -total * 0.16, 0.0)
			etiqueta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			holder.add_child(etiqueta)
			x += larguras[grau] + vao
		# Distancia que faz a fileira INTEIRA caber no campo de 38 graus.
		var dist: float = (total * 0.62) / tan(deg_to_rad(19.0))
		cam.global_position = Vector3(0.0, dist * 0.42, dist)
		cam.look_at(Vector3(0.0, -total * 0.06, 0.0), Vector3.UP)
		for i in range(8):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(
			"%s/%s.png" % [OUT_DIR, point])
		print("  foto: %s  (fileira de %.2f m, camera a %.2f m)" % [point, total, dist])
		holder.queue_free()
		await get_tree().process_frame
