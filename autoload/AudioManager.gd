extends Node
## Som do jogo: biblioteca de efeitos, mesa de volume e as vozes que tocam.
##
## Ate 2026-08-08 o jogo nao tinha UMA linha de audio — nenhum arquivo, nenhum
## AudioStreamPlayer. Este autoload e a base disso.
##
## Duas decisoes que valem saber antes de mexer:
##
##   * **Os barramentos sao criados EM CODIGO**, e nao num `default_bus_layout`.
##     E de proposito: arquivo de recurso escrito a mao ja ficou fora do `.pck`
##     uma vez neste projeto e so quebrou no binario exportado (ver o
##     `SettingsMenu` em 2026-08-04). Codigo o exportador sempre leva.
##   * **Uma piscina de vozes**, nao um player por som. Tocar um efeito nao
##     instancia no: pega a proxima voz livre. Sem isso, uma batida em cadeia
##     (que e o normal aqui — gambiarra caindo, carro batendo) criaria dezenas
##     de nos por segundo.

const PATH := "user://audio.cfg"

const BUS_SFX := "SFX"
const BUS_UI := "UI"

## Vozes 3D simultaneas. Passou disso, o som mais antigo cede o lugar — e
## melhor perder o mais velho que engolir a batida que acabou de acontecer.
const VOICES_3D := 16
const VOICES_2D := 6

## Alcance dos sons do mundo. Batida de carro tem que passar longe; passo, nao.
const DEFAULT_MAX_DISTANCE := 55.0

## Biblioteca. Cada chave aponta pras VARIACOES do mesmo som — o Kenney entrega
## 4-5 de cada justamente pra isso, e sortear entre elas e o que evita o efeito
## de metralhadora quando o mesmo som toca varias vezes seguidas.
##
## `de` existe porque os arquivos de IMPACTO do Kenney comecam em 000 e os de
## INTERFACE comecam em 001. (Isto ja foi uma string unica com campos separados
## por ":" e quebrou na hora: `res://` tem dois-pontos, entao o primeiro campo
## saia como "res".)
## Cada caminho vai INTEIRO, sem juntar constante com o nome do arquivo. Fica
## verboso de proposito: o auditor do build (`tools/verify/pack_audit.py`) acha
## dependencia varrendo literais que comecam com `res://`, entao um caminho
## montado por concatenacao fica invisivel pra ele — e som e justamente o tipo
## de arquivo que so falha no binario exportado, que e a classe de bug mais cara
## deste projeto (2026-08-02 e 2026-08-04).
const LIBRARY := {
	# --------------------------------------------------------------- mundo
	"batida_leve": {"arquivo": "res://assets/kenney/audio/impact/impactMetal_light_%03d.ogg", "n": 4},
	"batida_media": {"arquivo": "res://assets/kenney/audio/impact/impactMetal_medium_%03d.ogg", "n": 4},
	"batida_forte": {"arquivo": "res://assets/kenney/audio/impact/impactMetal_heavy_%03d.ogg", "n": 4},
	"buraco": {"arquivo": "res://assets/kenney/audio/impact/impactPlate_medium_%03d.ogg", "n": 3},
	"lataria": {"arquivo": "res://assets/kenney/audio/impact/impactTin_medium_%03d.ogg", "n": 3},
	"madeira": {"arquivo": "res://assets/kenney/audio/impact/impactWood_medium_%03d.ogg", "n": 3},
	"corpo": {"arquivo": "res://assets/kenney/audio/impact/impactSoft_medium_%03d.ogg", "n": 3},
	"passo_duro": {"arquivo": "res://assets/kenney/audio/impact/footstep_concrete_%03d.ogg", "n": 5},
	"passo_mato": {"arquivo": "res://assets/kenney/audio/impact/footstep_grass_%03d.ogg", "n": 5},
	# ------------------------------------------------------------ interface
	"clique": {"arquivo": "res://assets/kenney/audio/interface/click_%03d.ogg", "n": 2, "de": 1},
	"passar": {"arquivo": "res://assets/kenney/audio/interface/select_%03d.ogg", "n": 2, "de": 1},
	"confirma": {"arquivo": "res://assets/kenney/audio/interface/confirmation_%03d.ogg", "n": 2, "de": 1},
	"volta": {"arquivo": "res://assets/kenney/audio/interface/back_%03d.ogg", "n": 1, "de": 1},
	"abre": {"arquivo": "res://assets/kenney/audio/interface/open_%03d.ogg", "n": 1, "de": 1},
	"fecha": {"arquivo": "res://assets/kenney/audio/interface/close_%03d.ogg", "n": 1, "de": 1},
	"troca": {"arquivo": "res://assets/kenney/audio/interface/switch_%03d.ogg", "n": 1, "de": 1},
	"erro": {"arquivo": "res://assets/kenney/audio/interface/error_%03d.ogg", "n": 1, "de": 1},
	"encaixa": {"arquivo": "res://assets/kenney/audio/interface/drop_%03d.ogg", "n": 2, "de": 1},
}

