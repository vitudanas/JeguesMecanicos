extends Control
## Tela de carregamento entre o menu e a partida.
##
## Existe porque entrar no jogo era um congelamento seco: o `Main.tscn` carrega
## a cidade inteira e ainda GERA em codigo os ~175 predios, o cinturao, o anel
## rural e as 44 montanhas. O botao "Jogar" ficava afundado e a janela parada,
## sem nada dizendo que o jogo nao travou.
##
## Montada em CODIGO, sem .tscn, pelo mesmo motivo do `SettingsMenu`: um `.tscn`
## escrito a mao ja ficou de fora do `.pck` exportado neste projeto e so quebrou
## no binario (2026-08-04). Script o exportador sempre leva.
##
## **O que esta tela pode e o que nao pode**: a barra acompanha de verdade o
## carregamento dos RECURSOS, que roda em outra linha de execucao
## (`load_threaded_request`). A MONTAGEM do mundo — o `_ready()` dos geradores —
## roda na linha principal e trava a janela por natureza; nao da pra animar
## nada durante ela. Por isso a ultima etapa troca o texto ANTES de comecar, e
## espera dois quadros pra garantir que o texto foi PINTADO: assim a pausa final
## tem legenda em vez de parecer travamento.

signal finished

const SCENE_PATH := "res://scenes/main/Main.tscn"

## Dicas mostradas embaixo. Alem de ocupar a espera, e onde o jogo explica o que
## nenhum tutorial explica hoje.
const TIPS: Array[String] = [
	"Mire nos pontos coloridos do carro para instalar cada gambiarra.",
	"V troca entre primeira e terceira pessoa.",
	"Buraco na pista sacode a gambiarra — desvie, ou chegue com o carro em pedaços.",
	"Na chuva a poça de lama tira a tração: acelere menos nas curvas.",
	"Na entrega: E aceita, Q faz contraproposta e F tenta um blefe.",
	"A chance da negociação aparece na tela e cai com preço exagerado ou carro quebrado.",
	"F sai do carro — e, durante a negociação, tenta o blefe. Shift corre.",
	"Capotou? R desvira o carro onde ele estiver — dirigindo ou rebocando.",
	"O canto da tela mostra quantas gambiarras seguem inteiras e quanto o carro vale.",
	"A entrega é sempre numa casa diferente — siga a bússola no topo da tela.",
]

var _bar: ProgressBar = null
var _status: Label = null
var _started := false
var _building := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	ResourceLoader.load_threaded_request(SCENE_PATH)
	_started = true

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.11, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.custom_minimum_size = Vector2(680, 0)
	center.add_child(box)

	var title := Label.new()
	title.text = "Jegues Mecânicos"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	_status = Label.new()
	_status.text = "Carregando…"
	_status.add_theme_font_size_override("font_size", 18)
	_status.add_theme_color_override("font_color", Color(0.82, 0.85, 0.9))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status)

	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(0, 26)
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.value = 0.0
	_bar.show_percentage = false
	box.add_child(_bar)

	var tip := Label.new()
	tip.text = "Dica: " + TIPS[randi() % TIPS.size()]
	tip.add_theme_font_size_override("font_size", 16)
	tip.add_theme_color_override("font_color", Color(0.62, 0.68, 0.76))
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size = Vector2(680, 0)
	box.add_child(tip)

func _process(_delta: float) -> void:
	if not _started or _building:
		return
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(SCENE_PATH, progress)
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			# A carga de recurso vale ate 85%%: os ultimos 15%% sao a montagem,
			# que nao tem como ser medida de dentro.
			if not progress.is_empty():
				_bar.value = float(progress[0]) * 0.85
		ResourceLoader.THREAD_LOAD_LOADED:
			_begin_build()
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_status.text = "Falhou ao carregar o jogo."
			set_process(false)

## Ultima etapa. Trocar o texto e ESPERAR DOIS QUADROS antes de instanciar nao e
## frescura: `instantiate()` bloqueia a linha principal, entao um texto escrito
## no mesmo quadro nunca chegaria a aparecer — a tela congelaria ainda dizendo
## "Carregando", que e exatamente a impressao que esta tela existe pra evitar.
func _begin_build() -> void:
	_building = true
	_bar.value = 0.88
	_status.text = "Montando a cidade… (isso trava por um instante)"
	# DOIS quadros de processo, e nao `RenderingServer.frame_post_draw`: esse
	# sinal nao e emitido com o servidor de render falso, entao em headless o
	# await ficava pendurado pra sempre e a tela NUNCA chegava no jogo (o
	# verificador esperou 90 s e desistiu). Dois quadros dao o mesmo efeito numa
	# janela de verdade — o texto novo e pintado antes do congelamento — e
	# funcionam nos dois modos.
	await get_tree().process_frame
	await get_tree().process_frame
	var packed: PackedScene = ResourceLoader.load_threaded_get(SCENE_PATH)
	if packed == null:
		_status.text = "Falhou ao carregar o jogo."
		return
	_bar.value = 1.0
	finished.emit()
	get_tree().change_scene_to_packed(packed)
