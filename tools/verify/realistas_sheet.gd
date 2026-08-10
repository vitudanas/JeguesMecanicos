extends Node
## FOLHA DE CONTATO dos prédios fatiados (assets/realistas_prontos/).
##
## Fatiar por código acerta a geometria e erra fácil as três coisas que só
## aparecem na tela: a ESCALA (cada pacote veio numa unidade diferente), a
## ORIENTAÇÃO (a fachada tem que olhar pro -Z, que é o lado que o CityBlocks
## vira pra rua) e o que a peça É (pedaço de calçada que veio junto no pacote
## também passa nos filtros de tamanho).
##
## Cada prédio nasce ao lado de uma REGUA de 1,80 m — a altura do jogador. Sem
## uma referência humana no quadro não dá pra julgar escala: um prédio bonito
## renderizado sozinho parece certo em qualquer tamanho.
##
## Precisa de janela de verdade:
##   godot --path . tools/verify/realistas_sheet.tscn

const DIR := "res://assets/realistas_prontos"
const OUT := "user://realistas_sheet"
const REGUA := 1.80
## Quantos prédios por foto (ver o porquê no laço que pagina).
const POR_PAGINA := 6

var cam: Camera3D

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_mundo()
	var por_pacote := {}
	var d := DirAccess.open(DIR)
	if d == null:
		print("sem %s — rode tools/fatiar_realistas.tscn antes" % DIR)
		get_tree().quit(1)
		return
	for f in d.get_files():
		if not f.ends_with(".scn"):
			continue
		var pacote := f.substr(0, f.length() - 7)   # tira "_NN.scn"
		if not por_pacote.has(pacote):
			por_pacote[pacote] = []
		(por_pacote[pacote] as Array).append("%s/%s" % [DIR, f])
	var nomes := por_pacote.keys()
	nomes.sort()
	for nome: String in nomes:
		var arqs: Array = por_pacote[nome]
		arqs.sort()
		# Paginado de 6 em 6: a primeira versao punha as 26 pecas do brownstone
		# numa fileira so, a camera recuava 875 m pra caber tudo e cada predio
		# saia com 20 pixels de altura. Folha de contato que nao da pra ler nao
		# serve pra nada — o pacote de "predios europeus", que na verdade e um
		# pacote de ARVORE E BANCO DE PRACA, so apareceu quando deu pra enxergar.
		var pagina := 0
		while pagina * POR_PAGINA < arqs.size():
			var fatia := arqs.slice(pagina * POR_PAGINA, (pagina + 1) * POR_PAGINA)
			await _fila("%s_p%d" % [nome, pagina + 1], fatia)
			pagina += 1
	print("\nfotos em: %s" % ProjectSettings.globalize_path(OUT))
	get_tree().quit()

func _mundo() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.46, 0.53, 0.62)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.72, 0.76, 0.82)
	e.ambient_light_energy = 0.9
	env.environment = e
	add_child(env)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-40.0, -35.0, 0.0)
	sol.light_energy = 1.6
	sol.shadow_enabled = true
	add_child(sol)
	var chao := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2000, 2000)
	chao.mesh = pm
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.34, 0.35, 0.34)
	chao.material_override = cm
	add_child(chao)
	cam = Camera3D.new()
	cam.fov = 40.0
	cam.far = 6000.0
	add_child(cam)
	cam.make_current()

## Uma fileira com todos os prédios de um pacote, vistos de frente (do -Z, que é
## pra onde a fachada deve olhar) e de 3/4.
func _fila(nome: String, arqs: Array) -> void:
	var vivos: Array[Node3D] = []
	var cursor := 0.0
	var alt_max := 0.0
	var linhas: Array[String] = []
	for caminho: String in arqs:
		var cena := load(caminho) as PackedScene
		if cena == null:
			continue
		var no := cena.instantiate() as Node3D
		add_child(no)
		var b := _aabb(no, Transform3D.IDENTITY)
		var larg: float = b.size.x
		no.position = Vector3(cursor + larg * 0.5, 0.0, 0.0)
		cursor += larg + maxf(larg * 0.15, 2.0)
		alt_max = maxf(alt_max, b.size.y)
		vivos.append(no)
		linhas.append("    %-42s %6.1f x %6.1f x %6.1f m  base y=%.2f" % [
			caminho.get_file(), b.size.x, b.size.y, b.size.z, b.position.y])
		# Régua de 1,80 m encostada na frente do prédio.
		var r := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.45, REGUA, 0.45)
		r.mesh = bm
		var rm := StandardMaterial3D.new()
		rm.albedo_color = Color(0.95, 0.15, 0.15)
		r.material_override = rm
		add_child(r)
		r.position = Vector3(no.position.x - larg * 0.5 - 0.6, REGUA * 0.5,
			b.size.z * 0.5 + 1.0)
		vivos.append(r)

	print("\n%s (%d peca(s))" % [nome, arqs.size()])
	for l in linhas:
		print(l)

	var meio := cursor * 0.5
	# Distância que cabe o MAIOR dos dois: a largura da fileira e a altura da
	# peça mais alta (o downtown tem torre de 102 m ao lado de prédio de 18 m).
	var dist: float = maxf(cursor * 1.15, alt_max * 1.5) + 12.0
	await _foto("%s_frente" % nome, Vector3(meio, alt_max * 0.55, -dist),
		Vector3(meio, alt_max * 0.42, 0.0))
	await _foto("%s_tresquartos" % nome,
		Vector3(meio - cursor * 0.55, alt_max * 0.9, -dist * 0.8),
		Vector3(meio, alt_max * 0.35, 0.0))
	for n in vivos:
		n.queue_free()
	await get_tree().process_frame

func _foto(nome: String, olho: Vector3, alvo: Vector3) -> void:
	cam.global_position = olho
	cam.look_at(alvo, Vector3.UP)
	cam.make_current()
	for i in range(6):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OUT, nome])

func _aabb(no: Node, acc: Transform3D) -> AABB:
	var t := acc
	if no is Node3D:
		t = acc * (no as Node3D).transform
	var r := AABB()
	var tem := false
	if no is MeshInstance3D and (no as MeshInstance3D).mesh:
		r = t * (no as MeshInstance3D).get_aabb()
		tem = true
	for c in no.get_children():
		var cb := _aabb(c, t)
		if cb.size != Vector3.ZERO:
			r = cb if not tem else r.merge(cb)
			tem = true
	return r