signal changed

var master := 0.85
var sfx := 0.9
var ui := 0.7

var _sounds: Dictionary = {}          ## chave -> Array[AudioStream]
var _voices_3d: Array[AudioStreamPlayer3D] = []
var _voices_2d: Array[AudioStreamPlayer] = []
var _next_3d := 0
var _next_2d := 0
var _engine_stream: AudioStreamWAV = null
var _rain_stream: AudioStreamWAV = null

func _ready() -> void:
	# O som nao pode parar junto com a arvore: o menu de pause precisa dos
	# cliques dele, e o Esc pausa tudo.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	_load_library()
	_build_voices()
	_build_rain()
	_build_ambience()
	load_settings()
	apply()
	# Som de interface e ligado SOZINHO em todo controle que entra na arvore, em
	# vez de fiado botao a botao nos 3 menus. Alem de nao repetir codigo, isso
	# cobre a tela de configuracao, que e montada 100% em codigo (ela nao tem
	# .tscn de proposito — ver 2026-08-04) e cujos controles nasceriam mudos.
	get_tree().node_added.connect(_hook_ui)
	for node in get_tree().root.find_children("*", "", true, false):
		_hook_ui(node)

## Intervalo minimo entre dois "tec" de slider. Sem isto, arrastar o volume
## dispara um som por frame.
const SLIDER_GAP := 0.07
var _last_slider := 0.0

func _hook_ui(node: Node) -> void:
	if node is BaseButton:
		var b := node as BaseButton
		if not b.pressed.is_connected(_on_ui_pressed):
			b.pressed.connect(_on_ui_pressed)
		if not b.mouse_entered.is_connected(_on_ui_hover):
			b.mouse_entered.connect(_on_ui_hover)
	elif node is Slider:
		var s := node as Slider
		if not s.value_changed.is_connected(_on_ui_slider):
			s.value_changed.connect(_on_ui_slider)

func _on_ui_pressed() -> void:
	play_ui("clique", -4.0)

func _on_ui_hover() -> void:
	play_ui("passar", -20.0)

func _on_ui_slider(_value: float) -> void:
	var now := float(Time.get_ticks_msec()) / 1000.0
	if now - _last_slider < SLIDER_GAP:
		return
	_last_slider = now
	play_ui("troca", -18.0)

# ------------------------------------------------------------------ ambiente

## A cidade era densa de olhar e MUDA de ouvir: 42 carros de IA e 26 pedestres
## em silencio absoluto, e o unico som do mundo era o carro do proprio jogador.
##
## Duas camas cruzadas pela posicao (zumbido de transito na cidade, vento no
## campo) mais um punhado de vozes emprestadas aos carros de IA MAIS PROXIMOS.
## Custo FIXO: 2 tocadores de ambiente + `TRAFFIC_VOICES`, e nao um por carro —
## 42 tocadores era o motivo de o transito ter ficado mudo ate agora.

## Meia-largura da cidade (a grade vai de -112.5 a 112.5, ver CityStreets).
const CITY_EXTENT := 360.0
## Faixa de transicao entre cidade e campo.
const CITY_FADE := 70.0
const CITY_DB := -26.0
const WIND_DB := -30.0
const AMBIENCE_FADE := 1.5

## Carros de IA que ganham som ao mesmo tempo. Sao emprestadas aos mais
## proximos e reapontadas conforme o transito passa.
const TRAFFIC_VOICES := 4
## Alem disto o carro nao ganha voz: nao adianta gastar tocador com quem esta
## longe demais pra ser ouvido.
const TRAFFIC_RANGE := 42.0
const TRAFFIC_DB := -25.0
## Reapontar toda hora faz a voz "pular" de carro em carro e soar picotado.
const TRAFFIC_REFRESH := 0.35

var _city: AudioStreamPlayer = null
var _wind: AudioStreamPlayer = null
var _city_level := 0.0
var _traffic: Array[AudioStreamPlayer3D] = []
var _traffic_wait := 0.0

