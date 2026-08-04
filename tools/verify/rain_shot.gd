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

func _look(from: Vector3, at: Vector3) -> void:
	cam.global_position = from
	cam.look_at(at, Vector3.UP)
	cam.force_update_transform()

func _shot(n: String) -> void:
	for i in range(14):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OUT_DIR, n])
	print("  foto: %s" % n)

func _run() -> void:
	# Serra nova, do chao e de longe.
	_look(Vector3(-120, 3, 150), Vector3(-20, 120, 420))
	await _shot("01_serra_do_chao")
	_look(Vector3(0, 90, 300), Vector3(0, 30, -100))
	await _shot("02_serra_e_cidade")
	_look(Vector3(40, 2.0, 60), Vector3(40, 8.0, -80))
	await _shot("03_rua_com_serra_ao_fundo")

	# Chuva: liga na mao, espera o efeito encher e fotografa perto do jogador.
	var rain := main.get_node_or_null("RainFX")
	var player := get_tree().get_first_node_in_group("player")
	if rain == null or player == null:
		print("    (sem RainFX ou jogador, pulei a chuva)")
		return
	# O RainFX segue o jogador, entao o jogador vai pra rua antes.
	player.global_position = Vector3(0, 0.2, 30)
	WeatherManager.is_raining = true
	WeatherManager.weather_changed.emit(true)
	for i in range(150):
		await get_tree().physics_frame
	print("    chovendo: %s | emitindo: %s | gotas: %d" % [
		WeatherManager.is_raining, rain.emitting, rain.amount])
	_look(Vector3(2, 1.7, 34), Vector3(0, 3.0, 10))
	await _shot("04_chuva_na_rua")
	_look(Vector3(-172, 1.7, 6), Vector3(-175, 3.0, -6))
	await _shot("05_chuva_na_oficina")
