extends Node
## FOLHA DE CONTATO dos prédios gerados (ver BuildingFactory.gd).
##
## Geometria montada em código erra fácil no SENTIDO DAS FACES — face virada pra
## dentro simplesmente some, e o defeito não aparece em número nenhum (a
## montanha invisível de 2026-08-04 foi exatamente isso). Aqui uma fileira de
## cada tipo é renderizada de frente e de 3/4.
##
##   godot --path . tools/verify/building_sheet.tscn

const OUT := "user://building_sheet"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.42, 0.48, 0.56)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.70, 0.74, 0.80)
	e.ambient_light_energy = 0.75
	e.ssao_enabled = true
	env.environment = e
	add_child(env)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-38.0, -40.0, 0.0)
	sol.light_energy = 1.5
	sol.shadow_enabled = true
	add_child(sol)
	var chao := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	chao.mesh = pm
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.33, 0.33, 0.32)
	chao.material_override = cm
	add_child(chao)

	var cam := Camera3D.new()
	cam.fov = 42.0
	cam.far = 2000.0
	add_child(cam)
	cam.make_current()
	await get_tree().process_frame

	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var nomes := ["torre", "comercio", "casa", "galpao"]
	# Um prédio sozinho, de perto: numa fileira de cinco não dá pra dizer se o
	# que se vê é a parede da frente ou o interior do vizinho.
	var solo := BuildingFactory.roll(rng, BuildingFactory.Kind.COMERCIO)
	var unico := BuildingFactory.build(solo, 2.4, 0.62, 0.35)
	add_child(unico)
	# DIAGNOSTICO: troca a parede por um material de dupla face. Se ela aparecer
	# assim e não aparecer normal, o defeito é o SENTIDO das faces (winding); se
	# não aparecer nem assim, ela não foi gerada. São duas causas bem diferentes
	# e chutar entre elas já custou uma rodada.
	if OS.get_environment("SEM_CULL") == "1":
		for m in unico.get_children():
			if m is MeshInstance3D and m.name == "Parede":
				var plano := StandardMaterial3D.new()
				plano.albedo_color = Color(0.85, 0.3, 0.3)
				plano.cull_mode = BaseMaterial3D.CULL_DISABLED
				(m as MeshInstance3D).material_override = plano
	var ha: float = BuildingFactory.height_of(solo)
	cam.global_position = Vector3(float(solo["width"]) * 1.1, ha * 0.55, ha * 1.9)
	cam.look_at(Vector3(0, ha * 0.42, 0), Vector3.UP)
	for i in range(8):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/00_solo.png" % OUT)
	print("  solo: %.1f x %.1f x %.1f m, %d andares" % [
		solo["width"], ha, solo["depth"], solo["floors"]])
	unico.queue_free()
	await get_tree().process_frame
	for kind in range(4):
		var holder := Node3D.new()
		add_child(holder)
		var x := 0.0
		var alturas: Array[float] = []
		for n in range(5):
			var d := BuildingFactory.roll(rng, kind)
			var b := BuildingFactory.build(d, 2.4, 0.62, 0.35)
			holder.add_child(b)
			x += float(d["width"]) * 0.5
			b.position = Vector3(x, 0.0, 0.0)
			x += float(d["width"]) * 0.5 + 3.0
			alturas.append(BuildingFactory.height_of(d))
		holder.position.x = -x * 0.5
		var alto: float = alturas.max()
		var dist: float = maxf(x * 0.8, alto * 2.2)
		for vista: Array in [["frente", Vector3(0, alto * 0.45, dist)],
				["34", Vector3(dist * 0.55, alto * 0.8, dist * 0.75)]]:
			cam.global_position = vista[1]
			cam.look_at(Vector3(0, alto * 0.35, 0), Vector3.UP)
			for i in range(8):
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(
				"%s/%s_%s.png" % [OUT, nomes[kind], vista[0]])
		# Custo: quantas chamadas de desenho e quantos triangulos por predio.
		# POR SUPERFICIE: se a parede sumir da tela, o numero diz na hora se ela
		# nao foi gerada ou se foi gerada e nao esta aparecendo.
		var por_nome: Dictionary = {}
		for b in holder.get_children():
			for m in (b as Node3D).get_children():
				if m is MeshInstance3D:
					var mesh: Mesh = (m as MeshInstance3D).mesh
					var t := 0
					for s in range(mesh.get_surface_count()):
						t += mesh.surface_get_array_len(s) / 3
					por_nome[m.name] = int(por_nome.get(m.name, 0)) + t
		var partes: Array[String] = []
		for k: String in por_nome:
			partes.append("%s %d" % [k, int(por_nome[k]) / 5])
		print("  %-9s por predio: %s triangulos" % [nomes[kind], ", ".join(partes)])
		holder.queue_free()
		await get_tree().process_frame
	print("fotos em: %s" % ProjectSettings.globalize_path(OUT))
	get_tree().quit()