func _build_ambience() -> void:
	_city = _bed_player(ProceduralAudio.city_hum())
	_wind = _bed_player(ProceduralAudio.wind())
	for i in range(TRAFFIC_VOICES):
		var p := AudioStreamPlayer3D.new()
		p.stream = engine_stream()
		p.bus = BUS_SFX
		p.max_distance = TRAFFIC_RANGE
		p.unit_size = 4.0
		p.volume_db = -80.0
		# Cada voz num tom diferente, senao os 4 carros soam como um so motor
		# multiplicado.
		p.pitch_scale = randf_range(0.72, 1.05)
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		p.play()
		_traffic.append(p)

func _bed_player(stream: AudioStreamWAV) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = BUS_SFX
	p.volume_db = -80.0
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(p)
	p.play()
	return p

## Cidade ou campo, pela distancia Chebyshev ao centro — a mesma medida que o
## resto do projeto usa pra area da cidade, porque a malha viaria e um QUADRADO
## (com distancia euclidiana o canto da grade cairia como "campo").
func _update_ambience(delta: float, cam: Camera3D) -> void:
	if _city == null:
		return
	var in_world := cam != null and get_tree().get_first_node_in_group("player") != null
	var wanted := 0.0
	if in_world:
		var p := cam.global_position
		var d: float = maxf(absf(p.x), absf(p.z))
		wanted = clampf(1.0 - (d - CITY_EXTENT) / CITY_FADE, 0.0, 1.0)
	var step := delta / AMBIENCE_FADE
	_city_level = move_toward(_city_level, wanted, step)
	var presence := 1.0 if in_world else 0.0
	_city.volume_db = lerpf(-80.0, CITY_DB, _city_level * presence)
	# O vento e o complemento: fora da cidade ele assume.
	_wind.volume_db = lerpf(-80.0, WIND_DB, (1.0 - _city_level) * presence)

## Empresta as vozes aos carros de IA mais proximos da camera.
func _update_traffic(delta: float, cam: Camera3D) -> void:
	_traffic_wait -= delta
	if _traffic_wait > 0.0 or _traffic.is_empty():
		return
	_traffic_wait = TRAFFIC_REFRESH
	if cam == null:
		for v in _traffic:
			v.volume_db = -80.0
		return
	var here := cam.global_position
	var perto: Array = []
	for car in get_tree().get_nodes_in_group("traffic_car"):
		if not (car is Node3D):
			continue
		var d := (car as Node3D).global_position.distance_to(here)
		if d < TRAFFIC_RANGE:
			perto.append([d, car])
	perto.sort_custom(func(a, b): return a[0] < b[0])
	for i in range(_traffic.size()):
		var v := _traffic[i]
		if i < perto.size():
			v.global_position = (perto[i][1] as Node3D).global_position
			v.volume_db = TRAFFIC_DB
		else:
			v.volume_db = -80.0

# ---------------------------------------------------------------------- chuva

## Volume da chuva no auge. Ela toca o tempo todo e so muda de nivel — ligar e
## desligar o tocador dava um corte seco no meio do temporal.
const RAIN_DB := -12.0
const RAIN_FADE := 2.5

var _rain_player: AudioStreamPlayer = null
var _rain_level := 0.0

func _build_rain() -> void:
	_rain_player = AudioStreamPlayer.new()
	_rain_player.stream = rain_stream()
	_rain_player.bus = BUS_SFX
	_rain_player.volume_db = -80.0
	_rain_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_rain_player)
	_rain_player.play()

func _process(delta: float) -> void:
	if _rain_player == null:
		return
	# So chove onde existe mundo: o menu principal tambem carrega os autoloads,
	# e sem esta trava o jogador ouvia temporal na tela de titulo.
	var in_world := get_tree().get_first_node_in_group("player") != null
	var wanted := 1.0 if (in_world and WeatherManager.is_raining) else 0.0
	_rain_level = move_toward(_rain_level, wanted, delta / RAIN_FADE)
	_rain_player.volume_db = lerpf(-80.0, RAIN_DB, _rain_level)

	var cam := get_viewport().get_camera_3d()
	_update_ambience(delta, cam)
	_update_traffic(delta, cam)

# ---------------------------------------------------------------- barramentos

func _setup_buses() -> void:
	for bus_name in [BUS_SFX, BUS_UI]:
		if AudioServer.get_bus_index(bus_name) >= 0:
			continue
		var idx := AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")

