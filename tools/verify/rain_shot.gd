extends Node
## Fotos da CHUVA e da nova escala da serra, do ponto de vista do jogador.
##
## A chuva so existe quando o WeatherManager decide que esta chovendo, e ele
## sorteia por conta propria — pra fotografar, o teste liga o clima na mao.
##
##   godot --path . tools/verify/rain_shot.tscn

const OUT_DIR := "user://rain_shots"

var main: Node
var cam: Camera3D

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().physics_frame
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.far = 4000.0
	add_child(cam)
	# Sem `make_current()` a foto sai pela camera do jogador, nao por esta.
	cam.make_current()
	for i in range(60):
		await get_tree().physics_frame
	await _run()
	print("fotos em: %s" % ProjectSettings.globalize_path(OUT_DIR))
	get_tree().quit()

## Leva o JOGADOR junto com a camera. A grama de geometria (GrassField) nasce
## num anel em volta do jogador, entao fotografar o terreno de longe dele
## mostrava o chao pelado — foi assim que a primeira foto saiu "sem grama".
## O corpo dele fica invisivel pra nao entrar na frente.
func _look(from: Vector3, at: Vector3) -> void:
	cam.global_position = from
	cam.look_at(at, Vector3.UP)
	cam.force_update_transform()
	var pl := get_tree().get_first_node_in_group("player") as Node3D
	if pl:
		pl.global_position = Vector3(from.x, 0.4, from.z)
		pl.visible = false

func _shot(n: String) -> void:
	for i in range(14):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OUT_DIR, n])
	print("  foto: %s" % n)

## Pontos de vista fotografados SECO e depois CHOVENDO, do mesmo lugar. Comparar
## o par e o unico jeito de responder "parece que chove no mapa todo?" — uma foto
## de chuva sozinha nao diz se o mundo mudou ou se so tem gota na frente da
## camera.
const VIEWS: Array = [
	[Vector3(0.0, 1.7, 30.0), Vector3(6.0, 4.0, -40.0), "rua"],
	[Vector3(-150.0, 90.0, 150.0), Vector3(0.0, 8.0, 0.0), "cidade_de_cima"],
	[Vector3(-158.0, 1.7, 22.0), Vector3(-100.0, 6.0, 10.0), "campo"],
	[Vector3(-40.0, 6.0, 260.0), Vector3(-40.0, 90.0, 520.0), "serra"],
]

## Espera a transicao inteira do WeatherSky mais folga.
func _set_weather(raining: bool) -> void:
	WeatherManager.is_raining = raining
	WeatherManager.weather_changed.emit(raining)
	for i in range(300):
		await get_tree().process_frame

## A gota esta mesmo saindo? "Nao vejo chuva na foto" pode ser particula
## desligada, particula longe da camera ou gota transparente demais — e cada uma
## pede um conserto diferente.
func _report_rain() -> void:
	var fx := main.find_child("RainFX", true, false) as GPUParticles3D
	if fx == null:
		print("  [chuva] RainFX NAO ESTA NA CENA")
		return
	var cam_pos := cam.global_position
	var mat := fx.draw_pass_1.surface_get_material(0) if fx.draw_pass_1 else null
	var alpha := -1.0
	if mat is StandardMaterial3D:
		alpha = (mat as StandardMaterial3D).albedo_color.a
	print("  [chuva] emitindo=%s | %d gotas | a %.0f m da camera | alpha da gota %.2f"
		% [fx.emitting, fx.amount, fx.global_position.distance_to(cam_pos), alpha])

func _run() -> void:
	await _set_weather(false)
	for v in VIEWS:
		_look(v[0], v[1])
		await _shot("seco_%s" % v[2])
	await _set_weather(true)
	_report_rain()
	for v in VIEWS:
		_look(v[0], v[1])
		await _shot("chuva_%s" % v[2])
