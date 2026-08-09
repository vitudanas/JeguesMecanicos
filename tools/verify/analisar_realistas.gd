extends Node
## Mede o que veio dentro de cada pacote baixado (assets/realistas/).
##
## Antes de fatiar qualquer coisa e preciso saber o que cada arquivo E: um
## predio? uma fileira inteira? em que escala? com a origem onde? Isso nao da
## pra ver pela pasta — o `scene.gltf` de um pacote de 30 MB pode ser um unico
## mesh gigante ou 40 nos separados.
##
##   godot --headless --path . tools/verify/analisar_realistas.tscn

func _ready() -> void:
	var base := "res://assets/realistas"
	var dir := DirAccess.open(base)
	if dir == null:
		print("sem assets/realistas")
		get_tree().quit(1)
		return
	for pasta in dir.get_directories():
		var caminho := "%s/%s/scene.gltf" % [base, pasta]
		if not ResourceLoader.exists(caminho):
			print("%-38s (sem scene.gltf)" % pasta)
			continue
		var cena := load(caminho) as PackedScene
		if cena == null:
			print("%-38s NAO CARREGOU" % pasta)
			continue
		var raiz := cena.instantiate()
		add_child(raiz)
		var malhas: Array[MeshInstance3D] = []
		_coletar(raiz, malhas)
		var total := AABB()
		var tris := 0
		var primeiro := true
		for m in malhas:
			var b: AABB = m.global_transform * m.get_aabb()
			total = b if primeiro else total.merge(b)
			primeiro = false
			var mesh := m.mesh
			for s in range(mesh.get_surface_count()):
				tris += mesh.surface_get_array_len(s) / 3
		# "Pecas soltas" = filhos diretos que tem malha propria: e o numero que
		# diz se da pra fatiar em predios sem abrir no Blender.
		var pecas := 0
		for c in raiz.get_children():
			var sub: Array[MeshInstance3D] = []
			_coletar(c, sub)
			if not sub.is_empty():
				pecas += 1
		print("%-38s %3d malhas em %2d peca(s) | %6d tri | caixa %.1f x %.1f x %.1f m" % [
			pasta, malhas.size(), pecas, tris,
			total.size.x, total.size.y, total.size.z])
		raiz.queue_free()
		await get_tree().process_frame
	get_tree().quit()

func _coletar(n: Node, saida: Array[MeshInstance3D]) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		saida.append(n)
	for c in n.get_children():
		_coletar(c, saida)
