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
var _percent: Label = null
var _stage_labels: Array[Label] = []
var _started := false
var _building := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)
	_build()
	ResourceLoader.load_threaded_request(SCENE_PATH)
	_started = true

func _build() -> void:
	var bg := ColorRect.new()
	# O ColorRect cobre o menu antigo e fica atras do desenho industrial feito
	# pelo proprio Control. Tambem bloqueia clique enquanto a carga acontece.
	bg.color = Color(0.035, 0.04, 0.045, 1.0)
	bg.show_behind_parent = true
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	move_child(bg, 0)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(900, 440)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.055, 0.06, 0.065, 0.96)
	card_style.border_color = Color(0.98, 0.67, 0.12, 0.82)
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(8)
	card_style.shadow_color = Color(0, 0, 0, 0.5)
	card_style.shadow_size = 20
	card_style.content_margin_left = 54
	card_style.content_margin_right = 54
	card_style.content_margin_top = 42
	card_style.content_margin_bottom = 38
	card.add_theme_stylebox_override("panel", card_style)
	center.add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	card.add_child(box)

	var eyebrow := Label.new()
	eyebrow.text = "▰  ABRINDO A PORTA DA OFICINA"
	eyebrow.add_theme_font_size_override("font_size", 15)
	eyebrow.add_theme_color_override("font_color", Color(0.98, 0.67, 0.12))
	box.add_child(eyebrow)

	var title := Label.new()
	title.text = "JEGUES MECÂNICOS"
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.95, 0.94, 0.89))
	box.add_child(title)

	var stages := HBoxContainer.new()
	stages.add_theme_constant_override("separation", 8)
	box.add_child(stages)
	for stage_text in ["01  FERRAMENTAS", "02  CIDADE", "03  NEGÓCIOS"]:
		var stage := Label.new()
		stage.text = stage_text
		stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stage.add_theme_font_size_override("font_size", 13)
		stage.add_theme_color_override("font_color", Color(0.53, 0.55, 0.56))
		stages.add_child(stage)
		_stage_labels.append(stage)

	var divider := HSeparator.new()
	divider.add_theme_constant_override("separation", 10)
	box.add_child(divider)

	var status_row := HBoxContainer.new()
	box.add_child(status_row)
	_status = Label.new()
	_status.text = "Separando as ferramentas…"
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.add_theme_font_size_override("font_size", 20)
	_status.add_theme_color_override("font_color", Color(0.82, 0.83, 0.8))
	status_row.add_child(_status)

	_percent = Label.new()
	_percent.text = "00%"
	_percent.add_theme_font_size_override("font_size", 22)
	_percent.add_theme_color_override("font_color", Color(0.98, 0.67, 0.12))
	status_row.add_child(_percent)

	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(0, 22)
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.value = 0.0
	_bar.show_percentage = false
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.12, 0.13, 0.135)
	bar_bg.border_color = Color(0.26, 0.27, 0.27)
	bar_bg.set_border_width_all(1)
	bar_bg.set_corner_radius_all(3)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.98, 0.67, 0.12)
	bar_fill.set_corner_radius_all(3)
	_bar.add_theme_stylebox_override("background", bar_bg)
	_bar.add_theme_stylebox_override("fill", bar_fill)
	box.add_child(_bar)

	var tip_card := PanelContainer.new()
	var tip_style := StyleBoxFlat.new()
	tip_style.bg_color = Color(0.09, 0.098, 0.102)
	tip_style.border_width_left = 4
	tip_style.border_color = Color(0.98, 0.67, 0.12, 0.7)
	tip_style.content_margin_left = 18
	tip_style.content_margin_right = 18
	tip_style.content_margin_top = 13
	tip_style.content_margin_bottom = 13
	tip_card.add_theme_stylebox_override("panel", tip_style)
	box.add_child(tip_card)
	var tip := Label.new()
	tip.text = "DICA DE QUEM ENTENDE\n" + TIPS[randi() % TIPS.size()]
	tip.add_theme_font_size_override("font_size", 15)
	tip.add_theme_color_override("font_color", Color(0.7, 0.71, 0.68))
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_card.add_child(tip)

	var disclaimer := Label.new()
	disclaimer.text = "Preparando carros usados, clientes desconfiados e soluções duvidosas."
	disclaimer.add_theme_font_size_override("font_size", 12)
	disclaimer.add_theme_color_override("font_color", Color(0.42, 0.44, 0.44))
	disclaimer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(disclaimer)

func _draw() -> void:
	var s := size
	# Fachada industrial abstrata, propositalmente discreta para o cartao manter
	# a leitura mesmo em monitores pequenos.
	draw_circle(Vector2(s.x * 0.13, s.y * 0.20), minf(s.x, s.y) * 0.14,
		Color(0.95, 0.52, 0.08, 0.18))
	for x in range(-80, int(s.x) + 160, 150):
		draw_line(Vector2(x, 0), Vector2(x + 330, s.y), Color(0.12, 0.13, 0.135, 0.26), 54.0)
	draw_rect(Rect2(0, s.y - 14.0, s.x, 14.0), Color(0.98, 0.67, 0.12))
	for x in range(-20, int(s.x) + 80, 76):
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, s.y), Vector2(x + 28, s.y - 14),
			Vector2(x + 54, s.y - 14), Vector2(x + 26, s.y)]), Color(0.04, 0.045, 0.05))

func _set_progress(value: float) -> void:
	_bar.value = value
	_percent.text = "%02d%%" % int(round(value * 100.0))
	var active_stage := 0
	if value >= 0.42:
		active_stage = 1
	if value >= 0.86:
		active_stage = 2
	for i in range(_stage_labels.size()):
		_stage_labels[i].add_theme_color_override("font_color",
			Color(0.98, 0.67, 0.12) if i <= active_stage else Color(0.42, 0.44, 0.45))

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
				_set_progress(float(progress[0]) * 0.85)
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
	_set_progress(0.88)
	_status.text = "Erguendo a cidade… só mais um instante"
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
	_set_progress(1.0)
	finished.emit()
	get_tree().change_scene_to_packed(packed)