func apply() -> void:
	_set_bus("Master", master)
	_set_bus(BUS_SFX, sfx)
	_set_bus(BUS_UI, ui)
	changed.emit()

func _set_bus(bus_name: String, value: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	# No zero, MUDO de verdade: linear_to_db(0) e -inf, e a mesa continuaria
	# processando um sinal inaudivel a toa.
	AudioServer.set_bus_mute(idx, value <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(value, 0.001)))

# ----------------------------------------------------------------- biblioteca

func _load_library() -> void:
	for key: String in LIBRARY:
		var spec: Dictionary = LIBRARY[key]
		var pattern: String = spec["arquivo"]
		var first: int = spec.get("de", 0)
		var variants: Array[AudioStream] = []
		for i in range(int(spec["n"])):
			var path: String = pattern % (first + i)
			if not ResourceLoader.exists(path):
				push_warning("AudioManager: som ausente %s" % path)
				continue
			var stream := load(path) as AudioStream
			if stream:
				variants.append(stream)
		if variants.is_empty():
			push_warning("AudioManager: '%s' ficou sem nenhuma variacao" % key)
		else:
			_sounds[key] = variants

func _build_voices() -> void:
	for i in range(VOICES_3D):
		var p := AudioStreamPlayer3D.new()
		p.bus = BUS_SFX
		p.max_distance = DEFAULT_MAX_DISTANCE
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_voices_3d.append(p)
	for i in range(VOICES_2D):
		var p := AudioStreamPlayer.new()
		p.bus = BUS_UI
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_voices_2d.append(p)

func _pick(key: String) -> AudioStream:
	if not _sounds.has(key):
		return null
	var variants: Array = _sounds[key]
	return variants[randi() % variants.size()]

# -------------------------------------------------------------------- tocar

## Efeito no mundo, na posicao dada. `volume_db` e relativo, `pitch` multiplica
## (sortear um pouco de pitch e o que impede o som de soar identico duas vezes).
func play_at(key: String, position: Vector3, volume_db := 0.0,
		pitch := 1.0, max_distance := DEFAULT_MAX_DISTANCE) -> void:
	var stream := _pick(key)
	if stream == null:
		return
	var voice := _free_voice_3d()
	voice.stream = stream
	voice.global_position = position
	voice.volume_db = volume_db
	voice.pitch_scale = pitch * randf_range(0.94, 1.07)
	voice.max_distance = max_distance
	voice.play()

## Efeito de interface (sem posicao, no barramento UI).
func play_ui(key: String, volume_db := 0.0) -> void:
	var stream := _pick(key)
	if stream == null:
		return
	var voice := _free_voice_2d()
	voice.stream = stream
	voice.volume_db = volume_db
	voice.pitch_scale = randf_range(0.98, 1.03)
	voice.play()

## Primeira voz parada; se todas tocam, a mais antiga cede (round-robin).
func _free_voice_3d() -> AudioStreamPlayer3D:
	for p in _voices_3d:
		if not p.playing:
			return p
	var v := _voices_3d[_next_3d]
	_next_3d = (_next_3d + 1) % _voices_3d.size()
	return v

func _free_voice_2d() -> AudioStreamPlayer:
	for p in _voices_2d:
		if not p.playing:
			return p
	var v := _voices_2d[_next_2d]
	_next_2d = (_next_2d + 1) % _voices_2d.size()
	return v

# ------------------------------------------------------------- sons continuos

## Os dois lacos sintetizados sao gerados UMA vez e reaproveitados: gerar custa
## alguns milhares de senos, e todo carro da cidade pede o mesmo motor.
func engine_stream() -> AudioStreamWAV:
	if _engine_stream == null:
		_engine_stream = ProceduralAudio.engine()
	return _engine_stream

func rain_stream() -> AudioStreamWAV:
	if _rain_stream == null:
		_rain_stream = ProceduralAudio.rain()
	return _rain_stream

# ------------------------------------------------------------------ ajustes

func set_levels(new_master: float, new_sfx: float, new_ui: float) -> void:
	master = clampf(new_master, 0.0, 1.0)
	sfx = clampf(new_sfx, 0.0, 1.0)
	ui = clampf(new_ui, 0.0, 1.0)
	apply()
	save_settings()

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master)
	cfg.set_value("audio", "sfx", sfx)
	cfg.set_value("audio", "ui", ui)
	cfg.save(PATH)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	master = cfg.get_value("audio", "master", master)
	sfx = cfg.get_value("audio", "sfx", sfx)
	ui = cfg.get_value("audio", "ui", ui)
