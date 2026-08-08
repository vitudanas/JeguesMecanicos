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
	play_ui("passar", -14.0)

func _on_ui_slider(_value: float) -> void:
	var now := float(Time.get_ticks_msec()) / 1000.0
	if now - _last_slider < SLIDER_GAP:
		return
	_last_slider = now
	play_ui("troca", -18.0)

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
